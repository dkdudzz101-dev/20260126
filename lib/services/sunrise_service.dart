import 'dart:math';

class SunriseSunsetService {
  // 제주도 기본 좌표 (제주시 기준)
  static const double _jejuLat = 33.4890;
  static const double _jejuLng = 126.4983;

  // 일출/일몰 시간 계산 (제주도 기준)
  static SunTimes getTodaySunTimes({double? lat, double? lng}) {
    final latitude = lat ?? _jejuLat;
    final longitude = lng ?? _jejuLng;
    final now = DateTime.now();

    return _calculateSunTimes(now, latitude, longitude);
  }

  static SunTimes _calculateSunTimes(DateTime date, double lat, double lng) {
    // 연중 일수 (1월 1일 = 1)
    final dayOfYear = _getDayOfYear(date);

    // 태양 적위 (Solar Declination)
    final declination = 23.45 * sin(_toRadians(360 / 365 * (dayOfYear - 81)));

    // 시간각 (Hour Angle)
    final cosHourAngle = -tan(_toRadians(lat)) * tan(_toRadians(declination));

    // 극지방 체크 (일출/일몰이 없는 경우)
    if (cosHourAngle < -1 || cosHourAngle > 1) {
      return SunTimes(
        sunrise: DateTime(date.year, date.month, date.day, 6, 0),
        sunset: DateTime(date.year, date.month, date.day, 18, 0),
        isApproximate: true,
      );
    }

    final hourAngle = _toDegrees(acos(cosHourAngle));

    // 균시차 (Equation of Time) - 분 단위
    final b = 360 / 365 * (dayOfYear - 81);
    final eot = 9.87 * sin(_toRadians(2 * b)) -
                7.53 * cos(_toRadians(b)) -
                1.5 * sin(_toRadians(b));

    // 태양 정오 시간 (Solar Noon) - UTC 기준
    // 한국 표준시는 UTC+9, 경도 135도 기준
    final solarNoonMinutes = 720 - 4 * lng - eot + 9 * 60; // KST 보정

    // 일출/일몰 시간 (분)
    final sunriseMinutes = solarNoonMinutes - hourAngle * 4;
    final sunsetMinutes = solarNoonMinutes + hourAngle * 4;

    return SunTimes(
      sunrise: _minutesToDateTime(date, sunriseMinutes),
      sunset: _minutesToDateTime(date, sunsetMinutes),
      isApproximate: false,
    );
  }

  static int _getDayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
  static double _toDegrees(double radians) => radians * 180 / pi;

  static DateTime _minutesToDateTime(DateTime date, double minutes) {
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    return DateTime(date.year, date.month, date.day, hours.clamp(0, 23), mins.clamp(0, 59));
  }
}

class SunTimes {
  final DateTime sunrise;
  final DateTime sunset;
  final bool isApproximate;

  SunTimes({
    required this.sunrise,
    required this.sunset,
    this.isApproximate = false,
  });

  String get sunriseFormatted => _formatTime(sunrise);
  String get sunsetFormatted => _formatTime(sunset);

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 현재 시간 기준 상태
  String get currentStatus {
    final now = DateTime.now();
    if (now.isBefore(sunrise)) {
      final diff = sunrise.difference(now);
      if (diff.inMinutes < 60) {
        return '일출까지 ${diff.inMinutes}분';
      }
      return '일출 전';
    } else if (now.isBefore(sunset)) {
      return '낮';
    } else {
      return '일몰 후';
    }
  }
}
