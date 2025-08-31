import 'package:flutter/cupertino.dart';
import 'package:health/health.dart';
import '../models/health_data.dart';

class HealthService {
  final Health _health = Health();

  static final List<HealthDataType> dataTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<bool> requestAuthorization() async {
    try {
      final permissions = dataTypes.map((e) => HealthDataAccess.READ).toList();
      return await _health.requestAuthorization(
        dataTypes,
        permissions: permissions,
      );
    } catch (e) {
      debugPrint('권한 요청 실패: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      return await _health.hasPermissions(dataTypes) ?? false;
    } catch (e) {
      debugPrint('권한 확인 실패: $e');
      return false;
    }
  }

  Future<HealthData?> getLatestHealthData() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 1));

      // 헬스 데이터 가져오기
      final healthData = await _health.getHealthDataFromTypes(
        types: dataTypes,
        startTime: start,
        endTime: now,
      );

      if (healthData.isEmpty) return null;

      // 최신 데이터 추출
      int? heartRate;
      double? hrv;
      int steps = 0;

      for (final data in healthData) {
        switch (data.type) {
          case HealthDataType.HEART_RATE:
            final value = data.value;
            if (value is NumericHealthValue) {
              heartRate = value.numericValue.toInt();
            }
            break;
          case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
            final value = data.value;
            if (value is NumericHealthValue) {
              hrv = value.numericValue.toDouble();
            }
            break;
          case HealthDataType.STEPS:
            final value = data.value;
            if (value is NumericHealthValue) {
              steps += value.numericValue.toInt();
            }
            break;
          default:
            break;
        }
      }

      return HealthData(
        timestamp: now,
        heartRate: heartRate,
        heartRateVariability: hrv,
        steps: steps,
      );
    } catch (e) {
      debugPrint('헬스 데이터 가져오기 실패: $e');
      return null;
    }
  }

  Future<SleepData?> getSleepData(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final sleepTypes = [
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_AWAKE,
      ];

      final healthData = await _health.getHealthDataFromTypes(
        types: sleepTypes,
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (healthData.isEmpty) return null;

      int deepSleep = 0;
      int remSleep = 0;
      int lightSleep = 0;
      int awake = 0;
      DateTime? firstSleep;
      DateTime? lastSleep;

      for (final data in healthData) {
        final value = data.value;
        if (value is NumericHealthValue) {
          final minutes = value.numericValue.toInt();

          firstSleep ??= data.dateFrom;
          lastSleep = data.dateTo;

          switch (data.type) {
            case HealthDataType.SLEEP_DEEP:
              deepSleep += minutes;
              break;
            case HealthDataType.SLEEP_REM:
              remSleep += minutes;
              break;
            case HealthDataType.SLEEP_LIGHT:
              lightSleep += minutes;
              break;
            case HealthDataType.SLEEP_AWAKE:
              awake += minutes;
              break;
            default:
              break;
          }
        }
      }

      if (firstSleep == null || lastSleep == null) return null;

      final totalSleep = deepSleep + remSleep + lightSleep;
      final quality = _calculateSleepQuality(
        deepSleep,
        remSleep,
        lightSleep,
        awake,
        totalSleep,
      );

      return SleepData(
        startTime: firstSleep,
        endTime: lastSleep,
        deepSleepMinutes: deepSleep,
        remSleepMinutes: remSleep,
        lightSleepMinutes: lightSleep,
        awakeMinutes: awake,
        quality: quality,
      );
    } catch (e) {
      debugPrint('수면 데이터 가져오기 실패: $e');
      return null;
    }
  }

  Future<List<ActivityData>> getActivityData(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT, HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      final activities = <ActivityData>[];

      for (final data in healthData) {
        if (data.type == HealthDataType.WORKOUT) {
          final value = data.value;
          if (value is WorkoutHealthValue) {
            final duration = data.dateTo.difference(data.dateFrom).inMinutes;

            activities.add(
              ActivityData(
                type: _mapWorkoutType(value.workoutActivityType),
                durationMinutes: duration,
                intensity: _estimateIntensity(value.workoutActivityType),
                caloriesBurned: value.totalEnergyBurned?.toInt() ?? 0,
              ),
            );
          }
        }
      }

      return activities;
    } catch (e) {
      debugPrint('활동 데이터 가져오기 실패: $e');
      return [];
    }
  }

  double _calculateSleepQuality(
    int deep,
    int rem,
    int light,
    int awake,
    int total,
  ) {
    if (total == 0) return 0;

    // 수면 단계별 가중치
    final deepScore = (deep / total) * 40;
    final remScore = (rem / total) * 30;
    final lightScore = (light / total) * 20;
    final awakeDeduction = (awake / total) * 30;

    // 총 수면 시간 점수
    final durationScore = (total / 480).clamp(0, 1) * 10; // 8시간 기준

    return (deepScore + remScore + lightScore + durationScore - awakeDeduction)
        .clamp(0, 100);
  }

  String _mapWorkoutType(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
        return 'running';
      case HealthWorkoutActivityType.WALKING:
        return 'walking';
      case HealthWorkoutActivityType.BIKING:
        return 'cycling';
      default:
        return 'exercise';
    }
  }

  double _estimateIntensity(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
        return 80;
      case HealthWorkoutActivityType.BIKING:
        return 70;
      case HealthWorkoutActivityType.WALKING:
        return 40;
      default:
        return 60;
    }
  }
}
