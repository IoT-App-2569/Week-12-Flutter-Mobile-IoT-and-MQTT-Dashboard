# ใบงานการทดลองที่ 12.3
### การสร้างแดชบอร์ดแสดงผลเซนเซอร์เรียลไทม์ด้วย Radial Gauge และ Live Trend Line Chart

---

## ผลลัพธ์การทดลอง
<img width="1080" height="2400" alt="Screenshot_20261019_213700" src="https://github.com/user-attachments/assets/261aaec2-334d-4ce4-9c1d-d568d1b53d59" />
<img width="1080" height="2400" alt="Screenshot_20261019_213043" src="https://github.com/user-attachments/assets/99b60da0-0c8c-4638-8b42-bbba0049e54a" />
<img width="1080" height="2400" alt="Screenshot_20261019_213718" src="https://github.com/user-attachments/assets/c549b5e4-c3a0-48a2-a248-44278ceda4e9" />
<img width="1080" height="2400" alt="Screenshot_20261019_213053" src="https://github.com/user-attachments/assets/6f37c443-96cf-42b8-85a9-412342459dde" />


---

## 4. สรุปผลและคำถามท้ายการทดลอง (Review Questions)

### ข้อ 1: เหตุใดการใช้ `TweenAnimationBuilder` จึงทำให้เข็มมาตรวัดดูนุ่มนวลและไม่กระตุก แม้ข้อมูลเซนเซอร์จะเข้ามาทุกๆ 500 มิลลิวินาที?
* **คำตอบ:**
  * **การคำนวณค่าระหว่างทางอัตโนมัติ (Interpolation):** 
  * **การเรนเดอร์ระดับ 60–120 FPS ร่วมกับ Curve:** 

---

### ข้อ 2: การจำกัดความยาวของอาร์เรย์ `_history` ให้เก็บไม่เกิน 30 ตัวอย่าง ส่งผลดีต่อประสิทธิภาพหน่วยความจำของสมาร์ตโฟนอย่างไร?
* **คำตอบ:**
  * **ป้องกันปัญหาหน่วยความจำรั่วไหล (Memory Leak / Unbounded Growth):** 
  * **รักษาความเร็วในการวาดกราฟให้คงที่ (O(1) Rendering Complexity):** 

---

### ข้อ 3: หากเซนเซอร์ส่งค่าผิดพลาด เช่น ค่านอกช่วง 0 - 3.3V หรือค่าเป็น `null` โค้ดส่วนใดใน `telemetry_dashboard_screen.dart` ที่ช่วยป้องกันไม่ให้แอปแครช?
* **คำตอบ:**
  * **1. การดักจับข้อผิดพลาดด้วยบล็อก `try-catch`:** ห่อหุ้มกระบวนการแปลงข้อมูล `jsonDecode(payload)` ไว้ทั้งหมด ห
  * **2. การใช้ Null-aware Casting และ Null-coalescing Operator (`as num?`, `?.`, `??`):**
  * **3. การจำกัดขอบเขตค่าด้วยเมธอด `.clamp(0.0, 1.0)`:**
    * ใน `_SparklinePainter` (`((history[i] / maxLimit).clamp(0.0, 1.0) * size.height)`) และใน `_GaugePainter` (`(value / maxLimit).clamp(0.0, 1.0)`) หากเซนเซอร์ส่งค่าที่ติดลบหรือสูงเกิน `3.3V` เมธอด `.clamp(0.0, 1.0)` จะบังคับให้อัตราส่วนอยู่ในช่วง `0.0` ถึง `1.0` เสมอ ป้องกันไม่ให้เส้นกราฟหรือเส้นโค้งมาตรวัดวาดทะลุออกนอกขอบเขตของ Widget
