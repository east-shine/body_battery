import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data_sync_service.dart';
import '../models/health_data.dart';
import '../models/body_battery.dart';

/// 폰에서 실행되는 데이터 수신 및 관리 서비스
class PhoneDataReceiver {
  final DataSyncService _syncService = DataSyncService();
  
  // 데이터 스트림 컨트롤러
  final StreamController<BodyBattery> _batteryStreamController = 
      StreamController<BodyBattery>.broadcast();
  final StreamController<HealthData> _healthStreamController = 
      StreamController<HealthData>.broadcast();
  final StreamController<SleepData> _sleepStreamController = 
      StreamController<SleepData>.broadcast();
  final StreamController<List<ActivityData>> _activityStreamController = 
      StreamController<List<ActivityData>>.broadcast();
  
  // 최신 데이터 캐시
  BodyBattery? _latestBattery;
  HealthData? _latestHealthData;
  SleepData? _latestSleepData;
  List<ActivityData> _latestActivities = [];
  final List<BatteryHistory> _batteryHistory = [];
  
  // 연결 상태
  bool _isConnected = false;
  Timer? _reconnectTimer;
  
  // 데이터 스트림
  Stream<BodyBattery> get batteryStream => _batteryStreamController.stream;
  Stream<HealthData> get healthStream => _healthStreamController.stream;
  Stream<SleepData> get sleepStream => _sleepStreamController.stream;
  Stream<List<ActivityData>> get activityStream => _activityStreamController.stream;
  
  /// 서비스 초기화
  Future<bool> initialize() async {
    try {
      // 데이터 동기화 서비스 초기화
      _isConnected = await _syncService.initialize();
      
      if (_isConnected) {
        debugPrint('워치와 연결됨');
        _setupDataListener();
        
        // 초기 데이터 요청
        await requestFullSync();
      } else {
        debugPrint('워치와 연결 실패');
        _startReconnectTimer();
      }
      
      return _isConnected;
    } catch (e) {
      debugPrint('PhoneDataReceiver 초기화 실패: $e');
      return false;
    }
  }
  
  /// 데이터 리스너 설정
  void _setupDataListener() {
    _syncService.dataStream.listen((data) {
      debugPrint('데이터 수신: ${data['type']}');
      
      switch (data['type']) {
        case 'battery':
          _handleBatteryData(data);
          break;
        case 'health':
          _handleHealthData(data);
          break;
        case 'sleep':
          _handleSleepData(data);
          break;
        case 'activities':
          _handleActivityData(data);
          break;
        default:
          debugPrint('알 수 없는 데이터 타입: ${data['type']}');
      }
    });
  }
  
  /// Battery 데이터 처리
  void _handleBatteryData(Map<String, dynamic> data) {
    try {
      final status = BatteryStatus.values.firstWhere(
        (s) => s.toString() == data['status'],
        orElse: () => BatteryStatus.stable,
      );
      
      _latestBattery = BodyBattery(
        level: data['level'] as int,
        timestamp: DateTime.parse(data['timestamp']),
        status: status,
        changeRate: (data['changeRate'] as num).toDouble(),
        recommendation: data['recommendation'] as String,
      );
      
      // 히스토리 추가
      _batteryHistory.add(BatteryHistory(
        time: _latestBattery!.timestamp,
        level: _latestBattery!.level,
        activity: '워치 데이터',
      ));
      
      // 24시간 이상 된 히스토리 제거
      final now = DateTime.now();
      _batteryHistory.removeWhere((h) => now.difference(h.time).inHours > 24);
      
      _batteryStreamController.add(_latestBattery!);
      debugPrint('Battery 데이터 업데이트: ${_latestBattery!.level}%');
    } catch (e) {
      debugPrint('Battery 데이터 처리 실패: $e');
    }
  }
  
