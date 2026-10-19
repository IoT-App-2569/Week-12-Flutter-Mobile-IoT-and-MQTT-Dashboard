import 'package:flutter/material.dart';
import 'actuator_control_screen.dart';

const brokerIp = String.fromEnvironment(
  'MQTT_BROKER_IP',
  defaultValue: '127.0.0.1',
);

void main() {
  runApp(const ActuatorApp());
}

class ActuatorApp extends StatelessWidget {
  const ActuatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab 12.2 Actuator Switch',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      // เปลี่ยนค่าได้ด้วย --dart-define=MQTT_BROKER_IP=<broker-host>
      home: const ActuatorControlScreen(brokerIp: brokerIp),
      debugShowCheckedModeBanner: false,
    );
  }
}
