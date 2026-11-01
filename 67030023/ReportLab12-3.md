### Lab12-3

### กิจกรรมที่ 12-3.2: การสร้างหน้าจอ Telemetry Dashboard (`telemetry_dashboard_screen.dart`)

#### 1. สร้างไฟล์หน้าจอแดชบอร์ด (`lib/telemetry_dashboard_screen.dart`)
ในโฟลเดอร์ `lib/` ให้สร้างไฟล์ใหม่ชื่อ `telemetry_dashboard_screen.dart` และใส่โค้ดต่อไปนี้:

```dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'radial_gauge_widget.dart';

class TelemetryDashboardScreen extends StatefulWidget {
  final String brokerIp;
  const TelemetryDashboardScreen({super.key, required this.brokerIp});

  @override
  State<TelemetryDashboardScreen> createState() => _TelemetryDashboardScreenState();
}

class _TelemetryDashboardScreenState extends State<TelemetryDashboardScreen> {
  MqttServerClient? _client;
  double _currentVoltage = 0.0;
  int _currentRaw = 0;
  int _currentUptime = 0;
  double _maxVoltage = 0.0;
  double _minVoltage = 3.3;

  final List<double> _history = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    final clientId = 'Flutter_Telemetry_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient(widget.brokerIp, clientId);
    _client!.port = 1883;

    _client!.onConnected = () {
      setState(() => _isConnected = true);
      _client!.subscribe('iot/esp32/telemetry', MqttQos.atMostOnce);
      _client!.updates?.listen(_handleIncomingMessage);
    };

    _client!.onDisconnected = () {
      setState(() => _isConnected = false);
    };

    try {
      await _client!.connect();
    } catch (_) {}
  }

  void _handleIncomingMessage(List<MqttReceivedMessage<MqttMessage>> c) {
    final recMess = c[0].payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final v = (data['voltage'] as num?)?.toDouble() ?? 0.0;
      final raw = (data['raw'] as num?)?.toInt() ?? 0;
      final up = (data['uptime'] as num?)?.toInt() ?? 0;

      setState(() {
        _currentVoltage = v;
        _currentRaw = raw;
        _currentUptime = up;
        _maxVoltage = math.max(_maxVoltage, v);
        _minVoltage = math.min(_minVoltage, v);

        _history.add(v);
        if (_history.length > 30) _history.removeAt(0);
      });
    } catch (e) {
      debugPrint('Parsing error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Real-time Telemetry Dashboard'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              Icons.circle,
              size: 14,
              color: _isConnected ? const Color(0xFF00E676) : Colors.redAccent,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. มาตรวัดเข็มทรงกลม
            Center(
              child: RadialGaugeWidget(value: _currentVoltage, maxLimit: 3.3),
            ),
            const SizedBox(height: 24),

            // 2. การ์ดสรุปค่าสถิติ (Statistics Cards)
            Row(
              children: [
                _buildMetricCard('ค่าดิบ ADC', '$_currentRaw / 4095', const Color(0xFF00E5FF)),
                const SizedBox(width: 12),
                _buildMetricCard('แรงดันสูงสุด', '${_maxVoltage.toStringAsFixed(2)} V', const Color(0xFFFF5252)),
                const SizedBox(width: 12),
                _buildMetricCard('แรงดันต่ำสุด', '${_minVoltage == 3.3 ? 0.0 : _minVoltage.toStringAsFixed(2)} V', const Color(0xFF00E676)),
              ],
            ),
            const SizedBox(height: 20),

            // 3. กราฟเส้นแนวโน้มสด (Live Sparkline Graph)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'แนวโน้มแรงดันย้อนหลัง 30 ตัวอย่าง (Live Trend)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(history: _history, maxLimit: 3.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ESP32 Uptime: ${_currentUptime}s',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 6),
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> history;
  final double maxLimit;

  _SparklinePainter({required this.history, required this.maxLimit});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final dx = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final x = i * dx;
      final y = size.height - ((history[i] / maxLimit).clamp(0.0, 1.0) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
```

#### 2. ปรับปรุงไฟล์ `lib/main.dart` เพื่อเรียกใช้งานหน้าจอใหม่
เปิดไฟล์ `lib/main.dart` และแก้ไขโค้ดทั้งหมดให้เรียกใช้งาน `TelemetryDashboardScreen` เป็นหน้าจอเริ่มต้น (Home Screen):