  /// Health 데이터 처리
  void _handleHealthData(Map<String, dynamic> data) {
    try {
      _latestHealthData = HealthData(
        timestamp: DateTime.parse(data['timestamp']),
        heartRate: data['heartRate'] as int?,
        heartRateVariability: data['hrv'] as double?,
        steps: data['steps'] as int?,
        stressLevel: data['stressLevel'] as double?,
      );
      
      _healthStreamController.add(_latestHealthData!);
      debugPrint('Health 데이터 업데이트: HR=${_latestHealthData!.heartRate}');
    } catch (e) {
      debugPrint('Health 데이터 처리 실패: $e');
    }
  }
  
  /// Sleep 데이터 처리
  void _handleSleepData(Map<String, dynamic> data) {
    try {
      _latestSleepData = SleepData(
        startTime: DateTime.parse(data['startTime']),
        endTime: DateTime.parse(data['endTime']),
        deepSleepMinutes: data['deepSleep'] as int,
        remSleepMinutes: data['remSleep'] as int,
        lightSleepMinutes: data['lightSleep'] as int,
        awakeMinutes: data['awake'] as int,
        quality: (data['quality'] as num).toDouble(),
      );
      
      _sleepStreamController.add(_latestSleepData!);
      debugPrint('Sleep 데이터 업데이트');
    } catch (e) {
      debugPrint('Sleep 데이터 처리 실패: $e');
    }
  }
  
  /// Activity 데이터 처리
  void _handleActivityData(Map<String, dynamic> data) {
    try {
      final activities = (data['activities'] as List).map((a) => 
        ActivityData(
          type: a['type'] as String,
          durationMinutes: a['duration'] as int,
          intensity: (a['intensity'] as num).toDouble(),
          caloriesBurned: a['calories'] as int,
        )
      ).toList();
      
      _latestActivities = activities;
      _activityStreamController.add(_latestActivities);
      debugPrint('Activity 데이터 업데이트: ${_latestActivities.length}개');
    } catch (e) {
      debugPrint('Activity 데이터 처리 실패: $e');
    }
  }
  
  /// 전체 데이터 동기화 요청
  Future<void> requestFullSync() async {
    debugPrint('전체 동기화 요청');
    await _syncService.requestSync();
  }
  
  /// 실시간 모니터링 시작 요청
  Future<void> startRealTimeMonitoring() async {
    debugPrint('실시간 모니터링 시작 요청');
    await _syncService.requestStartMonitoring();
  }
  
  /// 실시간 모니터링 중지 요청
  Future<void> stopRealTimeMonitoring() async {
    debugPrint('실시간 모니터링 중지 요청');
    await _syncService.requestStopMonitoring();
  }
  
  /// 재연결 타이머 시작
  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      debugPrint('워치 재연결 시도');
      _isConnected = await _syncService.reconnect();
      
      if (_isConnected) {
        debugPrint('워치 재연결 성공');
        _reconnectTimer?.cancel();
        _setupDataListener();
        await requestFullSync();
      }
    });
  }
  
  /// 최신 데이터 가져오기
  BodyBattery? get latestBattery => _latestBattery;
  HealthData? get latestHealthData => _latestHealthData;
  SleepData? get latestSleepData => _latestSleepData;
  List<ActivityData> get latestActivities => _latestActivities;
  List<BatteryHistory> get batteryHistory => List.unmodifiable(_batteryHistory);
  
  /// 연결 상태 확인
  bool get isConnected => _isConnected;
  
  /// 예측 기능 (히스토리 기반)
  int predictBatteryLevel(Duration duration) {
    if (_batteryHistory.length < 2 || _latestBattery == null) {
      return _latestBattery?.level ?? 50;
    }
    
    // 최근 변화율 계산
    final recent = _batteryHistory.last;
    final previous = _batteryHistory[_batteryHistory.length - 2];
    final timeDiff = recent.time.difference(previous.time).inMinutes;
    
    if (timeDiff == 0) return _latestBattery!.level;
    
    final changeRate = (recent.level - previous.level) / timeDiff;
    final predictedChange = changeRate * duration.inMinutes;
    
    return (_latestBattery!.level + predictedChange).round().clamp(0, 100);
  }
  
  void dispose() {
    _reconnectTimer?.cancel();
    _batteryStreamController.close();
    _healthStreamController.close();
    _sleepStreamController.close();
    _activityStreamController.close();
    _syncService.dispose();
  }
}