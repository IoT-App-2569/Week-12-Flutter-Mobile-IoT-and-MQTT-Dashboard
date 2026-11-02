
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'radial_gauge_widget.dart';
import 'telemetry_data.dart';

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
  static const String _telemetryTopic =
      'iot/esp32/telemetry';

  MqttServerClient? _client;

  StreamSubscription<
      List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  bool _isConnected = false;
  bool _isDisposed = false;
  bool _isConnecting = false;

  String _connectionText = 'Disconnected';

  double _currentVoltage = 0.0;
  double _maxVoltage = 0.0;
  double _minVoltage = 0.0;

  int _currentRaw = 0;
  int _currentUptime = 0;

  bool _hasData = false;

  int _totalSamples = 0;
  int _invalidSamples = 0;

  final List<double> _history = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  // ------------------------------------------
  // MQTT CONNECTION
  // ------------------------------------------

  Future<void> _connect() async {
    if (_isConnecting || _isDisposed) return;

    _isConnecting = true;

    if (mounted) {
      setState(() {
        _connectionText = 'Connecting...';
      });
    }

    final clientId =
        'Flutter_Telemetry_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient(
      widget.brokerIp,
      clientId,
    );

    _client = client;

    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.autoReconnect = false;
    client.logging(on: false);

    client.onConnected = () {
      if (_isDisposed || !mounted) return;

      setState(() {
        _isConnected = true;
        _connectionText = 'Connected';
      });

      _subscribeToTelemetry();
    };

    client.onDisconnected = () {
      if (_isDisposed || !mounted) return;

      setState(() {
        _isConnected = false;
        _connectionText = 'Disconnected';
      });
    };

    try {
      final result = await client.connect();

      if (_isDisposed) return;

      if (result?.state != MqttConnectionState.connected) {
        _appendDebug('MQTT connection failed');

        client.disconnect();

        if (mounted) {
          setState(() {
            _isConnected = false;
            _connectionText = 'Connection Failed';
          });
        }
      }
    } catch (e) {
      _appendDebug('MQTT Error: $e');

      client.disconnect();

      if (mounted && !_isDisposed) {
        setState(() {
          _isConnected = false;
          _connectionText = 'Connection Error';
        });
      }
    } finally {
      _isConnecting = false;
    }
  }

  // ------------------------------------------
  // SUBSCRIBE TOPIC
  // ------------------------------------------

  void _subscribeToTelemetry() {
    final client = _client;

    if (client == null ||
        client.connectionStatus?.state !=
            MqttConnectionState.connected) {
      return;
    }

    client.subscribe(
      _telemetryTopic,
      MqttQos.atMostOnce,
    );

    _subscription?.cancel();

    _subscription = client.updates?.listen(
      _handleIncomingMessages,
      onError: (error) {
        _appendDebug('MQTT Stream Error: $error');
      },
    );

    _appendDebug('Subscribed: $_telemetryTopic');
  }

  // ------------------------------------------
  // RECEIVE TELEMETRY
  // ------------------------------------------

  void _handleIncomingMessages(
    List<MqttReceivedMessage<MqttMessage>> messages,
  ) {
    if (_isDisposed || !mounted) return;

    for (final message in messages) {
      if (message.topic != _telemetryTopic) continue;

      try {
        final received =
            message.payload as MqttPublishMessage;

        final payload =
            MqttPublishPayload.bytesToStringAsString(
          received.payload.message,
        );

        final decoded = jsonDecode(payload);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Invalid JSON object',
          );
        }

        final data = TelemetryData.fromJson(decoded);

        _updateTelemetry(data);
      } catch (e) {
        if (!_isDisposed && mounted) {
          setState(() {
            _invalidSamples++;
          });
        }

        _appendDebug('Telemetry Parsing Error: $e');
      }
    }
  }

  // ------------------------------------------
  // UPDATE TELEMETRY DATA
  // ------------------------------------------

  void _updateTelemetry(TelemetryData data) {
    if (_isDisposed || !mounted) return;

    setState(() {
      _currentVoltage = data.voltage;
      _currentRaw = data.raw;
      _currentUptime = data.uptime;

      if (!_hasData) {
        _maxVoltage = data.voltage;
        _minVoltage = data.voltage;
        _hasData = true;
      } else {
        _maxVoltage = math.max(
          _maxVoltage,
          data.voltage,
        );

        _minVoltage = math.min(
          _minVoltage,
          data.voltage,
        );
      }

      _history.add(data.voltage);

      if (_history.length > 30) {
        _history.removeAt(0);
      }

      _totalSamples++;
    });
  }

  // ------------------------------------------
  // DEBUG LOG
  // ------------------------------------------

  void _appendDebug(String message) {
    debugPrint('[Telemetry] $message');
  }

  // ------------------------------------------
  // DISCONNECT
  // ------------------------------------------

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    _client?.disconnect();
    _client = null;

    if (mounted) {
      setState(() {
        _isConnected = false;
        _connectionText = 'Disconnected';
      });
    }
  }

  // ------------------------------------------
  // METRIC CARD
  // ------------------------------------------

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),

            const SizedBox(height: 8),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),

            const SizedBox(height: 6),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // LIVE TREND CHART
  // ------------------------------------------

  Widget _buildTrendChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.show_chart,
                color: Color(0xFF00E5FF),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Trend',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Voltage history - Last 30 samples',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                history: List<double>.from(_history),
                maxLimit: 3.3,
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0.0 V',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              Text(
                '3.3 V',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // MAIN UI
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        title: const Text(
          'Telemetry Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            onPressed: _isConnected
                ? _disconnect
                : _connect,
            tooltip: _isConnected
                ? 'Disconnect'
                : 'Reconnect',
            icon: Icon(
              _isConnected
                  ? Icons.link_off
                  : Icons.refresh,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Connection Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: (_isConnected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent)
                    .withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConnected
                      ? const Color(0xFF00E676)
                      : Colors.redAccent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: _isConnected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'MQTT: $_connectionText',
                      style: TextStyle(
                        color: _isConnected
                            ? const Color(0xFF00E676)
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Text(
                    '${_history.length}/30 Samples',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Gauge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'ANALOG VOLTAGE SENSOR',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  RadialGaugeWidget(
                    value: _currentVoltage,
                    maxLimit: 3.3,
                  ),

                  Text(
                    _hasData
                        ? 'LIVE SENSOR DATA'
                        : 'WAITING FOR SENSOR DATA...',
                    style: TextStyle(
                      color: _hasData
                          ? const Color(0xFF00E676)
                          : Colors.amber,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Statistics Header
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SENSOR STATISTICS',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Statistics Row 1
            Row(
              children: [
                _buildMetricCard(
                  title: 'Raw ADC',
                  value: _hasData
                      ? '$_currentRaw / 4095'
                      : '-- / 4095',
                  color: const Color(0xFF00E5FF),
                  icon: Icons.memory,
                ),

                const SizedBox(width: 10),

                _buildMetricCard(
                  title: 'Maximum',
                  value: _hasData
                      ? '${_maxVoltage.toStringAsFixed(2)} V'
                      : '-- V',
                  color: const Color(0xFFFF5252),
                  icon: Icons.trending_up,
                ),

                const SizedBox(width: 10),

                _buildMetricCard(
                  title: 'Minimum',
                  value: _hasData
                      ? '${_minVoltage.toStringAsFixed(2)} V'
                      : '-- V',
                  color: const Color(0xFF00E676),
                  icon: Icons.trending_down,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Trend Chart
            _buildTrendChart(),

            const SizedBox(height: 18),

            // System Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'ESP32 Uptime',
                    _hasData
                        ? '${_currentUptime}s'
                        : '--',
                    Icons.timer,
                  ),

                  const Divider(
                    color: Colors.white12,
                    height: 24,
                  ),

                  _buildInfoRow(
                    'Total Samples',
                    '$_totalSamples',
                    Icons.data_usage,
                  ),

                  const Divider(
                    color: Colors.white12,
                    height: 24,
                  ),

                  _buildInfoRow(
                    'Invalid Packets',
                    '$_invalidSamples',
                    Icons.warning_amber,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'MQTT Topic: $_telemetryTopic',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF00E5FF),
          size: 18,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------
  // DISPOSE
  // ------------------------------------------

  @override
  void dispose() {
    _isDisposed = true;

    _subscription?.cancel();
    _client?.disconnect();

    super.dispose();
  }
}

// ==========================================
// SPARKLINE PAINTER
// ==========================================

class _SparklinePainter extends CustomPainter {
  final List<double> history;
  final double maxLimit;

  _SparklinePainter({
    required this.history,
    required this.maxLimit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty || size.isEmpty) return;

    // Horizontal Grid
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (history.length < 2) return;

    final safeMax = maxLimit > 0 ? maxLimit : 3.3;

    final path = Path();

    final dx = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final ratio = (history[i] / safeMax)
          .clamp(0.0, 1.0);

      final x = i * dx;
      final y = size.height - ratio * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient Line
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00E5FF),
          Color(0xFF00E676),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      )
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Last Point
    final lastValue = history.last;
    final lastRatio = (lastValue / safeMax)
        .clamp(0.0, 1.0);

    final lastPoint = Offset(
      size.width,
      size.height - lastRatio * size.height,
    );

    final pointPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      lastPoint,
      4,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _SparklinePainter oldDelegate,
  ) {
    return true;
  }
}
