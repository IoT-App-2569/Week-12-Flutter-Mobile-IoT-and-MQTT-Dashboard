import 'package:flutter_test/flutter_test.dart';
import 'package:iot_mqtt_basics/main.dart';

void main() {
  testWidgets('Actuator app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ActuatorApp());
    expect(find.text('Actuator Control Center'), findsOneWidget);
    expect(find.textContaining('OFFLINE'), findsOneWidget);
  });
}
