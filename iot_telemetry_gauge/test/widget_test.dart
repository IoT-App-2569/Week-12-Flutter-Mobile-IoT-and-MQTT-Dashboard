
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_telemetry_gauge/main.dart';

void main() {
  testWidgets('Telemetry Dashboard displays correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TelemetryApp());

    expect(find.text('Real-time Telemetry Dashboard'), findsOneWidget);
    expect(find.text('VOLTS (V)'), findsOneWidget);
    expect(find.textContaining('ESP32 Uptime:'), findsOneWidget);
  });
}
