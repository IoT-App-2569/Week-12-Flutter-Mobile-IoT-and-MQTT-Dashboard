# Week 12: Cross-Platform Mobile IoT Application with Flutter & MQTT Dashboard

## 1. บทนำ (Introduction)

ในสัปดาห์ที่ 11 ที่ผ่านมา เราได้วางรากฐานการสื่อสารผ่านระบบคลาวด์ (**Cloud Communication & Control**) ด้วยโปรโตคอล MQTT และสำรวจระบบนิเวศ ESP RainMaker ซึ่งช่วยให้อุปกรณ์ ESP32 สามารถส่งข้อมูลและรับคำสั่งข้ามเครือข่ายอินเทอร์เน็ตได้ อย่างไรก็ตาม ในการพัฒนาผลิตภัณฑ์เชิงพาณิชย์หรือระบบ IoT ระดับอุตสาหกรรม การมี **โมบายล์แอปพลิเคชันเฉพาะทาง (Dedicated Mobile Application)** ที่ออกแบบส่วนติดต่อประสานกับผู้ใช้ (UI/UX) ได้อย่างอิสระ สวยงาม รวดเร็ว และทำงานได้ข้ามแพลตฟอร์มทั้ง Android และ iOS คือหัวใจสำคัญในการส่งมอบประสบการณ์ที่ดีที่สุดแก่ผู้ใช้งาน

ในสัปดาห์ที่ 12 นี้ นักศึกษาจะได้เรียนรู้การพัฒนาแอปพลิเคชันมือถือสำหรับระบบ IoT ด้วยเฟรมเวิร์ก **Flutter** ซึ่งพัฒนาโดย Google และขับเคลื่อนด้วยภาษา **Dart** โดยโฟกัสที่การเชื่อมต่อโมบายล์แอปพลิเคชันเข้ากับ **MQTT Broker** โดยตรงผ่าน TCP Sockets และ WebSockets เพื่อสร้างแดชบอร์ดแสดงผลข้อมูลเซนเซอร์แบบเรียลไทม์ (Telemetry Monitoring) และแผงควบคุมสวิตช์สั่งการอุปกรณ์ (Actuator Remote Control) ที่ทำงานตอบสนองทันทีโดยไม่ต้องพึ่งพาคลาวด์ภายนอก

เนื้อหาประจำสัปดาห์นี้แบ่งออกเป็น 4 เสาหลัก:
1. **สถาปัตยกรรม Cross-Platform IoT & พื้นฐาน Flutter**: สถาปัตยกรรมการเรนเดอร์กราฟิกของ Flutter (Impeller Engine), โครงสร้างต้นไม้วิดเจ็ต (Widget Tree), วงจรชีวิตของวิดเจ็ต (Stateless vs Stateful Lifecycle), และเปรียบเทียบการรับส่งข้อมูลแบบ Reactive UI กับการ Polling แบบดั้งเดิม
2. **การผสานโปรโตคอล MQTT ใน Flutter**: การใช้งานแพ็กเกจ `mqtt_client`, การจัดการการเชื่อมต่อผ่าน TCP Socket และ WebSocket (พอร์ต 8083/9001), การดักฟังสตรีมข้อมูล (Stream Subscription), การแปลงข้อมูล JSON Payload, และกลไก Reconnection อัตโนมัติเมื่อสัญญาณเน็ตหลุด
3. **การจัดการสถานะเชิงปฏิกิริยา (Reactive State Management)**: การออกแบบสถาปัตยกรรมแอปพลิเคชันเพื่อแยก Network Layer ออกจาก Presentation Layer โดยใช้โมเดล Reactive เช่น `ChangeNotifier`, `ValueNotifier`, หรือ `StreamBuilder` รองรับการอัปเดตข้อมูลเซนเซอร์ความถี่สูงโดยไม่ทำให้หน้าจอกระตุก
4. **การออกแบบแดชบอร์ด IoT ระดับมืออาชีพ (IoT Dashboard UI Design)**: การสร้างคอมโพเนนต์มาตรวัดแบบเกจทรงกลม (Radial Gauge), กราฟแนวโน้มข้อมูลแบบเรียลไทม์ (Live Trend Line Chart), สวิตช์เปิด-ปิดแบบโต้ตอบ (Interactive Toggle Switch), แถบแจ้งเตือนสถานะการเชื่อมต่อ (Connection Banner), และชุดสี Dark Mode ที่ทันสมัย

