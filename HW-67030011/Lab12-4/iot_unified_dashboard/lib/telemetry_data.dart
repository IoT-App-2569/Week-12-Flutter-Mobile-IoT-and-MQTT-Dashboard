import 'dart:convert';

/// Data Model ของแพ็กเก็ต iot/esp32/telemetry: {"voltage": 2.50, "raw": 3102, "uptime": 10}
class TelemetryData {
  static const double maxVoltage = 3.3;
  static const int maxRaw = 4095;

  final double voltage;
  final int raw;
  final int uptime;

  const TelemetryData({required this.voltage, required this.raw, required this.uptime});

  /// คืนค่า null เมื่อ Payload ไม่ใช่ JSON Object, ไม่มี voltage, ชนิดข้อมูลผิด
  /// หรือค่าอยู่นอกช่วงที่ ADC 12-bit / 3.3 V วัดได้จริง (ไม่ให้ค่าผิดไปปนในสถิติและกราฟ)
  static TelemetryData? tryParse(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final v = decoded['voltage'];
    final r = decoded['raw'];
    final up = decoded['uptime'];
    if (v is! num || !v.isFinite) return null;
    if (r != null && r is! num) return null;
    if (up != null && up is! num) return null;

    final voltage = v.toDouble();
    final raw = (r as num?)?.toInt() ?? 0;
    if (voltage < 0 || voltage > maxVoltage) return null;
    if (raw < 0 || raw > maxRaw) return null;

    return TelemetryData(voltage: voltage, raw: raw, uptime: (up as num?)?.toInt() ?? 0);
  }
}
