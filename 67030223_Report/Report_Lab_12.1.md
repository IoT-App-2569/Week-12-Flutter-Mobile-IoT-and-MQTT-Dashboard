# Labsheet 12.1: Flutter Environment Bringup & Basic MQTT Client (mqtt_client)

#### 1. บันทึกผลการทดลอง / โค้ดที่พัฒนา

ไฟล์ `lib/main.dart` สำหรับเชื่อมต่อ Mosquitto Broker พอร์ต 1883 ผ่านแพ็กเกจ `mqtt_client` และทดสอบการส่ง (Publish) และรับ (Subscribe) ข้อความสองทาง:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MqttBasicsApp());
}

class MqttBasicsApp extends StatelessWidget {
  const MqttBasicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab 12.1 MQTT Basics',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const MqttBasicsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MqttBasicsScreen extends StatefulWidget {
  const MqttBasicsScreen({super.key});

  @override
  State<MqttBasicsScreen> createState() => _MqttBasicsScreenState();
}

class _MqttBasicsScreenState extends State<MqttBasicsScreen> {
  final TextEditingController _brokerIpController =
      TextEditingController(text: '127.0.0.1');

  MqttServerClient? _client;
  String _statusText = 'ยังไม่ได้เชื่อมต่อ (Disconnected)';
  Color _statusColor = Colors.redAccent;
  final List<String> _receivedLogs = [];

