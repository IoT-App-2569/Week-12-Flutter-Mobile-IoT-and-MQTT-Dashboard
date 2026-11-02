
class TelemetryData {
  final double voltage;
  final int raw;
  final int uptime;

  const TelemetryData({
    required this.voltage,
    required this.raw,
    required this.uptime,
  });

  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    final voltageValue = json['voltage'];
    final rawValue = json['raw'];
    final uptimeValue = json['uptime'];

    if (voltageValue is! num ||
        rawValue is! num ||
        uptimeValue is! num) {
      throw const FormatException(
        'Invalid telemetry data type',
      );
    }

    final voltage = voltageValue.toDouble();
    final raw = rawValue.toInt();
    final uptime = uptimeValue.toInt();

    if (!voltage.isFinite ||
        voltage < 0 ||
        voltage > 3.3) {
      throw const FormatException(
        'Voltage must be between 0 and 3.3V',
      );
    }

    if (raw < 0 || raw > 4095 || uptime < 0) {
      throw const FormatException(
        'Invalid raw ADC or uptime value',
      );
    }

    return TelemetryData(
      voltage: voltage,
      raw: raw,
      uptime: uptime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voltage': voltage,
      'raw': raw,
      'uptime': uptime,
    };
  }
}
