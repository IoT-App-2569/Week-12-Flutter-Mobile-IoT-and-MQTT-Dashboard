
import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadialGaugeWidget extends StatelessWidget {
  final double value;
  final double maxLimit;

  const RadialGaugeWidget({
    super.key,
    required this.value,
    this.maxLimit = 3.3,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = maxLimit > 0 ? maxLimit : 3.3;
    final safeValue = value.isFinite
        ? value.clamp(0.0, safeMax).toDouble()
        : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0.0,
        end: safeValue,
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(280, 280),
                painter: _GaugePainter(
                  value: animatedValue,
                  maxLimit: safeMax,
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'VOLTAGE',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    animatedValue.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),

                  const Text(
                    'VOLTS (V)',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${(safeValue / safeMax * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double maxLimit;

  _GaugePainter({
    required this.value,
    required this.maxLimit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.width / 2 - 24;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    // Background Track
    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Active Gradient Arc
    final ratio = (value / maxLimit).clamp(0.0, 1.0);

    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF00E5FF),
          Color(0xFF00E676),
          Color(0xFFFFD600),
          Color(0xFFFF5252),
        ],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * ratio,
      false,
      activePaint,
    );

    // Gauge Tick Marks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = startAngle +
          (sweepAngle * i / 10);

      final outerRadius = radius + 15;
      final innerRadius = radius + 22;

      final start = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      final end = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, tickPaint);
    }

    // Start / End Labels
    final textStyle = const TextStyle(
      color: Colors.white54,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    _drawLabel(
      canvas,
      '0.0',
      Offset(
        center.dx - radius * 0.78,
        center.dy + radius * 0.78,
      ),
      textStyle,
    );

    _drawLabel(
      canvas,
      maxLimit.toStringAsFixed(1),
      Offset(
        center.dx + radius * 0.78,
        center.dy + radius * 0.78,
      ),
      textStyle,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxLimit != maxLimit;
  }
}