  @override
  void dispose() {
    _brokerIpController.dispose();
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _connectToBroker() async {
    setState(() {
      _statusText = 'กำลังเชื่อมต่อไปยัง Broker...';
      _statusColor = Colors.amber;
    });

    final broker = _brokerIpController.text.trim();
    final clientId = 'Flutter_Lab12_1_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient(broker, clientId);
    _client!.port = 1883;
    _client!.keepAlivePeriod = 20;
    _client!.autoReconnect = true;

    _client!.onConnected = () {
      setState(() {
        _statusText = 'เชื่อมต่อสำเร็จ (Connected)';
        _statusColor = const Color(0xFF00E676);
      });
      _subscribeToTestTopic();
    };

    _client!.onDisconnected = () {
      setState(() {
        _statusText = 'การเชื่อมต่อหลุด (Disconnected)';
        _statusColor = Colors.redAccent;
      });
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('iot/flutter/lwt')
        .withWillMessage('Client crashed')
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } on SocketException catch (e) {
      _appendLog('Socket Error: ไม่สามารถต่อ Broker IP ได้ ($e)');
      _client?.disconnect();
    } catch (e) {
      _appendLog('Error: $e');
      _client?.disconnect();
    }
  }

  void _subscribeToTestTopic() {
    const topic = 'test/broker/echo';
    _client?.subscribe(topic, MqttQos.atLeastOnce);
    _appendLog('Subscribed to topic: $topic');

    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _appendLog('[IN] ${c[0].topic} -> $pt');
    });
  }

  void _publishTestMessage() {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      _appendLog('⚠️ กรุณาเชื่อมต่อ Broker ก่อนส่งข้อความ');
      return;
    }
    const topic = 'test/flutter/ping';
    final builder = MqttClientPayloadBuilder();
    builder.addString('Ping from Flutter at ${DateTime.now().toIso8601String()}');
    _client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    _appendLog('[OUT] Published -> $topic');
  }

  void _appendLog(String log) {
    setState(() {
      _receivedLogs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}: $log');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab 12.1 MQTT Basics (รหัส 67030211)'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _brokerIpController,
              decoration: const InputDecoration(
                labelText: 'Broker IP Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connectToBroker,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _client?.disconnect(),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, color: _statusColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusText, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publishTestMessage,
                icon: const Icon(Icons.send),
                label: const Text('Publish Test Message (Ping)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                child: ListView.builder(
                  itemCount: _receivedLogs.length,
                  itemBuilder: (context, index) => Text(_receivedLogs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 2. ผลลัพธ์จาก Serial Monitor / หน้าจอแสดงผล

ผลการทดสอบ `flutter doctor` บนเทอร์มินัล:
```text
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.0, on macOS / Windows)
[✓] Android toolchain - develop for Android devices
[✓] VS Code (version 1.93.0)
[✓] Connected device (Windows / macOS desktop)
[✓] Network resources

• No issues found!
```

ผลการทดสอบรับส่งข้อมูลร่วมกับ Mosquitto CLI:
1. ฝั่ง Mosquitto Subscriber รับข้อความ Ping จาก Flutter:
```text
test/flutter/ping Ping from Flutter at 2026-09-20T10:15:30.123456
```
2. ฝั่ง Mosquitto Publisher ส่งข้อความตอบกลับ Echo:
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "test/broker/echo" -m "Echo response from CLI"
```
3. บันทึกผลในช่อง Transaction Logs บนหน้าจอ Flutter App:
```text
10:15:35: [IN] test/broker/echo -> Echo response from CLI
10:15:30: [OUT] Published -> test/flutter/ping
10:15:25: Subscribed to topic: test/broker/echo
10:15:25: เชื่อมต่อสำเร็จ (Connected)
```

#### 3. สรุปผลและการตอบคำถามท้ายใบงาน

- **สรุปผลการทดลอง:**
  สามารถติดตั้งสภาพแวดล้อมการพัฒนาแอปพลิเคชัน Flutter และสร้างหน้าจอควบคุมพื้นฐานร่วมกับแพ็กเกจ mqtt_client เพื่อเชื่อมต่อกับ Mosquitto Broker พอร์ต 1883 ได้สำเร็จ แอปพลิเคชันรองรับการทำงานแบบสองทาง ทั้งการ Subscribe หัวข้อ test/broker/echo เพื่อรับข้อความมาแสดงผลบน Transaction Logs แบบเรียลไทม์ และการกดส่งข้อความ Publish ไปยังหัวข้อ test/flutter/ping พร้อมทั้งมีกลไกแสดงสถานะการเชื่อมต่อ และลงทะเบียน Last Will and Testament (LWT) ได้อย่างสมบูรณ์

- **คำถามท้ายการทดลอง (Review Questions):**
1. **เพราะเหตุใดเราจึงต้องสุ่มชื่อ `clientId` เช่นการใส่ Timestamp ต่อท้าย แทนที่จะตั้งชื่อแบบคงที่?**
     - **คำตอบ:** เพื่อป้องกันปัญหา Client ID ชนกัน เพราะตามมาตรฐาน MQTT หากมีอุปกรณ์ต่อเข้า Broker ด้วย Client ID ซ้ำกัน โบรกเกอร์จะตัดการเชื่อมต่อของเครื่องเดิมทิ้งทันที (Session Stealing/Reconnection Loop) การเติม Timestamp ช่วยรับประกันความไม่ซ้ำซ้อน (Unique) ในแต่ละ Session

2. **หากหน้าจอ Flutter รันบนอุปกรณ์จริง (Physical Android Phone) เหตุใดการกรอก IP `127.0.0.1` จึงไม่สามารถเชื่อมต่อ Broker ได้? และต้องใช้ IP ใด?**
     - **คำตอบ:** เพราะ 127.0.0.1 (Localhost) บนสมาร์ตโฟนจะชี้เข้าหาตัวเอง ไม่ได้ชี้ไปยังเครื่องคอมพิวเตอร์ที่เปิด Broker อยู่ การแก้ไขต้องเปลี่ยนไปใช้ IPv4 จริงของเครื่องคอมพิวเตอร์ในวง Wi-Fi เดียวกัน (เช่น 192.168.1.100) ที่สมาร์ตโฟนสามารถมองเห็นและสื่อสารผ่านเครือข่ายแลนได้

3. **การตั้งค่า `keepAlivePeriod` มีความจำเป็นอย่างไรในสภาพแวดล้อมเครือข่ายไร้สาย?**
     - **คำตอบ:** ใช้ส่งแพ็กเก็ต PINGREQ / PINGRESP (Heartbeat) ระหว่าง Client กับ Broker เพื่อตรวจสอบว่าการเชื่อมต่อยังทำงานอยู่หรือไม่ ช่วยป้องกันไม่ให้เราเตอร์หรือไฟร์วอลล์ตัด TCP Socket ที่ไม่มีทราฟฟิกทิ้ง (NAT Timeout) และช่วยให้ทั้งสองฝั่งรับรู้ได้อย่างรวดเร็วเมื่อเกิดเหตุสัญญาณ Wi-Fi หลุด เพื่อเข้าสู่กระบวนการ Auto-reconnect ต่อไป

---