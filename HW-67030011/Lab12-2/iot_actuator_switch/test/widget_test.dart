import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iot_mqtt_basics/actuator_control_screen.dart';

void main() {
  testWidgets('switch is disabled while ESP32 is offline', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ActuatorControlScreen(brokerIp: '127.0.0.1')),
    );

    expect(find.text('ESP32 ฮาร์ดแวร์: ออฟไลน์ (OFFLINE)'), findsOneWidget);
    expect(find.text('สถานะ: ปิดการทำงาน (Standby)'), findsOneWidget);

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
    expect(sw.onChanged, isNull);
  });
}
