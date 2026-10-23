import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class ActuatorControlScreen extends StatefulWidget {
  final String brokerIp;

  const ActuatorControlScreen({super.key, required this.brokerIp});

  @override
  State<ActuatorControlScreen> createState() => _ActuatorControlScreenState();
}

class _ActuatorControlScreenState extends State<ActuatorControlScreen> {
  MqttServerClient? _client;

  bool _isLedOn = false;
  bool _isDeviceOnline = false;
  bool _isWaitingAck = false;

  String _networkStatus = 'กำลังเชื่อมต่อ Broker...';

  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  @override
  void dispose() {
    final client = _client;
    _client = null;

    client?.disconnect();

    super.dispose();
  }

  Future<void> _connectMqtt() async {
    final clientId = 'Flutter_Switch_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient(widget.brokerIp, clientId);
    _client = client;

    client.port = 1883;
    client.keepAlivePeriod = 20;

    client.onConnected = () {
      if (!mounted || !identical(_client, client)) return;

      setState(() {
        _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย';
      });

      _subscribeTopics(client);
    };

    client.onDisconnected = () {
      if (!mounted || !identical(_client, client)) return;

      setState(() {
        _networkStatus = 'ขาดการเชื่อมต่อ Broker!';
        _isDeviceOnline = false;
        _isWaitingAck = false;
      });
    };

    try {
      await client.connect();

      if (!mounted || !identical(_client, client)) {
        client.disconnect();
        return;
      }

      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        setState(() {
          _networkStatus = 'เชื่อมต่อล้มเหลว กรุณาตรวจสอบ Broker';
          _isDeviceOnline = false;
        });

        client.disconnect();
      }
    } catch (e) {
      debugPrint('MQTT connection error: $e');

      client.disconnect();

      if (!mounted || !identical(_client, client)) return;

      setState(() {
        _networkStatus = 'เชื่อมต่อล้มเหลว: $e';
        _isDeviceOnline = false;
      });
    }
  }

  void _subscribeTopics(MqttServerClient client) {
    client.subscribe('iot/esp32/status', MqttQos.atMostOnce);

    client.subscribe('iot/esp32/led_ack', MqttQos.atMostOnce);

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      if (!mounted || !identical(_client, client) || messages.isEmpty) {
        return;
      }

      try {
        final recMess = messages.first.payload as MqttPublishMessage;

        final payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        final topic = messages.first.topic;

        if (!mounted) return;

        setState(() {
          if (topic == 'iot/esp32/status') {
            _isDeviceOnline = payload.trim().toLowerCase() == 'online';
          } else if (topic == 'iot/esp32/led_ack') {
            _isWaitingAck = false;

            try {
              final decoded = jsonDecode(payload);

              if (decoded is Map<String, dynamic>) {
                _isLedOn = decoded['led_state'] == true;
              }
            } catch (e) {
              debugPrint('LED ACK parsing error: $e');
            }
          }
        });
      } catch (e) {
        debugPrint('MQTT message error: $e');
      }
    });
  }

  void _toggleLed(bool targetState) {
    final client = _client;

    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ กรุณาเชื่อมต่อ Broker ก่อนสั่งการ')),
      );
      return;
    }

    if (!_isDeviceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ อุปกรณ์ ESP32 ออฟไลน์อยู่ ไม่สามารถส่งคำสั่งได้'),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isWaitingAck = true;
    });

    final payloadMap = {'led': targetState ? 'ON' : 'OFF'};

    final jsonStr = jsonEncode(payloadMap);

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonStr);

    final payload = builder.payload;

    if (payload == null) {
      setState(() {
        _isWaitingAck = false;
      });
      return;
    }

    client!.publishMessage('iot/esp32/control', MqttQos.atLeastOnce, payload);
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // แถบแสดงสถานะ Device Online/Offline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDeviceOnline
                    ? const Color(0x1A00E676)
                    : const Color(0x1AFF5252),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDeviceOnline
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF5252),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: _isDeviceOnline
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFF5252),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isDeviceOnline
                          ? 'ESP32 ฮาร์ดแวร์: ออนไลน์ (ONLINE)'
                          : 'ESP32 ฮาร์ดแวร์: ออฟไลน์ (OFFLINE)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDeviceOnline
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // การ์ดควบคุมหลอดไฟแบบ Glassmorphism
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isLedOn
                      ? const Color(0xFF00E676).withValues(alpha: 0.6)
                      : Colors.white12,
                  width: 2,
                ),
                boxShadow: _isLedOn
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF00E676,
                          ).withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  // ไอคอนหลอดไฟพร้อมเอฟเฟกต์แสง
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLedOn
                          ? const Color(0x3300E676)
                          : Colors.black26,
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      size: 72,
                      color: _isLedOn
                          ? const Color(0xFF00E676)
                          : Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'หลอดไฟ LED ทดสอบ (GPIO 2)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isWaitingAck
                        ? 'กำลังรอการยืนยันจากบอร์ด (Waiting ACK)...'
                        : _isLedOn
                        ? 'สถานะ: เปิดสว่าง (Active)'
                        : 'สถานะ: ปิดการทำงาน (Standby)',
                    style: TextStyle(
                      color: _isWaitingAck
                          ? Colors.amber
                          : _isLedOn
                          ? const Color(0xFF00E676)
                          : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // สวิตช์ควบคุม
                  Transform.scale(
                    scale: 1.4,
                    child: Switch(
                      value: _isLedOn,
                      activeThumbColor: const Color(0xFF00E676),
                      onChanged: _isWaitingAck ? null : _toggleLed,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              _networkStatus,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
