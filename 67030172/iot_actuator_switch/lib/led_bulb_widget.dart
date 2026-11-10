import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget วาดรูปหลอดไฟ LED จริงๆ ด้วย CustomPaint
/// ใช้แทน Icons.lightbulb เพื่อให้ดูสมจริงยิ่งขึ้น
class LedBulbWidget extends StatelessWidget {
  final bool isOn;
  final double size;

  const LedBulbWidget({
    super.key,
    required this.isOn,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.3,
      child: CustomPaint(
        painter: _LedBulbPainter(isOn: isOn),
      ),
    );
  }
}

class _LedBulbPainter extends CustomPainter {
  final bool isOn;
  _LedBulbPainter({required this.isOn});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bulbRadius = size.width * 0.38;
    final bulbCenterY = size.height * 0.38;

    // ── 1. Glow effect เมื่อ LED เปิด ──────────────────────────────
    if (isOn) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E676).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
      canvas.drawCircle(Offset(cx, bulbCenterY), bulbRadius * 1.6, glowPaint);

      final glowPaint2 = Paint()
        ..color = const Color(0xFF00E676).withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(Offset(cx, bulbCenterY), bulbRadius * 2.2, glowPaint2);
    }

    // ── 2. วาดฐานหลอดไฟ (Base / Cap) ─────────────────────────────
    final baseW = bulbRadius * 0.65;
    final baseTop = bulbCenterY + bulbRadius * 0.55;
    final baseBottom = size.height * 0.92;

    // ฐานเงินๆ
    final basePaint = Paint()
      ..shader = LinearGradient(
        colors: isOn
            ? [const Color(0xFF9E9E9E), const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)]
            : [const Color(0xFF424242), const Color(0xFF757575), const Color(0xFF424242)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(cx - baseW, baseTop, baseW * 2, baseBottom - baseTop));

    // วาดตัวฐานทรงกระบอก
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, (baseTop + baseBottom) / 2),
        width: baseW * 2,
        height: baseBottom - baseTop,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(baseRect, basePaint);

    // เส้นขั้นฐาน (screw threads)
    final threadPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final threadCount = 4;
    final threadStep = (baseBottom - baseTop) / (threadCount + 1);
    for (int i = 1; i <= threadCount; i++) {
      final y = baseTop + threadStep * i;
      canvas.drawLine(Offset(cx - baseW, y), Offset(cx + baseW, y), threadPaint);
    }

    // ── 3. วาดคอหลอด (Neck) ────────────────────────────────────────
    final neckW = bulbRadius * 0.52;
    final neckTop = bulbCenterY + bulbRadius * 0.7;
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, (neckTop + baseTop) / 2),
        width: neckW * 2,
        height: (baseTop - neckTop).abs() + 2,
      ),
      const Radius.circular(3),
    );
    final neckPaint = Paint()
      ..shader = LinearGradient(
        colors: isOn
            ? [const Color(0xFFB0BEC5), const Color(0xFFECEFF1), const Color(0xFFB0BEC5)]
            : [const Color(0xFF37474F), const Color(0xFF546E7A), const Color(0xFF37474F)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromCenter(center: Offset(cx, neckTop), width: neckW * 2, height: 20));
    canvas.drawRRect(neckRect, neckPaint);

    // ── 4. วาดแก้วหลอด (Glass Bulb) ────────────────────────────────
    final glassPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: isOn
            ? [
                const Color(0xFFE8FFE8),
                const Color(0xFF00E676).withOpacity(0.85),
                const Color(0xFF00BCD4).withOpacity(0.6),
              ]
            : [
                const Color(0xFF546E7A).withOpacity(0.6),
                const Color(0xFF263238).withOpacity(0.85),
                const Color(0xFF263238),
              ],
      ).createShader(Rect.fromCircle(center: Offset(cx, bulbCenterY), radius: bulbRadius));

    canvas.drawCircle(Offset(cx, bulbCenterY), bulbRadius, glassPaint);

    // ── 5. Specular highlight (แสงสะท้อน) ──────────────────────────
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(isOn ? 0.6 : 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(cx - bulbRadius * 0.28, bulbCenterY - bulbRadius * 0.3),
      bulbRadius * 0.18,
      highlightPaint,
    );

    // ── 6. เส้นขอบแก้ว ─────────────────────────────────────────────
    final rimPaint = Paint()
      ..color = isOn
          ? const Color(0xFF00E676).withOpacity(0.4)
          : Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, bulbCenterY), bulbRadius, rimPaint);

    // ── 7. Filament (ไส้หลอด) ────────────────────────────────────────
    if (isOn) {
      final filamentPaint = Paint()
        ..color = const Color(0xFFFFF176).withOpacity(0.9)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final fx = cx;
      final fy = bulbCenterY + bulbRadius * 0.1;
      final amp = bulbRadius * 0.12;
      final w = bulbRadius * 0.35;

      path.moveTo(fx - w, fy);
      // วาดเส้น W-shape ไส้หลอด
      for (int i = 0; i < 3; i++) {
        final x1 = fx - w + (w * 2 / 3) * i;
        final x2 = fx - w + (w * 2 / 3) * i + w / 3;
        final midX = (x1 + x2) / 2;
        path.quadraticBezierTo(midX, fy - amp, x2, fy);
        path.quadraticBezierTo(midX + w / 6, fy + amp, x2 + w / 6, fy);
      }

      canvas.drawPath(path, filamentPaint);

      // เส้น support ไส้หลอด
      final supportPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(fx, fy + amp), Offset(fx, fy + bulbRadius * 0.5), supportPaint);
    } else {
      // ไส้หลอดดับ
      final filamentDimPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(cx - bulbRadius * 0.2, bulbCenterY + bulbRadius * 0.1),
        Offset(cx + bulbRadius * 0.2, bulbCenterY + bulbRadius * 0.1),
        filamentDimPaint,
      );
    }

    // ── 8. Ray lines เมื่อ LED เปิด ──────────────────────────────────
    if (isOn) {
      final rayPaint = Paint()
        ..color = const Color(0xFF00E676).withOpacity(0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final rayCount = 8;
      final innerR = bulbRadius * 1.15;
      final outerR = bulbRadius * 1.45;
      for (int i = 0; i < rayCount; i++) {
        final angle = (i / rayCount) * 2 * math.pi - math.pi / 2;
        canvas.drawLine(
          Offset(cx + innerR * math.cos(angle), bulbCenterY + innerR * math.sin(angle)),
          Offset(cx + outerR * math.cos(angle), bulbCenterY + outerR * math.sin(angle)),
          rayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedBulbPainter oldDelegate) =>
      oldDelegate.isOn != isOn;
}

