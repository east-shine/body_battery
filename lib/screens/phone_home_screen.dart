import 'package:flutter/material.dart';
import '../models/body_battery.dart';
import '../models/health_data.dart';
import '../services/phone_data_receiver.dart';
import '../widgets/battery_gauge.dart';
import 'detail_screen.dart';

/// 폰 전용 홈 화면 - 워치 데이터 수신 및 상세 표시
class PhoneHomeScreen extends StatefulWidget {
  const PhoneHomeScreen({super.key});

  @override
  State<PhoneHomeScreen> createState() => _PhoneHomeScreenState();
}

class _PhoneHomeScreenState extends State<PhoneHomeScreen> {
  late PhoneDataReceiver _dataReceiver;
  BodyBattery? _currentBattery;
  HealthData? _latestHealthData;
  SleepData? _latestSleepData;
  List<ActivityData> _latestActivities = [];
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _initializeDataReceiver();
  }

  Future<void> _initializeDataReceiver() async {
    _dataReceiver = PhoneDataReceiver();

    _isConnected = await _dataReceiver.initialize();

    if (_isConnected) {
      // 데이터 스트림 구독
      _dataReceiver.batteryStream.listen((battery) {
        if (mounted) {
          setState(() {
            _currentBattery = battery;
          });
        }
      });

      _dataReceiver.healthStream.listen((health) {
        if (mounted) {
          setState(() {
            _latestHealthData = health;
          });
        }
      });

      _dataReceiver.sleepStream.listen((sleep) {
        if (mounted) {
          setState(() {
            _latestSleepData = sleep;
          });
        }
      });

      _dataReceiver.activityStream.listen((activities) {
        if (mounted) {
          setState(() {
            _latestActivities = activities;
          });
        }
      });

      setState(() {
        _currentBattery = _dataReceiver.latestBattery;
        _latestHealthData = _dataReceiver.latestHealthData;
        _latestSleepData = _dataReceiver.latestSleepData;
        _latestActivities = _dataReceiver.latestActivities;
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
    _dataReceiver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : !_isConnected
              ? _buildConnectionError(context)
              : _buildMainContent(context),
    );
  }

  Widget _buildConnectionError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.watch_off, size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              '워치와 연결되지 않음',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '워치 앱이 실행 중인지 확인하고\n블루투스가 켜져 있는지 확인하세요',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                await _initializeDataReceiver();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('재연결'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_currentBattery == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              '워치에서 데이터 수신 중...',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _dataReceiver.requestFullSync(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('데이터 동기화'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            Center(child: BatteryGauge(battery: _currentBattery!, size: 280)),
            const SizedBox(height: 30),
            _buildStatusCard(),
            const SizedBox(height: 20),
            if (_latestHealthData != null) ...[
              _buildHealthCard(),
              const SizedBox(height: 20),
            ],
            if (_latestSleepData != null) ...[
              _buildSleepCard(),
              const SizedBox(height: 20),
            ],
            if (_latestActivities.isNotEmpty) ...[
              _buildActivityCard(),
              const SizedBox(height: 20),
            ],
            _buildRecommendationCard(),
            const SizedBox(height: 20),
            _buildPredictionCard(),
            const SizedBox(height: 20),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Body Battery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.watch,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? '워치 연결됨' : '연결 끊김',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
                if (_isMonitoring) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.sensors, color: Colors.blue, size: 14),
                  const SizedBox(width: 4),
                  const Text(
                    '실시간',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ],
            ),
            Text(
              '업데이트: ${_formatTime(_currentBattery!.timestamp)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.sync, color: Colors.white),
          onPressed: () => _dataReceiver.requestFullSync(),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final changePrefix = _currentBattery!.changeRate > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '상태',
            _currentBattery!.statusText,
            _currentBattery!.status == BatteryStatus.charging
                ? Icons.battery_charging_full
                : Icons.battery_std,
          ),
          _buildStatItem(
            '변화율',
            '$changePrefix${_currentBattery!.changeRate.toStringAsFixed(1)}/분',
            _currentBattery!.changeRate > 0
                ? Icons.trending_up
                : Icons.trending_down,
          ),
          _buildStatItem(
            '레벨',
            _currentBattery!.levelDescription.split(' - ')[0],
            Icons.signal_cellular_alt,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '헬스 데이터',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (_latestHealthData!.heartRate != null)
                _buildHealthItem(
                  '심박수',
                  '${_latestHealthData!.heartRate} bpm',
                  Icons.favorite,
                  Colors.red,
                ),
              if (_latestHealthData!.stressLevel != null)
                _buildHealthItem(
                  '스트레스',
                  '${_latestHealthData!.stressLevel!.round()}%',
                  Icons.psychology,
                  Colors.orange,
                ),
              if (_latestHealthData!.steps != null)
                _buildHealthItem(
                  '걸음수',
                  '${_latestHealthData!.steps}',
                  Icons.directions_walk,
                  Colors.green,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard() {
    final totalSleep = _latestSleepData!.getTotalSleepMinutes();
    final hours = totalSleep ~/ 60;
    final minutes = totalSleep % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수면 데이터',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.bedtime, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Text(
                '$hours시간 $minutes분',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '품질: ${_latestSleepData!.quality.round()}%',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 활동',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ..._latestActivities
              .take(3)
              .map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getActivityIcon(activity.type),
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getActivityName(activity.type),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        '${activity.durationMinutes}분',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activity.caloriesBurned} kcal',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _currentBattery!.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _currentBattery!.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: _currentBattery!.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentBattery!.recommendation,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    final in1Hour = _dataReceiver.predictBatteryLevel(const Duration(hours: 1));
    final in3Hours = _dataReceiver.predictBatteryLevel(
      const Duration(hours: 3),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '예상 배터리 레벨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPredictionItem('1시간 후', in1Hour),
              _buildPredictionItem('3시간 후', in3Hours),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              if (_isMonitoring) {
                await _dataReceiver.stopRealTimeMonitoring();
              } else {
                await _dataReceiver.startRealTimeMonitoring();
              }
              setState(() {
                _isMonitoring = !_isMonitoring;
              });
            },
            icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
            label: Text(_isMonitoring ? '모니터링 중지' : '실시간 모니터링'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMonitoring ? Colors.orange : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _navigateToDetail(context),
            icon: const Icon(Icons.analytics),
            label: const Text('상세 분석'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _currentBattery!.color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionItem(String label, int level) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            BatteryIcon(level: level, size: 32),
            const SizedBox(width: 8),
            Text(
              '$level%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'running':
        return Icons.directions_run;
      case 'walking':
        return Icons.directions_walk;
      case 'cycling':
        return Icons.directions_bike;
      case 'exercise':
        return Icons.fitness_center;
      default:
        return Icons.sports;
    }
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(dataReceiver: _dataReceiver),
      ),
    );
  }
}
