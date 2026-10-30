# Report_ใบงานการทดลองที่ 12.2
### การสร้างสวิตช์ควบคุมอุปกรณ์สองทาง (Bi-directional Actuator Switch) พร้อมระบบ Feedback และสถานะ LWT

<img width="378" height="866" alt="สกรีนช็อต 2026-10-31 032859" src="https://github.com/user-attachments/assets/58caa852-66b8-4bac-9cfc-f232be6f0dca" />

---

#### 1. จำลองส่งสถานะ Online (เสมือน ESP32 บูตเสร็จ)
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/status" -m "online" -r
```
*สังเกตหน้าจอ Flutter แถบสถานะด้านบนจะเปลี่ยนเป็นสีเขียวทันที*

<img width="373" height="863" alt="สกรีนช็อต 2026-10-31 033433" src="https://github.com/user-attachments/assets/919522fd-aee1-4958-bd5f-8004e6396acb" />

---


#### 2. เฝ้าดูคำสั่งที่ส่งมาจากแอป Flutter
```powershell
mosquitto_sub -h 127.0.0.1 -p 1883 -t "iot/esp32/control" -v
```
*เมื่อแตะสวิตช์บน Flutter จะเห็นแพ็กเก็ต `{"led":"ON"}` หรือ `{"led":"OFF"}` ปรากฏในเทอร์มินัล*

<img width="382" height="872" alt="image" src="https://github.com/user-attachments/assets/5677be26-e69f-4bef-9b6f-e33338dd9832" />

---

#### 3. ส่งคำสั่งยืนยันกลับไปยังแอป (เสมือนบอร์ดเปลี่ยนสถานะขา GPIO สำเร็จ)
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/led_ack" -m '{"led_state": true, "ack": true}'
```
*สังเกตสวิตช์และไอคอนหลอดไฟบนมือถือจะเรืองแสงสีเขียวทันที*

<img width="382" height="872" alt="image" src="https://github.com/user-attachments/assets/5677be26-e69f-4bef-9b6f-e33338dd9832" />

---

#### 4. จำลองเหตุการณ์บอร์ดดับหรือเน็ตหลุด (เสมือน Broker ส่ง LWT)
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/status" -m "offline" -r
```
*สังเกตว่าหน้าจอจะแจ้งเตือนว่า ESP32 ออฟไลน์ทันที และสวิตช์จะไม่ยอมให้สั่งการ*

<img width="377" height="867" alt="image" src="https://github.com/user-attachments/assets/79524bd9-73e3-45b7-8430-5ed0e795f5d7" />

<img width="990" height="261" alt="image" src="https://github.com/user-attachments/assets/334edeb6-8678-4535-8078-de4bb8214821" />

---
## 4. สรุปผลและคำถามท้ายการทดลอง
1. ประโยชน์ของการรอสัญญาณ ACK จากหัวข้อ `iot/esp32/led_ack` แทนการเปลี่ยน UI ทันที (Optimistic Update) คืออะไร?

   **ตอบ** ป้องกันปัญหา UI แสดงผลไม่ตรงกับสถานะจริงทางกายภาพ (State Desynchronization) เช่น กรณีเครือข่ายหลุดหรืออุปกรณ์ปลายทางดับ การรอ ACK จะรับประกันว่าสวิตช์บนแอปจะเปลี่ยนสถานะก็ต่อเมื่อบอร์ดฮาร์ดแวร์ทำงานสำเร็จจริงแล้วเท่านั้น

2. ทำไมเราจึงควรตั้งแฟล็ก Retain (`-r`) สำหรับหัวข้อสถานะ `iot/esp32/status`?

   **ตอบ** เพื่อให้ Mosquitto Broker จดจำสถานะล่าสุดของอุปกรณ์ไว้ตลอดเวลา เมื่อแอปพลิเคชันเพิ่งเปิดขึ้นมาใหม่หรือเพิ่งเชื่อมต่อ จะได้รับสถานะ Online/Offline ล่าสุดทันทีโดยไม่ต้องรอให้บอร์ดส่งข้อมูลรอบใหม่
