import 'dart:math';

class CalorieCalculator {
  /// MET (Metabolic Equivalent of Task) 기반 칼로리 계산
  /// 등산: 오르막 8.0, 내리막 3.5, 평지 6.0
  static int calculateHikingCalories({
    required double distanceKm,
    required int durationMinutes,
    required double elevationGainM,
    required double elevationLossM,
    double weightKg = 70.0,
  }) {
    if (durationMinutes <= 0 || distanceKm <= 0) return 0;

    // 오르막/내리막 비율 계산
    final totalElevationChange = elevationGainM + elevationLossM;
    final uphillRatio = totalElevationChange > 0
        ? elevationGainM / totalElevationChange
        : 0.5;

    // 평균 MET 계산 (오르막 8.0, 내리막 3.5 가중 평균)
    final avgMet = (8.0 * uphillRatio) + (3.5 * (1 - uphillRatio));

    // 칼로리 = MET * 체중(kg) * 시간(hour)
    final hours = durationMinutes / 60.0;
    final baseCalories = avgMet * weightKg * hours;

    // 고도 보정 (100m 상승당 +50kcal)
    final elevationBonus = (elevationGainM / 100) * 50;

    // 거리 보정 (km당 추가 소모)
    final distanceBonus = distanceKm * 10;

    return max(0, (baseCalories + elevationBonus + distanceBonus).round());
  }

  /// 간단한 칼로리 계산 (고도 데이터 없을 때)
  static int calculateSimpleCalories({
    required double distanceKm,
    required int durationMinutes,
    double weightKg = 70.0,
  }) {
    if (durationMinutes <= 0) return 0;

    // 평균 등산 MET = 6.0
    const avgMet = 6.0;
    final hours = durationMinutes / 60.0;
    final calories = avgMet * weightKg * hours;

    return max(0, calories.round());
  }
}
