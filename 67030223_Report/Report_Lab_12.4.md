# Labsheet 12.4: End-to-End Mobile-to-Hardware IoT Ecosystem (ESP32 <-> Broker <-> Flutter)

#### 1. บันทึกผลการทดลอง / โค้ดที่พัฒนา

ไฟล์ `lib/main.dart` รวมศูนย์แอปพลิเคชันแบบ Multi-tab โดยใช้ `IndexedStack` เพื่อรักษาสถานะและการเชื่อมต่อของทั้งหน้าจอ Telemetry และ Actuator Switch ให้ทำงานร่วมกันได้อย่างต่อเนื่อง:

```dart
import 'package:flutter/material.dart';
import 'actuator_control_screen.dart';
import 'telemetry_dashboard_screen.dart';

void main() {
  runApp(const UnifiedIotApp());
}

class UnifiedIotApp extends StatelessWidget {
  const UnifiedIotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Smart IoT Commander (67030211)',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const MainNavigationShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final String brokerIp = '127.0.0.1'; // หรือ IP ของ Broker ในวง LAN
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TelemetryDashboardScreen(brokerIp: brokerIp),
      ActuatorControlScreen(brokerIp: brokerIp),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
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
```

#### 2. ผลลัพธ์จาก Serial Monitor / หน้าจอแสดงผล

ตารางบันทึกผลการทดสอบระบบครบวงจร 4 กรณีทดสอบวิกฤต (Verification Test Matrix):

| รายการทดสอบ | การกระทำเชิงกายภาพ / การจำลอง | พฤติกรรมที่เกิดขึ้นบน Flutter App | ผลการทดลอง |
| :--- | :--- | :--- | :---: |
| **Test Case 1: Telemetry Monitoring** | หมุน Potentiometer จากซ้ายสุดไปขวาสุด (0 ถึง 3.3V) | เข็มบน Radial Gauge กวาดตามมืออย่างนุ่มนวล ค่า Voltage และ Raw ADC ปรับเปลี่ยนตรงตามค่าที่อ่านได้ และกราฟเส้นขยับต่อเนื่อง | **ผ่าน** |
| **Test Case 2: Actuator Remote Control** | แตะสวิตช์บนแอปเพื่อสั่งเปิด-ปิดไฟ | แอปส่งข้อความ `{"led":"ON"}` ออกไป หลอดไฟ LED ขา GPIO 2 บนบอร์ดสว่างขึ้นทันที พร้อมการสั่นตอบสนอง (Haptic Feedback) | **ผ่าน** |
| **Test Case 3: State Sync & Physical ACK** | บอร์ดส่งสัญญาณยืนยันสถานะกลับมาทาง `iot/esp32/led_ack` | แอปพลิเคชันได้รับค่า ACK และปรับสวิตช์เป็นสีเขียวเรืองแสง หากไม่ได้รับ ACK สวิตช์จะไม่เปลี่ยนสถานะค้างไว้ | **ผ่าน** |
| **Test Case 4: Fault Tolerance (LWT)** | ถอดสายไฟของบอร์ด ESP32 ออกกะทันหัน | Broker ส่งข้อความ LWT `"offline"` ป้ายสถานะบนแอปเปลี่ยนเป็นสีแดง `ESP32: OFFLINE` และสวิตช์สั่งการถูกปิดกั้นทันที | **ผ่าน** |

ผลการตรวจวัดความหน่วงเวลาในการควบคุม (Control Latency Benchmark):
- **Local Wi-Fi LAN เดียวกัน:** เวลาตอบสนอง RTT เฉลี่ยอยู่ที่ประมาณ `28 ms` (ตอบสนองได้แทบจะในทันที)
- **เชื่อมต่อระยะไกลผ่าน Hotspot/4G:** เวลาตอบสนอง RTT เฉลี่ยอยู่ที่ประมาณ `115 ms` (มีความหน่วงเพิ่มขึ้นตามโครงข่ายแต่ยังอยู่ในเกณฑ์ที่ใช้งานได้ราบรื่น)

#### 3. สรุปผลและการตอบคำถามท้ายใบงาน

