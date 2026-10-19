import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iot_mqtt_basics/main.dart';

void main() {
  testWidgets('MQTT basics screen renders in disconnected state', (WidgetTester tester) async {
    await tester.pumpWidget(const MqttBasicsApp());

    expect(find.text('Lab 12.1: MQTT Client Basics'), findsOneWidget);
    expect(find.text('ยังไม่ได้เชื่อมต่อ (Disconnected)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Broker IPv4 Address'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Publish Test Message (Ping)'), findsOneWidget);
  });
}
