import 'package:flutter/material.dart';
import '../models/body_battery.dart';
import '../services/watch_data_collector.dart';
import '../widgets/battery_gauge.dart';

/// 워치 전용 홈 화면 - 주 데이터 수집 및 표시
class WatchHomeScreen extends StatefulWidget {
  const WatchHomeScreen({super.key});

  @override
  State<WatchHomeScreen> createState() => _WatchHomeScreenState();
}

class _WatchHomeScreenState extends State<WatchHomeScreen> {
  late WatchDataCollector _dataCollector;
  BodyBattery? _currentBattery;
  bool _isLoading = true;
  bool _isConnectedToPhone = false;
  bool _isMonitoring = false;
  
  @override
  void initState() {
    super.initState();
    _initializeDataCollector();
  }
  
  Future<void> _initializeDataCollector() async {
    _dataCollector = WatchDataCollector();
    
    final initialized = await _dataCollector.initialize();
    if (initialized) {
      // 배터리 스트림 구독
      _dataCollector.batteryStream.listen((battery) {
        if (mounted) {
          setState(() {
            _currentBattery = battery;
          });
        }
      });
      
      // 배경 동기화 시작
      _dataCollector.startBackgroundSync();
      
      setState(() {
        _currentBattery = _dataCollector.getCurrentBattery();
        _isConnectedToPhone = _dataCollector.isConnectedToPhone;
        _isMonitoring = _dataCollector.isMonitoring;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _dataCollector.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isRoundWatch = size.width == size.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _buildContent(context, isRoundWatch),
    );
  }
  
  Widget _buildContent(BuildContext context, bool isRoundWatch) {
    if (_currentBattery == null) {
      return const Center(
        child: Text(
          '데이터 수집 중...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    
    return GestureDetector(
      onTap: _toggleMonitoring,
      onLongPress: _showOptionsMenu,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: EdgeInsets.all(isRoundWatch ? 16 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 상태 표시줄
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isConnectedToPhone)
                    const Icon(
                      Icons.phone_android,
                      color: Colors.green,
                      size: 14,
                    ),
                  if (_isMonitoring) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.sensors,
                      color: Colors.blue,
                      size: 14,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              
              // 배터리 게이지
              BatteryGauge(
                battery: _currentBattery!,
                size: MediaQuery.of(context).size.width * 0.55,
              ),
              
              const SizedBox(height: 8),
              
              // 상태 텍스트
              Text(
                _currentBattery!.statusText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // 레벨 설명
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _currentBattery!.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentBattery!.levelDescription.split(' - ')[0],
                  style: TextStyle(
                    color: _currentBattery!.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 6),
              
              // 추천사항 (간단히)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  _getShortRecommendation(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getShortRecommendation() {
    final recommendation = _currentBattery!.recommendation;
    // 짧은 버전으로 변환
    if (recommendation.contains('매우 낮습니다')) {
      return '즉시 휴식 필요';
    } else if (recommendation.contains('가벼운 활동')) {
      return '가벼운 활동 권장';
    } else if (recommendation.contains('일상 활동')) {
      return '일상 활동 가능';
    } else if (recommendation.contains('활발한 활동')) {
      return '활발한 활동 가능';
    } else if (recommendation.contains('최상의 컨디션')) {
      return '최상의 컨디션!';
    }
    return '적절한 휴식 유지';
  }
  
  void _toggleMonitoring() {
    if (_isMonitoring) {
      _dataCollector.stopRealTimeMonitoring();
    } else {
      _dataCollector.startRealTimeMonitoring();
    }
    
    setState(() {
      _isMonitoring = !_isMonitoring;
    });
    
    // 햅틱 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMonitoring ? '실시간 모니터링 시작' : '모니터링 중지',
          style: const TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: _isMonitoring ? Colors.green : Colors.grey,
      ),
    );
  }
  
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.sync,
                color: Colors.white,
                size: 20,
              ),
              title: const Text(
                '데이터 동기화',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(context);
                _dataCollector.startBackgroundSync();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('동기화 시작', style: TextStyle(fontSize: 12)),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                _isConnectedToPhone ? Icons.phone_disabled : Icons.phone_android,
                color: Colors.white,
                size: 20,
              ),
              title: Text(
                _isConnectedToPhone ? '폰 연결 끊기' : '폰 연결',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(context);
                // 연결/끊기 로직
              },
            ),
          ],
        ),
      ),
    );
  }
}