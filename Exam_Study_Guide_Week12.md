# สรุปเนื้อหาและสาระสำคัญสำหรับเตรียมสอบ (Exam Study Guide)
## รายวิชา IoT: Week 12 - Cross-Platform Mobile IoT Application with Flutter & MQTT Dashboard

---

### สารบัญ (Table of Contents)
1. ภาพรวมสถาปัตยกรรมและบทบาทของโมบายล์แอปพลิเคชันในระบบ IoT
2. การเปรียบเทียบเทคโนโลยีพัฒนาโมบายล์แอป (Native vs Hybrid vs Flutter)
3. โครงสร้างและสถาปัตยกรรมภายในของ Flutter Framework
4. การทำงานของ MQTT Client บน Flutter (`mqtt_client`)
5. การจัดการสถานะเชิงปฏิกิริยา (Reactive State Management)
6. การออกแบบ Dashboard UI, CustomPainter และ แอนิเมชัน
7. สรุปการทดลอง 4 ปฏิบัติการ (Lab 12.1 – Lab 12.4)
8. ประเด็นคำถามยอดฮิตและแนวข้อสอบพร้อมเฉลยละเอียด (Exam Q&A)
9. คำศัพท์สำคัญที่ต้องจำเข้าห้องสอบ (Key Terms & Definitions)

---

## 1. ภาพรวมสถาปัตยกรรมและบทบาทของโมบายล์แอปพลิเคชันในระบบ IoT

ในระบบนิเวศ IoT ระดับอุตสาหกรรมและเชิงพาณิชย์ ไมโครคอนโทรลเลอร์ (เช่น ESP32) ทำหน้าที่เป็น **Edge Node** สำหรับเก็บเกี่ยวข้อมูลเชิงกายภาพ (Data Acquisition) และควบคุมสั่งการ (Physical Actuation) แต่ **สมาร์ตโฟน (Smartphone)** คือศูนย์กลางในการปฏิสัมพันธ์ระหว่างมนุษย์กับระบบ (**Human-Machine Interface: HMI**)

### 4 บทบาทหลักของ Mobile Application ใน IoT:
1. **Commissioning & Provisioning (การลงทะเบียนและตั้งค่าเริ่มต้น):** บอร์ดไมโครคอนโทรลเลอร์ไม่มีจอทัชสกรีนหรือคีย์บอร์ด สมาร์ตโฟนจึงใช้ BLE (Bluetooth Low Energy) หรือ Wi-Fi SoftAP ช่วยส่งค่า SSID และ Password ของเครือข่ายเข้าสู่บอร์ด
2. **Ubiquitous Telemetry & Control (การตรวจสอบและสั่งการได้ทุกที่):** แสดงผลค่าเซนเซอร์แบบเรียลไทม์ และส่งคำสั่งควบคุมข้ามเครือข่ายอินเทอร์เน็ต (Wi-Fi, 4G, 5G)
3. **Instant Alerting & Push Notifications:** การแจ้งเตือนทันทีเมื่อเซนเซอร์ตรวจพบความผิดปกติ เช่น อุณหภูมิสูงเกินพิกัด หรือไฟไหม้
4. **Product Experience & Commercial Value:** ประสบการณ์ผู้ใช้ ความลื่นไหล และความสวยงามของหน้าจอเป็นตัวตัดสินความพึงพอใจของผู้ใช้งานในเชิงพาณิชย์

---

## 2. การเปรียบเทียบเทคโนโลยีโมบายล์ (Mobile Development Approaches)

| มิติเชิงเทคนิค | Native (Kotlin / Swift) | Hybrid Web (Ionic / Cordova) | React Native (JavaScript) | Flutter (Dart) |
| :--- | :--- | :--- | :--- | :--- |
| **ภาษาที่ใช้** | Kotlin (Android), Swift (iOS) | HTML5, CSS, JS | JavaScript / TypeScript | **Dart** |
| **กลไกการเรนเดอร์** | Native Platform Widgets | Web View (DOM) | แปลงเป็น Native Views ผ่าน JS Bridge | **วาดเองทุกพิกเซลผ่าน Canvas / Impeller Engine** |
| **ประสิทธิภาพ (FPS)** | สูงสุด (60-120 FPS) | ต่ำ-ปานกลาง (มักกระตุกเมื่อข้อมูลถี่) | สูง แต่มีคอขวดที่ JS Bridge | **สูงเทียบเท่า Native (60-120 FPS คงที่)** |
| **การรองรับ Socket / MQTT** | Native TCP Socket | WebSockets เท่านั้น | ต้องใช้ Native Module / Polyfill | **รองรับทั้ง Raw TCP Socket และ WebSocket** |
| **ความสม่ำเสมอของ UI** | หน้าตาต่างกันตามแต่ละ OS | หน้าตาเหมือนกันแต่อืด | อิง UI ตามแต่ละ OS | **Pixel-Perfect สวยงามเหมือนกัน 100% ทุก OS** |
| **ต้นทุนและเวลาพัฒนา** | สูง (เขียนโค้ด 2 ชุดแยกกัน) | ต่ำ แต่ประสิทธิภาพจำกัด | ปานกลาง (Codebase เดียว) | **คุ้มค่าสูงสุด (Codebase เดียว ประสิทธิภาพสูง)** |

