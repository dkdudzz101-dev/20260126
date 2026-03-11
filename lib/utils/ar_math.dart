import 'dart:math';

/// 내 위치(lat1, lng1)에서 목표(lat2, lng2) 방향의 방위각(bearing)을 계산한다.
/// 반환값: 0~360도 (북=0, 동=90, 남=180, 서=270)
double calculateBearing(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final dLng = _toRad(lng2 - lng1);
  final lat1Rad = _toRad(lat1);
  final lat2Rad = _toRad(lat2);

  final y = sin(dLng) * cos(lat2Rad);
  final x = cos(lat1Rad) * sin(lat2Rad) -
      sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

  final bearing = atan2(y, x);
  return (_toDeg(bearing) + 360) % 360;
}

/// 나침반 방향(compassHeading)과 오름 방위각(oreumBearing)의 차이를 이용해
/// 카메라 화면 상 X 좌표 비율(-1 ~ +1)을 계산한다.
/// FOV(시야각) 범위를 벗어나면 null 반환.
double? oreumScreenX({
  required double compassHeading,
  required double oreumBearing,
  double fov = 60.0,
}) {
  double diff = oreumBearing - compassHeading;

  // -180 ~ +180 범위로 정규화
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;

  final halfFov = fov / 2;
  if (diff.abs() > halfFov) return null;

  // -1(왼쪽) ~ +1(오른쪽)
  return diff / halfFov;
}

/// 거리(m)에 따른 글자 크기 선형 보간.
/// 0m → maxSize, maxDistance → minSize
double labelFontSize(
  double distanceMeters, {
  double maxDistance = 10000,
  double minSize = 12,
  double maxSize = 24,
}) {
  final t = (distanceMeters / maxDistance).clamp(0.0, 1.0);
  return maxSize - (maxSize - minSize) * t;
}

double _toRad(double deg) => deg * pi / 180;
double _toDeg(double rad) => rad * 180 / pi;
