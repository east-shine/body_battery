import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/health_data.dart';
import '../models/body_battery.dart';

/// 워치와 폰 간 데이터 동기화 서비스
/// Wear Data Layer API를 사용한 양방향 통신
/// 
/// 주의: 실제 구현을 위해서는 네이티브 Android 코드 구현이 필요합니다.
/// 현재는 Mock 구현으로 대체되어 있습니다.
class DataSyncService {
  static const platform = MethodChannel('body_battery/wear_data');
  
  StreamController<Map<String, dynamic>>? _dataStreamController;
  StreamController<String>? _commandStreamController;
  
  Timer? _syncTimer;
  bool _isConnected = false;
  String? _pairedDeviceId = 'mock_device';
  
  // 데이터 수신 스트림
  Stream<Map<String, dynamic>> get dataStream {
    _dataStreamController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _dataStreamController!.stream;
  }
  
  // 명령 수신 스트림 (워치용)
  Stream<String> get commandStream {
    _commandStreamController ??= StreamController<String>.broadcast();
    return _commandStreamController!.stream;
  }
  
  /// 서비스 초기화
  Future<bool> initialize() async {
    try {
      // Mock 구현: 항상 연결된 것으로 가정
      _isConnected = true;
      _pairedDeviceId = 'mock_device';
      
      debugPrint('DataSyncService Mock 초기화 완료');
      debugPrint('실제 구현을 위해서는 네이티브 코드가 필요합니다');
      
      // 메시지 리스너 설정
      _setupMockMessageListener();
      
      // 연결 상태 모니터링
      _startConnectionMonitoring();
      
      return true;
    } catch (e) {
      debugPrint('DataSyncService 초기화 실패: $e');
      return false;
    }
  }
  
  /// Mock 메시지 리스너 설정
  void _setupMockMessageListener() {
    // Mock 구현: 5초마다 가짜 데이터 생성
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected && _dataStreamController != null) {
        final mockBatteryData = {
          'type': 'battery',
          'level': 50 + DateTime.now().second % 50,
          'status': 'BatteryStatus.stable',
          'changeRate': -0.5,
          'recommendation': '적당한 활동을 유지하세요',
          'timestamp': DateTime.now().toIso8601String(),
        };
        _dataStreamController!.add(mockBatteryData);
      }
    });
  }
  
  /// 연결 상태 모니터링
  void _startConnectionMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (_) async {
      // Mock 구현: 항상 연결 상태 유지
      _isConnected = true;
    });
  }
  
  /// Body Battery 데이터 전송 (워치 → 폰)
  Future<void> sendBatteryData(BodyBattery battery) async {
    if (!_isConnected || _pairedDeviceId == null) {
      debugPrint('디바이스 연결되지 않음');
      return;
    }
    
    final data = {
      'type': 'battery',
      'level': battery.level,
      'status': battery.status.toString(),
      'changeRate': battery.changeRate,
      'recommendation': battery.recommendation,
      'timestamp': battery.timestamp.toIso8601String(),
    };
    
    try {
      // Mock 구현: 데이터를 로컬 스트림으로 전송
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
      debugPrint('Battery 데이터 전송 (Mock): ${battery.level}%');
    } catch (e) {
      debugPrint('Battery 데이터 전송 실패: $e');
    }
  }
  
  /// 헬스 데이터 전송 (워치 → 폰)
  Future<void> sendHealthData(HealthData healthData) async {
    if (!_isConnected || _pairedDeviceId == null) {
      debugPrint('디바이스 연결되지 않음');
      return;
    }
    
    final data = {
      'type': 'health',
      'heartRate': healthData.heartRate,
      'hrv': healthData.heartRateVariability,
      'steps': healthData.steps,
      'stressLevel': healthData.stressLevel,
      'timestamp': healthData.timestamp.toIso8601String(),
    };
    
    try {
      // Mock 구현
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
      debugPrint('Health 데이터 전송 (Mock)');
    } catch (e) {
      debugPrint('Health 데이터 전송 실패: $e');
    }
  }
  
  /// 수면 데이터 전송 (워치 → 폰)
  Future<void> sendSleepData(SleepData sleepData) async {
    if (!_isConnected || _pairedDeviceId == null) return;
    
    final data = {
      'type': 'sleep',
      'startTime': sleepData.startTime.toIso8601String(),
      'endTime': sleepData.endTime.toIso8601String(),
      'deepSleep': sleepData.deepSleepMinutes,
      'remSleep': sleepData.remSleepMinutes,
      'lightSleep': sleepData.lightSleepMinutes,
      'awake': sleepData.awakeMinutes,
      'quality': sleepData.quality,
    };
    
    try {
      // Mock 구현
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
      debugPrint('Sleep 데이터 전송 (Mock)');
    } catch (e) {
      debugPrint('Sleep 데이터 전송 실패: $e');
    }
  }
  
  /// 활동 데이터 전송 (워치 → 폰)
  Future<void> sendActivityData(List<ActivityData> activities) async {
    if (!_isConnected || _pairedDeviceId == null) return;
    
    final data = {
      'type': 'activities',
      'activities': activities.map((a) => {
        'type': a.type,
        'duration': a.durationMinutes,
        'intensity': a.intensity,
        'calories': a.caloriesBurned,
      }).toList(),
    };
    
    try {
      // Mock 구현
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
      debugPrint('Activity 데이터 전송 (Mock): ${activities.length}개');
    } catch (e) {
      debugPrint('Activity 데이터 전송 실패: $e');
    }
  }
  
  /// 명령 전송 (폰 → 워치)
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _pairedDeviceId == null) {
      debugPrint('디바이스 연결되지 않음');
      return;
    }
    
    try {
      // Mock 구현
      if (_commandStreamController != null) {
        _commandStreamController!.add(command);
      }
      debugPrint('명령 전송 (Mock): $command');
    } catch (e) {
      debugPrint('명령 전송 실패: $e');
    }
  }
  
  /// 데이터 동기화 요청 (폰 → 워치)
  Future<void> requestSync() async {
    await sendCommand('sync');
  }
  
  /// 실시간 모니터링 시작 요청 (폰 → 워치)
  Future<void> requestStartMonitoring() async {
    await sendCommand('start_monitoring');
  }
  
  /// 실시간 모니터링 중지 요청 (폰 → 워치)
  Future<void> requestStopMonitoring() async {
    await sendCommand('stop_monitoring');
  }
  
  /// 주기적 동기화 시작 (워치용)
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      // 현재 데이터를 폰으로 전송하도록 트리거
      debugPrint('주기적 동기화 실행 (Mock)');
    });
  }
  
  /// 주기적 동기화 중지
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  /// 연결 상태 확인
  bool get isConnected => _isConnected;
  
  /// 페어링된 디바이스 ID
  String? get pairedDeviceId => _pairedDeviceId;
  
  /// 연결 재시도
  Future<bool> reconnect() async {
    debugPrint('재연결 시도 (Mock)...');
    _isConnected = true;
    _pairedDeviceId = 'mock_device';
    
    return true;
  }
  
  void dispose() {
    _syncTimer?.cancel();
    _dataStreamController?.close();
    _commandStreamController?.close();
  }
}