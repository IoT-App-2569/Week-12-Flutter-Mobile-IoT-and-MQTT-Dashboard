import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iot_unified_dashboard/radial_gauge_widget.dart';

void main() {
  testWidgets('Radial gauge animates to the given voltage', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: RadialGaugeWidget(value: 1.65)))),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.65'), findsOneWidget);
    expect(find.text('VOLTS (V)'), findsOneWidget);
  });
}
