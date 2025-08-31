import 'dart:async';
import 'package:flutter/foundation.dart';
import 'wear_health_service.dart';
import 'data_sync_service.dart';
import 'battery_calculator.dart';
import '../models/body_battery.dart';
import '../models/health_data.dart';

/// 워치에서 실행되는 메인 데이터 수집 및 전송 서비스
class WatchDataCollector {
  final WearHealthService _healthService = WearHealthService();
  final DataSyncService _syncService = DataSyncService();
  late BatteryCalculator _batteryCalculator;
  
  Timer? _dataCollectionTimer;
  Timer? _batterySyncTimer;
  bool _isMonitoring = false;
  
  // 수집 주기
  static const Duration _healthDataInterval = Duration(minutes: 1);
  static const Duration _batteryDataInterval = Duration(minutes: 5);
  
  /// 서비스 초기화
  Future<bool> initialize() async {
    try {
      // Health Services 초기화
      final healthInit = await _healthService.initialize();
      if (!healthInit) {
        debugPrint('Health Services 초기화 실패');
        return false;
      }
      
      // 데이터 동기화 서비스 초기화
      final syncInit = await _syncService.initialize();
      if (!syncInit) {
        debugPrint('Data Sync Service 초기화 실패');
        // 폰과 연결되지 않아도 로컬에서는 동작
      }
      
      // Battery Calculator 초기화 (워치 로컬용)
      _batteryCalculator = BatteryCalculator(_healthService);
      await _batteryCalculator.initialize();
      
      // 명령 리스너 설정
      _setupCommandListener();
      
      // 패시브 모니터링 시작
      await _healthService.startPassiveMonitoring();
      
      debugPrint('WatchDataCollector 초기화 완료');
      return true;
    } catch (e) {
      debugPrint('WatchDataCollector 초기화 실패: $e');
      return false;
    }
  }
  
  /// 폰으로부터의 명령 리스너 설정
  void _setupCommandListener() {
    _syncService.commandStream.listen((command) {
      debugPrint('명령 수신: $command');
      
      switch (command) {
        case 'sync':
          _performFullSync();
          break;
        case 'start_monitoring':
          startRealTimeMonitoring();
          break;
        case 'stop_monitoring':
          stopRealTimeMonitoring();
          break;
        default:
          debugPrint('알 수 없는 명령: $command');
      }
    });
  }
  
  /// 실시간 모니터링 시작
  void startRealTimeMonitoring() {
    if (_isMonitoring) {
      debugPrint('이미 모니터링 중');
      return;
    }
    
    _isMonitoring = true;
    
    // 헬스 데이터 수집 타이머
    _dataCollectionTimer = Timer.periodic(_healthDataInterval, (_) async {
      await _collectAndSendHealthData();
    });
    
    // 배터리 데이터 동기화 타이머
    _batterySyncTimer = Timer.periodic(_batteryDataInterval, (_) async {
      await _collectAndSendBatteryData();
    });
    
    // Health Services 이벤트 구독
    _healthService.subscribeToDataUpdates();
    _healthService.dataStream.listen((healthData) {
      // 실시간 데이터 즉시 전송
      _syncService.sendHealthData(healthData);
    });
    
    debugPrint('실시간 모니터링 시작됨');
  }
  
  /// 실시간 모니터링 중지
  void stopRealTimeMonitoring() {
    _isMonitoring = false;
    _dataCollectionTimer?.cancel();
    _batterySyncTimer?.cancel();
    
    debugPrint('실시간 모니터링 중지됨');
  }
  
  /// 헬스 데이터 수집 및 전송
  Future<void> _collectAndSendHealthData() async {
    try {
      var healthData = await _healthService.getCurrentData();
      if (healthData != null) {
        // 스트레스 레벨 추가 수집
        final stressLevel = await _healthService.getStressLevel();
        if (stressLevel != null) {
          // 새로운 HealthData 객체 생성 (final 필드이므로)
          healthData = HealthData(
            timestamp: healthData.timestamp,
            heartRate: healthData.heartRate,
            heartRateVariability: healthData.heartRateVariability,
            steps: healthData.steps,
            sleepData: healthData.sleepData,
            activityData: healthData.activityData,
            stressLevel: stressLevel,
          );
        }
        
        // 폰으로 전송
        await _syncService.sendHealthData(healthData);
        
        debugPrint('헬스 데이터 전송: HR=${healthData.heartRate}, Stress=${healthData.stressLevel}');
      }
    } catch (e) {
      debugPrint('헬스 데이터 수집 실패: $e');
    }
  }
  
  /// 배터리 데이터 수집 및 전송
  Future<void> _collectAndSendBatteryData() async {
    try {
      // 최신 데이터로 배터리 계산
      await _batteryCalculator.updateBatteryLevel();
      final battery = _batteryCalculator.getCurrentBattery();
      
      // 폰으로 전송
      await _syncService.sendBatteryData(battery);
      
      debugPrint('배터리 데이터 전송: ${battery.level}%');
    } catch (e) {
      debugPrint('배터리 데이터 전송 실패: $e');
    }
  }
  
  /// 전체 데이터 동기화
  Future<void> _performFullSync() async {
    debugPrint('전체 동기화 시작');
    
    try {
      // 현재 헬스 데이터
      await _collectAndSendHealthData();
      
      // 배터리 데이터
      await _collectAndSendBatteryData();
      
      // 오늘 수면 데이터
      final today = DateTime.now();
      final sleepData = await _healthService.getSleepData(today);
      if (sleepData != null) {
        await _syncService.sendSleepData(sleepData);
      }
      
      // 오늘 활동 데이터
      final activities = await _healthService.getActivityData(today);
      if (activities.isNotEmpty) {
        await _syncService.sendActivityData(activities);
      }
      
      debugPrint('전체 동기화 완료');
    } catch (e) {
      debugPrint('전체 동기화 실패: $e');
    }
  }
  
  /// 배경 동기화 시작 (5분마다)
  void startBackgroundSync() {
    _syncService.startPeriodicSync(
      interval: const Duration(minutes: 5),
    );
    
    // 주기적으로 데이터 전송
    Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_isMonitoring) {
        // 실시간 모니터링 중이 아닐 때만 배경 동기화
        await _collectAndSendBatteryData();
      }
    });
  }
  
  /// 현재 배터리 레벨 가져오기 (워치 로컬 표시용)
  BodyBattery getCurrentBattery() {
    return _batteryCalculator.getCurrentBattery();
  }
  
  /// 배터리 스트림 (워치 로컬 UI 업데이트용)
  Stream<BodyBattery> get batteryStream => _batteryCalculator.batteryStream;
  
  /// 연결 상태 확인
  bool get isConnectedToPhone => _syncService.isConnected;
  
  /// 모니터링 상태 확인
  bool get isMonitoring => _isMonitoring;
  
  void dispose() {
    stopRealTimeMonitoring();
    _syncService.stopPeriodicSync();
    _healthService.stopPassiveMonitoring();
    _healthService.dispose();
    _syncService.dispose();
    _batteryCalculator.dispose();
  }
}