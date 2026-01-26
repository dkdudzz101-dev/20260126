class OreumModel {
  static const String _storageBaseUrl = 'https://zsodcfgchbmmvpbwhuyu.supabase.co/storage/v1/object/public/oreum-data/';

  final String id;
  final String name;
  final String? trailName;
  final double? distance;
  final String? difficulty;
  final int? timeUp;
  final int? timeDown;
  final String? surface;
  final String? description;
  final String? _imageUrl;
  final String? _stampUrl;
  final String? _elevationUrl;
  final double? startLat;
  final double? startLng;
  final double? summitLat;
  final double? summitLng;
  final List<String> categories;
  final String? geojsonPath;
  final double? rating;
  final int? reviewCount;
  final String? forestCode;
  final String? address;
  final int? elevation;
  final String? parking;
  final String? restroom;
  final bool isActive;
  final bool isBeta;
  final String? restriction;
  final String? restrictionNote;
  final String? origin;

  OreumModel({
    required this.id,
    required this.name,
    this.trailName,
    this.distance,
    this.difficulty,
    this.timeUp,
    this.timeDown,
    this.surface,
    this.description,
    String? imageUrl,
    String? stampUrl,
    String? elevationUrl,
    this.startLat,
    this.startLng,
    this.summitLat,
    this.summitLng,
    this.categories = const [],
    this.geojsonPath,
    this.rating,
    this.reviewCount,
    this.forestCode,
    this.address,
    this.elevation,
    this.parking,
    this.restroom,
    this.isActive = true,
    this.isBeta = false,
    this.restriction,
    this.restrictionNote,
    this.origin,
  }) : _imageUrl = imageUrl, _stampUrl = stampUrl, _elevationUrl = elevationUrl;

  // 이미지 URL (상대경로 → 전체 URL 변환)
  String? get imageUrl {
    if (_imageUrl == null) return null;
    if (_imageUrl.startsWith('http')) return _imageUrl;
    return '$_storageBaseUrl$_imageUrl';
  }

  // 스탬프 URL (상대경로 → 전체 URL 변환)
  String? get stampUrl {
    if (_stampUrl == null) return null;
    if (_stampUrl.startsWith('http')) return _stampUrl;
    return '$_storageBaseUrl$_stampUrl';
  }

  // 고도 그래프 URL (상대경로 → 전체 URL 변환)
  String? get elevationUrl {
    if (_elevationUrl == null) return null;
    if (_elevationUrl.startsWith('http')) return _elevationUrl;
    return '$_storageBaseUrl$_elevationUrl';
  }

  // 총 소요시간 (분)
  int get totalTime => (timeUp ?? 0) + (timeDown ?? 0);

  // 소요시간 문자열
  String get timeString {
    final total = totalTime;
    if (total < 60) {
      return '$total분';
    } else {
      final hours = total ~/ 60;
      final minutes = total % 60;
      return minutes > 0 ? '$hours시간 $minutes분' : '$hours시간';
    }
  }

  // 거리 문자열
  String get distanceString {
    if (distance == null) return '-';
    return '${distance!.toStringAsFixed(2)}km';
  }

  // 난이도 색상
  String get difficultyColor {
    switch (difficulty) {
      case '쉬움':
        return 'easy';
      case '보통':
        return 'medium';
      case '어려움':
        return 'hard';
      default:
        return 'easy';
    }
  }

  factory OreumModel.fromJson(Map<String, dynamic> json) {
    return OreumModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      trailName: json['trail_name'],
      distance: json['distance']?.toDouble(),
      difficulty: json['difficulty'],
      timeUp: json['time_up'],
      timeDown: json['time_down'],
      surface: json['surface'],
      description: json['description'],
      imageUrl: json['image_url'],
      stampUrl: json['stamp_url'],
      elevationUrl: json['elevation_url'],
      startLat: json['start_lat']?.toDouble(),
      startLng: json['start_lng']?.toDouble(),
      summitLat: json['summit_lat']?.toDouble(),
      summitLng: json['summit_lng']?.toDouble(),
      categories: json['category'] != null
          ? List<String>.from(json['category'])
          : [],
      geojsonPath: json['geojson_path'],
      rating: json['rating']?.toDouble(),
      reviewCount: json['review_count'],
      forestCode: json['forest_code'],
      address: json['address'],
      elevation: json['elevation'],
      parking: json['parking'],
      restroom: json['restroom'],
      isActive: json['is_active'] ?? true,
      isBeta: json['is_beta'] ?? false,
      restriction: json['restriction'],
      restrictionNote: json['restriction_note'],
      origin: json['origin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trail_name': trailName,
      'distance': distance,
      'difficulty': difficulty,
      'time_up': timeUp,
      'time_down': timeDown,
      'surface': surface,
      'description': description,
      'image_url': _imageUrl,
      'stamp_url': _stampUrl,
      'elevation_url': _elevationUrl,
      'start_lat': startLat,
      'start_lng': startLng,
      'summit_lat': summitLat,
      'summit_lng': summitLng,
      'category': categories,
      'geojson_path': geojsonPath,
      'rating': rating,
      'review_count': reviewCount,
      'forest_code': forestCode,
      'address': address,
      'elevation': elevation,
      'parking': parking,
      'restroom': restroom,
      'is_active': isActive,
      'is_beta': isBeta,
      'restriction': restriction,
      'restriction_note': restrictionNote,
      'origin': origin,
    };
  }
}
