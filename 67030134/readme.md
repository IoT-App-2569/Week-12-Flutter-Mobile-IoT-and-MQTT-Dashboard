# ปฏิบัติการสัปดาห์ที่ 12
**หัวข้อ:** Cross-Platform Mobile IoT Application Development with Flutter & MQTT Dashboard  
**รหัสนักศึกษา:** 67030134  
**สาขาวิชา:** วิศวกรรมระบบไอโอทีและสารสนเทศ (IoT System and Information Engineering)

---

## สรุปรายการผลการทดลองและรายงาน (Laboratory Reports)

* **Lab 12.1 Flutter Environment Setup & MQTT Client Basics**
  * รายงานฉบับสมบูรณ์: [report12-1.md](report12-1.md)
  * โค้ดโปรเจกต์ Flutter: [../codes-project/iot_mqtt_basics/](../codes-project/iot_mqtt_basics/)
  * สาระสำคัญ: การติดตั้งสภาพแวดล้อม Flutter, การเชื่อมต่อ Mosquitto Broker พอร์ต 1883, การส่ง Ping และรับ Echo ผ่าน CLI

* **Lab 12.2 Interactive Actuator Control Switch & Status Feedback**
  * รายงานฉบับสมบูรณ์: [report12-2.md](report12-2.md)
  * โค้ดโปรเจกต์ Flutter: [../codes-project/iot_actuator_switch/](../codes-project/iot_actuator_switch/)
  * สาระสำคัญ: สวิตช์ควบคุมอุปกรณ์สองทาง (Bi-directional Control), การรอรับ ACK ก่อนปรับสถานะ, การใช้กลไก Retain Flag และ LWT ตรวจจับสถานะออนไลน์/ออฟไลน์

* **Lab 12.3 Real-time Telemetry Dashboard & Custom Radial Gauge**
  * รายงานฉบับสมบูรณ์: [report12-3.md](report12-3.md)
  * โค้ดโปรเจกต์ Flutter: [../codes-project/iot_telemetry_gauge/](../codes-project/iot_telemetry_gauge/)
  * สาระสำคัญ: การสร้างหน้าปัดวัดแรงดันแบบแอนิเมชันด้วย `CustomPainter` และ `TweenAnimationBuilder`, กราฟประวัติ Live Trend Sparkline แบบ Rolling Buffer 30 จุด

* **Lab 12.4 End-to-End IoT Ecosystem Integration**
  * รายงานฉบับสมบูรณ์: [report12-4.md](report12-4.md)
  * โค้ดโปรเจกต์ Flutter: [../codes-project/iot_unified_dashboard/](../codes-project/iot_unified_dashboard/)
  * สาระสำคัญ: การผสานรวมแดชบอร์ดครบวงจรผ่าน `IndexedStack` และ BottomNavigationBar, การทดสอบ 4 Critical Verification Test Cases, การวัด Latency Benchmark (RTT)

---

## โครงสร้างโฟลเดอร์ส่งงาน

```text
Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/
├── 67030134/
│   ├── report12-1.md       # รายงานผลแล็บ 12.1 + คำตอบท้ายการทดลอง 3 ข้อ
│   ├── report12-2.md       # รายงานผลแล็บ 12.2 + คำตอบท้ายการทดลอง 2 ข้อ
│   ├── report12-3.md       # รายงานผลแล็บ 12.3 + คำตอบท้ายการทดลอง 3 ข้อ
│   ├── report12-4.md       # รายงานผลแล็บ 12.4 + ตาราง 4 Test Cases + คำตอบท้ายการทดลอง 3 ข้อ
│   └── readme.md           # สรุปภาพรวมและดัชนีนำทางของรหัส 67030134
└── codes-project/
    ├── iot_mqtt_basics/        # โปรเจกต์ Flutter แล็บ 12.1
    ├── iot_actuator_switch/    # โปรเจกต์ Flutter แล็บ 12.2
    ├── iot_telemetry_gauge/    # โปรเจกต์ Flutter แล็บ 12.3
    └── iot_unified_dashboard/  # โปรเจกต์ Flutter รวมแล็บ 12.4
```
