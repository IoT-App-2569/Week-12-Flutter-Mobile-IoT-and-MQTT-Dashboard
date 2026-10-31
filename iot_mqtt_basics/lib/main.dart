import 'package:flutter/material.dart';

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
  final TextEditingController _brokerIpController = TextEditingController(
    text: '127.0.0.1',
  );

  bool _isConnected = false;
  String _statusText = 'ยังไม่ได้เชื่อมต่อ (Disconnected)';
  Color _statusColor = Colors.redAccent;
  final List<String> _receivedLogs = [];

  @override
  void dispose() {
    _brokerIpController.dispose();
    super.dispose();
  }

  void _connectToBroker() {
    setState(() {
      _isConnected = true;
      _statusText = 'เชื่อมต่อสำเร็จ (Connected)';
      _statusColor = const Color(0xFF00E676);
    });
    _appendLog('✅ เชื่อมต่อกับ Broker (${_brokerIpController.text}) สำเร็จ');
    _appendLog('📢 Subscribed to: test/broker/echo');
  }

  void _disconnectFromBroker() {
    setState(() {
      _isConnected = false;
      _statusText = 'ยังไม่ได้เชื่อมต่อ (Disconnected)';
      _statusColor = Colors.redAccent;
    });
    _appendLog('ℹ️ ตัดการเชื่อมต่อเรียบร้อย');
  }

  void _publishTestMessage() {
    if (!_isConnected) {
      _appendLog('⚠️ ไม่สามารถส่งข้อความได้เนื่องจากยังไม่ได้เชื่อมต่อ');
      return;
    }

    const topic = 'test/flutter/ping';
    final timeStr = DateTime.now().toIso8601String();
    _appendLog('🚀 Published -> $topic : Hello from Flutter at $timeStr');

    // จำลองการได้รับ Echo ตอบกลับ
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isConnected) {
        _appendLog(
          '📩 [test/broker/echo] -> Echo response from CLI ($timeStr)',
        );
      }
    });
  }

  void _appendLog(String log) {
    setState(() {
      _receivedLogs.insert(
        0,
        '[${DateTime.now().toLocal().toString().substring(11, 19)}] $log',
      );
      if (_receivedLogs.length > 50) _receivedLogs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab 12.1: MQTT Client Basics'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _brokerIpController,
              decoration: const InputDecoration(
                labelText: 'Broker IPv4 Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, color: _statusColor, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectFromBroker,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publishTestMessage,
                icon: const Icon(Icons.send),
                label: const Text('Publish Test Message (Ping)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'บันทึกการทำงาน (Transaction Logs):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  itemCount: _receivedLogs.length,
                  itemBuilder: (context, index) => Text(
                    _receivedLogs[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
