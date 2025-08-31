import 'dart:async';
import 'dart:convert';
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
      // 네이티브 플러그인 초기화
      final result = await platform.invokeMethod('initialize');
      
      if (result == true) {
        debugPrint('DataSyncService 초기화 완료');
        
        // 연결된 디바이스 확인
        await _checkConnectedDevices();
        
        // 메시지 리스너 설정
        _setupMessageListener();
        
        // 연결 상태 모니터링
        _startConnectionMonitoring();
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DataSyncService 초기화 실패: $e');
      // Mock 모드로 폴백
      _isConnected = true;
      _pairedDeviceId = 'mock_device';
      return true;
    }
  }
  
  /// 메시지 리스너 설정  
  void _setupMessageListener() {
    // 네이티브 코드에서 메서드 호출을 받기 위한 설정
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDataReceived':
          final data = Map<String, dynamic>.from(call.arguments);
          _dataStreamController?.add(data);
          break;
        case 'onCommandReceived':
          final command = call.arguments['command'] as String;
          _commandStreamController?.add(command);
          break;
        case 'onConnectionChanged':
          _isConnected = call.arguments['connected'] as bool;
          if (call.arguments['deviceIds'] != null) {
            final devices = List<String>.from(call.arguments['deviceIds']);
            _pairedDeviceId = devices.isNotEmpty ? devices.first : null;
          }
          break;
        case 'onSyncRequested':
          // 동기화 요청 처리
          debugPrint('동기화 요청 수신: ${call.arguments['from']}');
          break;
      }
    });
  }
  
  /// 연결된 디바이스 확인
  Future<void> _checkConnectedDevices() async {
    try {
      final devices = await platform.invokeMethod('getConnectedDevices');
      if (devices is List && devices.isNotEmpty) {
        _isConnected = true;
        _pairedDeviceId = devices.first['id'];
        debugPrint('연결된 디바이스: $_pairedDeviceId');
      } else {
        _isConnected = false;
        _pairedDeviceId = null;
      }
    } catch (e) {
      debugPrint('디바이스 확인 실패: $e');
    }
  }
  
  /// 연결 상태 모니터링
  void _startConnectionMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (_) async {
      // 주기적으로 연결 상태 확인
      await _checkConnectedDevices();
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
      // 네이티브 코드를 통해 데이터 전송
      await platform.invokeMethod('sendData', {
        'path': '/body_battery/battery',
        'data': jsonEncode(data),
      });
      debugPrint('Battery 데이터 전송 완료: ${battery.level}%');
    } catch (e) {
      debugPrint('Battery 데이터 전송 실패: $e');
      // 폴백: 로컬 스트림으로 전송
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
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
      // 네이티브 코드를 통해 데이터 전송
      await platform.invokeMethod('sendData', {
        'path': '/body_battery/health',
        'data': jsonEncode(data),
      });
      debugPrint('Health 데이터 전송 완료');
    } catch (e) {
      debugPrint('Health 데이터 전송 실패: $e');
      // 폴백: 로컬 스트림으로 전송
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
    }
  }
  
  /// 수면 데이터 전송 (워치 → 폰)
  Future<void> sendSleepData(SleepData sleepData) async {
    if (!_isConnected || _pairedDeviceId == null) {
      debugPrint('디바이스 연결되지 않음');
      return;
    }
    
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
      // 네이티브 코드를 통해 데이터 전송
      await platform.invokeMethod('sendData', {
        'path': '/body_battery/sleep',
        'data': jsonEncode(data),
      });
      debugPrint('Sleep 데이터 전송 완료');
    } catch (e) {
      debugPrint('Sleep 데이터 전송 실패: $e');
      // 폴백: 로컬 스트림으로 전송
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
    }
  }
  
  /// 활동 데이터 전송 (워치 → 폰)
  Future<void> sendActivityData(List<ActivityData> activities) async {
    if (!_isConnected || _pairedDeviceId == null) {
      debugPrint('디바이스 연결되지 않음');
      return;
    }
    
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
      // 네이티브 코드를 통해 데이터 전송
      await platform.invokeMethod('sendData', {
        'path': '/body_battery/activities',
        'data': jsonEncode(data),
      });
      debugPrint('Activity 데이터 전송 완료: ${activities.length}개');
    } catch (e) {
      debugPrint('Activity 데이터 전송 실패: $e');
      // 폴백: 로컬 스트림으로 전송
      if (_dataStreamController != null) {
        _dataStreamController!.add(data);
      }
    }
  }
  
  /// 명령 전송 (폰 → 워치)
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _pairedDeviceId == null) {
      debugPrint('디바이스 연결되지 않음');
      return;
    }
    
    try {
      // 네이티브 코드를 통해 명령 전송
      await platform.invokeMethod('sendMessage', {
        'deviceId': _pairedDeviceId,
        'path': '/body_battery/command',
        'data': command,
      });
      debugPrint('명령 전송 완료: $command');
    } catch (e) {
      debugPrint('명령 전송 실패: $e');
      // 폴백: 로컬 스트림으로 전송
      if (_commandStreamController != null) {
        _commandStreamController!.add(command);
      }
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
    _syncTimer = Timer.periodic(interval, (_) async {
      // 현재 데이터를 폰으로 전송하도록 트리거
      debugPrint('주기적 동기화 실행');
      await requestSync();
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
    debugPrint('재연결 시도...');
    
    try {
      // 네이티브 코드를 통해 재연결
      final result = await platform.invokeMethod('reconnect');
      if (result == true) {
        await _checkConnectedDevices();
        return _isConnected;
      }
      return false;
    } catch (e) {
      debugPrint('재연결 실패: $e');
      // Mock 모드로 폴백
      _isConnected = true;
      _pairedDeviceId = 'mock_device';
      return true;
    }
  }
  
  void dispose() {
    _syncTimer?.cancel();
    _dataStreamController?.close();
    _commandStreamController?.close();
  }
}