```dart
import 'package:flutter/material.dart';
import 'telemetry_dashboard_screen.dart';

void main() {
  runApp(const TelemetryApp());
}

class TelemetryApp extends StatelessWidget {
  const TelemetryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab 12.3 Telemetry Dashboard',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      // กำหนด IP ของ Mosquitto Broker (ใช้ 127.0.0.1 หากรันบนคอมพิวเตอร์เครื่องเดียวกัน)
      home: const TelemetryDashboardScreen(brokerIp: '127.0.0.1'),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

#### 3. สั่งรัน Flutter App
```powershell
# รันบน Windows Desktop
flutter run -d windows

# หรือรันบน Android Device / Emulator
flutter run -d <device-id>
```

---

### กิจกรรมที่ 12-3.3: การทดสอบร่วมกับสคริปต์จำลองเซนเซอร์ (Telemetry Mock Simulation)

หากยังไม่ได้ต่อบอร์ด ESP32 จริงกับวงจรแบ่งแรงดัน (Potentiometer) สามารถทดสอบจำลองส่งข้อมูลเซนเซอร์เข้าสู่ Broker ได้ทั้งการใช้สคริปต์ Python และคำสั่ง Mosquitto CLI บน PowerShell:

#### 1. การทดสอบด้วยสคริปต์ Python Telemetry Simulator
สร้างไฟล์สคริปต์ `pyTeleSim.py` (หรือ `Sine_wave_gen.py`) เพื่อจำลองส่งคลื่นสัญญาณ Sine Wave ของแรงดันไฟฟ้า (0.0 ถึง 3.3V) ไปยัง Broker อย่างต่อเนื่อง:

```python
import paho.mqtt.client as mqtt
import time
import json
import math

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "PyTelemetrySim")
client.connect("127.0.0.1", 1883)

t = 0
while True:
    # สร้างคลื่น Sine จำลองแรงดัน 0.0 ถึง 3.3V
    voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
    raw = int((voltage / 3.3) * 4095)
    payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
    
    client.publish("iot/esp32/telemetry", payload)
    print(f"Published: {payload}")
    t += 1
    time.sleep(0.5)
```

รันสคริปต์ด้วยคำสั่ง:
```powershell
python pyTeleSim.py
```

เมื่อเปิดดูหน้าจอแดชบอร์ดบน Flutter: เข็ม Radial Gauge จะเคลื่อนไหวขึ้นลงอย่างนุ่มนวลตามคลื่น Sine พร้อมกับการ์ดสถิติ (Max, Min, Raw ADC) และกราฟประวัติย้อนหลัง 30 ตัวอย่าง (Live Trend Sparkline) ที่วาดเป็นระลอกคลื่นอย่างสวยงาม:

<p align="center">
  <img src="Images/python-tele-simexample.png" alt="ผลการทำงานของ Real-time Telemetry Dashboard" width="90%">
  <br>
  <em>รูปที่ 12.3-2 ผลการทดสอบแดชบอร์ดแสดงผลค่าแรงดันแบบเรียลไทม์ร่วมกับสัญญาณ Sine Wave</em>
</p>

#### 2. การทดสอบแบบเจาะจงค่าผ่าน Mosquitto CLI (PowerShell)
สามารถใช้คำสั่ง `mosquitto_pub` ทดสอบส่งค่าเฉพาะเพื่อตรวจสอบพฤติกรรมของ Gauge ในสภาวะต่างๆ:

- **ทดสอบส่งค่าปกติ (1.65 V):**
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/telemetry" -m '{"voltage": 1.65, "raw": 2048, "uptime": 10}'
```
*สังเกตเข็ม Radial Gauge หมุนไปที่กึ่งกลาง (1.65 V) และการ์ดแสดงค่า 2048 / 4095*