---

## 2. แผนผังเนื้อหาการเรียนรู้ประจำสัปดาห์ (Lesson Roadmap)

<p align="center"><img src="Images/Fig_Readme_2026-10-27T19-55-17_academic.svg" alt="Readme"></p>
<p align="center">  2. แผนผังเนื้อหาการเรียนรู้ประจำสัปดาห์ (Lesson Roadmap)</p>

---

## 3. สถาปัตยกรรมการเชื่อมต่อของระบบ (End-to-End System Topology)

ในสัปดาห์นี้ เราจะสร้างวงจรการทำงานที่สมบูรณ์แบบของระบบ IoT โดยเชื่อมต่อ 3 องค์ประกอบหลักเข้าด้วยกัน:

<p align="center"><img src="Images/Fig_Readme_2026-10-27T20-00-43_academic.svg" alt="Readme" width="800" ></p>
<p align="center">  3. สถาปัตยกรรมการเชื่อมต่อของระบบ (End-to-End System Topology)</p>

---

## 4. แผนภาพการต่อสายฮาร์ดแวร์ (Hardware Wiring)

การทดลองใช้ฮาร์ดแวร์ต่อเนื่องจากสัปดาห์ที่ 11 เพื่อให้นักศึกษาสามารถนำบอร์ดเดิมมาทดสอบร่วมกับแอปพลิเคชัน Flutter ได้ทันที:

| อุปกรณ์ | ขาบนอุปกรณ์ | ขาต่อบน ESP32-C3 | ขาต่อบน Classic ESP32 | หน้าที่การทำงาน |
| :--- | :--- | :--- | :--- | :--- |
| **LED 5mm** | Anode (+) ผ่าน R 220Ω | **GPIO 8** | **GPIO 2** | ตัวแทน Actuator รับคำสั่งเปิด-ปิดจากสวิตช์บนมือถือ |
| **Resistor 220Ω** | ขาใดก็ได้ | อนุกรมกับ LED | อนุกรมกับ LED | จำกัดกระแสไฟป้องกัน LED เสียหาย |
| **Potentiometer 10k** | ขากลาง (Wiper) | **GPIO 0** (ADC1_CH0) | **GPIO 34** (ADC1_CH6) | ตัวแทน Sensor ส่งค่าแรงดันขึ้นไปแสดงบนเกจวัดในแอป |
| **Potentiometer 10k** | ขาริม 2 ขา | **3.3V / GND** | **3.3V / GND** | แรงดันไฟเลี้ยงและกราวด์อ้างอิง |

---

## 5. รายการเอกสารบทเรียนและใบงานประจำสัปดาห์

