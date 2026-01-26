import 'dart:convert' show json, utf8;
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:proj4dart/proj4dart.dart';
import '../config/supabase_config.dart';

// 시설물 포인트 데이터
class FacilityPoint {
  final LatLng location;
  final String type; // 화장실, 쉼터, 시종점, 정상
  final String? name;
  final String? description;

  FacilityPoint({
    required this.location,
    required this.type,
    this.name,
    this.description,
  });
}

// 등산로 데이터 (트레일 + 시설물)
class TrailData {
  final List<LatLng> trailPoints;
  final List<List<LatLng>> trailSegments; // 분리된 등산로 세그먼트들
  final List<FacilityPoint> facilities;

  TrailData({
    required this.trailPoints,
    this.trailSegments = const [],
    required this.facilities,
  });
}

class TrailService {
  // 좌표 변환기 (EPSG:5186 한국중부원점 -> EPSG:4326 WGS84)
  static final _tmProjection = Projection.parse(
    '+proj=tmerc +lat_0=38 +lon_0=127 +k=1 +x_0=200000 +y_0=600000 +ellps=GRS80 +units=m +no_defs'
  );
  static final _wgs84Projection = Projection.WGS84;

  // Supabase 스토리지에서 GeoJSON 로드
  Future<List<LatLng>?> loadTrailFromSupabase(String oreumId) async {
    try {
      final url = SupabaseConfig.client.storage
          .from('oreum-data')
          .getPublicUrl('$oreumId/map.geojson');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final geojson = json.decode(utf8.decode(response.bodyBytes));
        return parseGeoJson(geojson);
      }
    } catch (e) {
      print('Error loading trail from Supabase: $e');
    }
    return null;
  }

  // Supabase에서 등산로 + 시설물 데이터 로드
  Future<TrailData?> loadTrailDataFromSupabase(String oreumId) async {
    try {
      final url = SupabaseConfig.client.storage
          .from('oreum-data')
          .getPublicUrl('$oreumId/map.geojson');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final geojson = json.decode(utf8.decode(response.bodyBytes));
        return parseGeoJsonWithFacilities(geojson);
      }
    } catch (e) {
      print('Error loading trail data from Supabase: $e');
    }
    return null;
  }

  // GeoJSON 파싱 (등산로 + 시설물)
  TrailData? parseGeoJsonWithFacilities(Map<String, dynamic> geojson) {
    try {
      final List<LatLng> trailPoints = [];
      final List<List<LatLng>> trailSegments = [];
      final List<FacilityPoint> facilities = [];

      // ESRI 형식 (TM 좌표) 처리
      if (_isEsriFormat(geojson)) {
        final features = geojson['features'] as List?;
        if (features != null) {
          for (final feature in features) {
            final geometry = feature['geometry'];
            if (geometry != null && geometry['paths'] != null) {
              // esriGeometryPolyline - 등산로
              for (final path in geometry['paths']) {
                final segment = <LatLng>[];
                for (final coord in path) {
                  final x = (coord[0] as num).toDouble();
                  final y = (coord[1] as num).toDouble();
                  final point = _tmToWgs84(x, y);
                  trailPoints.add(point);
                  segment.add(point);
                }
                if (segment.isNotEmpty) {
                  trailSegments.add(segment);
                }
              }
            }
          }
        }
        // ESRI 형식은 시설물 없이 등산로만 반환
        return trailPoints.isNotEmpty
            ? TrailData(trailPoints: trailPoints, trailSegments: trailSegments, facilities: [])
            : null;
      }

      // 표준 GeoJSON 처리
      if (geojson['type'] == 'FeatureCollection') {
        final features = geojson['features'] as List?;
        if (features != null) {
          for (final feature in features) {
            final geometry = feature['geometry'];
            final properties = feature['properties'] as Map<String, dynamic>?;

            if (geometry == null) continue;

            final type = geometry['type'];

            if (type == 'Point') {
              // 시설물 포인트 추출
              final coords = geometry['coordinates'];
              if (coords != null) {
                final location = LatLng(
                  (coords[1] as num).toDouble(),
                  (coords[0] as num).toDouble(),
                );

                // 시설물 타입 결정 (다양한 속성명 시도)
                String facilityType = properties?['MANAGE_SP2']
                    ?? properties?['DETAIL_SPO']
                    ?? properties?['type']
                    ?? properties?['name']
                    ?? properties?['시설물']
                    ?? properties?['종류']
                    ?? '';

                // 타입 정규화
                if (facilityType.contains('화장실') || facilityType.contains('toilet')) {
                  facilityType = '화장실';
                } else if (facilityType.contains('정상') || facilityType.contains('summit')) {
                  facilityType = '정상';
                } else if (facilityType.contains('시종점') || facilityType.contains('입구') || facilityType.contains('start') || facilityType.contains('end')) {
                  facilityType = '시종점';
                } else if (facilityType.contains('쉼터') || facilityType.contains('휴게') || facilityType.contains('rest')) {
                  facilityType = '쉼터';
                } else if (facilityType.contains('주차') || facilityType.contains('parking')) {
                  facilityType = '주차장';
                } else if (facilityType.contains('매점') || facilityType.contains('shop')) {
                  facilityType = '매점';
                } else if (facilityType.isEmpty) {
                  facilityType = '기타';
                }

                final description = properties?['DETAIL_SPO'] ?? properties?['description'] ?? '';

                facilities.add(FacilityPoint(
                  location: location,
                  type: facilityType,
                  description: description != facilityType ? description : '',
                ));
              }
            } else if (type == 'LineString') {
              // 단일 등산로 세그먼트 추출
              final segment = _extractLineStringCoords(geometry);
              if (segment.isNotEmpty) {
                trailSegments.add(segment);
                trailPoints.addAll(segment);
              }
            } else if (type == 'MultiLineString') {
              // 다중 등산로 세그먼트 추출 (각각 분리)
              final segments = _extractMultiLineStringCoords(geometry);
              for (final segment in segments) {
                if (segment.isNotEmpty) {
                  trailSegments.add(segment);
                  trailPoints.addAll(segment);
                }
              }
            }
          }
        }
      }

      if (trailPoints.isEmpty && facilities.isEmpty) return null;

      return TrailData(
        trailPoints: trailPoints,
        trailSegments: trailSegments,
        facilities: facilities,
      );
    } catch (e) {
      print('Error parsing GeoJSON with facilities: $e');
      return null;
    }
  }

  // LineString 좌표 추출
  List<LatLng> _extractLineStringCoords(Map<String, dynamic> geometry) {
    final coords = geometry['coordinates'];
    if (coords == null) return [];

    final List<LatLng> points = [];
    for (final coord in coords) {
      points.add(LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      ));
    }
    return points;
  }

  // MultiLineString 좌표 추출 (분리된 세그먼트들로)
  List<List<LatLng>> _extractMultiLineStringCoords(Map<String, dynamic> geometry) {
    final coords = geometry['coordinates'];
    if (coords == null) return [];

    final List<List<LatLng>> segments = [];
    for (final line in coords) {
      final segment = <LatLng>[];
      for (final coord in line) {
        segment.add(LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        ));
      }
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }
    return segments;
  }

  // 로컬 assets에서 GeoJSON 로드
  Future<List<LatLng>?> loadTrailFromAssets(String assetPath) async {
    try {
      // Flutter assets에서 로드하려면 rootBundle 필요
      // 여기서는 URL 로드만 지원
      return null;
    } catch (e) {
      print('Error loading trail from assets: $e');
    }
    return null;
  }

  // URL에서 GeoJSON 로드
  Future<List<LatLng>?> loadTrailFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final geojson = json.decode(utf8.decode(response.bodyBytes));
        return parseGeoJson(geojson);
      }
    } catch (e) {
      print('Error loading trail from URL: $e');
    }
    return null;
  }

  // TM 좌표를 WGS84로 변환
  LatLng _tmToWgs84(double x, double y) {
    final tmPoint = Point(x: x, y: y);
    final wgs84Point = _tmProjection.transform(_wgs84Projection, tmPoint);
    return LatLng(wgs84Point.y, wgs84Point.x);
  }

  // ESRI 형식인지 확인 (TM 좌표)
  bool _isEsriFormat(Map<String, dynamic> geojson) {
    return geojson.containsKey('geometryType') &&
           geojson.containsKey('spatialReference') &&
           geojson.containsKey('features');
  }

  // GeoJSON 파싱
  List<LatLng>? parseGeoJson(Map<String, dynamic> geojson) {
    try {
      final List<LatLng> points = [];

      // ESRI 형식 (TM 좌표) 처리
      if (_isEsriFormat(geojson)) {
        final features = geojson['features'] as List?;
        if (features != null) {
          for (final feature in features) {
            final geometry = feature['geometry'];
            if (geometry != null && geometry['paths'] != null) {
              // esriGeometryPolyline
              for (final path in geometry['paths']) {
                for (final coord in path) {
                  final x = (coord[0] as num).toDouble();
                  final y = (coord[1] as num).toDouble();
                  points.add(_tmToWgs84(x, y));
                }
              }
            }
          }
        }
        return points.isNotEmpty ? points : null;
      }

      // 표준 GeoJSON 처리
      if (geojson['type'] == 'FeatureCollection') {
        final features = geojson['features'] as List?;
        if (features != null) {
          for (final feature in features) {
            final coords = _extractCoordinates(feature['geometry']);
            points.addAll(coords);
          }
        }
      } else if (geojson['type'] == 'Feature') {
        final coords = _extractCoordinates(geojson['geometry']);
        points.addAll(coords);
      } else {
        // 직접 geometry인 경우
        final coords = _extractCoordinates(geojson);
        points.addAll(coords);
      }

      return points.isNotEmpty ? points : null;
    } catch (e) {
      print('Error parsing GeoJSON: $e');
      return null;
    }
  }

  // Geometry에서 좌표 추출 (LineString만 추출, Point는 무시)
  List<LatLng> _extractCoordinates(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    final List<LatLng> points = [];
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (coordinates == null) return [];

    switch (type) {
      case 'Point':
        // Point는 시설물 위치이므로 등산로에서 제외
        break;

      case 'LineString':
        // [[lng, lat], [lng, lat], ...]
        for (final coord in coordinates) {
          points.add(LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          ));
        }
        break;

      case 'MultiLineString':
        // [[[lng, lat], ...], [[lng, lat], ...]]
        // 각 라인 세그먼트 사이에 끊김 없이 연결하면 이상한 선이 생김
        // 첫 번째 라인만 사용하거나 모든 라인을 순서대로 연결
        for (final line in coordinates) {
          for (final coord in line) {
            points.add(LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            ));
          }
        }
        break;

      case 'Polygon':
        // Polygon은 등산로가 아니므로 제외
        break;

      case 'MultiPolygon':
        // MultiPolygon은 등산로가 아니므로 제외
        break;
    }

    return points;
  }

  // 등산로 Polyline 생성
  Polyline createTrailPolyline({
    required String id,
    required List<LatLng> points,
    int strokeColor = 0xFFFF6B35, // 주황색
    int strokeWidth = 4,
  }) {
    return Polyline(
      polylineId: id,
      points: points,
      strokeColor: Color(strokeColor),
      strokeWidth: strokeWidth,
    );
  }

  // 등산로 총 거리 계산 (미터)
  double calculateTrailDistance(List<LatLng> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += _haversineDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  // Haversine 공식으로 거리 계산
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // 미터

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  double _sin(double x) => _sinApprox(x);
  double _cos(double x) => _sinApprox(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _sqrtApprox(x) : 0;
  double _atan2(double y, double x) => _atan2Approx(y, x);

  // 근사 함수들
  double _sinApprox(double x) {
    // Taylor series approximation
    x = x % (2 * 3.141592653589793);
    if (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    if (x < -3.141592653589793) x += 2 * 3.141592653589793;

    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _sqrtApprox(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2Approx(double y, double x) {
    if (x > 0) return _atanApprox(y / x);
    if (x < 0 && y >= 0) return _atanApprox(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atanApprox(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _atanApprox(double x) {
    // 간단한 근사
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atanApprox(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}

