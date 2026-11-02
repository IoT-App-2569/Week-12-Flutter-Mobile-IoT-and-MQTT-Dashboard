# Labsheet 12.3: Real-Time Telemetry Dashboard, Animated Radial Gauge & Line Chart

#### 1. บันทึกผลการทดลอง / โค้ดที่พัฒนา

1. ไฟล์ `lib/radial_gauge_widget.dart` วาดมาตรวัดทรงกลมด้วย `CustomPainter` และทำแอนิเมชันเข็มด้วย `TweenAnimationBuilder`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadialGaugeWidget extends StatelessWidget {
  final double value;
  final double maxLimit;

  const RadialGaugeWidget({super.key, required this.value, this.maxLimit = 3.3});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 240),
                painter: _GaugePainter(value: animatedValue, maxLimit: maxLimit),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    animatedValue.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                  ),
                  const Text(
                    'VOLTS (V)',
                    style: TextStyle(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
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
  _GaugePainter({required this.value, required this.maxLimit});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, trackPaint);

    final ratio = (value / maxLimit).clamp(0.0, 1.0);
    final currentSweep = sweepAngle * ratio;

    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF00E5FF), Color(0xFF00E676), Color(0xFFFFD600), Color(0xFFFF5252)],
        startAngle: 0.0,
        endAngle: math.pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, currentSweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.value != value;
}
```

2. การรับข้อมูลและวาดกราฟเส้นย้อนหลังใน `lib/telemetry_dashboard_screen.dart`:
```dart
// ถอดรหัส JSON และเก็บประวัติย้อนหลัง 30 ค่า
final data = jsonDecode(payloadStr);
final double v = (data['voltage'] as num).toDouble().clamp(0.0, 3.3);
final int r = (data['raw'] as num).toInt();

setState(() {
  _voltage = v;
  _rawAdc = r;
  _maxVoltage = math.max(_maxVoltage, v);
  _minVoltage = math.min(_minVoltage, v);
  _history.add(v);
  if (_history.length > 30) {
    _history.removeAt(0);
  }
});
```

#### 2. ผลลัพธ์จาก Serial Monitor / หน้าจอแสดงผล

ผลการทดสอบสตรีมข้อมูลจำลองด้วยสคริปต์ `pyTeleSim.py` (Sine Wave 0.0 ถึง 3.3V ทุก 500ms):
```text
Published: {"voltage": 1.65, "raw": 2048, "uptime": 1}
Published: {"voltage": 1.95, "raw": 2420, "uptime": 2}
Published: {"voltage": 2.23, "raw": 2767, "uptime": 3}
Published: {"voltage": 2.47, "raw": 3065, "uptime": 4}
Published: {"voltage": 2.65, "raw": 3288, "uptime": 5}
```

พฤติกรรมบนหน้าจอ Flutter App:
- เข็มบนมาตรวัด Radial Gauge หมุนขึ้นและลงตามคลื่น Sine อย่างนุ่มนวล โดยไม่มีอาการกระตุก
- กล่องสถิติแสดงผลถูกต้อง:
  - แรงดันปัจจุบัน: `1.65 V`
  - ค่าดิบแอนะล็อก ADC 12 บิต: `2048 / 4095`
  - สถิติแรงดันสูงสุด: `3.15 V`
  - สถิติแรงดันต่ำสุด: `0.15 V`
- กราฟเส้นแนวโน้มย้อนหลัง (Sparkline) วาดเป็นระลอกคลื่น 30 จุดย้อนหลังอย่างต่อเนื่อง

#### 3. สรุปผลและการตอบคำถามท้ายใบงาน

- **สรุปผลการทดลอง:**
 สามารถสร้างหน้าจอแดชบอร์ดแสดงผลข้อมูลโทรมาตรแบบเรียลไทม์บน Flutter ได้สำเร็จ โดยใช้ CustomPainter วาดมาตรวัด Radial Gauge ทรงกลมไล่เฉดสีร่วมกับ TweenAnimationBuilder เพื่อสร้างแอนิเมชันเข็มวัดที่ลื่นไหล พร้อมทั้งประมวลผลข้อความ JSON จาก MQTT นำค่าแรงดันและค่าดิบ ADC มาแสดงผลสถิติ (ปัจจุบัน, สูงสุด, ต่ำสุด) และพล็อตกราฟเส้นแนวโน้มย้อนหลัง 30 จุดได้อย่างถูกต้องและมีเสถียรภาพ

- **คำถามท้ายการทดลอง:**
1. **เหตุใดการใช้ `TweenAnimationBuilder` จึงทำให้เข็มมาตรวัดดูนุ่มนวลและไม่กระตุก แม้ข้อมูลเซนเซอร์จะเข้ามาทุกๆ 500 มิลลิวินาที?**
     - **คำตอบ:** เพราะตัววิดเจ็ตทำหน้าที่ Interpolate (เกลี่ยค่าแบบแอนิเมชัน) ระหว่างค่าเก่าไปยังค่าใหม่ผ่านช่วงเวลา 300 ms ตามเส้นโค้ง easeOutCubic ช่วยลดการกระโดดข้ามของตัวเลขในทันที ทำให้การเคลื่อนที่ของเส้นอาร์กมีความต่อเนื่องและนุ่มนวล
     
2. **การจำกัดความยาวของอาร์เรย์ `_history` ให้เก็บไม่เกิน 30 ตัวอย่าง ส่งผลดีต่อประสิทธิภาพหน่วยความจำของสมาร์ตโฟนอย่างไร?**
     - **คำตอบ:** ป้องกันปัญหา หน่วยความจำบวม (Memory Leak/Bloat) จากการสะสมข้อมูลสตรีมมิ่งที่ส่งมาต่อเนื่องไม่สิ้นสุด และช่วยรักษาขอบเขตภาระการวาดกราฟ (Rendering Load) ให้คงที่ที่ 30 พิกัด ป้องกันปัญหาเฟรมเรตร่วง (Frame Drop) บนสมาร์ตโฟน 

3. **หากเซนเซอร์ส่งค่าผิดพลาด เช่น ค่านอกช่วง 0 - 3.3V หรือค่าเป็น `null` โค้ดส่วนใดใน `telemetry_dashboard_screen.dart` ที่ช่วยป้องกันไม่ให้แอปแครช?**
     - **คำตอบ:** กรณีค่านอกช่วง: ป้องกันด้วยคำสั่ง .clamp(0.0, 3.3) ซึ่งจะบีบค่าให้อยู่ในช่วง 0 ถึง 3.3 V เสมอ

กรณี Type/Null ผิดพลาด: ใช้การแปลงชนิดข้อมูลด้วย (data['voltage'] as num).toDouble() ช่วยรองรับทั้งจำนวนเต็มและทศนิยม (และหากต้องการกัน null แบบสมบูรณ์ มักใส่ตัวดำเนินการ Null-aware เช่น (data['voltage'] as num?)?.toDouble() ?? 0.0 ร่วมด้วย)

---