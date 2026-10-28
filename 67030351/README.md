# Week 12: Flutter Mobile IoT & MQTT Dashboard
**รหัสนักศึกษา:** 67030351

📄 **รายงานผลการทดลองฉบับเต็ม:** [report.md](report.md) *(บันทึกผล รูปภาพ และตอบคำถามครบทั้ง 4 แล็บ)*

---

### 📂 โครงสร้างการทดลอง (Lab Navigation)

| แล็บ | หัวข้อ | ซอร์สโค้ด | ลิงก์ในรายงาน |
| :---: | :--- | :---: | :---: |
| **12.1** | Flutter Environment & Basic MQTT Client | [Lab12-1/](Lab12-1/) | [ดูผล Lab 12.1](report.md#ใบงานการทดลองที่-121-การติดตั้งสภาพแวดล้อม-flutter-และการพัฒนา-mqtt-client-พื้นฐานบนสมาร์ตโฟน) |
| **12.2** | Bi-directional Actuator Switch & LWT | [Lab12-2/](Lab12-2/) | [ดูผล Lab 12.2](report.md#ใบงานการทดลองที่-122-การสร้างสวิตช์ควบคุมอุปกรณ์สองทาง-bi-directional-actuator-switch-พร้อมระบบ-feedback-และสถานะ-lwt) |
| **12.3** | Realtime Telemetry & Animated Radial Gauge | [Lab12-3/](Lab12-3/) | [ดูผล Lab 12.3](report.md#ใบงานการทดลองที่-123-การสร้างแดชบอร์ดแสดงผลเซนเซอร์เรียลไทม์ด้วย-radial-gauge-และ-live-trend-line-chart) |
| **12.4** | Complete End-to-End IoT Ecosystem (ESP32 + Flutter) | [Lab12-4/](Lab12-4/) | [ดูผล Lab 12.4](report.md#ใบงานการทดลองที่-124-การทดสอบผสานรวมระบบครบวงจร-esp32-hardware---mosquitto-broker---flutter-mobile-app) |

---

### 🎥 วิดีโอหลักฐานการทดสอบกับฮาร์ดแวร์จริง (Lab 12.4)
- **Test Case 1 (หมุน Potentiometer -> ปรับเข็ม Gauge):** [คลิกชมวิดีโอบน Google Drive](https://drive.google.com/file/d/1wZLPbCpnLN82cZUfLkf4cuFIX_N7oLYu/view?usp=sharing)
- **Test Case 2 (แตะสวิตช์บนแอป -> เปิดไฟ LED จริง):** [คลิกชมวิดีโอบน Google Drive](https://drive.google.com/file/d/1WNWv4tLhxvGQwt9FSkAghK-qRE3fu4Dm/view?usp=sharing)

---

### ⚡ คำสั่งเปิดรันโปรเจกต์แบบย่อ
```bash
# 1. เปิด Broker
/opt/homebrew/sbin/mosquitto -c mosquitto.conf -d

# 2. รันแอปพลิเคชันรวมศูนย์ (Lab 12.4)
cd 67030351/Lab12-4/iot_unified_dashboard && flutter run -d macos

# 3. รันตัวจำลอง ESP32 (กรณีไม่มีบอร์ดจริง)
cd 67030351/Lab12-4 && ./mock_esp32.sh
```
