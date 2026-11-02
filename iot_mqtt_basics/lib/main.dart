
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const MqttBasicsScreen(),
    );
  }
}

class MqttBasicsScreen extends StatefulWidget {
  const MqttBasicsScreen({super.key});

  @override
  State<MqttBasicsScreen> createState() =>
      _MqttBasicsScreenState();
}

class _MqttBasicsScreenState extends State<MqttBasicsScreen> {
  final TextEditingController _brokerIpController =
      TextEditingController(text: '127.0.0.1');

  MqttServerClient? _client;

  String _statusText = 'ยังไม่ได้เชื่อมต่อ (Disconnected)';
  Color _statusColor = Colors.redAccent;

  final List<String> _receivedLogs = [];

  bool _isConnecting = false;

  @override
  void dispose() {
    _brokerIpController.dispose();
    _client?.disconnect();
    super.dispose();
  }

  // เพิ่มข้อความลงใน Transaction Logs
  void _appendLog(String log) {
    if (!mounted) return;

    setState(() {
      final time = DateTime.now()
          .toLocal()
          .toString()
          .substring(11, 19);

      _receivedLogs.insert(0, '[$time] $log');

      if (_receivedLogs.length > 50) {
        _receivedLogs.removeLast();
      }
    });
  }

  // เชื่อมต่อ MQTT Broker
  Future<void> _connectToBroker() async {
    if (_isConnecting) return;

    final broker = _brokerIpController.text.trim();

    if (broker.isEmpty) {
      _appendLog('⚠️ กรุณากรอก Broker IP Address');
      return;
    }

    if (_client?.connectionStatus?.state ==
        MqttConnectionState.connected) {
      _appendLog('⚠️ เชื่อมต่อ Broker อยู่แล้ว');
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusText = 'กำลังเชื่อมต่อไปยัง Broker...';
      _statusColor = Colors.amber;
    });

    final clientId =
        'Flutter_Lab12_1_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient(broker, clientId);

    _client = client;

    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.autoReconnect = false;

    client.onConnected = () {
      if (!mounted) return;

      setState(() {
        _statusText = 'เชื่อมต่อสำเร็จ (Connected)';
        _statusColor = const Color(0xFF00E676);
        _isConnecting = false;
      });

      _appendLog('✅ Connected to Broker: $broker:1883');

      _subscribeToTestTopic();
    };

    client.onDisconnected = () {
      if (!mounted) return;

      setState(() {
        _statusText = 'การเชื่อมต่อหลุด (Disconnected)';
        _statusColor = Colors.redAccent;
        _isConnecting = false;
      });

      _appendLog('❌ Broker Disconnected');
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
            _statusText = 'เชื่อมต่อไม่สำเร็จ';
            _statusColor = Colors.redAccent;
            _isConnecting = false;
          });
        }
      }
    } on SocketException catch (e) {
      _appendLog('❌ Socket Error: $e');

      client.disconnect();

      if (mounted) {
        setState(() {
          _statusText = 'ไม่สามารถเชื่อมต่อ Broker ได้';
          _statusColor = Colors.redAccent;
          _isConnecting = false;
        });
      }
    } catch (e) {
      _appendLog('❌ Error: $e');

      client.disconnect();

      if (mounted) {
        setState(() {
          _statusText = 'เกิดข้อผิดพลาดในการเชื่อมต่อ';
          _statusColor = Colors.redAccent;
          _isConnecting = false;
        });
      }
    }
  }

  // Subscribe หัวข้อสำหรับรับข้อความจาก Mosquitto CLI
  void _subscribeToTestTopic() {
    const topic = 'test/broker/echo';

    if (_client?.connectionStatus?.state !=
        MqttConnectionState.connected) {
      return;
    }

    _client!.subscribe(topic, MqttQos.atMostOnce);

    _appendLog('📢 Subscribed to: $topic');

    _client!.updates?.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final receivedMessage =
              message.payload as MqttPublishMessage;

          final payload =
              MqttPublishPayload.bytesToStringAsString(
            receivedMessage.payload.message,
          );

          _appendLog('📩 [${message.topic}] -> $payload');
        }
      },
    );
  }

  // Publish ข้อความไปยัง Broker
  void _publishTestMessage() {
    if (_client?.connectionStatus?.state !=
        MqttConnectionState.connected) {
      _appendLog('⚠️ กรุณาเชื่อมต่อ Broker ก่อนส่งข้อความ');
      return;
    }

    const topic = 'test/flutter/ping';

    final builder = MqttClientPayloadBuilder();

    builder.addString(
      'Hello from Flutter at ${DateTime.now().toIso8601String()}',
    );

    final payload = builder.payload;

    if (payload == null) {
      _appendLog('❌ ไม่สามารถสร้างข้อความได้');
      return;
    }

    _client!.publishMessage(
      topic,
      MqttQos.atMostOnce,
      payload,
    );

    _appendLog('🚀 Published -> $topic');
  }

  // ตัดการเชื่อมต่อ
  void _disconnectFromBroker() {
    if (_client == null) {
      _appendLog('⚠️ ยังไม่มีการเชื่อมต่อ');
      return;
    }

    _client!.disconnect();
    _client = null;

    if (mounted) {
      setState(() {
        _statusText = 'ตัดการเชื่อมต่อแล้ว (Disconnected)';
        _statusColor = Colors.redAccent;
        _isConnecting = false;
      });
    }

    _appendLog('ℹ️ Disconnected from Broker');
  }

  // ล้างประวัติ Logs
  void _clearLogs() {
    setState(() {
      _receivedLogs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lab 12.1: MQTT Client Basics',
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
            // Broker IP Address
            TextField(
              controller: _brokerIpController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Broker IPv4 Address',
                hintText: '127.0.0.1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: _statusColor,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Connect / Disconnect Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting
                        ? null
                        : _connectToBroker,
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

            const SizedBox(height: 10),

            // Publish Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publishTestMessage,
                icon: const Icon(Icons.send),
                label: const Text(
                  'Publish Test Message (Ping)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

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
                  border: Border.all(color: Colors.white12),
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
