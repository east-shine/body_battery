import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/body_battery.dart';
import '../services/battery_calculator.dart';
import '../services/phone_data_receiver.dart';

class DetailScreen extends StatefulWidget {
  final BatteryCalculator? batteryCalculator;
  final PhoneDataReceiver? dataReceiver;

  const DetailScreen({
    super.key,
    this.batteryCalculator,
    this.dataReceiver,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late List<BatteryHistory> _history;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // 배터리 스트림 구독 (워치용 또는 폰용)
    if (widget.batteryCalculator != null) {
      widget.batteryCalculator!.batteryStream.listen((battery) {
        if (mounted) {
          setState(() {
            _history = widget.batteryCalculator!.getHistory();
          });
        }
      });
    } else if (widget.dataReceiver != null) {
      widget.dataReceiver!.batteryStream.listen((battery) {
        if (mounted) {
          setState(() {
            _history = widget.dataReceiver!.batteryHistory;
          });
        }
      });
    }
  }

  void _loadData() {
    if (widget.batteryCalculator != null) {
      _history = widget.batteryCalculator!.getHistory();
    } else if (widget.dataReceiver != null) {
      _history = widget.dataReceiver!.batteryHistory;
    } else {
      _history = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWatchSize = MediaQuery.of(context).size.width < 300;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isWatchSize ? null : AppBar(
        backgroundColor: Colors.black,
        title: const Text('상세 정보'),
        elevation: 0,
      ),
      body: isWatchSize ? _buildWatchLayout() : _buildPhoneLayout(),
    );
  }

  Widget _buildWatchLayout() {
    return PageView(
      children: [
        _buildGraphPage(true),
        _buildHistoryPage(true),
        _buildStatsPage(true),
      ],
    );
  }

  Widget _buildPhoneLayout() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: '그래프'),
              Tab(text: '기록'),
              Tab(text: '통계'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGraphPage(false),
                _buildHistoryPage(false),
                _buildStatsPage(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphPage(bool isWatch) {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          '데이터가 없습니다',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isWatch ? 8 : 16),
      child: Column(
        children: [
          if (!isWatch) ...[
            const Text(
              '24시간 변화 추이',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: isWatch ? 6 : 3,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: !isWatch,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 3,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        return Text(
                          '$hour시',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white12),
                ),
                minX: 0,
                maxX: 24,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: _getChartSpots(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                      ],
                    ),
                    barWidth: isWatch ? 2 : 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.3),
                          Colors.yellow.withValues(alpha: 0.2),
                          Colors.orange.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPage(bool isWatch) {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          '기록이 없습니다',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isWatch ? 8 : 16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[_history.length - 1 - index];
        return _buildHistoryItem(item, isWatch);
      },
    );
  }

  Widget _buildHistoryItem(BatteryHistory item, bool isWatch) {
    final color = _getColorForLevel(item.level);
    
    return Container(
      margin: EdgeInsets.only(bottom: isWatch ? 4 : 8),
      padding: EdgeInsets.all(isWatch ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isWatch ? 40 : 50,
            height: isWatch ? 40 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                '${item.level}%',
                style: TextStyle(
                  color: color,
                  fontSize: isWatch ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: isWatch ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.activity,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWatch ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isWatch ? 2 : 4),
                Text(
                  _formatDateTime(item.time),
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isWatch ? 10 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPage(bool isWatch) {
    final stats = _calculateStats();
    
    return Padding(
      padding: EdgeInsets.all(isWatch ? 8 : 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: isWatch ? 8 : 16,
        crossAxisSpacing: isWatch ? 8 : 16,
        childAspectRatio: isWatch ? 1.2 : 1.5,
        children: [
          _buildStatCard(
            '평균 레벨',
            '${stats['average']}%',
            Icons.analytics,
            Colors.blue,
            isWatch,
          ),
          _buildStatCard(
            '최고 레벨',
            '${stats['max']}%',
            Icons.arrow_upward,
            Colors.green,
            isWatch,
          ),
          _buildStatCard(
            '최저 레벨',
            '${stats['min']}%',
            Icons.arrow_downward,
            Colors.orange,
            isWatch,
          ),
          _buildStatCard(
            '충전 시간',
            '${stats['chargingTime']}시간',
            Icons.battery_charging_full,
            Colors.teal,
            isWatch,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isWatch,
  ) {
    return Container(
      padding: EdgeInsets.all(isWatch ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: isWatch ? 20 : 24,
          ),
          SizedBox(height: isWatch ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWatch ? 16 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isWatch ? 2 : 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: isWatch ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _getChartSpots() {
    if (_history.isEmpty) return [];
    
    final spots = <FlSpot>[];
    for (final item in _history) {
      final hour = item.time.hour + (item.time.minute / 60);
      spots.add(FlSpot(hour, item.level.toDouble()));
    }
    
    // 정렬
    spots.sort((a, b) => a.x.compareTo(b.x));
    
    return spots;
  }

  Map<String, int> _calculateStats() {
    if (_history.isEmpty) {
      return {
        'average': 0,
        'max': 0,
        'min': 0,
        'chargingTime': 0,
      };
    }
    
    int sum = 0;
    int max = 0;
    int min = 100;
    int chargingCount = 0;
    
    for (final item in _history) {
      sum += item.level;
      if (item.level > max) max = item.level;
      if (item.level < min) min = item.level;
      if (item.activity.contains('충전') || item.activity.contains('수면')) {
        chargingCount++;
      }
    }
    
    return {
      'average': (sum / _history.length).round(),
      'max': max,
      'min': min,
      'chargingTime': ((chargingCount * 5) / 60).round(), // 5분 간격 기준
    };
  }

  Color _getColorForLevel(int level) {
    if (level >= 80) return Colors.green;
    if (level >= 60) return Colors.lightGreen;
    if (level >= 40) return Colors.yellow;
    if (level >= 20) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}