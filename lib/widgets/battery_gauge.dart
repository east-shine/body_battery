import 'dart:math';
import 'package:flutter/material.dart';
import '../models/body_battery.dart';

class BatteryGauge extends StatefulWidget {
  final BodyBattery battery;
  final double size;
  final bool showLabel;

  const BatteryGauge({
    super.key,
    required this.battery,
    this.size = 200,
    this.showLabel = true,
  });

  @override
  State<BatteryGauge> createState() => _BatteryGaugeState();
}

class _BatteryGaugeState extends State<BatteryGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _previousLevel = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: _previousLevel,
      end: widget.battery.level.toDouble(),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(BatteryGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battery.level != widget.battery.level) {
      _previousLevel = oldWidget.battery.level.toDouble();
      _animation = Tween<double>(
        begin: _previousLevel,
        end: widget.battery.level.toDouble(),
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _BatteryGaugePainter(
            level: _animation.value,
            color: widget.battery.color,
            status: widget.battery.status,
            showLabel: widget.showLabel,
          ),
        );
      },
    );
  }
}

class _BatteryGaugePainter extends CustomPainter {
  final double level;
  final Color color;
  final BatteryStatus status;
  final bool showLabel;

  _BatteryGaugePainter({
    required this.level,
    required this.color,
    required this.status,
    required this.showLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // 배경 원
    final backgroundPaint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.15;

    canvas.drawCircle(center, radius * 0.8, backgroundPaint);

    // 배터리 레벨 원호
    final levelPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.15
          ..strokeCap = StrokeCap.round;

    final sweepAngle = (level / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      -pi / 2,
      sweepAngle,
      false,
      levelPaint,
    );

    // 중앙 텍스트
    if (showLabel) {
      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${level.round()}',
              style: TextStyle(
                fontSize: radius * 0.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            TextSpan(
              text: '%',
              style: TextStyle(
                fontSize: radius * 0.25,
                fontWeight: FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );

      // 상태 텍스트 제거 (워치 화면에서 중복 표시 방지)
    }

    // 애니메이션 효과 (충전 중일 때)
    if (status == BatteryStatus.charging) {
      final chargingPaint =
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.02;

      for (int i = 0; i < 3; i++) {
        final animRadius = radius * (0.85 + i * 0.05);
        canvas.drawCircle(center, animRadius, chargingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BatteryGaugePainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.color != color ||
        oldDelegate.status != status;
  }
}

class BatteryIcon extends StatelessWidget {
  final int level;
  final double size;
  final Color? color;

  const BatteryIcon({
    super.key,
    required this.level,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final batteryColor = color ?? _getColorForLevel(level);

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.battery_full, size: size, color: Colors.grey[300]),
        ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: level / 100,
            child: Icon(Icons.battery_full, size: size, color: batteryColor),
          ),
        ),
        if (level <= 20)
          Icon(Icons.battery_alert, size: size * 0.5, color: Colors.white),
      ],
    );
  }

  Color _getColorForLevel(int level) {
    if (level >= 80) return Colors.green;
    if (level >= 60) return Colors.lightGreen;
    if (level >= 40) return Colors.yellow;
    if (level >= 20) return Colors.orange;
    return Colors.red;
  }
}
