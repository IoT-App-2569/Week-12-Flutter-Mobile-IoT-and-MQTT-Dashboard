import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActuatorControlScreen extends StatefulWidget {
  final String brokerIp;
  const ActuatorControlScreen({super.key, required this.brokerIp});

  @override
  State<ActuatorControlScreen> createState() => _ActuatorControlScreenState();
}

class _ActuatorControlScreenState extends State<ActuatorControlScreen> {
  bool _isLedOn = false;
  bool _isDeviceOnline = true; // จำลองสถานะ Online
  bool _isWaitingAck = false;
  String _networkStatus = 'เชื่อมต่อ Broker เรียบร้อย (Simulation Mode)';

  void _toggleLed(bool targetState) {
    if (!_isDeviceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ อุปกรณ์ ESP32 ออฟไลน์อยู่ ไม่สามารถส่งคำสั่งได้'),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isWaitingAck = true;
    });

    // จำลองการส่งคำสั่งและรอรับ ACK ตอบกลับจาก ESP32 (300 ms)
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isWaitingAck = false;
          _isLedOn = targetState;
        });
      }
    });
  }

  void _toggleDeviceOnlineStatus() {
    setState(() {
      _isDeviceOnline = !_isDeviceOnline;
      if (!_isDeviceOnline) {
        _isLedOn = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Actuator Control Center'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(
              _isDeviceOnline ? Icons.wifi : Icons.wifi_off,
              color: _isDeviceOnline ? const Color(0xFF00E676) : Colors.red,
            ),
            tooltip: 'จำลองสลับสถานะ LWT Online/Offline',
            onPressed: _toggleDeviceOnlineStatus,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // แถบแสดงสถานะ Device Online/Offline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDeviceOnline
                    ? const Color(0x1A00E676)
                    : const Color(0x1AFF5252),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDeviceOnline
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF5252),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: _isDeviceOnline
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFF5252),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isDeviceOnline
                        ? 'ESP32 ฮาร์ดแวร์: ออนไลน์ (ONLINE)'
                        : 'ESP32 ฮาร์ดแวร์: ออฟไลน์ (OFFLINE)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isDeviceOnline
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // การ์ดควบคุมหลอดไฟแบบ Glassmorphism
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isLedOn
                      ? const Color(0xFF00E676).withOpacity(0.6)
                      : Colors.white12,
                  width: 2,
                ),
                boxShadow: _isLedOn
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLedOn
                          ? const Color(0x3300E676)
                          : Colors.black26,
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      size: 72,
                      color: _isLedOn
                          ? const Color(0xFF00E676)
                          : Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'หลอดไฟ LED ทดสอบ (GPIO 2)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isWaitingAck
                        ? 'กำลังรอการยืนยันจากบอร์ด (Waiting ACK)...'
                        : _isLedOn
                        ? 'สถานะ: เปิดสว่าง (Active)'
                        : 'สถานะ: ปิดการทำงาน (Standby)',
                    style: TextStyle(
                      color: _isWaitingAck
                          ? Colors.amber
                          : (_isLedOn
                                ? const Color(0xFF00E676)
                                : Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Transform.scale(
                    scale: 1.4,
                    child: Switch(
                      value: _isLedOn,
                      activeColor: const Color(0xFF00E676),
                      onChanged: _isWaitingAck ? null : _toggleLed,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              _networkStatus,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
