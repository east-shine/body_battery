import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/health_data.dart';

/// Wear OS Health Services API를 사용한 센서 데이터 직접 수집
/// 워치 전용 - 실시간 센서 접근
class WearHealthService {
  static const platform = MethodChannel('com.body_battery/health_services');
  
  StreamController<HealthData>? _dataStreamController;
  Timer? _passiveMonitoringTimer;
  
  // 지원되는 데이터 타입
  static const List<String> supportedDataTypes = [
    'HEART_RATE',
    'HEART_RATE_VARIABILITY',
    'STRESS_LEVEL',
    'STEPS',
    'CALORIES',
    'OXYGEN_SATURATION',
    'BODY_TEMPERATURE',
    'RESPIRATORY_RATE',
  ];

  /// Health Services 초기화 및 권한 확인
  Future<bool> initialize() async {
    try {
      final result = await platform.invokeMethod('initialize');
      debugPrint('Health Services 초기화: $result');
      
      // result가 Map인 경우 success 필드 확인
      if (result is Map) {
        return result['success'] == true;
      }
      return result as bool;
    } catch (e) {
      debugPrint('Health Services 초기화 실패: $e');
      return false;
    }
  }

  /// 실시간 센서 데이터 스트림
  Stream<HealthData> get dataStream {
    _dataStreamController ??= StreamController<HealthData>.broadcast();
    return _dataStreamController!.stream;
  }

  /// 패시브 모니터링 시작 (배터리 효율적)
  Future<void> startPassiveMonitoring() async {
    try {
      // Native 패시브 모니터링 시작
      await platform.invokeMethod('startPassiveMonitoring', {
        'dataTypes': supportedDataTypes,
        'intervalMinutes': 5,
      });
      
      // 주기적으로 데이터 가져오기
      _passiveMonitoringTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _fetchLatestData(),
      );
      
      debugPrint('패시브 모니터링 시작됨');
    } catch (e) {
      debugPrint('패시브 모니터링 시작 실패: $e');
    }
  }

  /// 패시브 모니터링 중지
  Future<void> stopPassiveMonitoring() async {
    _passiveMonitoringTimer?.cancel();
    try {
      await platform.invokeMethod('stopPassiveMonitoring');
      debugPrint('패시브 모니터링 중지됨');
    } catch (e) {
      debugPrint('패시브 모니터링 중지 실패: $e');
    }
  }

  /// 현재 센서 데이터 즉시 가져오기
  Future<HealthData?> getCurrentData() async {
    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod('getCurrentData');
      
      return HealthData(
        timestamp: DateTime.now(),
        heartRate: result['heartRate'] as int?,
        heartRateVariability: result['hrv'] as double?,
        steps: result['steps'] as int?,
        stressLevel: result['stressLevel'] as double?,
      );
    } catch (e) {
      debugPrint('현재 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// 스트레스 레벨 직접 가져오기 (Health Services 전용)
  Future<double?> getStressLevel() async {
    try {
      final result = await platform.invokeMethod('getStressLevel');
      return result as double?;
    } catch (e) {
      debugPrint('스트레스 레벨 가져오기 실패: $e');
      return null;
    }
  }

  /// 수면 데이터 가져오기
  Future<SleepData?> getSleepData(DateTime date) async {
    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod('getSleepData', {
        'date': date.millisecondsSinceEpoch,
      });
      
      if (result.isEmpty) return null;
      
      return SleepData(
        startTime: DateTime.fromMillisecondsSinceEpoch(result['startTime']),
        endTime: DateTime.fromMillisecondsSinceEpoch(result['endTime']),
        deepSleepMinutes: result['deepSleepMinutes'] ?? 0,
        remSleepMinutes: result['remSleepMinutes'] ?? 0,
        lightSleepMinutes: result['lightSleepMinutes'] ?? 0,
        awakeMinutes: result['awakeMinutes'] ?? 0,
        quality: result['quality'] ?? 75.0,
      );
    } catch (e) {
      debugPrint('수면 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// 운동 데이터 가져오기
  Future<List<ActivityData>> getActivityData(DateTime date) async {
    try {
      final List<dynamic> results = await platform.invokeMethod('getActivityData', {
        'date': date.millisecondsSinceEpoch,
      });
      
      return results.map((data) => ActivityData(
        type: data['type'] as String,
        durationMinutes: data['durationMinutes'] as int,
        intensity: data['intensity'] as double,
        caloriesBurned: data['caloriesBurned'] as int,
      )).toList();
    } catch (e) {
      debugPrint('활동 데이터 가져오기 실패: $e');
      return [];
    }
  }

  /// 배터리 효율적인 구독 모드
  Future<void> subscribeToDataUpdates() async {
    try {
      // Native 메서드 채널로 이벤트 구독
      const EventChannel eventChannel = EventChannel('com.body_battery/health_events');
      
      eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(event);
          final healthData = HealthData(
            timestamp: DateTime.now(),
            heartRate: data['heartRate'] as int?,
            heartRateVariability: data['hrv'] as double?,
            steps: data['steps'] as int?,
            stressLevel: data['stressLevel'] as double?,
          );
          
          _dataStreamController?.add(healthData);
        },
        onError: (dynamic error) {
          debugPrint('데이터 구독 오류: $error');
        },
      );
    } catch (e) {
      debugPrint('데이터 구독 실패: $e');
    }
  }

  /// 최신 데이터 가져오기 (내부용)
  Future<void> _fetchLatestData() async {
    final data = await getCurrentData();
    if (data != null && _dataStreamController != null) {
      _dataStreamController!.add(data);
    }
  }

  /// 수면 품질 계산
  double _calculateSleepQuality(Map<dynamic, dynamic> sleepData) {
    final deep = sleepData['deepSleepMinutes'] ?? 0;
    final rem = sleepData['remSleepMinutes'] ?? 0;
    final light = sleepData['lightSleepMinutes'] ?? 0;
    final awake = sleepData['awakeMinutes'] ?? 0;
    final total = deep + rem + light;
    
    if (total == 0) return 0;
    
    final deepScore = (deep / total) * 40;
    final remScore = (rem / total) * 30;
    final lightScore = (light / total) * 20;
    final awakeDeduction = (awake / total) * 30;
    final durationScore = (total / 480).clamp(0, 1) * 10;
    
    return (deepScore + remScore + lightScore + durationScore - awakeDeduction)
        .clamp(0, 100);
  }

  void dispose() {
    _passiveMonitoringTimer?.cancel();
    _dataStreamController?.close();
  }
}