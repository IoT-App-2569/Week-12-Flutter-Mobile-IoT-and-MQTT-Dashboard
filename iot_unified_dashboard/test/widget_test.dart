
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:iot_unified_dashboard/main.dart';

void main() {
  testWidgets('Unified IoT App builds',
      (WidgetTester tester) async {
    await tester.pumpWidget(const UnifiedIotApp());

    expect(find.byType(UnifiedIotApp), findsOneWidget);

    // ถอดหน้าจอออกจาก Widget Test
    // เพื่อให้ Flutter เริ่ม dispose หน้าจอ
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Test complete'),
        ),
      ),
    );

    expect(find.text('Test complete'), findsOneWidget);
  });
}
