# ผลตรวจโค้ดตัวอย่าง (`Code/`)

> [← กลับหน้ารวม](README.md)
>
> **วิธีตรวจ:** อ่านโค้ดทุกไฟล์แล้วไล่ตรวจกับใบงาน **ยังไม่ได้คอมไพล์หรือรันจริง** เพราะบนเครื่องที่ตรวจไม่พบ `flutter`, `mosquitto` และ `idf.py` ใน PATH
> ให้ยืนยันอีกครั้งด้วย `flutter pub get` → `flutter analyze` → `flutter run -d windows`

## สรุป

| โปรเจกต์ | รันแอปได้ไหม (`flutter run`) | `flutter test` / `flutter analyze` | หมายเหตุ |
| :--- | :--- | :--- | :--- |
| Lab12-1 `iot_mqtt_basics` | ✅ ได้ | ❌ test พัง | test เรียก `MyApp` ซึ่งไม่มีแล้ว |
| Lab12-2 `iot_actuator_switch` | ✅ ได้ | ❌ test พัง | เหมือน Lab12-1 |
| Lab12-3 `iot_telemetry_gauge` | ✅ ได้ | ⚠️ test อาจค้างหรือไม่ผ่าน | หน้าจอพยายามต่อ MQTT จริงระหว่างเทส |
| Lab12-4 `iot_unified_dashboard` | ✅ ได้ | ⚠️ เหมือน Lab12-3 | ไฟล์หน้าจอเหมือน 12-2 / 12-3 ทุกไบต์ |
| `pyTeleSim.py` | ✅ ได้ | – | ต้องใช้ `paho-mqtt >= 2.0` |
| `mock_esp32.ps1` | ✅ ได้ | – | ต้องมี `mosquitto_pub/sub` ใน PATH |
| `esp32_firmware` | ✅ น่าจะ build ได้ (ESP-IDF v5.x) | – | ต้องแก้ SSID/รหัส/IP ก่อน และ target เป็น `esp32` รุ่นมาตรฐาน ไม่ใช่ C3 |

**สรุป:** ใช้ทำแล็บได้ครบทั้ง 4 ใบงาน Topic และรูปแบบ JSON ตรงกันทุกส่วน (Flutter ⇄ mock ⇄ firmware) จุดที่พังจริงมีแค่ไฟล์ `test/widget_test.dart` ซึ่งไม่กระทบการรันแอป

## รายละเอียดที่ควรรู้

### 🔴 ต้องแก้ / ระวัง

1. **`test/widget_test.dart` ของ Lab12-1 และ Lab12-2** ยังเป็นเทส Counter ที่ `flutter create` สร้างให้ และเรียก `const MyApp()` ซึ่งไม่มีในโค้ด (มีแต่ `MqttBasicsApp` / `ActuatorApp`) ผลคือ `flutter test` คอมไพล์ไม่ผ่าน และ `flutter analyze` จะรายงาน error
   วิธีแก้: เปลี่ยนเป็น `MqttBasicsApp()` / `ActuatorApp()` แล้วลบส่วนที่ทดสอบปุ่ม `+` ออก หรือลบไฟล์เทสทิ้ง
2. **รหัส Wi-Fi จริงอยู่ใน `esp32_firmware/main/main.c`** (`WIFI_SSID` / `WIFI_PASS`) และถูก commit ขึ้น git แล้ว ถ้า push repo เป็น public รหัสจะรั่ว ควรเปลี่ยนเป็นค่า placeholder และพิจารณาเปลี่ยนรหัส Wi-Fi
3. **ESP32 ต้องเชื่อมต่อ Broker ผ่าน LAN** ต้องรัน `mosquitto -c mosquitto.conf -v` (ไฟล์อยู่ที่รากโปรเจกต์) ถ้ารันแค่ `mosquitto -v` จะฟังเฉพาะ `127.0.0.1` และต้องแก้ `MQTT_BROKER_URI` (ปัจจุบันคือ `192.168.0.107`) ให้ตรงกับ IP ของเครื่อง

### 🟡 พฤติกรรมที่ต่างจากใบงานเล็กน้อย

4. **สวิตช์ค้างถ้าไม่ได้รับ ACK:** `_isWaitingAck` ไม่มี Timeout ถ้าบอร์ดไม่ตอบ สวิตช์จะกดไม่ได้จนกว่าจะเปิดแอปใหม่
5. **ตอน OFFLINE สวิตช์ไม่ได้เป็น Disabled** แต่ใช้วิธีดักไว้แล้วแสดง SnackBar ผลคือไม่มีคำสั่งออกไปเหมือนกัน ต่างแค่หน้าตา
6. **ใบงาน 12.4 TC2** เขียนว่าจะเห็น `{"command": "ON"}` แต่โค้ดส่ง `{"led":"ON"}` (ใบงาน 12.2 เขียนถูก)
7. **เฟิร์มแวร์ใช้ขา GPIO 2 / GPIO 34 (ESP32 รุ่นมาตรฐาน)** ส่วน README ยกตัวอย่าง C3 ที่ GPIO 8 / GPIO 0 ถ้าใช้ C3 ต้องแก้ `LED_PIN`, `ADC_CHANNEL` และรัน `idf.py set-target esp32c3`
8. **LWT บนบอร์ดจริงไม่ได้มาทันที:** `keepalive = 60` ทำให้หลังถอดสายอาจต้องรอประมาณ 90 วินาที

### ⚪ เล็กน้อย (ไม่กระทบการทดลอง)

9. Lab12-1 ตั้ง `autoReconnect = true` และเรียก `updates.listen` ทุกครั้งใน `onConnected` ถ้าเชื่อมต่อใหม่หลายรอบอาจเห็น Log ซ้ำ
10. มีการใช้ `withOpacity()` และ `Switch.activeColor` ซึ่งถูก deprecate ใน Flutter รุ่นใหม่ จะขึ้นเป็น *info* ใน `flutter analyze` แต่ยังทำงานได้
11. ทุกโปรเจกต์ใช้ `name: iot_mqtt_basics` เหมือนกัน (เพราะคัดลอกโฟลเดอร์มา) ไม่มีปัญหาเพราะแยกโฟลเดอร์ แต่ชื่อแอปที่ติดตั้งลงเครื่องจะเหมือนกัน และจะทับกันถ้าติดตั้งลงมือถือเครื่องเดียว
12. `flutter run -d chrome` ใช้ไม่ได้ทุกแล็บ เพราะ `MqttServerClient` ใช้ `dart:io` (ใบงานแจ้งไว้แล้ว)

## ลำดับคำสั่งทดสอบด่วน

```powershell
# หน้าต่างที่ 1: Broker
mosquitto -c mosquitto.conf -v

# หน้าต่างที่ 2: แอป
cd Code\Lab12-4\iot_unified_dashboard
flutter pub get
flutter run -d windows

# หน้าต่างที่ 3: จำลอง ESP32
cd Code\Lab12-4
powershell -ExecutionPolicy Bypass -File .\mock_esp32.ps1
```
