# ใบงานการทดลองที่ 12.2
### การสร้างสวิตช์ควบคุมอุปกรณ์สองทาง (Bi-directional Actuator Switch) พร้อมระบบ Feedback และสถานะ LWT

---

## ผลลัพธ์การทดลอง
<img width="1197" height="217" alt="12-2-1" src="https://github.com/user-attachments/assets/de49da1f-afe5-4676-a5bd-d6cfc47c1009" />

<img width="677" height="135" alt="12-2-2" src="https://github.com/user-attachments/assets/aba796e9-58fa-4820-a623-0cf302c07ba1" />

<img width="1080" height="2400" alt="Screenshot_20261019_104934" src="https://github.com/user-attachments/assets/b001e751-7ff4-4305-9c08-5fb457b0e6dd" />
<img width="1080" height="2400" alt="Screenshot_20261019_105704" src="https://github.com/user-attachments/assets/f661d199-4e02-4241-bd4e-a85a7f91d063" />

---

## 4. สรุปผลและคำถามท้ายการทดลอง (Review Questions)

### ข้อ 1: ประโยชน์ของการรอสัญญาณ ACK จากหัวข้อ `iot/esp32/led_ack` แทนการเปลี่ยน UI ทันที (Optimistic Update) คืออะไร?
* **คำตอบ:**
  * **ความสอดคล้องกับสถานะจริงทางกายภาพ (True State Synchronization)** 
  * **การป้องกันคำสั่งค้างและการกดย้ำ (Debouncing / Prevention of Multiple Commands)** 
  * **ความน่าเชื่อถือในระบบ IoT (System Integrity)** 

---

### ข้อ 2: ทำไมเราจึงควรตั้งแฟล็ก Retain (`-r`) สำหรับหัวข้อสถานะ `iot/esp32/status`?
* **คำตอบ:**
  * **การซิงโครไนซ์สถานะทันทีเมื่อเปิดแอป (Instant Initial State Delivery)** 
  * **ทำงานร่วมกับกลไก LWT (Last Will and Testament) ได้อย่างสมบูรณ์แบบ** เ