> **ข้อสอบมักถาม:** *ทำไมแอป IoT ถึงเลือกใช้ Flutter แทน Hybrid Web หรือ React Native?*  
> **แนวคำตอบ:** ข้อมูล IoT Telemetry ไหลเข้ามาด้วยความถี่สูง (High-Frequency Stream เช่น 2-10 ครั้ง/วินาที) หากใช้ Hybrid Web จะเกิด Frame Drop จากการทำ DOM Reflow ส่วน React Native จะติดคอขวด Serialization ผ่าน JS Bridge ในขณะที่ **Flutter คอมไพล์ภาษา Dart เป็น Machine Code โดยตรง (AOT)** และวาดภาพผ่าน **Impeller/Skia Engine ลงบน GPU โดยตรง** ทำให้เรนเดอร์กราฟและเข็มวัดได้นุ่มนวลคงที่ 60-120 FPS

---

## 3. โครงสร้างและสถาปัตยกรรมภายในของ Flutter Framework

### 3.1 สถาปัตยกรรม 3 ชั้น (Three-Tier Architecture)
1. **Framework Layer (Dart):** ชั้นบนสุดที่นักพัฒนาเขียน ประกอบด้วย Widgets, Rendering, Animation, Painting และ Material/Cupertino
2. **Engine Layer (C/C++):** ทำหน้าที่เป็นแกนกลางหลัก ประกอบด้วย **Impeller / Skia** (กราฟิกเอนจิน), **Dart VM / AOT Runtime**, และ Text Layout Engine
3. **Embedder Layer (Platform Specific):** ชั้นสื่อสารกับ OS ปลายทาง (Android, iOS, Windows, Linux, macOS) จัดการเรื่อง Window Display, Threading, Input Events

### 3.2 ปรัชญา "Everything is a Widget"
ทุกสิ่งบนหน้าจอ Flutter ล้วนเป็น Widget แบ่งเป็น 2 กลุ่มหลัก:
* **StatelessWidget:** วิดเจ็ตแบบคงรูป ไม่มีการเปลี่ยนค่าสถานะภายในตลอดวงจรชีวิต ทำงานตามพารามิเตอร์ที่รับมา
* **StatefulWidget:** วิดเจ็ตแบบมีสถานะ ข้อมูลภายในสามารถเปลี่ยนแปลงตามเวลาหรือตามเหตุการณ์ภายนอกได้ (Event-driven)

### 3.3 วงจรชีวิตของ StatefulWidget (State Lifecycle)
1. **`initState()`:** ทำงานเพียงครั้งเดียวเมื่อ Widget ถูกสร้างขึ้น เหมาะสำหรับ: กำหนดค่าเริ่มต้น, เชื่อมต่อ MQTT Broker, เริ่มดักฟัง Stream
2. **`build(BuildContext context)`:** ทำงานเมื่อสร้างหน้าจอ หรือถูกเรียกซ้ำหลังสั่ง `setState()`
3. **`didUpdateWidget()`:** ทำงานเมื่อ Parent Widget ส่งค่า Configuration ใหม่มาให้
4. **`dispose()`:** ทำงานเมื่อ Widget ถูกทำลายออกจากหน้าจอ เหมาะสำหรับ: ยกเลิกการเชื่อมต่อ MQTT (`client.disconnect()`), คืนหน่วยความจำ Controller (`controller.dispose()`), ยกเลิก `StreamSubscription`

