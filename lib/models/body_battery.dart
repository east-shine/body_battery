import 'package:flutter/material.dart';

class BodyBattery {
  final int level; // 0-100
  final DateTime timestamp;
  final BatteryStatus status;
  final double changeRate; // 분당 변화율
  final String recommendation;

  BodyBattery({
    required this.level,
    required this.timestamp,
    required this.status,
    required this.changeRate,
    required this.recommendation,
  });

  Color get color {
    if (level >= 80) return Colors.green;
    if (level >= 60) return Colors.lightGreen;
    if (level >= 40) return Colors.yellow;
    if (level >= 20) return Colors.orange;
    return Colors.red;
  }

  String get statusText {
    switch (status) {
      case BatteryStatus.charging:
        return '충전 중';
      case BatteryStatus.draining:
        return '소모 중';
      case BatteryStatus.stable:
        return '안정';
    }
  }

  String get levelDescription {
    if (level >= 80) return '매우 높음 - 활발한 활동 가능';
    if (level >= 60) return '높음 - 일상 활동 적합';
    if (level >= 40) return '보통 - 가벼운 활동 권장';
    if (level >= 20) return '낮음 - 휴식 필요';
    return '매우 낮음 - 즉시 휴식 권장';
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'timestamp': timestamp.toIso8601String(),
    'status': status.index,
    'changeRate': changeRate,
    'recommendation': recommendation,
  };

  factory BodyBattery.fromJson(Map<String, dynamic> json) => BodyBattery(
    level: json['level'],
    timestamp: DateTime.parse(json['timestamp']),
    status: BatteryStatus.values[json['status']],
    changeRate: json['changeRate'],
    recommendation: json['recommendation'],
  );
}

enum BatteryStatus {
  charging,
  draining,
  stable,
}

class BatteryHistory {
  final DateTime time;
  final int level;
  final String activity;

  BatteryHistory({
    required this.time,
    required this.level,
    required this.activity,
  });
}