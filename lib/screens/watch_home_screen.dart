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

  // 실시간 센서 데이터
  int? _currentHeartRate;
  double? _currentHRV;
  int? _currentSteps;
  double? _currentStressLevel;

  @override
  void initState() {
    super.initState();
    _initializeDataCollector();
  }

  Future<void> _initializeDataCollector() async {
    try {
      _dataCollector = WatchDataCollector();

      final initialized = await _dataCollector.initialize();
      if (initialized) {
        // 배터리 스트림 구독
        _dataCollector.batteryStream.listen(
          (battery) {
            if (mounted) {
              setState(() {
                _currentBattery = battery;
              });
            }
          },
          onError: (error) {
            debugPrint('배터리 스트림 에러: $error');
          },
        );

        // 헬스 데이터 스트림 구독 (센서 데이터 업데이트)
        _dataCollector.healthDataStream.listen(
          (healthData) {
            if (mounted) {
              setState(() {
                _currentHeartRate = healthData.heartRate;
                _currentHRV = healthData.heartRateVariability;
                _currentSteps = healthData.steps;
                _currentStressLevel = healthData.stressLevel;
              });
            }
          },
          onError: (error) {
            debugPrint('헬스 데이터 스트림 에러: $error');
          },
        );

        // 배경 동기화 시작
        _dataCollector.startBackgroundSync();
        
        // 초기 센서 데이터 가져오기
        final initialHealthData = await _dataCollector.getCurrentHealthData();
        if (initialHealthData != null) {
          _currentHeartRate = initialHealthData.heartRate;
          _currentHRV = initialHealthData.heartRateVariability;
          _currentSteps = initialHealthData.steps;
          _currentStressLevel = initialHealthData.stressLevel;
        }

        if (mounted) {
          setState(() {
            _currentBattery = _dataCollector.getCurrentBattery();
            _isConnectedToPhone = _dataCollector.isConnectedToPhone;
            _isMonitoring = _dataCollector.isMonitoring;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('데이터 수집기 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _buildContent(context, isRoundWatch),
    );
  }

  Widget _buildContent(BuildContext context, bool isRoundWatch) {
    if (_currentBattery == null) {
      return const Center(
        child: Text('데이터 수집 중...', style: TextStyle(color: Colors.white)),
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
                    const Icon(Icons.sensors, color: Colors.blue, size: 14),
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
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              const SizedBox(height: 4),

              // 레벨 설명
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 16),

              // 구분선
              Container(
                width: MediaQuery.of(context).size.width * 0.3,
                height: 1,
                color: Colors.white24,
              ),

              const SizedBox(height: 16),

              // 상세 정보 섹션
              _buildDetailSection(context),

              const SizedBox(height: 16),

              // 계산 근거 섹션
              _buildCalculationSection(context),

              const SizedBox(height: 16),

              // 센서 데이터 섹션
              _buildSensorDataSection(context),

              const SizedBox(height: 20),
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

  Widget _buildDetailSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상세 정보',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 현재 레벨
          _buildInfoRow(
            icon: Icons.battery_charging_full,
            label: '현재 레벨',
            value: '${_currentBattery!.level}%',
            color: _currentBattery!.color,
          ),

          const SizedBox(height: 4),

          // 변화율
          _buildInfoRow(
            icon:
                _currentBattery!.changeRate > 0
                    ? Icons.trending_up
                    : Icons.trending_down,
            label: '변화율',
            value:
                '${_currentBattery!.changeRate > 0 ? '+' : ''}${_currentBattery!.changeRate.toStringAsFixed(1)}%/h',
            color:
                _currentBattery!.changeRate > 0 ? Colors.green : Colors.orange,
          ),

          const SizedBox(height: 4),

          // 예상 시간
          _buildInfoRow(
            icon: Icons.access_time,
            label: _currentBattery!.changeRate > 0 ? '완충 예상' : '소진 예상',
            value: _getEstimatedTime(),
            color: Colors.white60,
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계산 근거',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // HRV 영향
          _buildFactorRow(
            label: 'HRV (심박변이도)',
            value:
                _currentHRV != null
                    ? '${_currentHRV!.toStringAsFixed(1)}ms'
                    : '측정 중',
            impact: _getHRVImpact(),
            explanation: 'HRV가 높을수록 회복력 좋음',
          ),

          const SizedBox(height: 4),

          // 스트레스 영향
          _buildFactorRow(
            label: '스트레스 레벨',
            value:
                _currentStressLevel != null
                    ? '${_currentStressLevel!.toStringAsFixed(0)}%'
                    : '측정 중',
            impact: _getStressImpact(),
            explanation: '스트레스가 높으면 에너지 소모',
          ),

          const SizedBox(height: 4),

          // 심박수 영향
          _buildFactorRow(
            label: '심박수',
            value:
                _currentHeartRate != null ? '${_currentHeartRate}bpm' : '측정 중',
            impact: _getHeartRateImpact(),
            explanation: '안정시 심박수가 낮을수록 효율적',
          ),

          const SizedBox(height: 4),

          // 활동량 영향
          _buildFactorRow(
            label: '오늘 걸음수',
            value: _currentSteps != null ? '$_currentSteps걸음' : '0걸음',
            impact: _getActivityImpact(),
            explanation: '적절한 활동은 에너지 순환 도움',
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDataSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실시간 센서 데이터',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 센서 데이터 그리드
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSensorCard(
                icon: Icons.favorite,
                label: '심박수',
                value: _currentHeartRate != null ? '$_currentHeartRate' : '--',
                unit: 'bpm',
                color: Colors.red,
              ),
              _buildSensorCard(
                icon: Icons.timeline,
                label: 'HRV',
                value:
                    _currentHRV != null
                        ? _currentHRV!.toStringAsFixed(0)
                        : '--',
                unit: 'ms',
                color: Colors.blue,
              ),
              _buildSensorCard(
                icon: Icons.directions_walk,
                label: '걸음수',
                value: _currentSteps != null ? '$_currentSteps' : '0',
                unit: '걸음',
                color: Colors.green,
              ),
              _buildSensorCard(
                icon: Icons.psychology,
                label: '스트레스',
                value:
                    _currentStressLevel != null
                        ? _currentStressLevel!.toStringAsFixed(0)
                        : '--',
                unit: '%',
                color: Colors.orange,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 마지막 업데이트
          Text(
            '마지막 업데이트: ${_getLastUpdateTime()}',
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFactorRow({
    required String label,
    required String value,
    required String impact,
    required String explanation,
  }) {
    final impactColor = _getImpactColor(impact);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 9),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                impact,
                style: TextStyle(
                  color: impactColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          explanation,
          style: const TextStyle(color: Colors.white38, fontSize: 7),
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.38,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 8),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getEstimatedTime() {
    if (_currentBattery!.changeRate == 0) return '변화 없음';

    final hours =
        _currentBattery!.changeRate > 0
            ? (100 - _currentBattery!.level) / _currentBattery!.changeRate
            : _currentBattery!.level / -_currentBattery!.changeRate;

    if (hours < 1) {
      return '${(hours * 60).round()}분';
    } else if (hours < 24) {
      return '${hours.round()}시간';
    } else {
      return '${(hours / 24).round()}일';
    }
  }

  String _getHRVImpact() {
    if (_currentHRV == null) return '측정 중';
    if (_currentHRV! >= 50) return '+높음';
    if (_currentHRV! >= 30) return '보통';
    return '-낮음';
  }

  String _getStressImpact() {
    if (_currentStressLevel == null) return '측정 중';
    if (_currentStressLevel! <= 30) return '+낮음';
    if (_currentStressLevel! <= 60) return '보통';
    return '-높음';
  }

  String _getHeartRateImpact() {
    if (_currentHeartRate == null) return '측정 중';
    if (_currentHeartRate! <= 60) return '+좋음';
    if (_currentHeartRate! <= 80) return '보통';
    return '-높음';
  }

  String _getActivityImpact() {
    if (_currentSteps == null) return '측정 중';
    if (_currentSteps! >= 8000) return '+활발';
    if (_currentSteps! >= 5000) return '적절';
    if (_currentSteps! >= 2000) return '보통';
    return '-부족';
  }

  Color _getImpactColor(String impact) {
    if (impact.startsWith('+')) return Colors.green;
    if (impact.startsWith('-')) return Colors.orange;
    if (impact == '측정 중') return Colors.grey;
    return Colors.white60;
  }

  String _getLastUpdateTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.sync, color: Colors.white, size: 20),
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
                    _isConnectedToPhone
                        ? Icons.phone_disabled
                        : Icons.phone_android,
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