1. **[01-Cross-Platform-IoT-and-Flutter-Architecture.md](01-Cross-Platform-IoT-and-Flutter-Architecture.md)** - สถาปัตยกรรม Flutter, การทำงานของ Widget Tree, Reactive Programming, และการเปรียบเทียบการพัฒนา Mobile IoT ด้วย Flutter vs Native vs Web
2. **[02-MQTT-Client-Integration-in-Flutter.md](02-MQTT-Client-Integration-in-Flutter.md)** - การติดตั้งแพ็กเกจ `mqtt_client`, การเชื่อมต่อผ่าน TCP Sockets และ WebSockets, วงจรชีวิตการเชื่อมต่อ, การถอดรหัส JSON Payload, และกลไก Auto-Reconnect
3. **[03-State-Management-and-Reactive-IoT-UI.md](03-State-Management-and-Reactive-IoT-UI.md)** - การจัดการสถานะของข้อมูลเซนเซอร์ความถี่สูงด้วย `ChangeNotifier` และ `Streams`, การแยกเลเยอร์การสื่อสารเครือข่ายออกจาก UI
4. **[04-IoT-Dashboard-UI-Design-and-Interactive-Controls.md](04-IoT-Dashboard-UI-Design-and-Interactive-Controls.md)** - หลักการออกแบบ UI แดชบอร์ด IoT, การสร้าง Radial Gauge มาตรวัดเข็ม, กราฟเส้นแสดงข้อมูลย้อนหลัง, สวิตช์ควบคุมแอนิเมชัน, และชุดสีสไตล์ Dark Mode & Glassmorphism
5. **[05-Glossary.md](05-Glossary.md)** - อภิธานศัพท์และคำย่อทางเทคนิคประจำสัปดาห์ที่ 12
6. **[06-Labsheet-12-1-Flutter-Environment-Setup-and-MQTT-Basics.md](06-Labsheet-12-1-Flutter-Environment-Setup-and-MQTT-Basics.md)** - **ใบงานที่ 12.1: การติดตั้งสภาพแวดล้อม Flutter และการพัฒนา MQTT Client พื้นฐานบนสมาร์ตโฟน**
7. **[07-Labsheet-12-2-Interactive-Actuator-Control-Switch-and-Status.md](07-Labsheet-12-2-Interactive-Actuator-Control-Switch-and-Status.md)** - **ใบงานที่ 12.2: การสร้างสวิตช์ควบคุมอุปกรณ์สองทาง (Bi-directional Actuator Switch) พร้อมระบบ Feedback และสถานะ LWT**
8. **[08-Labsheet-12-3-Realtime-Telemetry-Dashboard-and-Radial-Gauge.md](08-Labsheet-12-3-Realtime-Telemetry-Dashboard-and-Radial-Gauge.md)** - **ใบงานที่ 12.3: การสร้างแดชบอร์ดแสดงผลเซนเซอร์เรียลไทม์ด้วย Radial Gauge และ Live Trend Line Chart**
9. **[09-Labsheet-12-4-End-to-End-IoT-Ecosystem-Integration.md](09-Labsheet-12-4-End-to-End-IoT-Ecosystem-Integration.md)** - **ใบงานที่ 12.4: การทดสอบผสานรวมระบบครบวงจร (ESP32-C3 Hardware <-> Mosquitto Broker <-> Flutter Mobile App)**

---

## 6. เครื่องมือและข้อกำหนดเบื้องต้น (Prerequisites)

* **เครื่องคอมพิวเตอร์สำหรับการพัฒนา**:
  * ติดตั้ง **Flutter SDK v3.19+** หรือเวอร์ชันล่าสุด
  * ติดตั้ง **VS Code** พร้อมส่วนขยาย *Flutter* และ *Dart* หรือ **Android Studio**
  * ติดตั้ง **Google Chrome** (สำหรับรันและทดสอบ Flutter Web) หรือติดตั้ง **Android Emulator** / มือถือจริงที่เปิด Developer Mode & USB Debugging
* **เครื่องมือเครือข่าย**:
  * ซอฟต์แวร์ **Eclipse Mosquitto Broker** จากสัปดาห์ที่ 11 (รันอยู่บนพอร์ต 1883 และสามารถเปิด WebSocket พอร์ต 8083/9001 ได้)
* **ฮาร์ดแวร์ฝั่งไมโครคอนโทรลเลอร์**:
  * บอร์ด **ESP32-C3** หรือ **ESP32** ที่แฟลชเฟิร์มแวร์ MQTT Client จากใบงานที่ 11.2 ไว้แล้ว
  * โมดูลเซนเซอร์ Potentiometer 10k และหลอดไฟ LED พร้อมตัวต้านทาน 220Ω

# Week 06: Wi-Fi SoftAP, RF Performance Profiling & Sensor Fusion with FreeRTOS

