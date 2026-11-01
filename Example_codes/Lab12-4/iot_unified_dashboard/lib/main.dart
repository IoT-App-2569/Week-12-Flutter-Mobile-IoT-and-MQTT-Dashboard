import 'package:flutter/material.dart';
import 'actuator_control_screen.dart';
import 'telemetry_dashboard_screen.dart';

void main() {
  runApp(const UnifiedIotApp());
}

class UnifiedIotApp extends StatelessWidget {
  const UnifiedIotApp({super.key, this.connectToMqtt = true});

  final bool connectToMqtt;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Smart IoT Commander',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: MainNavigationShell(connectToMqtt: connectToMqtt),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, this.connectToMqtt = true});

  final bool connectToMqtt;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // Android Emulator uses this address to reach the broker on the host computer.
  // Use the computer's LAN IP when running on a physical phone or ESP32.
  final String brokerIp = '10.0.2.2';

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TelemetryDashboardScreen(
        brokerIp: brokerIp,
        connectToMqtt: widget.connectToMqtt,
      ),
      ActuatorControlScreen(
        brokerIp: brokerIp,
        connectToMqtt: widget.connectToMqtt,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ใช้ IndexedStack เพื่อรักษาสถานะ (State) และการเชื่อมต่อ MQTT ของทั้งสองหน้าจอให้ทำงานต่อเนื่อง
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed),
            selectedIcon: Icon(Icons.speed, color: Color(0xFF00E5FF)),
            label: 'Telemetry Gauge',
          ),
          NavigationDestination(
            icon: Icon(Icons.toggle_on_outlined),
            selectedIcon: Icon(Icons.toggle_on, color: Color(0xFF00E676)),
            label: 'Actuator Switch',
          ),
        ],
      ),
    );
  }
}
