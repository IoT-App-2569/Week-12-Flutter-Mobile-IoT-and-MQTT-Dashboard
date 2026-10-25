# Lab 12.4: End-to-End IoT Ecosystem Integration

โปรเจกต์การทดสอบผสานรวมระบบครบวงจร (ESP32 Hardware / Mock <-> Mosquitto Broker <-> Flutter Mobile App)

## โครงสร้างภายในโฟลเดอร์
- `iot_unified_dashboard/`: โปรเจกต์ Flutter รวมศูนย์ (Unified Multi-tab IoT App) รองรับทั้งมาตรวัด Telemetry Gauge และสวิตช์ Actuator Switch
- `esp32_firmware/`: เฟิร์มแวร์ ESP-IDF สำหรับบอร์ด ESP32 จริง (Hardware Mode)
- `mock_esp32.ps1`: สคริปต์ PowerShell สำหรับจำลองการทำงานของบอร์ด ESP32 ครบวงจร (Mock Simulation Mode)

## วิธีการใช้งาน

### 1. เปิดใช้งาน Mosquitto Broker
```powershell
mosquitto -c ../../mosquitto.conf -v
```

### 2. รันแอปพลิเคชัน Flutter (Unified Dashboard)
```powershell
cd iot_unified_dashboard
flutter run -d windows
```

### 3. รันตัวจำลองฮาร์ดแวร์ ESP32 (Mock Mode)
เปิด PowerShell หน้าต่างใหม่:
```powershell
powershell -ExecutionPolicy Bypass -File .\mock_esp32.ps1
```
หรือหากทดสอบด้วยฮาร์ดแวร์ ESP32 จริง:
```powershell
cd esp32_firmware
idf.py flash monitor
```
