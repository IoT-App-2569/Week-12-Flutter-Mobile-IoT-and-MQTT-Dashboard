import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_factory.dart';
import 'radial_gauge_widget.dart';

class TelemetryDashboardScreen extends StatefulWidget {
  final String brokerIp;
  const TelemetryDashboardScreen({super.key, required this.brokerIp});

  @override
  State<TelemetryDashboardScreen> createState() => _TelemetryDashboardScreenState();
}

class _TelemetryDashboardScreenState extends State<TelemetryDashboardScreen> {
  MqttClient? _client;
  double _currentVoltage = 0.0;
  int _currentRaw = 0;
  int _currentUptime = 0;
  double _maxVoltage = 0.0;
  double _minVoltage = 3.3;
  int _packetCount = 0;

  final List<double> _history = [];
  bool _isConnected = false;
  bool _isListening = false;
  bool _isSimulating = false;
  Timer? _simTimer;
  int _simTick = 0;

  @override
  void initState() {
    super.initState();
    _connect();
    // Auto-start simulation after 2 seconds if no packets received yet
    Timer(const Duration(seconds: 2), () {
      if (mounted && _packetCount == 0) {
        _startSimulation();
      }
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _client?.disconnect();
    super.dispose();
  }

  void _startSimulation() {
    if (_isSimulating) return;
    setState(() => _isSimulating = true);
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      _simTick++;
      final v = double.parse((1.65 + 1.5 * math.sin(_simTick * 0.2)).toStringAsFixed(2));
      final raw = ((v / 3.3) * 4095).round();
      final payload = jsonEncode({'voltage': v, 'raw': raw, 'uptime': _simTick});

      // Also publish to MQTT broker if connected
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(payload);
        _client?.publishMessage('iot/esp32/telemetry', MqttQos.atMostOnce, builder.payload!);
      }

      setState(() {
        _packetCount++;
        _currentVoltage = v;
        _currentRaw = raw;
        _currentUptime = _simTick;
        _maxVoltage = math.max(_maxVoltage, v);
        _minVoltage = _minVoltage == 3.3 ? v : math.min(_minVoltage, v);
        _history.add(v);
        if (_history.length > 30) _history.removeAt(0);
      });
    });
  }

  Future<void> _connect() async {
    final clientId = 'Flutter_Telemetry_${DateTime.now().millisecondsSinceEpoch}';
    _client = getMqttClient(widget.brokerIp, clientId);
    _client!.keepAlivePeriod = 60;

    _client!.onConnected = () {
      setState(() => _isConnected = true);
      _client!.subscribe('iot/esp32/telemetry', MqttQos.atMostOnce);
      if (!_isListening) {
        _isListening = true;
        _client!.updates?.listen(_handleIncomingMessage);
      }
    };

    _client!.onDisconnected = () {
      setState(() => _isConnected = false);
    };

    try {
      await _client!.connect();
    } catch (_) {}
  }

  void _handleIncomingMessage(List<MqttReceivedMessage<MqttMessage>> c) {
    if (c.isEmpty) return;
    final recMess = c[0].payload as MqttPublishMessage;
    final rawString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final payload = rawString.replaceAll('\u0000', '').trim();

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final v = double.tryParse(data['voltage']?.toString() ?? '0') ?? 0.0;
      final raw = int.tryParse(data['raw']?.toString() ?? '0') ?? 0;
      final up = int.tryParse(data['uptime']?.toString() ?? '0') ?? 0;

      // When external packets arrive, stop internal timer
      if (_isSimulating && _simTimer != null) {
        _simTimer?.cancel();
        _isSimulating = false;
      }

      setState(() {
        _packetCount++;
        _currentVoltage = v;
        _currentRaw = raw;
        _currentUptime = up;
        _maxVoltage = math.max(_maxVoltage, v);
        _minVoltage = _minVoltage == 3.3 ? v : math.min(_minVoltage, v);

        _history.add(v);
        if (_history.length > 30) _history.removeAt(0);
      });
    } catch (e) {
      debugPrint('Parsing error: $e for payload: $payload');
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
          TextButton.icon(
            onPressed: () {
              if (_isSimulating) {
                _simTimer?.cancel();
                setState(() => _isSimulating = false);
              } else {
                _startSimulation();
              }
            },
            icon: Icon(
              _isSimulating ? Icons.sensors : Icons.sensors_off,
              size: 18,
              color: const Color(0xFF00E5FF),
            ),
            label: Text(
              _isSimulating ? 'จำลอง: กำลังส่ง' : 'เริ่มจำลอง',
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
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
                _buildMetricCard('แรงดันต่ำสุด', '${_minVoltage.toStringAsFixed(2)} V', const Color(0xFF00E676)),
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
              'ESP32 Uptime: ${_currentUptime}s  |  ข้อมูลที่ได้รับ: $_packetCount แพ็กเก็ต',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
    final stepX = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final normalizedY = (history[i] / maxLimit).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = const Color(0xFF00E676);
    final lastX = size.width;
    final lastNormalizedY = (history.last / maxLimit).clamp(0.0, 1.0);
    final lastY = size.height - (lastNormalizedY * size.height);
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