- **ทดสอบส่งค่าแรงดันสูงแตะขีดจำกัด (3.15 V):**
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/telemetry" -m '{"voltage": 3.15, "raw": 3910, "uptime": 20}'
```
*สังเกตเข็มหมุนเข้าสู่โซนสีแดง และการ์ด "แรงดันสูงสุด" ปรับค่าเป็น `3.15 V` ทันที*

- **จำลองสตรีมข้อมูลต่อเนื่อง 30 ค่าด้วย PowerShell Loop:**
```powershell
1..30 | ForEach-Object {
    $v = [Math]::Round(1.65 + 1.5 * [Math]::Sin($_ * 0.4), 2)
    $raw = [int](($v / 3.3) * 4095)
    mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/telemetry" -m "{`"voltage`": $v, `"raw`": $raw, `"uptime`": $_}"
    Start-Sleep -Milliseconds 500
}
```

---

## 4. สรุปผลและคำถามท้ายการทดลอง
1. เหตุใดการใช้ `TweenAnimationBuilder` จึงทำให้เข็มมาตรวัดดูนุ่มนวลและไม่กระตุก แม้ข้อมูลเซนเซอร์จะเข้ามาทุกๆ 500 มิลลิวินาที?
    เพราะ TweenAnimationBuilder ทำหน้าที่สร้าง Interpolation (การสร้างค่าเปลี่ยนผ่านระหว่างจุด) โดยเมื่อมีค่าแรงดันใหม่ส่งเข้ามา ตัว Builder จะคำนวณและวาดเฟรมย่อยๆ (60 หรือ 120 FPS) เพื่อค่อยๆ เคลื่อนเข็มจาก "ค่าเดิม" ไปยัง "ค่าใหม่" ตามระยะเวลา (Duration) ที่กำหนด แทนที่จะเปลี่ยนมุมองศาของเข็มทันทีแบบทันทีทันใด (Discontinuous Jump) จึงทำให้เข็มหมุนอย่างนุ่มนวล กวาดสายตาได้อย่างต่อเนื่อง และไม่กระตุก

2. การจำกัดความยาวของอาร์เรย์ `_history` ให้เก็บไม่เกิน 30 ตัวอย่าง ส่งผลดีต่อประสิทธิภาพหน่วยความจำของสมาร์ตโฟนอย่างไร?
    ควบคุมการใช้ RAM (Memory Footprint): ป้องกันไม่ให้อาร์เรย์เติบโตอย่างไม่จำกัด (Memory Leak) ซึ่งหากเปิดแอปทิ้งไว้เป็นเวลานานแล้วเก็บข้อมูลทุกๆ 500ms อาจมีข้อมูลหลายแสนตัวอย่างสะสมใน RAM

    รักษาความเร็วในการวาด UI (Rendering Performance): _SparklinePainter ต้องวนลูปวาดเส้นกราฟด้วย CustomPaint ทุกครั้งที่มีข้อมูลใหม่ หากข้อมูลมีเพียง 30 จุด CPU/GPU จะใช้เวลาคำนวณพิกัดเพียงเล็กน้อย รักษาระดับเฟรมเรตให้อยู่ที่ 60-120 FPS ได้ตลอดเวลา

3. หากเซนเซอร์ส่งค่าผิดพลาด เช่น ค่านอกช่วง 0 - 3.3V หรือค่าเป็น `null` โค้ดส่วนใดใน `telemetry_dashboard_screen.dart` ที่ช่วยป้องกันไม่ให้แอปแครช?
    การครอบบล็อก try-catch และการแปลงชนิดข้อมูลอย่างปลอดภัย (Defensive Parsing)
    final v = (data['voltage'] as num?)?.toDouble() ?? 0.0;
    final raw = (data['raw'] as num?)?.toInt() ?? 0;
    final up = (data['uptime'] as num?)?.toInt() ?? 0;
    หากค่าส่งมาเป็น null หรือ key ไม่ตรง ตัวดำเนินการ Null-coalescing (??)
    จะกำหนดค่าเริ่มต้นความปลอดภัยเป็น 0.0 หรือ 0 แทน ป้องกันข้อผิดพลาด Null check operator used on a null value หรือ TypeError
    
    การใช้ .clamp(0.0, 1.0) ใน CustomPainter
    final y = size.height - ((history[i] / maxLimit).clamp(0.0, 1.0) * size.height);
    หากค่าแรงดันหลุดช่วงขอบเขต (เช่น ส่งมา 5.0V หรือ -1.2V) ตัวฟังก์ชัน .clamp() จะบีบอัตราส่วนให้อยู่ในกรอบ 0.0 ถึง 1.0 เสมอ ทำให้ตำแหน่งพิกัด Y ที่คำนวณได้ไม่หลุดออกนอกขอบเขตพื้นที่ Canvas หรือสร้างการคำนวณพิกัดเรขาคณิตที่ผิดพลาดจนแอปแครช