## 1. บทนำ (Introduction)
ในสัปดาห์ที่ 6 นี้ เราจะย้ายจากการทำงานในโหมด Station (`WIFI_STA`) มาสู่การกำหนดให้ ESP32 ทำงานเป็น **Access Point (SoftAP Mode)** เพื่อสร้างเครือข่ายไร้สายส่วนตัวของตนเอง 

นอกจากนี้นักศึกษาจะได้เรียนรู้และทดลองวัดประสิทธิภาพสัญญาณคลื่นวิทยุจริงผ่าน **RF Signal Physics (RSSI vs Speed/Throughput)** ด้วยการปรับกำลังส่ง (`esp_wifi_set_max_tx_power`) และวัดการชะลอตัวของสัญญาณเมื่อมีระยะทางหรือสิ่งกีดขวาง จากนั้นประยุกต์ใช้ **FreeRTOS Multi-Tasking & Queues** เพื่อรวมพลังกับเซนเซอร์ในการทำ **Sensor & Signal Fusion** สร้างแอปพลิเคชัน IoT ที่ใช้งานได้จริงในชีวิตประจำวัน เช่น **ระบบเช็กชื่อและประเมินระยะทางอัจฉริยะ (Proximity Attendance System)**

---

## 2. เนื้อหาการเรียนรู้ประจำสัปดาห์ (Lesson Roadmap)

1. **[01-Wi-Fi-SoftAP-Architecture.md](01-Wi-Fi-SoftAP-Architecture.md)** - สถาปัตยกรรม SoftAP Mode, DHCP Server (`dhcps`), Beacon Interval และ Event Handling (`WIFI_EVENT_AP_STACONNECTED`)
2. **[02-RF-Signal-Physics-and-TxPower.md](02-RF-Signal-Physics-and-TxPower.md)** - ฟิสิกส์คลื่นวิทยุ RSSI (dBm), Path Loss, การปรับกำลังส่งด้วย `esp_wifi_set_max_tx_power` และการวัด Throughput/Speed (Kbps)
3. **[03-FreeRTOS-Task-Design-for-IoT-Nodes.md](03-FreeRTOS-Task-Design-for-IoT-Nodes.md)** - สถาปัตยกรรม Multi-Tasking ด้วย FreeRTOS, การแบ่งงาน Network vs Sensor, และการสื่อสารผ่าน FreeRTOS Queues
4. **[04-Glossary.md](04-Glossary.md)** - อภิธานศัพท์ คำย่อ และนิยามทางเทคนิคประจำสัปดาห์ที่ 6

---

## 3. ใบงานปฏิบัติการประจำสัปดาห์ (Labsheets)

1. **[05-Labsheet-06-1-ESP32-SoftAP-Tracking.md](05-Labsheet-06-1-ESP32-SoftAP-Tracking.md)** - ใบงานที่ 6.1: การคอนฟิก ESP32 SoftAP และการสกัด Forensic Log ข้อมูล Client (MAC Address & AID)
2. **[06-Labsheet-06-2-RSSI-Speed-Profiling.md](06-Labsheet-06-2-RSSI-Speed-Profiling.md)** - ใบงานที่ 6.2: การประเมินความสัมพันธ์ RSSI vs Throughput ด้วย Software Tx-Power Control (Pair Work 👥)
3. **[07-Labsheet-06-3-FreeRTOS-Sensor-Queue.md](07-Labsheet-06-3-FreeRTOS-Sensor-Queue.md)** - ใบงานที่ 6.3: การออกแบบ FreeRTOS Task Architecture & Sensor Data Fusion ผ่าน Queue
4. **[08-Labsheet-06-4-Proximity-Attendance-System.md](08-Labsheet-08-4-Proximity-Attendance-System.md)** - ใบงานที่ 6.4: มินิโปรเจกต์ระบบเช็กชื่อและยืนยันตัวตนอัจฉริยะในห้องเรียนด้วย RF Proximity & Sensor Fusion

---

ปรับปรุงล่าสุด: 3 สิงหาคม 2569