### 3.4 แนวคิด Declarative UI vs Imperative UI
* **Imperative UI (ดั้งเดิม):** สั่งการเปลี่ยนแปลงหน้าจอเป็นขั้นตอน เช่น `lblStatus.setText("Online"); lblStatus.setColor(Green);` ทำให้เกิดความผิดพลาดเมื่อสถานะซับซ้อน
* **Declarative UI (Flutter):** นิยามหน้าจอในรูปแบบสมการ **`UI = f(State)`** เมื่อ State เปลี่ยนแปลง Flutter จะคำนวณส่วนต่างและ Rebuild เฉพาะส่วนที่เปลี่ยนให้อัตโนมัติ

---

## 4. การทำงานของ MQTT Client บน Flutter (`mqtt_client`)

### 4.1 สถาปัตยกรรมการเชื่อมต่อ (Transport Layer)
* **`MqttServerClient` (TCP Socket):**  
  ใช้สำหรับ Mobile (Android/iOS) และ Desktop (Windows/macOS/Linux) เชื่อมต่อไปยังพอร์ต **1883** (ไม่เข้ารหัส) หรือ **8883** (MQTTS/TLS) มี Packet Overhead ต่ำที่สุดและเร็วที่สุด
* **`MqttBrowserClient` (WebSocket):**  
  ใช้สำหรับ Flutter Web เนื่องจากเบราว์เซอร์ไม่อนุญาตให้เปิด Raw TCP Socket จึงต้องส่งผ่าน WebSocket พอร์ต **8083** หรือ **9001**

### 4.2 กลไกสำคัญของ MQTT Client ในระดับโปรดักชัน
1. **Client Identifier (`clientId`):**  
   ต้อง **Unique (ไม่ซ้ำกัน)** ในแต่ละเซสชันเสมอ โดยนิยมสุ่ม Timestamp ต่อท้าย เช่น `Flutter_Client_${DateTime.now().millisecondsSinceEpoch}`  
   *ถ้าใช้ ID ซ้ำ โบรกเกอร์จะสั่งตัดการเชื่อมต่อของไคลเอนต์เดิมทันที (Client Takeover)*
2. **Clean Session:**  
   ตั้งเป็น `true` เพื่อไม่ให้ค้างข้อความเก่าที่ไม่จำเป็นเมื่อแอปปิดไป
3. **Keep-Alive Period & PINGREQ/PINGRESP:**  
   ในเครือข่ายมือถือ (4G/5G) ผู้ให้บริการเครือข่ายมักตัด NAT Table หากไม่มีทราฟฟิกเกิน 60 วินาที จึงต้องตั้ง `keepAlivePeriod` ไว้ประมาณ **20-30 วินาที** เพื่อส่งแพ็กเก็ต `PINGREQ` ขนาด 2 ไบต์ไปรักษาการเชื่อมต่อ
4. **Last Will and Testament (LWT):**  
   ฝากข้อความพินัยกรรมไว้ที่ Broker ตั้งแต่ตอน Connect เช่น ส่ง `"offline"` (แบบ Retained) ไปที่ `iot/esp32/status` เมื่ออุปกรณ์ตัดการเชื่อมต่อกะทันหัน โบรกเกอร์จะปล่อยข้อความนี้แจ้งเตือนระบบทันที
5. **Stream-based Message Handling:**  
   ข้อมูลข้อความขาเข้าใน Dart จะถูกส่งออกมาในรูป `client.updates` (Stream) ทำให้นักพัฒนาสามารถใช้ `listen()` ดักฟังและถอดรหัส `MqttPublishPayload.bytesToStringAsString()` ได้แบบ Non-blocking

---

## 5. การจัดการสถานะเชิงปฏิกิริยา (Reactive State Management)

### 5.1 ปัญหาของ Spaghetti Code (The State Dilemma)
หากเขียนตรรกะการเชื่อมต่อเครือข่าย (Network Sockets) รวมไว้ในคลาส UI Widget หน้าจอจะ Rebuild พร่ำเพรื่อ เกิดอาการกระตุก (UI Jitter) และบำรุงรักษายาก

### 5.2 การออกแบบแยก 3 เลเยอร์ (Layered Architecture)
1. **Service Layer (`MqttService`):** จัดการ Socket, การเชื่อมต่อ, การส่งข้อความ Publish และรับไบต์ข้อมูล
2. **State Layer (`ChangeNotifier` / Provider):** ถอดรหัส JSON Payload, อัปเดตตัวแปรในหน่วยความจำ, จัดเก็บประวัติข้อมูล (History List), แล้วเรียก **`notifyListeners()`**
3. **UI Layer (Widgets / `ListenableBuilder`):** ดักฟังเฉพาะตัวแปรที่ตนเองสนใจ เพื่อ Rebuild เฉพาะส่วน เช่น เข็มเกจ หรือ สวิตช์ โดยไม่ต้องวาดหน้าจอใหม่ทั้งหมด

