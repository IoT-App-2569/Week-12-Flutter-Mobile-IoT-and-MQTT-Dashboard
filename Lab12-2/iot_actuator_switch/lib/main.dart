
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MqttActuatorApp());
}

class MqttActuatorApp extends StatelessWidget {
  const MqttActuatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab 12.2 MQTT Actuator Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const ActuatorControlScreen(),
    );
  }
}

class ActuatorControlScreen extends StatefulWidget {
  const ActuatorControlScreen({super.key});

  @override
  State<ActuatorControlScreen> createState() =>
      _ActuatorControlScreenState();
}

class _ActuatorControlScreenState
    extends State<ActuatorControlScreen> {
  // --------------------------------------------------
  // MQTT CONFIGURATION
  // --------------------------------------------------

  final TextEditingController _brokerIpController =
      TextEditingController(text: '127.0.0.1');

  MqttServerClient? _client;

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
      _updatesSubscription;

  static const String _controlTopic = 'iot/esp32/control';
  static const String _ackTopic = 'iot/esp32/led_ack';
  static const String _statusTopic = 'iot/esp32/status';

  static const Duration _ackTimeout =
      Duration(seconds: 5);

  Timer? _ackTimer;

  // --------------------------------------------------
  // APPLICATION STATE
  // --------------------------------------------------

  String _brokerStatus = 'Disconnected';
  Color _brokerStatusColor = Colors.redAccent;

  String _deviceStatus = 'Unknown';
  Color _deviceStatusColor = Colors.grey;

  bool _isConnecting = false;
  bool _isLedOn = false;
  bool _isDeviceOnline = false;
  bool _isWaitingAck = false;

  // สถานะ LED ที่กำลังรอ ACK
  bool? _pendingLedState;

  final List<String> _receivedLogs = [];

  // --------------------------------------------------
  // LOG SYSTEM
  // --------------------------------------------------

  void _appendLog(String log) {
    if (!mounted) return;

    final time = DateTime.now()
        .toLocal()
        .toString()
        .substring(11, 19);

    setState(() {
      _receivedLogs.insert(0, '[$time] $log');

      if (_receivedLogs.length > 100) {
        _receivedLogs.removeLast();
      }
    });
  }

  // --------------------------------------------------
  // CONNECT MQTT BROKER
  // --------------------------------------------------

  Future<void> _connectToBroker() async {
    if (_isConnecting) return;

    if (_client?.connectionStatus?.state ==
        MqttConnectionState.connected) {
      _appendLog('⚠️ MQTT Broker is already connected');
      return;
    }

    final broker = _brokerIpController.text.trim();

    if (broker.isEmpty) {
      _appendLog('⚠️ กรุณากรอก Broker IP Address');
      return;
    }

    setState(() {
      _isConnecting = true;
      _brokerStatus = 'Connecting...';
      _brokerStatusColor = Colors.amber;
      _deviceStatus = 'Unknown';
      _deviceStatusColor = Colors.grey;
      _isDeviceOnline = false;
    });

    // ปิดการเชื่อมต่อเก่าถ้ามี
    await _updatesSubscription?.cancel();
    _updatesSubscription = null;
    _client?.disconnect();

    final clientId =
        'Flutter_Lab12_2_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient(broker, clientId);

    _client = client;

    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.autoReconnect = false;
    client.logging(on: false);

    client.onConnected = () {
      if (!mounted) return;

      setState(() {
        _brokerStatus = 'Connected';
        _brokerStatusColor = const Color(0xFF00E676);
        _isConnecting = false;
      });

      _appendLog('✅ Connected to Broker: $broker:1883');

      _subscribeToTopics();
    };

    client.onDisconnected = () {
      if (!mounted) return;

      _cancelPendingCommand();

      setState(() {
        _brokerStatus = 'Disconnected';
        _brokerStatusColor = Colors.redAccent;
        _deviceStatus = 'Unknown';
        _deviceStatusColor = Colors.grey;
        _isDeviceOnline = false;
        _isConnecting = false;
      });

      _appendLog('❌ MQTT Broker Disconnected');
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('iot/flutter/lwt')
        .withWillMessage('Client crashed')
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      final result = await client.connect();

      if (result?.state != MqttConnectionState.connected) {
        _appendLog('❌ Connection failed: ${result?.state}');

        client.disconnect();

        if (mounted) {
          setState(() {
            _brokerStatus = 'Connection Failed';
            _brokerStatusColor = Colors.redAccent;
            _isConnecting = false;
          });
        }
      }
    } on SocketException catch (e) {
      _appendLog('❌ Socket Error: $e');
      client.disconnect();

      if (mounted) {
        setState(() {
          _brokerStatus = 'Cannot connect to Broker';
          _brokerStatusColor = Colors.redAccent;
          _isConnecting = false;
        });
      }
    } catch (e) {
      _appendLog('❌ MQTT Error: $e');
      client.disconnect();

      if (mounted) {
        setState(() {
          _brokerStatus = 'Connection Error';
          _brokerStatusColor = Colors.redAccent;
          _isConnecting = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // SUBSCRIBE MQTT TOPICS
  // --------------------------------------------------

  void _subscribeToTopics() {
    final client = _client;

    if (client == null ||
        client.connectionStatus?.state !=
            MqttConnectionState.connected) {
      return;
    }

    // Subscribe สถานะ ESP32
    client.subscribe(
      _statusTopic,
      MqttQos.atLeastOnce,
    );

    // Subscribe ACK จาก ESP32
    client.subscribe(
      _ackTopic,
      MqttQos.atLeastOnce,
    );

    _appendLog('📢 Subscribed: $_statusTopic');
    _appendLog('📢 Subscribed: $_ackTopic');

    // รับข้อความจาก MQTT
    _updatesSubscription?.cancel();

    _updatesSubscription = client.updates?.listen(
      (messages) {
        for (final message in messages) {
          final receivedMessage =
              message.payload as MqttPublishMessage;

          final payload =
              MqttPublishPayload.bytesToStringAsString(
            receivedMessage.payload.message,
          );

          _appendLog(
            '📩 [${message.topic}] -> $payload',
          );

          if (message.topic == _statusTopic) {
            _handleDeviceStatus(payload);
          } else if (message.topic == _ackTopic) {
            _handleLedAck(payload);
          }
        }
      },
      onError: (error) {
        _appendLog('❌ MQTT Stream Error: $error');
      },
    );
  }

  // --------------------------------------------------
  // HANDLE ESP32 ONLINE / OFFLINE
  // --------------------------------------------------

  void _handleDeviceStatus(String payload) {
    final status = payload.trim().toLowerCase();

    if (!mounted) return;

    if (status == 'online') {
      setState(() {
        _isDeviceOnline = true;
        _deviceStatus = 'Online';
        _deviceStatusColor = const Color(0xFF00E676);
      });

      _appendLog('🟢 ESP32 is ONLINE');
    } else if (status == 'offline') {
      _cancelPendingCommand();

      setState(() {
        _isDeviceOnline = false;
        _deviceStatus = 'Offline';
        _deviceStatusColor = Colors.redAccent;
      });

      _appendLog('🔴 ESP32 is OFFLINE');
    } else {
      _appendLog('⚠️ Unknown device status: $payload');
    }
  }

  // --------------------------------------------------
  // HANDLE ACK FROM ESP32
  // --------------------------------------------------

  void _handleLedAck(String payload) {
    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map) {
        _appendLog('⚠️ Invalid ACK format');
        return;
      }

      final bool ack = decoded['ack'] == true;
      final ledState = decoded['led_state'];

      if (ledState is! bool) {
        _appendLog('⚠️ Invalid led_state in ACK');
        return;
      }

      if (!ack) {
        _cancelPendingCommand();
        _appendLog('❌ ESP32 rejected LED command');

        if (mounted) {
          setState(() {
            _isWaitingAck = false;
            _pendingLedState = null;
          });
        }
        return;
      }

      if (!_isWaitingAck || _pendingLedState == null) {
        _appendLog('ℹ️ Received ACK without pending command');
        return;
      }

      // ตรวจสอบว่า ACK ตรงกับคำสั่งที่ส่งไปหรือไม่
      if (ledState != _pendingLedState) {
        _appendLog('⚠️ ACK state does not match pending command');
        return;
      }

      _ackTimer?.cancel();
      _ackTimer = null;

      setState(() {
        _isLedOn = ledState;
        _isWaitingAck = false;
        _pendingLedState = null;
      });

      HapticFeedback.mediumImpact();

      _appendLog(
        '✅ ACK Received: LED ${ledState ? "ON" : "OFF"}',
      );
    } catch (e) {
      _appendLog('❌ Cannot decode ACK: $e');
    }
  }

  // --------------------------------------------------
  // LED CONTROL
  // --------------------------------------------------

  void _toggleLed(bool targetState) {
    final client = _client;

    if (client == null ||
        client.connectionStatus?.state !=
            MqttConnectionState.connected) {
      _appendLog('⚠️ กรุณาเชื่อมต่อ MQTT Broker ก่อน');
      return;
    }

    if (!_isDeviceOnline) {
      _appendLog('⚠️ ESP32 is offline');
      return;
    }

    if (_isWaitingAck) {
      _appendLog('⏳ กรุณารอ ACK จาก ESP32');
      return;
    }

    final command = {
      'led': targetState ? 'ON' : 'OFF',
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(command));

    final payload = builder.payload;

    if (payload == null) {
      _appendLog('❌ Cannot create MQTT payload');
      return;
    }

    // กำหนดสถานะรอ ACK ก่อน Publish
    setState(() {
      _isWaitingAck = true;
      _pendingLedState = targetState;
    });

    HapticFeedback.selectionClick();

    // เริ่มจับเวลา ACK Timeout
    _ackTimer?.cancel();

    _ackTimer = Timer(_ackTimeout, () {
      if (!mounted || !_isWaitingAck) return;

      setState(() {
        _isWaitingAck = false;
        _pendingLedState = null;
      });

      _appendLog('⏰ ACK Timeout: ESP32 did not respond');
    });

    try {
      client.publishMessage(
        _controlTopic,
        MqttQos.atLeastOnce,
        payload,
      );

      _appendLog(
        '🚀 Published: ${jsonEncode(command)}',
      );
    } catch (e) {
      _cancelPendingCommand();

      if (mounted) {
        setState(() {
          _isWaitingAck = false;
          _pendingLedState = null;
        });
      }

      _appendLog('❌ Publish Error: $e');
    }
  }

  // --------------------------------------------------
  // CANCEL PENDING COMMAND
  // --------------------------------------------------

  void _cancelPendingCommand() {
    _ackTimer?.cancel();
    _ackTimer = null;
    _pendingLedState = null;

    if (mounted) {
      setState(() {
        _isWaitingAck = false;
      });
    }
  }

  // --------------------------------------------------
  // DISCONNECT MQTT
  // --------------------------------------------------

  Future<void> _disconnectFromBroker() async {
    final client = _client;

    if (client == null) {
      _appendLog('⚠️ No MQTT connection');
      return;
    }

    await _updatesSubscription?.cancel();
    _updatesSubscription = null;

    _cancelPendingCommand();

    _client = null;
    client.disconnect();

    if (mounted) {
      setState(() {
        _brokerStatus = 'Disconnected';
        _brokerStatusColor = Colors.redAccent;
        _deviceStatus = 'Unknown';
        _deviceStatusColor = Colors.grey;
        _isDeviceOnline = false;
        _isConnecting = false;
      });
    }

    _appendLog('ℹ️ Disconnected from Broker');
  }

  // --------------------------------------------------
  // CLEAR LOGS
  // --------------------------------------------------

  void _clearLogs() {
    setState(() {
      _receivedLogs.clear();
    });
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _ackTimer?.cancel();
    _updatesSubscription?.cancel();
    _brokerIpController.dispose();
    _client?.disconnect();
    super.dispose();
  }

  // --------------------------------------------------
  // UI COMPONENTS
  // --------------------------------------------------

  Widget _buildStatusCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // MAIN UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canControl =
        _client?.connectionStatus?.state ==
                MqttConnectionState.connected &&
            _isDeviceOnline &&
            !_isWaitingAck;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lab 12.2: Actuator Control',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Broker IP
            TextField(
              controller: _brokerIpController,
              enabled: !_isConnecting &&
                  _client?.connectionStatus?.state !=
                      MqttConnectionState.connected,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Broker IPv4 Address',
                hintText: '127.0.0.1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),

            const SizedBox(height: 14),

            // Connection Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _brokerStatusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _brokerStatusColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: _brokerStatusColor,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Broker: $_brokerStatus',
                      style: TextStyle(
                        color: _brokerStatusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Device Status
            Row(
              children: [
                _buildStatusCard(
                  title: 'ESP32 Device',
                  value: _deviceStatus,
                  color: _deviceStatusColor,
                  icon: Icons.memory,
                ),
                const SizedBox(width: 10),
                _buildStatusCard(
                  title: 'LED Status',
                  value: _isLedOn ? 'ON' : 'OFF',
                  color: _isLedOn
                      ? const Color(0xFF00E676)
                      : Colors.white54,
                  icon: Icons.lightbulb,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Connect / Disconnect
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isConnecting ? null : _connectToBroker,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectFromBroker,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // LED Control Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isLedOn
                      ? const Color(0xFF00E676)
                      : Colors.white12,
                  width: 1.5,
                ),
                boxShadow: _isLedOn
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E676)
                              .withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lightbulb,
                    size: 65,
                    color: _isLedOn
                        ? const Color(0xFF00E676)
                        : Colors.white30,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'ESP32 LED CONTROL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _isLedOn ? 'LED IS ON' : 'LED IS OFF',
                    style: TextStyle(
                      color: _isLedOn
                          ? const Color(0xFF00E676)
                          : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Switch(
                    value: _isLedOn,
                    onChanged: canControl
                        ? _toggleLed
                        : null,
                    activeThumbColor:
                        const Color(0xFF00E676),
                    activeTrackColor:
                        const Color(0xFF00E676)
                            .withOpacity(0.35),
                  ),

                  const SizedBox(height: 8),

                  if (_isWaitingAck) ...[
                    const CircularProgressIndicator(
                      color: Color(0xFF00E5FF),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Waiting for ESP32 ACK...',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else if (!canControl) ...[
                    Text(
                      !_isDeviceOnline
                          ? 'Waiting for ESP32 Online...'
                          : 'Connect to MQTT Broker first',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Tap switch to control LED',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Transaction Logs Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Logs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_receivedLogs.length} messages',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Logs Display
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: _receivedLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs yet.\nConnect to MQTT Broker to start.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _receivedLogs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(
                          color: Colors.white12,
                          height: 12,
                        ),
                        itemBuilder: (context, index) {
                          return Text(
                            _receivedLogs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
