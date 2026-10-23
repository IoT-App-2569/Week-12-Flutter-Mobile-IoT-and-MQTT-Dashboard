
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'radial_gauge_widget.dart';

class TelemetryDashboardScreen extends StatefulWidget {
  final String brokerIp;

  const TelemetryDashboardScreen({
    super.key,
    required this.brokerIp,
  });

  @override
  State<TelemetryDashboardScreen> createState() =>
      _TelemetryDashboardScreenState();
}

class _TelemetryDashboardScreenState
    extends State<TelemetryDashboardScreen> {
  MqttServerClient? _client;

  double _currentVoltage = 0.0;
  int _currentRaw = 0;
  int _currentUptime = 0;

  double _maxVoltage = 0.0;
  double _minVoltage = 3.3;

  final List<double> _history = [];

  bool _isConnected = false;
  String _connectionMessage = 'กำลังเชื่อมต่อ MQTT...';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    final client = _client;
    _client = null;

    if (client != null) {
      client.disconnect();
    }

    super.dispose();
  }

  Future<void> _connect() async {
    final clientId =
        'Flutter_Telemetry_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient(widget.brokerIp, clientId);
    _client = client;

    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 10000;
    client.logging(on: false);

    client.onConnected = () {
      debugPrint('MQTT CONNECTED: ${widget.brokerIp}:1883');

      if (!mounted || !identical(_client, client)) return;

      setState(() {
        _isConnected = true;
        _connectionMessage = 'MQTT CONNECTED';
      });

      client.subscribe(
        'iot/esp32/telemetry',
        MqttQos.atMostOnce,
      );

      client.updates?.listen(_handleIncomingMessage);
    };

    client.onDisconnected = () {
      debugPrint('MQTT DISCONNECTED');

      if (!mounted || !identical(_client, client)) return;

      setState(() {
        _isConnected = false;
        _connectionMessage = 'MQTT DISCONNECTED';
      });
    };

    client.onSubscribed = (topic) {
      debugPrint('MQTT SUBSCRIBED: $topic');
    };

    try {
      debugPrint(
        'กำลังเชื่อมต่อ Broker ${widget.brokerIp}:1883',
      );

      await client.connect();

      if (!mounted || !identical(_client, client)) {
        client.disconnect();
        return;
      }

      if (client.connectionStatus?.state !=
          MqttConnectionState.connected) {
        debugPrint(
          'MQTT connection failed: '
          '${client.connectionStatus}',
        );

        client.disconnect();

        setState(() {
          _isConnected = false;
          _connectionMessage = 'เชื่อมต่อ MQTT ไม่สำเร็จ';
        });
      }
    } catch (e) {
      debugPrint('MQTT connection error: $e');

      client.disconnect();

      if (mounted && identical(_client, client)) {
        setState(() {
          _isConnected = false;
          _connectionMessage = 'เชื่อมต่อ MQTT ไม่สำเร็จ';
        });
      }
    }
  }

  void _handleIncomingMessage(
    List<MqttReceivedMessage<MqttMessage>> messages,
  ) {
    if (!mounted || messages.isEmpty) return;

    try {
      for (final message in messages) {
        if (message.topic != 'iot/esp32/telemetry') continue;

        final recMess = message.payload as MqttPublishMessage;

        final payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        debugPrint('MQTT TELEMETRY: $payload');

        final decoded = jsonDecode(payload);

        if (decoded is! Map<String, dynamic>) {
          debugPrint('Invalid telemetry data: $payload');
          continue;
        }

        final voltage = (decoded['voltage'] as num?)?.toDouble();
        final raw = (decoded['raw'] as num?)?.toInt();
        final uptime = (decoded['uptime'] as num?)?.toInt();

        if (voltage == null || raw == null || uptime == null) {
          debugPrint('Telemetry fields missing: $payload');
          continue;
        }

        if (!mounted) return;

        setState(() {
          _currentVoltage = voltage;
          _currentRaw = raw;
          _currentUptime = uptime;

          _maxVoltage = math.max(_maxVoltage, voltage);
          _minVoltage = math.min(_minVoltage, voltage);

          _history.add(voltage);

          if (_history.length > 30) {
            _history.removeAt(0);
          }
        });
      }
    } catch (e) {
      debugPrint('Telemetry parsing error: $e');
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
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 14,
                  color: _isConnected
                      ? const Color(0xFF00E676)
                      : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isConnected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _connectionMessage,
              style: TextStyle(
                color: _isConnected
                    ? const Color(0xFF00E676)
                    : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: RadialGaugeWidget(
                value: _currentVoltage,
                maxLimit: 3.3,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                _buildMetricCard(
                  'ค่าดิบ ADC',
                  '$_currentRaw / 4095',
                  const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'แรงดันสูงสุด',
                  '${_maxVoltage.toStringAsFixed(2)} V',
                  const Color(0xFFFF5252),
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'แรงดันต่ำสุด',
                  '${_minVoltage == 3.3 ? 0.0 : _minVoltage.toStringAsFixed(2)} V',
                  const Color(0xFF00E676),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'แนวโน้มแรงดันย้อนหลัง 30 ตัวอย่าง (Live Trend)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        history: _history,
                        maxLimit: 3.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'ESP32 Uptime: ${_currentUptime}s',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String val,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              val,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> history;
  final double maxLimit;

  _SparklinePainter({
    required this.history,
    required this.maxLimit,
  });

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

      final y = size.height -
          ((history[i] / maxLimit).clamp(0.0, 1.0) *
              size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return true;
  }
}