---

## 6. การออกแบบ Dashboard UI, CustomPainter และ แอนิเมชัน

### 6.1 สไตล์ Glassmorphism
ใช้พาเล็ตแบบ **Dark Mode** (`0xFF0F172A`) ผสมผสานกับการใช้กระจกฝ้าโปร่งแสง (`BackdropFilter` + `ImageFilter.blur`), แสงเรืองนีออน (Glow Shadow ด้วย `BoxShadow`), และการตอบสนองการสั่นสัมผัส (**Haptic Feedback** ผ่าน `HapticFeedback.mediumImpact()`)

### 6.2 การวาด Radial Gauge ด้วย `CustomPainter`
* ใช้ **`Canvas.drawArc`** วาดเส้นรอบวงพื้นหลัง (Background Track) และแถบสีความก้าวหน้า (Active Arc)
* คำนวณมุมด้วยตรีโกณมิติ:
  $$\text{startAngle} = 135^\circ \times \left(\frac{\pi}{180}\right)$$
  $$\text{sweepAngle} = 270^\circ \times \left(\frac{\pi}{180}\right)$$
* ใช้ **`SweepGradient`** ไล่เฉดสีจาก ฟ้า ($\rightarrow$) เขียว ($\rightarrow$) ส้ม ($\rightarrow$) แดง ตามระดับความเสี่ยงของแรงดันไฟฟ้า
* **`TweenAnimationBuilder`:** ช่วยหน่วงการเคลื่อนไหวของเข็มวัดด้วยเส้นโค้ง Ease-Out ทำให้เข็มหมุนอย่างนุ่มนวล แม้ข้อมูลดิบจะกระโดดมาแบบ Step

---

## 7. สรุปสาระสำคัญของ 4 ปฏิบัติการ (Lab 12.1 – Lab 12.4)

### Lab 12.1: Flutter Setup & MQTT Client Basics
* **โฟกัส:** ติดตั้ง `mqtt_client`, เขียน `MqttServerClient` เชื่อมต่อไปยังพอร์ต 1883
* **ฟังก์ชัน:** มีช่องกรอก IP, ปุ่ม Connect / Disconnect, แถบสถานะสี, ปุ่มส่ง Ping ไปยัง `test/flutter/ping`, และช่องแสดง Log ขาเข้าจาก `test/broker/echo`

### Lab 12.2: Bi-directional Actuator Switch & LWT
* **โฟกัส:** การควบคุมสวิตช์สองทาง และการรักษาสถานะ (State Synchronization)
* **Topic Architecture:**
  * `iot/esp32/control` (ส่ง `{"led": "ON"}` หรือ `{"led": "OFF"}`)
  * `iot/esp32/led_ack` (รับ ACK `{"led_state": true, "ack": true}`)
  * `iot/esp32/status` (รับ LWT: `"online"` หรือ `"offline"`)
* **จุดเน้น:** ป้องกันการสั่งการเมื่ออุปกรณ์ Offline และใช้ **Acknowledged State** (รอ ACK จากฮาร์ดแวร์ก่อนเปลี่ยนสถานะสวิตช์จริง)

### Lab 12.3: Realtime Telemetry Dashboard & Radial Gauge
* **โฟกัส:** การถอดรหัส JSON Payload และการวาดกราฟิกความเร็วสูง
* **Topic:** `iot/esp32/telemetry` ส่ง JSON: `{"voltage": 2.50, "raw": 3102, "uptime": 10}`
* **จุดเน้น:** วาด Radial Gauge ด้วย `CustomPainter`, ทำเข็มนุ่มนวลด้วย `TweenAnimationBuilder`, บันทึกอาร์เรย์ `_history` สูงสุด 30 ค่าเพื่อวาด Live Trend Sparkline และการ์ดแสดง Max / Min

### Lab 12.4: Complete End-to-End IoT Ecosystem Integration
* **โฟกัส:** ผสานรวมหน้าจอควบคุมและหน้าจอแสดงผลเข้าเป็นแอปเดียว (**Unified Dashboard**)
* **เทคนิคสำคัญ:** ใช้ **`IndexedStack`** ร่วมกับ **`NavigationBar`** เพื่อรักษาสถานะ (Keep State) และคงการเชื่อมต่อ MQTT ของทั้ง 2 หน้าจอไว้ตลอดเวลาเมื่อผู้ใช้สลับแท็บ
* **การทดสอบ:** รองรับทั้งการต่อบอร์ด ESP32 จริง และการใช้สคริปต์ `mock_esp32.ps1` ในการจำลองส่ง Telemetry, ตอบ ACK และทดสอบ LWT

