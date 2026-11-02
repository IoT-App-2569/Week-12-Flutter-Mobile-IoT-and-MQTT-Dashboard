
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class ActuatorControlScreen extends StatefulWidget {
  final String brokerIp;

  const ActuatorControlScreen({
    super.key,
    required this.brokerIp,
  });

  @override
  State<ActuatorControlScreen> createState() =>
      _ActuatorControlScreenState();
}

class _ActuatorControlScreenState
    extends State<ActuatorControlScreen> {
  MqttServerClient? _client;

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
      _updatesSubscription;

  Timer? _ackTimer;
  Timer? _reconnectTimer;

  bool _isLedOn = false;
  bool _isDeviceOnline = false;
  bool _isWaitingAck = false;
  bool _isDisposed = false;
  bool _isConnecting = false;

  bool? _pendingTargetState;

  String _networkStatus = 'กำลังเชื่อมต่อ Broker...';

  static const String _controlTopic = 'iot/esp32/control';
  static const String _ackTopic = 'iot/esp32/led_ack';
  static const String _statusTopic = 'iot/esp32/status';

  static const Duration _ackTimeout = Duration(seconds: 5);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _ackTimer?.cancel();
    _reconnectTimer?.cancel();
    _updatesSubscription?.cancel();

    _client?.disconnect();

    super.dispose();
  }

  void _safeSetState(VoidCallback callback) {
    if (mounted && !_isDisposed) {
      setState(callback);
    }
  }

  Future<void> _connectMqtt() async {
    if (_isConnecting || _isDisposed) return;

    _isConnecting = true;

    _safeSetState(() {
      _networkStatus = 'กำลังเชื่อมต่อ Broker...';
    });

    final clientId =
        'Flutter_Switch_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient.withPort(
      widget.brokerIp,
      clientId,
      1883,
    );

    _client = client;

    client.keepAlivePeriod = 20;
    client.autoReconnect = false;
    client.logging(on: false);

    client.onConnected = () {
      if (_isDisposed) return;

      _reconnectTimer?.cancel();

      _safeSetState(() {
        _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย';
      });

      _subscribeTopics();
    };

    client.onDisconnected = () {
      if (_isDisposed) return;

      _ackTimer?.cancel();

      _safeSetState(() {
        _isDeviceOnline = false;
        _isWaitingAck = false;
        _pendingTargetState = null;
        _networkStatus = 'ขาดการเชื่อมต่อ Broker!';
      });

      _scheduleReconnect();
    };

    try {
      final status = await client.connect();

      if (_isDisposed) {
        client.disconnect();
        return;
      }

      if (status?.state != MqttConnectionState.connected) {
        throw Exception('Broker connection failed');
      }

    } catch (e) {
      debugPrint('MQTT Connection Error: $e');

      client.disconnect();

      _safeSetState(() {
        _networkStatus = 'เชื่อมต่อล้มเหลว: $e';
        _isDeviceOnline = false;
      });

      _scheduleReconnect();

    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed) {
        _connectMqtt();
      }
    });
  }

  void _subscribeTopics() {
    final client = _client;

    if (client == null ||
        client.connectionStatus?.state !=
            MqttConnectionState.connected) {
      return;
    }

    _updatesSubscription?.cancel();

    client.subscribe(_statusTopic, MqttQos.atLeastOnce);
    client.subscribe(_ackTopic, MqttQos.atLeastOnce);

    _updatesSubscription = client.updates?.listen((messages) {
      if (messages.isEmpty || _isDisposed) return;

      final message = messages.first;

      final received = message.payload as MqttPublishMessage;

      final payload =
          MqttPublishPayload.bytesToStringAsString(
        received.payload.message,
      );

      _handleMessage(message.topic, payload);
    });
  }

  void _handleMessage(String topic, String payload) {
    if (_isDisposed) return;

    if (topic == _statusTopic) {
      final status = payload.trim().toLowerCase();

      _safeSetState(() {
        _isDeviceOnline = status == 'online';

        if (!_isDeviceOnline) {
          _ackTimer?.cancel();
          _isWaitingAck = false;
          _pendingTargetState = null;
        }
      });

      return;
    }

    if (topic == _ackTopic) {
      _handleAck(payload);
    }
  }

  void _handleAck(String payload) {
    try {
      final data = jsonDecode(payload);

      if (data is! Map<String, dynamic>) return;

      // ต้องเป็น ACK ที่สำเร็จเท่านั้น
      if (data['ack'] != true) {
        _ackTimer?.cancel();

        _safeSetState(() {
          _isWaitingAck = false;
          _pendingTargetState = null;
        });

        _showMessage('ESP32 ไม่สามารถดำเนินการตามคำสั่งได้');

        return;
      }

      if (data['led_state'] is! bool) return;

      final confirmedState = data['led_state'] as bool;

      // ตรวจสอบ ACK ให้ตรงกับคำสั่งล่าสุดที่รออยู่
      if (!_isWaitingAck ||
          _pendingTargetState != confirmedState) {
        return;
      }

      _ackTimer?.cancel();

      _safeSetState(() {
        _isLedOn = confirmedState;
        _isWaitingAck = false;
        _pendingTargetState = null;
      });

      _showMessage(
        confirmedState
            ? 'LED เปิดสำเร็จ'
            : 'LED ปิดสำเร็จ',
      );

    } catch (e) {
      debugPrint('Invalid ACK: $e');
    }
  }

  void _toggleLed(bool targetState) {
    final client = _client;

    if (client?.connectionStatus?.state !=
        MqttConnectionState.connected) {
      _showMessage('กรุณาเชื่อมต่อ Broker ก่อนสั่งการ');
      return;
    }

    if (!_isDeviceOnline) {
      _showMessage('ESP32 ออฟไลน์ ไม่สามารถสั่งงานได้');
      return;
    }

    if (_isWaitingAck) {
      return;
    }

    HapticFeedback.lightImpact();

    final payload = jsonEncode({
      'led': targetState ? 'ON' : 'OFF',
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    try {
      _safeSetState(() {
        _isWaitingAck = true;
        _pendingTargetState = targetState;
      });

      client!.publishMessage(
        _controlTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      // รอ ACK ไม่เกิน 5 วินาที
      _ackTimer?.cancel();

      _ackTimer = Timer(_ackTimeout, () {
        if (_isDisposed || !_isWaitingAck) return;

        _safeSetState(() {
          _isWaitingAck = false;
          _pendingTargetState = null;
        });

        _showMessage('หมดเวลารอ ACK จาก ESP32');
      });

    } catch (e) {
      _ackTimer?.cancel();

      _safeSetState(() {
        _isWaitingAck = false;
        _pendingTargetState = null;
      });

      _showMessage('ส่งคำสั่งไม่สำเร็จ: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ledColor = _isLedOn
        ? const Color(0xFF00E676)
        : Colors.white24;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        title: const Text('Actuator Control Center'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            // DEVICE STATUS
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

            // LED CONTROL CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.8),

                borderRadius: BorderRadius.circular(24),

                border: Border.all(
                  color: _isLedOn
                      ? const Color(0xFF00E676).withOpacity(0.6)
                      : Colors.white12,

                  width: 2,
                ),

                boxShadow: _isLedOn
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E676)
                              .withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),

              child: Column(
                children: [
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
                      color: ledColor,
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

                  const SizedBox(height: 8),

                  Text(
                    _isWaitingAck
                        ? 'กำลังรอการยืนยันจากบอร์ด (Waiting ACK)...'
                        : _isLedOn
                            ? 'สถานะ: เปิดสว่าง (Active)'
                            : 'สถานะ: ปิดการทำงาน (Standby)',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: _isWaitingAck
                          ? Colors.amber
                          : _isLedOn
                              ? const Color(0xFF00E676)
                              : Colors.white38,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Transform.scale(
                    scale: 1.4,

                    child: Switch(
                      value: _isLedOn,

                      activeColor: const Color(0xFF00E676),

                      onChanged: _isWaitingAck
                          ? null
                          : _toggleLed,
                    ),
                  ),

                  if (_isWaitingAck) ...[
                    const SizedBox(height: 12),

                    const LinearProgressIndicator(
                      color: Colors.amber,
                      backgroundColor: Colors.white12,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Timeout: 5 วินาที',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            Text(
              _networkStatus,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
