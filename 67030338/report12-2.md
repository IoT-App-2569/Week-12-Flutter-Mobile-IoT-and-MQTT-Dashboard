# ใบงานการทดลองที่ 12.2
### การสร้างสวิตช์ควบคุมอุปกรณ์สองทาง (Bi-directional Actuator Switch) พร้อมระบบ Feedback และสถานะ LWT

---

## ผลลัพธ์การทดลอง



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