---

## 8. ประเด็นคำถามยอดฮิตและแนวข้อสอบพร้อมเฉลยละเอียด (Exam Q&A)

#### คำถามที่ 1: เหตุใดต้องสุ่ม `clientId` ในการเชื่อมต่อ MQTT บน Flutter?
**เฉลย:**  
ตามมาตรฐาน MQTT Broker ไม่อนุญาตให้มีไคลเอนต์ที่ใช้ `clientId` ซ้ำกันเชื่อมต่อในเวลาเดียวกัน หากมีอุปกรณ์เชื่อมต่อเข้ามาด้วย ID เดียวกัน โบรกเกอร์จะตัดการเชื่อมต่อของเซสชันเดิมทิ้งทันที (**Client Takeover**) ในการพัฒนาด้วย Flutter มักเกิดการ Hot Restart / Hot Reload บ่อยครั้ง หากใช้ ID คงที่ แอปจะเตะการเชื่อมต่อของตัวเองจนเกิดลูป Disconnect สลับไปมา จึงต้องสุ่มค่า เช่น ใช้ Timestamp ต่อท้าย

#### คำถามที่ 2: รัน Flutter บนโทรศัพท์มือถือจริง แต่ต่อ Broker ด้วย IP `127.0.0.1` ไม่ได้ เพราะเหตุใด และแก้ไขอย่างไร?
**เฉลย:**  
`127.0.0.1` คือ **Loopback Address (Localhost)** หมายถึงตัวเครื่องที่รันโค้ดอยู่ เมื่อรันบนโทรศัพท์มือถือ แอปจะพยายามต่อพอร์ต 1883 บนตัวมือถือเอง ซึ่งไม่มี Broker ติดตั้งอยู่ จึงเกิด Connection Refused  
**วิธีแก้ไข:** ต้องเชื่อมต่อมือถือและคอมพิวเตอร์เข้า Wi-Fi วงเดียวกัน แล้วกรอก **IPv4 Address ของเครื่องคอมพิวเตอร์** (ดูจาก `ipconfig` เช่น `192.168.1.100`) และที่ตัว Mosquitto ต้องคอนฟิก `listener 1883 0.0.0.0` พร้อม `allow_anonymous true`

#### คำถามที่ 3: ทำไมแอป IoT แบบ Multi-tab ต้องใช้ `IndexedStack` แทนการสลับวิดเจ็ตแบบ `body: pages[index]`?
**เฉลย:**  
การสลับวิดเจ็ตแบบธรรมดา (`body: pages[index]`) จะทำให้หน้าจอที่ไม่ได้ถูกเลือกถูกทำลายทิ้งจากหน่วยความจำ (เรียก `dispose()`) ซึ่งจะไปตัดการเชื่อมต่อ Socket ของ MQTT และเมื่อสลับแท็บกลับมาจะต้องสร้าง State ใหม่และเชื่อมต่อ Broker ใหม่อีกครั้ง ทำให้ข้อมูลขาดตอน  
ในขณะที่ **`IndexedStack`** จะเก็บรักษาวิดเจ็ตทุกหน้าไว้ในหน่วยความจำพร้อมกัน ทำให้การเชื่อมต่อ MQTT Socket และการดักฟัง Stream ของทุกแท็บยังคงทำงานต่อเนื่องตลอดเวลา

#### คำถามที่ 4: เปรียบเทียบระหว่าง "Optimistic UI" กับ "Acknowledged State" แบบใดเหมาะกับระบบ IoT มากกว่ากัน?
**เฉลย:**  
* **Optimistic UI:** สลับสถานะสวิตช์บนหน้าจอทันทีที่ผู้ใช้แตะ โดยหวังว่าคำสั่งจะส่งสำเร็จ
* **Acknowledged State:** สวิตช์จะเปลี่ยนสถานะก็ต่อเมื่อได้รับข้อความตอบรับ (**ACK**) ยืนยันว่าฮาร์ดแวร์ทำงานจริงแล้ว  
**การเลือกใช้:** ในระบบ IoT การควบคุมเชิงกายภาพ (เช่น การเปิดปั๊มน้ำ, ประตู, ฮีตเตอร์) **ต้องใช้ Acknowledged State** เสมอ เพื่อป้องกันความผิดพลาดในกรณีสัญญาณเน็ตหลุด คำสั่งส่งไม่ถึง แต่หน้าจอแสดงว่าเปิดอยู่ ซึ่งอาจก่อให้เกิดอันตรายร้ายแรงได้

