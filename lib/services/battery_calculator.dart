import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/body_battery.dart';
import '../models/health_data.dart';
import 'wear_health_service.dart';

class BatteryCalculator {
  final WearHealthService _healthService;
  
  static const String _batteryLevelKey = 'body_battery_level';
  static const String _lastUpdateKey = 'body_battery_last_update';
  
  Timer? _updateTimer;
  StreamController<BodyBattery>? _batteryStreamController;
  
  int _currentLevel = 50;
  DateTime _lastUpdate = DateTime.now();
  BatteryStatus _status = BatteryStatus.stable;
  double _changeRate = 0.0;
  
  final List<BatteryHistory> _history = [];
  
  BatteryCalculator(this._healthService);
  
  Stream<BodyBattery> get batteryStream {
    _batteryStreamController ??= StreamController<BodyBattery>.broadcast();
    return _batteryStreamController!.stream;
  }
  
  Future<void> initialize() async {
    await _loadSavedBattery();
    await updateBatteryLevel();
    _startPeriodicUpdate();
  }
  
  void dispose() {
    _updateTimer?.cancel();
    _batteryStreamController?.close();
  }
  
  Future<void> _loadSavedBattery() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLevel = prefs.getInt(_batteryLevelKey) ?? 50;
    
    final lastUpdateMillis = prefs.getInt(_lastUpdateKey);
    if (lastUpdateMillis != null) {
      _lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis);
      
      // 마지막 업데이트 이후 시간에 따른 자연 회복/소모 계산
      final hoursSinceUpdate = DateTime.now().difference(_lastUpdate).inHours;
      if (hoursSinceUpdate > 0) {
        // 기본적으로 시간당 2포인트 회복 (수면 중이면 더 많이)
        _currentLevel = (_currentLevel + (hoursSinceUpdate * 2)).clamp(0, 100);
      }
    }
  }
  
  Future<void> _saveBattery() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_batteryLevelKey, _currentLevel);
    await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      updateBatteryLevel();
    });
  }
  
  Future<void> updateBatteryLevel() async {
    final now = DateTime.now();
    final healthData = await _healthService.getCurrentData();
    final sleepData = await _healthService.getSleepData(now);
    final activities = await _healthService.getActivityData(now);
    
    double deltaChange = 0;
    String currentActivity = '일상 활동';
    
    // 수면 데이터 처리
    if (sleepData != null && _isCurrentlySleeping(sleepData)) {
      final recoveryScore = sleepData.calculateRecoveryScore();
      deltaChange = (recoveryScore / 100) * 15; // 수면 중 회복
      _status = BatteryStatus.charging;
      currentActivity = '수면 중';
    } 
    // 활동 데이터 처리
    else if (activities.isNotEmpty) {
      final recentActivity = activities.last;
      deltaChange = -recentActivity.calculateEnergyDrain();
      _status = BatteryStatus.draining;
      currentActivity = _getActivityName(recentActivity.type);
    }
    // 일반 상태 처리
    else if (healthData != null) {
      final stress = healthData.stressLevel ?? healthData.calculateStress();
      
      if (stress > 70) {
        deltaChange = -3; // 높은 스트레스
        _status = BatteryStatus.draining;
        currentActivity = '스트레스 상태';
      } else if (stress < 30) {
        deltaChange = 2; // 낮은 스트레스 (휴식)
        _status = BatteryStatus.charging;
        currentActivity = '휴식 중';
      } else {
        deltaChange = -0.5; // 일반 활동
        _status = BatteryStatus.stable;
      }
      
      // 심박수 기반 조정
      if (healthData.heartRate != null) {
        if (healthData.heartRate! > 100) {
          deltaChange -= 2;
        } else if (healthData.heartRate! < 60) {
          deltaChange += 1;
        }
      }
    }
    
    // 시간 기반 자연 변화
    final hour = now.hour;
    if (hour >= 22 || hour < 6) {
      deltaChange += 1; // 야간 회복 보너스
    }
    
    // 레벨 업데이트
    final timeDiffMinutes = now.difference(_lastUpdate).inMinutes;
    if (timeDiffMinutes > 0) {
      _changeRate = deltaChange / timeDiffMinutes;
      _currentLevel = (_currentLevel + (deltaChange * timeDiffMinutes / 60)).round().clamp(0, 100);
    }
    
    _lastUpdate = now;
    
    // 히스토리 추가
    _history.add(BatteryHistory(
      time: now,
      level: _currentLevel,
      activity: currentActivity,
    ));
    
    // 24시간 이상 된 히스토리 제거
    _history.removeWhere((h) => now.difference(h.time).inHours > 24);
    
    // 배터리 상태 업데이트 및 저장
    final battery = BodyBattery(
      level: _currentLevel,
      timestamp: now,
      status: _status,
      changeRate: _changeRate,
      recommendation: _getRecommendation(),
    );
    
    _batteryStreamController?.add(battery);
    await _saveBattery();
  }
  
  bool _isCurrentlySleeping(SleepData sleepData) {
    final now = DateTime.now();
    return now.isAfter(sleepData.startTime) && now.isBefore(sleepData.endTime);
  }
  
  String _getActivityName(String type) {
    switch (type) {
      case 'running':
        return '달리기';
      case 'walking':
        return '걷기';
      case 'cycling':
        return '자전거';
      case 'exercise':
        return '운동';
      default:
        return '활동';
    }
  }
  
  String _getRecommendation() {
    final hour = DateTime.now().hour;
    
    if (_currentLevel < 20) {
      return '에너지가 매우 낮습니다. 즉시 휴식을 취하세요.';
    } else if (_currentLevel < 40) {
      if (hour >= 20) {
        return '충분한 수면을 위해 일찍 잠자리에 드세요.';
      }
      return '가벼운 활동만 하고 휴식을 취하세요.';
    } else if (_currentLevel < 60) {
      return '일상 활동에 적합한 수준입니다.';
    } else if (_currentLevel < 80) {
      if (hour >= 6 && hour <= 18) {
        return '활발한 활동이 가능합니다.';
      }
      return '내일을 위해 에너지를 아껴두세요.';
    } else {
      return '최상의 컨디션! 도전적인 활동을 시작하기 좋습니다.';
    }
  }
  
  List<BatteryHistory> getHistory() => List.unmodifiable(_history);
  
  BodyBattery getCurrentBattery() {
    return BodyBattery(
      level: _currentLevel,
      timestamp: _lastUpdate,
      status: _status,
      changeRate: _changeRate,
      recommendation: _getRecommendation(),
    );
  }
  
  // 예측 기능
  int predictBatteryLevel(Duration duration) {
    final predictedChange = _changeRate * duration.inMinutes;
    return (_currentLevel + predictedChange).round().clamp(0, 100);
  }
}