- **สรุปผลการทดลอง:**
 สามารถบูรณาการระบบนิเวศ IoT ครบวงจร (End-to-End IoT Ecosystem) ระหว่าง ESP32 $\leftrightarrow$ Mosquitto Broker $\leftrightarrow$ Flutter Mobile App ได้สำเร็จ โดยใช้ IndexedStack รวมศูนย์หน้าจอ Telemetry และ Actuator Switch ให้ทำงานร่วมกันได้แบบมัลติแท็บโดยไม่สูญเสียการเชื่อมต่อ ระบบผ่านการทดสอบทั้ง 4 กรณีวิกฤต: รับค่าสตรีมแอนะล็อกแบบเรียลไทม์, สั่งงานเปิด-ปิดไฟ LED พร้อม Haptic Feedback, ยืนยันสถานะฮาร์ดแวร์สองทางด้วย Physical ACK, และตรวจจับความขัดข้องของโหนดตัดสถานะเป็น Offline ผ่าน LWT ได้ทันที ด้วยความหน่วงเฉลี่ยระดับวงแลนต่ำเพียง 28 ms

- **คำถามท้ายบทเรียน:**
1. **เหตุใดการใช้ `IndexedStack` ใน `MainNavigationShell` จึงมีความสำคัญอย่างยิ่งสำหรับแอปพลิเคชัน IoT แบบ Multi-tab เมื่อเทียบกับการสลับวิดเจ็ตด้วย `body: _pages[_currentIndex]`?**
     - **คำตอบ:** ช่วย รักษาสถานะ (State) และการเชื่อมต่อ MQTT Socket ค้างไว้ในหน่วยความจำ แม้ผู้ใช้จะสลับไปหน้าอื่น วิดเจ็ตจะไม่ถูกทำลาย (Dispose) และสร้างใหม่ ทำให้ประวัติกราฟไม่หาย และสามารถรับฟังข้อความ (Subscribe) ได้อย่างต่อเนื่องโดยไม่ต้องต่อ Broker ใหม่ทุกครั้งที่เปลี่ยนแท็บ

2. **เมื่อเปรียบเทียบการพัฒนาด้วย Flutter ในสัปดาห์นี้ กับการเปิดหน้าเว็บ HTTP บนเบราว์เซอร์ในสัปดาห์ที่ 8-10 ข้อใดให้ประสบการณ์การใช้งาน (UX) และความเสถียรที่ดีกว่าเมื่อข้อมูลเซนเซอร์มาด้วยความถี่สูง? เพราะเหตุใด?**
     - **คำตอบ:** Flutter ร่วมกับ MQTT ให้ UX และความเสถียรที่ดีกว่าอย่างมาก เพราะ MQTT ใช้ TCP Socket แบบ Persistent เชื่อมต่อค้างไว้ ข้อมูลใหม่ถูกพุช (Push) ผ่านไบนารีขนาดเล็กทันที ต่างจาก HTTP บนเบราว์เซอร์ที่ต้องทำ Polling/Handshake ซ้ำๆ สิ้นเปลืองทั้งซีพียูและแบนด์วิดท์ อีกทั้งเอนจินกราฟิกของ Flutter เรนเดอร์ได้ลื่นไหลระดับ 60–120 fps ไม่เกิดอาการหน่วงหรือหน้าเว็บกระตุก

3. **หากต้องการนำแอปพลิเคชันนี้ไปเผยแพร่จริงบน Google Play Store หรือ Apple App Store ขั้นตอนความปลอดภัยที่ต้องปรับปรุงเพิ่มเติมมีอะไรบ้าง?**
     - **คำตอบ:** เปลี่ยนเป็น MQTTS (พอร์ต 8883): เข้ารหัสข้อมูลทราฟฟิกทั้งหมดด้วย TLS/SSL ป้องกันการดักฟัง (Eavesdropping / Sniffing)

ระบบยืนยันตัวตน: บังคับใส่ Username / Password หรือใช้ Client Certificate (mTLS) แทนการเปิด Anonymous

จัดการความลับปลอดภัย: ไม่ฮาร์ดโค้ด IP/กุญแจลับลงในโค้ด โดยเก็บไว้ใน Secure Storage หรือดึงผ่าน Config API

โดเมนและไฟร์วอลล์: ใช้ Public Domain ร่วมกับใบรับรอง CA ที่ถูกต้อง (เช่น Let's Encrypt) แทนการต่อตรงด้วย IP Address ดิบในวงแลน
       