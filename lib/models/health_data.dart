class HealthData {
  final DateTime timestamp;
  final int? heartRate;
  final double? heartRateVariability;
  final int? steps;
  final SleepData? sleepData;
  final ActivityData? activityData;
  final double? stressLevel;

  HealthData({
    required this.timestamp,
    this.heartRate,
    this.heartRateVariability,
    this.steps,
    this.sleepData,
    this.activityData,
    this.stressLevel,
  });

  double calculateStress() {
    if (heartRateVariability == null || heartRate == null) return 50.0;
    
    // HRV 기반 스트레스 계산 (간단한 모델)
    double baseStress = 50.0;
    
    // HRV가 낮을수록 스트레스가 높음
    if (heartRateVariability! < 20) {
      baseStress += 30;
    } else if (heartRateVariability! < 50) {
      baseStress += 15;
    } else if (heartRateVariability! > 100) {
      baseStress -= 20;
    }
    
    // 심박수가 높을수록 스트레스가 높음
    if (heartRate! > 100) {
      baseStress += 20;
    } else if (heartRate! > 80) {
      baseStress += 10;
    } else if (heartRate! < 60) {
      baseStress -= 10;
    }
    
    return baseStress.clamp(0, 100);
  }
}

class SleepData {
  final DateTime startTime;
  final DateTime endTime;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int lightSleepMinutes;
  final int awakeMinutes;
  final double quality; // 0-100

  SleepData({
    required this.startTime,
    required this.endTime,
    required this.deepSleepMinutes,
    required this.remSleepMinutes,
    required this.lightSleepMinutes,
    required this.awakeMinutes,
    required this.quality,
  });

  int get totalMinutes => deepSleepMinutes + remSleepMinutes + lightSleepMinutes;
  
  int getTotalSleepMinutes() => totalMinutes;
  
  double calculateRecoveryScore() {
    // 깊은 수면과 REM 수면이 회복에 중요
    double deepScore = (deepSleepMinutes / 90) * 40; // 90분이 이상적
    double remScore = (remSleepMinutes / 120) * 30; // 120분이 이상적
    double totalScore = (totalMinutes / 480) * 30; // 8시간이 이상적
    
    return (deepScore + remScore + totalScore).clamp(0, 100);
  }
}

class ActivityData {
  final String type; // 'exercise', 'walking', 'running', 'cycling'
  final int durationMinutes;
  final double intensity; // 0-100
  final int caloriesBurned;

  ActivityData({
    required this.type,
    required this.durationMinutes,
    required this.intensity,
    required this.caloriesBurned,
  });

  double calculateEnergyDrain() {
    // 강도와 지속시간에 따른 에너지 소모 계산
    double baseDrain = (intensity / 100) * (durationMinutes / 60) * 20;
    
    // 활동 유형에 따른 보정
    switch (type) {
      case 'exercise':
        return baseDrain * 1.5;
      case 'running':
        return baseDrain * 1.3;
      case 'cycling':
        return baseDrain * 1.2;
      case 'walking':
        return baseDrain * 0.7;
      default:
        return baseDrain;
    }
  }
}