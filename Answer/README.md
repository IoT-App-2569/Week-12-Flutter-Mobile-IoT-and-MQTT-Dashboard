# Week 12 – สมุดบันทึกการทดลอง (Answer)

**ชื่อ-สกุล:** ______________________ **รหัสนักศึกษา:** 67030098 **วันที่ทดลอง:** ____/____/______

| ใบงาน | หัวข้อ | ไฟล์บันทึก | โค้ดที่ใช้ |
| :--- | :--- | :--- | :--- |
| 12.1 | ติดตั้ง Flutter + MQTT Client พื้นฐาน | [Lab12-1.md](Lab12-1.md) | `Code/Lab12-1/iot_mqtt_basics` |
| 12.2 | สวิตช์ควบคุม LED สองทาง + ACK + LWT | [Lab12-2.md](Lab12-2.md) | `Code/Lab12-2/iot_actuator_switch` |
| 12.3 | Telemetry Dashboard + Radial Gauge | [Lab12-3.md](Lab12-3.md) | `Code/Lab12-3/iot_telemetry_gauge` |
| 12.4 | ผสานรวมระบบครบวงจร ESP32 ⇄ Broker ⇄ Flutter | [Lab12-4.md](Lab12-4.md) | `Code/Lab12-4/` |
| – | ตรวจสอบความพร้อมของโค้ดตัวอย่าง | [Code-Review.md](Code-Review.md) | ทุกโฟลเดอร์ |

## วิธีใช้สมุดนี้

- ช่อง **ผลที่คาดหวัง** กรอกไว้ให้แล้วจากใบงานและการอ่านโค้ด
- ช่อง **ผลจริง** และ **☐ ผ่าน / ☐ ไม่ผ่าน** ให้กรอกเองหลังทดลอง (ใส่ ☑ แทน ☐)
- ตำแหน่ง `![...](images/...)` คือที่วางภาพหน้าจอ ให้บันทึกภาพไว้ในโฟลเดอร์ `Answer/images/`
- คำตอบคำถามท้ายการทดลองเขียนไว้ท้ายไฟล์ของแต่ละใบงาน

## Topic MQTT ที่ใช้ทั้งสัปดาห์

| Topic | ทิศทาง | Payload |
| :--- | :--- | :--- |
| `test/flutter/ping` | Flutter → CLI | ข้อความ `Hello from Flutter at ...` (Lab 12.1) |
| `test/broker/echo` | CLI → Flutter | ข้อความใดก็ได้ (Lab 12.1) |
| `iot/esp32/control` | Flutter → ESP32 | `{"led":"ON"}` / `{"led":"OFF"}` |
| `iot/esp32/led_ack` | ESP32 → Flutter | `{"led_state": true, "ack": true}` |
| `iot/esp32/status` | ESP32 → Flutter (Retain + LWT) | `online` / `offline` |
| `iot/esp32/telemetry` | ESP32 → Flutter | `{"voltage": 1.65, "raw": 2048, "uptime": 10}` |
