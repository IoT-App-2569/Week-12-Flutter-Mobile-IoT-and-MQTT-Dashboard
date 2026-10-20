import 'package:flutter_test/flutter_test.dart';

import 'package:iot_mqtt_basics/telemetry_data.dart';

void main() {
  group('TelemetryData.tryParse', () {
    test('parses a valid packet', () {
      final d = TelemetryData.tryParse('{"voltage": 1.65, "raw": 2048, "uptime": 10}');
      expect(d, isNotNull);
      expect(d!.voltage, 1.65);
      expect(d.raw, 2048);
      expect(d.uptime, 10);
    });

    test('accepts integer voltage and missing optional fields', () {
      final d = TelemetryData.tryParse('{"voltage": 3}');
      expect(d!.voltage, 3.0);
      expect(d.raw, 0);
      expect(d.uptime, 0);
    });

    for (final bad in [
      '{"voltage": null, "raw": null, "uptime": 31}',
      '{"voltage": 5.0, "raw": 6200, "uptime": 32}',
      '{"voltage": -1.2, "raw": -10, "uptime": 33}',
      'hello',
      '{"voltage": "2.5", "raw": 3102, "uptime": 34}',
      '[1, 2, 3]',
      '{"raw": 100}',
    ]) {
      test('rejects $bad', () => expect(TelemetryData.tryParse(bad), isNull));
    }
  });
}
