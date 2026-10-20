import 'package:flutter_test/flutter_test.dart';

import 'package:iot_mqtt_basics/main.dart';

void main() {
  testWidgets('shows broker field, disconnected status and blocks publish before connect',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MqttBasicsApp());

    expect(find.text('Lab 12.1: MQTT Client Basics'), findsOneWidget);
    expect(find.text('127.0.0.1'), findsOneWidget);
    expect(find.text('ยังไม่ได้เชื่อมต่อ (Disconnected)'), findsOneWidget);

    await tester.tap(find.text('Publish Test Message (Ping)'));
    await tester.pump();

    expect(find.textContaining('ไม่สามารถส่งข้อความได้เนื่องจากยังไม่ได้เชื่อมต่อ'), findsOneWidget);
  });
}
