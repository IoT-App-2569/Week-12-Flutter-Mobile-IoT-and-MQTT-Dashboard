import 'dart:async';
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
  static const _statusTopic = 'iot/esp32/status';
  static const _ledAckTopic = 'iot/esp32/led_ack';
  static const _controlTopic = 'iot/esp32/control';

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
  _updatesSubscription;
  Timer? _ackTimeout;
  bool _isLedOn = false;
  bool _isDeviceOnline = false;
  bool _isWaitingAck = false;
  bool _isConnecting = false;
  String _networkStatus = 'กำลังเชื่อมต่อ Broker...';

  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  @override
  void dispose() {
    _ackTimeout?.cancel();
    unawaited(_updatesSubscription?.cancel());
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _connectMqtt() async {
    if (_isConnecting ||
        _client?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    final brokerHost = widget.brokerIp.trim();
    if (brokerHost.isEmpty) {
      _setNetworkStatus('กรุณากำหนด IP หรือชื่อโฮสต์ของ Broker');
      return;
    }

    if (mounted) {
      setState(() {
        _isConnecting = true;
        _networkStatus = 'กำลังเชื่อมต่อ Broker...';
      });
    }

    final clientId = 'Flutter_Switch_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(brokerHost, clientId)
      ..port = 1883
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 10000
      ..autoReconnect = true;
    final previousClient = _client;
    _client = client;
    unawaited(_updatesSubscription?.cancel());
    _updatesSubscription = null;
    previousClient?.disconnect();

    client.onConnected = () {
      if (!_isCurrentClient(client)) return;
      setState(() {
        _isConnecting = false;
        _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย';
      });
      _subscribeTopics(client);
    };

    client.onDisconnected = () {
      if (!_isCurrentClient(client)) return;
      _ackTimeout?.cancel();
      setState(() {
        _networkStatus = 'ขาดการเชื่อมต่อ Broker!';
        _isDeviceOnline = false;
        _isWaitingAck = false;
        _isConnecting = false;
      });
    };

    client.onAutoReconnect = () {
      if (!_isCurrentClient(client)) return;
      setState(() {
        _isDeviceOnline = false;
        _isWaitingAck = false;
        _isConnecting = true;
        _networkStatus = 'กำลังเชื่อมต่อ Broker อีกครั้ง...';
      });
    };

    client.onAutoReconnected = () {
      if (!_isCurrentClient(client)) return;
      setState(() {
        _isConnecting = false;
        _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย';
      });
    };

    try {
      final status = await client.connect();
      if (!_isCurrentClient(client)) return;
      if (status?.state != MqttConnectionState.connected) {
        setState(() {
          _isConnecting = false;
          _networkStatus = 'เชื่อมต่อ Broker ไม่สำเร็จ';
        });
      }
    } on Exception catch (error) {
      debugPrint('MQTT connection failed: $error');
      if (!_isCurrentClient(client)) return;
      setState(() {
        _isConnecting = false;
        _networkStatus = 'เชื่อมต่อล้มเหลว: $error';
      });
    }
  }

  bool _isCurrentClient(MqttServerClient client) =>
      mounted && identical(_client, client);

  void _setNetworkStatus(String status) {
    if (!mounted) return;
    setState(() => _networkStatus = status);
  }

  void _subscribeTopics(MqttServerClient client) {
    unawaited(_updatesSubscription?.cancel());
    _updatesSubscription = client.updates?.listen(
      (messages) => _handleMessages(client, messages),
      onError: (Object error, StackTrace stackTrace) {
        if (!_isCurrentClient(client)) return;
        debugPrint('MQTT updates stream error: $error');
        _setNetworkStatus('เกิดข้อผิดพลาดในการรับข้อมูลจาก Broker');
      },
    );

    client.subscribe(_statusTopic, MqttQos.atMostOnce);
    client.subscribe(_ledAckTopic, MqttQos.atMostOnce);
  }

  void _handleMessages(
    MqttServerClient client,
    List<MqttReceivedMessage<MqttMessage>> messages,
  ) {
    if (!_isCurrentClient(client)) return;

    for (final message in messages) {
      final payload = message.payload;
      if (payload is! MqttPublishMessage) continue;

      final text = MqttPublishPayload.bytesToStringAsString(
        payload.payload.message,
      );

      if (message.topic == _statusTopic) {
        final isOnline = text.trim().toLowerCase() == 'online';
        if (!isOnline) _ackTimeout?.cancel();
        setState(() {
          _isDeviceOnline = isOnline;
          if (!isOnline && _isWaitingAck) {
            _isWaitingAck = false;
            _networkStatus = 'อุปกรณ์ ESP32 ออฟไลน์อยู่';
          }
        });
      } else if (message.topic == _ledAckTopic) {
        _handleLedAcknowledgement(text);
      }
    }
  }

  void _handleLedAcknowledgement(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Missing boolean led_state');
      }
      final ledState = decoded['led_state'];
      if (ledState is! bool) {
        throw const FormatException('Missing boolean led_state');
      }

      _ackTimeout?.cancel();
      setState(() {
        _isWaitingAck = false;
        _isLedOn = ledState;
        _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย';
      });
    } on FormatException catch (error) {
      debugPrint('Invalid LED acknowledgement: $error');
      _setNetworkStatus('ได้รับข้อมูลยืนยันจากบอร์ดไม่ถูกต้อง');
    }
  }

  void _toggleLed(bool targetState) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
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

    unawaited(HapticFeedback.lightImpact());

    _ackTimeout?.cancel();
    setState(() {
      _isWaitingAck = true;
    });
    _ackTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted || !_isWaitingAck) return;
      setState(() {
        _isWaitingAck = false;
        _networkStatus = 'ไม่ได้รับการยืนยันจากบอร์ดภายในเวลาที่กำหนด';
      });
    });

    final payloadMap = {'led': targetState ? 'ON' : 'OFF'};
    final jsonStr = jsonEncode(payloadMap);
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonStr);

    final payload = builder.payload;
    final client = _client;
    if (payload == null || client == null) {
      _ackTimeout?.cancel();
      setState(() {
        _isWaitingAck = false;
        _networkStatus = 'ไม่สามารถเตรียมคำสั่งส่งไปยังอุปกรณ์ได้';
      });
      return;
    }

    try {
      client.publishMessage(_controlTopic, MqttQos.atLeastOnce, payload);
    } on Exception catch (error) {
      debugPrint('MQTT publish failed: $error');
      _ackTimeout?.cancel();
      setState(() {
        _isWaitingAck = false;
        _networkStatus = 'ส่งคำสั่งไปยังอุปกรณ์ไม่สำเร็จ';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Actuator Control Center'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            tooltip: 'เชื่อมต่อ Broker อีกครั้ง',
            onPressed:
                _isConnecting ||
                    _client?.connectionStatus?.state ==
                        MqttConnectionState.connected
                ? null
                : _connectMqtt,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // แถบแสดงสถานะ Device Online/Offline
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                            : (_isLedOn
                                  ? const Color(0xFF00E676)
                                  : Colors.white38),
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
              const SizedBox(height: 24),
              Text(
                _networkStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
