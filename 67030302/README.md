# โฟลเดอร์งานปฏิบัติการ Week 12 - รหัสนักศึกษา 67030302

**วิชา/หัวข้อ:** Cross-Platform Mobile IoT Application with Flutter & MQTT Dashboard

---

## รายการใบงานประจำสัปดาห์ (Labsheets)
- 📄 **Lab 12.1:** [06-Labsheet-12-1-Flutter-Environment-Setup-and-MQTT-Basics.md](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/06-Labsheet-12-1-Flutter-Environment-Setup-and-MQTT-Basics.md) หรือใน [Lab12-1/](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/Lab12-1/06-Labsheet-12-1-Flutter-Environment-Setup-and-MQTT-Basics.md)
- 📄 **Lab 12.2:** [07-Labsheet-12-2-Interactive-Actuator-Control-Switch-and-Status.md](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/07-Labsheet-12-2-Interactive-Actuator-Control-Switch-and-Status.md) หรือใน [Lab12-2/](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/Lab12-2/07-Labsheet-12-2-Interactive-Actuator-Control-Switch-and-Status.md)
- 📄 **Lab 12.3:** [08-Labsheet-12-3-Realtime-Telemetry-Dashboard-and-Radial-Gauge.md](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/08-Labsheet-12-3-Realtime-Telemetry-Dashboard-and-Radial-Gauge.md) หรือใน [Lab12-3/](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/Lab12-3/08-Labsheet-12-3-Realtime-Telemetry-Dashboard-and-Radial-Gauge.md)
- 📄 **Lab 12.4:** [09-Labsheet-12-4-End-to-End-IoT-Ecosystem-Integration.md](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/09-Labsheet-12-4-End-to-End-IoT-Ecosystem-Integration.md) หรือใน [Lab12-4/](file:///Users/povofwinter/Desktop/U/DrGo/Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard/67030302/Lab12-4/09-Labsheet-12-4-End-to-End-IoT-Ecosystem-Integration.md)

---

## โครงสร้างโฟลเดอร์สำหรับแลป (Directory Structure)

```text
67030302/
├── Lab12-1/
│   └── iot_mqtt_basics/             # ใบงานที่ 12.1: พื้นฐานการเชื่อมต่อ MQTT Client บน Flutter
├── Lab12-2/
│   └── iot_actuator_switch/         # ใบงานที่ 12.2: สวิตช์ควบคุมอุปกรณ์สองทาง (Bi-directional Actuator)
├── Lab12-3/
│   └── iot_telemetry_gauge/         # ใบงานที่ 12.3: แสดงผล Telemetry ด้วย Radial Gauge
│       └── pyTeleSim.py             # สคริปต์จำลองการส่งข้อมูลเซนเซอร์ (Python)
├── Lab12-4/
│   ├── iot_unified_dashboard/       # ใบงานที่ 12.4: แดชบอร์ด IoT รวมศูนย์ (Unified App)
│   ├── esp32_firmware/              # โค้ด ESP-IDF C สำหรับบอร์ด ESP32/ESP32-C3
│   ├── mock_esp32.ps1               # สคริปต์จำลอง ESP32 ครบวงจรสำหรับ Windows (PowerShell)
│   └── mock_esp32.py                # สคริปต์จำลอง ESP32 ครบวงจรสำหรับ macOS/Linux/Windows (Python)
├── Flutter-check.md                 # เอกสารตรวจสอบสภาพแวดล้อม Flutter
└── README.md                        # สรุปและคู่มือการทำแลป
```

---

## ขั้นตอนการเริ่มต้นทำแลป

### 1. เปิด Mosquitto MQTT Broker
เปิด Terminal ที่รูทของโปรเจกต์ (`Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard`):
```bash
mosquitto -c mosquitto.conf -v
```

### 2. การรันแต่ละแลป (Flutter)
เข้าไปที่โฟลเดอร์ของแลปที่ต้องการ เช่น:
```bash
# Lab 12.1
cd 67030302/Lab12-1/iot_mqtt_basics
flutter run

# Lab 12.2
cd 67030302/Lab12-2/iot_actuator_switch
flutter run

# Lab 12.3
cd 67030302/Lab12-3/iot_telemetry_gauge
flutter run

# Lab 12.4
cd 67030302/Lab12-4/iot_unified_dashboard
flutter run
```

### 3. การจำลองฝั่งฮาร์ดแวร์ (Mock ESP32 / Telemetry Simulator)
หากไม่ได้ต่อบอร์ด ESP32 จริง สามารถใช้สคริปต์จำลองได้:
- **จำลองเฉพาะ Telemetry (Lab 12-3 / 12-4):**
  ```bash
  python3 67030302/Lab12-3/iot_telemetry_gauge/pyTeleSim.py
  ```
- **จำลอง ESP32 ครบวงจรทั้ง Switch, Telemetry และ LWT (Lab 12-4):**
  ```bash
  python3 67030302/Lab12-4/mock_esp32.py
  ```
  *(หรือใช้ `pwsh 67030302/Lab12-4/mock_esp32.ps1` บนเครื่องที่ติดตั้ง PowerShell)*

