# ใบงานการทดลองที่ 12.4
### การทดสอบผสานรวมระบบครบวงจร (ESP32 Hardware <-> Mosquitto Broker <-> Flutter Mobile App)

---

## ผลลัพธ์การทดลอง
<img width="1080" height="2400" alt="Screenshot_20261019_221426" src="https://github.com/user-attachments/assets/097de0a2-2a6b-42ff-bef8-a7fcc1fb659c" />
<img width="1080" height="2400" alt="Screenshot_20261019_220818" src="https://github.com/user-attachments/assets/f7fcf1a2-1e5d-43f9-bdb6-ed4b6463b11c" />
<img width="1080" height="2400" alt="Screenshot_20261019_220707" src="https://github.com/user-attachments/assets/a849950d-3c7e-45ea-a4d5-afb8c73621d1" />


### ตารางบันทึกผลการทดสอบ 4 กรณีทดสอบวิกฤต (Verification Test Matrix)

| รายการทดสอบ | การกระทำเชิงกายภาพ (Hardware Action) / การจำลอง (Mock Action) | พฤติกรรมที่คาดหวังบน Flutter App | ผลการทดลองจริง (ผ่าน/ไม่ผ่าน) |
| :--- | :--- | :--- | :--- |
| **Test Case 1: Telemetry Monitoring** | **จำลอง:** สคริปต์ PowerShell/Python สตรีมค่า Sine Wave อัตโนมัติ | เข็มบน Radial Gauge หมุนระหว่าง 0.0V ถึง 3.3V อย่างนุ่มนวล ค่าดิบ ADC เปลี่ยนแปลง และกราฟประวัติ Live Sparkline ขยับต่อเนื่อง | ผ่าน |
| **Test Case 2: Actuator Remote Control** | แตะสวิตช์บนแอปเพื่อเปิดหรือปิดไฟ LED | >**จำลอง:** เทอร์มินัลแสดงข้อความ `ได้รับคำสั่ง: {"led":"ON"}` สวิตช์และไอคอนบนแอปเรืองแสงสีเขียว พร้อมการสั่นตอบสนอง (Haptic Feedback) | ผ่าน |
| **Test Case 3: State Sync & Physical ACK** | สลับสถานะหลอดไฟโดยตรง หรือปล่อยให้สคริปต์ส่งสัญญาณ ACK | แอปพลิเคชันได้รับค่า ACK และปรับปรุงสวิตช์ตามความเป็นจริง  | ผ่าน |
| **Test Case 4: Fault Tolerance (LWT)** | **จำลอง:** กด `Ctrl + C` บนหน้าต่างเทอร์มินัลที่รันสคริปต์จำลอง | ป้ายสถานะฮาร์ดแวร์บนแอปเปลี่ยนเป็น "OFFLINE" สีแดง และสวิตช์สั่งการจะถูกปิดกั้น (Disabled) ไม่ให้ส่งคำสั่ง | ผ่าน |

---

## 4. สรุปผลและคำถามท้ายบทเรียน (Review Questions)

### ข้อ 1: เหตุใดการใช้ `IndexedStack` ใน `MainNavigationShell` จึงมีความสำคัญอย่างยิ่งสำหรับแอปพลิเคชัน IoT แบบ Multi-tab เมื่อเทียบกับการสลับวิดเจ็ตด้วย `body: _pages[_currentIndex]`?
* **คำตอบ:**
  * **การรักษาชีวิตของ State และการเชื่อมต่อ TCP/MQTT (State & Connection Persistence)
  * **การรักษาข้อมูลประวัติเรียลไทม์ (Continuous Data Buffering):

---

### ข้อ 2: เมื่อเปรียบเทียบการพัฒนาด้วย Flutter ในสัปดาห์นี้ กับการเปิดหน้าเว็บ HTTP บนเบราว์เซอร์ในสัปดาห์ที่ 8-10 ข้อใดให้ประสบการณ์การใช้งาน (UX) และความเสถียรที่ดีกว่าเมื่อข้อมูลเซนเซอร์มาด้วยความถี่สูง? เพราะเหตุใด?
* **คำตอบ:**
  * **แอปพลิเคชัน Flutter ร่วมกับ MQTT ให้ UX และความเสถียรที่ดีกว่าอย่างชัดเจน** ด้วยเหตุผลดังนี้:
    1.  MQTT ใช้การเชื่อมต่อ TCP ค้างไว้เพียงครั้งเดียวและส่งเฉพาะเฟรมข้อมูลขนาดเล็ก (Header เพียง 2 ไบต์) แบบ Event-Driven ทันทีที่มีข้อมูลใหม่ ในขณะที่ HTTP แบบดั้งเดิมมี Overhead ของ Header สูงและหากใช้การดึงข้อมูลซ้ำๆ (HTTP Polling) ที่ความถี่สูง (เช่น ทุก 500ms) จะทำให้ ESP32 รับภาระหนักจนเกิดความหน่วงหรือค้างได้ง่าย
    2. Flutter คอมไพล์เป็น Native Machine Code และวาด UI ผ่านเอนจินกราฟิก (Impeller/Skia) บน GPU โดยตรงด้วยความเร็ว 60–120 FPS ร่วมกับ `CustomPainter` และ `TweenAnimationBuilder` จึงแสดงผลเข็มมาตรวัดและกราฟเส้นได้ลื่นไหลกว่าการอัปเดต DOM บนเว็บเบราว์เซอร์ พร้อมรองรับ Native API เช่น `HapticFeedback`

---

### ข้อ 3: หากต้องการนำแอปพลิเคชันนี้ไปเผยแพร่จริงบน Google Play Store หรือ Apple App Store ขั้นตอนความปลอดภัยที่ต้องปรับปรุงเพิ่มเติมมีอะไรบ้าง? (พิจารณาเรื่อง MQTTS / TLS พอร์ต 8883, การเข้ารหัส Token ยืนยันตัวตน, และการเก็บรักษา Credential)
* **คำตอบ:**
  * **1. การเข้ารหัสช่องทางสื่อสารด้วย MQTTS / TLS (Port 8883):**
  * **2. การยืนยันตัวตนและกำหนดสิทธิ์ (Authentication & Topic ACL):**
  * **3. การจัดเก็บข้อมูลความลับอย่างปลอดภัย (Secure Credential Storage):**
   
