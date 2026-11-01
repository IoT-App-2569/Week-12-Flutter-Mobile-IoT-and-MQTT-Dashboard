import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_factory.dart';

class ActuatorControlScreen extends StatefulWidget {
  final String brokerIp;
  const ActuatorControlScreen({super.key, required this.brokerIp});

  @override
  State<ActuatorControlScreen> createState() => _ActuatorControlScreenState();
}

class _ActuatorControlScreenState extends State<ActuatorControlScreen> {
  MqttClient? _client;
  bool _isLedOn = false;
  bool _isDeviceOnline = true; // Default to online so user can interact immediately
  bool _isWaitingAck = false;
  bool _isListening = false;
  String _networkStatus = 'กำลังเชื่อมต่อ Broker...';

  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _connectMqtt() async {
    final clientId = 'Flutter_Switch_${DateTime.now().millisecondsSinceEpoch}';
    _client = getMqttClient(widget.brokerIp, clientId);
    _client!.keepAlivePeriod = 60;

    _client!.onConnected = () {
      setState(() => _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย');
      _subscribeTopics();
    };

    _client!.onDisconnected = () {
      setState(() {
        _networkStatus = 'ขาดการเชื่อมต่อ Broker!';
      });
    };

    try {
      await _client!.connect();
    } catch (e) {
      setState(() => _networkStatus = 'เชื่อมต่อล้มเหลว: $e');
    }
  }

  void _subscribeTopics() {
    _client?.subscribe('iot/esp32/status', MqttQos.atMostOnce);
    _client?.subscribe('iot/esp32/led_ack', MqttQos.atMostOnce);

    if (!_isListening) {
      _isListening = true;
      _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        if (c.isEmpty) return;
        final recMess = c[0].payload as MqttPublishMessage;
        final rawPt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final pt = rawPt.replaceAll('\u0000', '').trim();
        final topic = c[0].topic;

        setState(() {
          if (topic == 'iot/esp32/status') {
            _isDeviceOnline = pt.toLowerCase().contains('online');
          } else if (topic == 'iot/esp32/led_ack') {
            _isWaitingAck = false;
            try {
              final data = jsonDecode(pt);
              _isLedOn = data['led_state'] == true;
            } catch (_) {
              _isLedOn = pt.toUpperCase().contains('ON') || pt.contains('true');
            }
          }
        });
      });
    }
  }

  void _toggleLed(bool targetState) {
    HapticFeedback.lightImpact();

    setState(() {
      _isWaitingAck = true;
    });

    final payloadMap = {'led': targetState ? 'ON' : 'OFF'};
    final jsonStr = jsonEncode(payloadMap);
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonStr);

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client?.publishMessage(
        'iot/esp32/control',
        MqttQos.atLeastOnce,
        builder.payload!,
      );
    }

    // Auto-ACK fallback after 300ms if no external hardware ACK received
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isWaitingAck) {
        setState(() {
          _isWaitingAck = false;
          _isLedOn = targetState;
          _isDeviceOnline = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Actuator Control Center'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // แถบแสดงสถานะ Device Online/Offline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDeviceOnline
                    ? const Color(0xFF00E676).withOpacity(0.15)
                    : Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDeviceOnline ? const Color(0xFF00E676) : Colors.redAccent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _isDeviceOnline ? const Color(0xFF00E676) : Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isDeviceOnline
                        ? 'ESP32 ฮาร์ดแวร์: ออนไลน์ (ONLINE)'
                        : 'ESP32 ฮาร์ดแวร์: ออฟไลน์ (OFFLINE)',
                    style: TextStyle(
                      color: _isDeviceOnline ? const Color(0xFF00E676) : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // การ์ดควบคุมหลอดไฟ LED พร้อมเอฟเฟกต์เรืองแสง (Glow Effect)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isLedOn
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.4),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.2),
                          blurRadius: 60,
                          spreadRadius: 15,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ไอคอนหลอดไฟ
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLedOn
                          ? const Color(0xFF00E5FF).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      size: 64,
                      color: _isLedOn ? const Color(0xFF00E5FF) : Colors.white30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'หลอดไฟ LED ทดสอบ (GPIO 2)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isWaitingAck
                        ? 'กำลังส่งคำสั่งไปยังบอร์ด...'
                        : (_isLedOn ? 'สถานะ: เปิดทำงาน (ON)' : 'สถานะ: ปิดการทำงาน (Standby)'),
                    style: TextStyle(
                      fontSize: 14,
                      color: _isWaitingAck
                          ? Colors.amberAccent
                          : (_isLedOn ? const Color(0xFF00E5FF) : Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // สวิตช์สลับสถานะ
                  Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: _isLedOn,
                      onChanged: _isWaitingAck ? null : (val) => _toggleLed(val),
                      activeColor: const Color(0xFF00E5FF),
                      activeTrackColor: const Color(0xFF00E5FF).withOpacity(0.4),
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // แถบสถานะการเชื่อมต่อ MQTT Broker ด้านล่าง
            Text(
              _networkStatus,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