#### คำถามที่ 5: ประโยชน์ของ `keepAlivePeriod` บนระบบเครือข่ายไร้สาย (Cellular/Wi-Fi) คืออะไร?
**เฉลย:**  
1. ป้องกันปัญหา **Ghost / Half-Open Connection** โดยแอปจะส่งแพ็กเก็ต `PINGREQ` (2 ไบต์) ไปทดสอบ หาก Broker ไม่ตอบ `PINGRESP` เกินกว่า $1.5 \times \text{keepAlivePeriod}$ จะสรุปว่าหลุดและทริกเกอร์กลไก LWT ทันที
2. ป้องกันไม่ให้ Firewall หรือเราเตอร์ผู้ให้บริการมือถือ (Telco NAT Table) สั่งตัดการเชื่อมต่อ TCP ทิ้งเนื่องจากไม่มีทราฟฟิกไหลผ่านเป็นเวลานาน

#### คำถามที่ 6: การจำกัดขนาดประวัติข้อมูล `_history.length > 30` ใน Dart ส่งผลดีต่อระบบอย่างไร?
**เฉลย:**  
ช่วยป้องกันปัญหา **Memory Leak** และรักษาประสิทธิภาพของหน่วยความจำ (Garbage Collection Overhead) บนสมาร์ตโฟน หากปล่อยให้อาร์เรย์เก็บข้อมูลเซนเซอร์ที่ส่งเข้ามาทุกๆ 500 ms โดยไม่จำกัดขนาด หน่วยความจำจะเต็มอย่างรวดเร็ว และทำให้การคำนวณวาดกราฟเส้นของ CustomPainter เชื่องช้าลงจนแอปแครช

---

## 9. คำศัพท์สำคัญที่ต้องจำเข้าห้องสอบ (Key Terms & Definitions)

| คำศัพท์ | คำจำกัดความสั้นกระชับ (จำง่าย) |
| :--- | :--- |
| **Impeller Engine** | กราฟิกเอนจินยุคใหม่ของ Flutter ที่ Pre-compile Shaders ล่วงหน้า ป้องกันอาการกระตุกของเฟรมแรก (Jank) |
| **StatefulWidget** | วิดเจ็ตที่มี State เปลี่ยนแปลงได้ตามกาลเวลาและเหตุการณ์เครือข่าย |
| **`initState()`** | เมธอดใน State Lifecycle ที่ทำงานครั้งแรกครั้งเดียว เหมาะสำหรับเริ่มต่อ MQTT |
| **`dispose()`** | เมธอดสุดท้ายก่อน Widget ถูกทำลาย ใช้ตัดการเชื่อมต่อและคืนหน่วยความจำ |
| **`ChangeNotifier`** | คลาสตาม Observer Pattern ใช้เก็บข้อมูลสถานะและเรียก `notifyListeners()` เตือน UI |
| **`ListenableBuilder`** | วิดเจ็ตที่คอยดักฟัง Provider เพื่อ Rebuild เฉพาะชิ้นส่วนที่เกี่ยวข้อง ไม่โหลดซ้ำทั้งหน้า |
| **LWT (Last Will)** | ข้อความพินัยกรรมที่ Broker ปล่อยออกมาแจ้งเตือนแทนอุปกรณ์ เมื่ออุปกรณ์ดับหรือหลุดกะทันหัน |
| **Retained Message** | ข้อความที่ Broker บันทึกไว้ส่งต่อให้ผู้ที่มา Subscribe ในภายหลังทันที |
| **CustomPainter** | คลาสเข้าถึง Canvas 2D โดยตรงสำหรับวาดรูปทรงเรขาคณิตและเกจวัดตามหลักตรีโกณมิติ |
| **IndexedStack** | วิดเจ็ตจัดเก็บหน้าต่างแบบซ้อนทับ ช่วยรักษาสถานะและ Socket ไม่ให้หลุดเมื่อสลับแท็บ |
| **Haptic Feedback** | การสั่งมอเตอร์สั่นของโทรศัพท์เพื่อตอบสนองการกดปุ่มของผู้ใช้ |
| **Sparkline** | กราฟเส้นแนวโน้มขนาดเล็กแบบย่อส่วน ไม่เน้นสเกลแกน แต่เน้นแสดงแนวโน้มขึ้นลงของข้อมูล |
