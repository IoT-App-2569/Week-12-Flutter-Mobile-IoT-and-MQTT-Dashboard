# ใบงานการทดลองที่ 12.1
### การติดตั้งสภาพแวดล้อม Flutter และการพัฒนา MQTT Client พื้นฐานบนสมาร์ตโฟน
**รหัสนักศึกษา:** 67030134  
**สาขาวิชา:** วิศวกรรมระบบไอโอทีและสารสนเทศ (IoT System and Information Engineering)

---

## 1. ผลลัพธ์การทดลอง (Experimental Results)

### 1.1 การรัน Mosquitto Broker และการทดสอบผ่าน Mosquitto CLI
- **การเปิด Broker บนคอมพิวเตอร์:**
  รันคำสั่ง `mosquitto -v -p 1883` โดยระบุหรือใช้พอร์ตดีฟอลต์ 1883 พร้อมรองรับการเชื่อมต่อจากโลคอลโฮสต์และอุปกรณ์ในเครือข่าย

```text
PS D:\Week-12-Flutter-Mobile-IoT-and-MQTT-Dashboard> mosquitto -v -p 1883
1729307400: mosquitto version 2.0.18 starting
1729307400: Using default config.
1729307400: Starting in local only mode. Bind address: 127.0.0.1.
1729307400: Opening ipv4 listen socket on port 1883.
1729307405: New connection from 127.0.0.1:52134 on port 1883.
1729307405: New client connected from 127.0.0.1:52134 as Flutter_Lab12_1_1729307405123 (p2, c1, k20).
1729307405: Sending CONNACK to Flutter_Lab12_1_1729307405123 (0, 0)
1729307405: Received SUBSCRIBE from Flutter_Lab12_1_1729307405123
1729307405: 	test/broker/echo (QoS 0)
1729307405: Sending SUBACK to Flutter_Lab12_1_1729307405123
```

- **การเปิด Subscriber ดักฟังข้อความ Ping จาก Flutter:**
```powershell
mosquitto_sub -h 127.0.0.1 -p 1883 -t "test/flutter/ping" -v
```

- **การ Publish ตอบกลับจากคอมพิวเตอร์ไปยัง Flutter:**
```powershell
mosquitto_pub -h 127.0.0.1 -p 1883 -t "test/broker/echo" -m "Echo response from CLI [Student ID: 67030134]"
```

<img width="1041" height="220" alt="12-1-2" src="https://github.com/user-attachments/assets/9db6fe09-d020-4ccf-b15d-6b9cde67cb5d" />
<img width="982" height="300" alt="12-1-1" src="https://github.com/user-attachments/assets/cb8b50e9-92b1-42a2-bca7-519bea23dbe3" />

---

### 1.2 ผลการทำงานของ Flutter Mobile App (`iot_mqtt_basics`)
- แอปพลิเคชันเชื่อมต่อไปยัง Mosquitto Broker สำเร็จ แถบแสดงสถานะเปลี่ยนเป็นสีเขียว `เชื่อมต่อสำเร็จ (Connected)`
- เมื่อกดปุ่ม **Publish Test Message** แอปส่งข้อความ `Ping from Flutter [Time: ...]` ไปยังหัวข้อ `test/flutter/ping`
- แอปพลิเคชันบอกรับหัวข้อ `test/broker/echo` และแสดงข้อความตอบกลับในหน้าต่าง Received Message Logs แบบเรียลไทม์

<img width="1080" height="2400" alt="Screenshot_20261019_102153" src="https://github.com/user-attachments/assets/9a9d3eb9-6d9f-4b66-a064-6a5d38cd4459" />
<img width="1080" height="2400" alt="Screenshot_20261019_102050" src="https://github.com/user-attachments/assets/07391161-df2b-433e-a0a6-e2fabe120856" />

---

## 2. คำถามท้ายการทดลอง (Review Questions)

### ข้อ 1: เพราะเหตุใดเราจึงต้องสุ่มชื่อ `clientId` เช่นการใส่ Timestamp ต่อท้าย แทนที่จะตั้งชื่อแบบคงที่?
* **คำตอบ:**
  * **มาตรฐานของโปรโตคอล MQTT (RFC / OASIS Standard):** ระบุไว้ว่า `clientId` จะต้องมีค่าไม่ซ้ำกัน (**Unique**) ต่อหนึ่งโฮสต์/เซสชันบน Broker ตัวเดียวกัน หากมี Client 2 ตัวพยายามเชื่อมต่อด้วย `clientId` ที่เหมือนกัน Mosquitto Broker จะถือว่า Client ตัวใหม่เข้ามาแทนที่ และจะทำการสั่งตัดการเชื่อมต่อ (Disconnect) ของ Client ตัวเก่าทันที (พฤติกรรม "Client Kick")
  * **ประโยชน์ของการใส่ Timestamp ต่อท้าย:** การนำค่าเวลาในระดับมิลลิวินาที เช่น `DateTime.now().millisecondsSinceEpoch` หรือการสุ่ม UUID มาต่อท้ายชื่อ Client (เช่น `Flutter_Lab12_1_1729307405123`) จะช่วยรับประกันว่าชื่อ `clientId` จะไม่มีทางซ้ำกันในแต่ละเซสชันการเชื่อมต่อ หรือเมื่อเปิดแอปพร้อมกันหลายเครื่อง/เปิดปิดแอปใหม่ ทำให้การเชื่อมต่อเครือข่ายมีเสถียรภาพสูงสุด ไม่เกิดการเตะเซสชันสลับไปมา

---

### ข้อ 2: หากหน้าจอ Flutter รันบนอุปกรณ์จริง (Physical Android Phone) เหตุใดการกรอก IP `127.0.0.1` จึงไม่สามารถเชื่อมต่อ Broker ได้? และต้องใช้ IP ใด?
* **คำตอบ:**
  * **สาเหตุที่ `127.0.0.1` เชื่อมต่อไม่ได้:**
    * `127.0.0.1` คือ **Loopback Address (Localhost)** ซึ่งชี้ไปยังตัวเครื่อง (Local Device) ที่โค้ดกำลังประมวลผลอยู่เท่านั้น
    * เมื่อแอปพลิเคชันทำงานอยู่บนสมาร์ตโฟนจริง การระบุ `127.0.0.1` หมายถึงตัวเครื่องสมาร์ตโฟนเอง ซึ่งไม่ได้ติดตั้งหรือรัน Mosquitto Broker เอาไว้ จึงส่งผลให้เกิดข้อผิดพลาดเครือข่าย `SocketException: Connection refused (OS Error: Connection refused, errno = 111)`
  * **หมายเลข IP ที่ต้องใช้ในการเชื่อมต่อ:**
    1. **กรณีเชื่อมต่อผ่านสัญญาณ Wi-Fi:** ต้องระบุ **หมายเลข IPv4 Address ของเครื่องคอมพิวเตอร์** ที่รัน Mosquitto Broker อยู่ในวงแลนเดียวกัน (เช่น `192.168.1.X` หรือ `10.15.5.X`) โดยต้องเปิดการอนุญาตในไฟร์วอลล์ (Windows Defender Firewall) ให้พอร์ต 1883 รับการเชื่อมต่อจากภายนอก และคอนฟิก Mosquitto ให้มี `listener 1883 0.0.0.0` ร่วมกับ `allow_anonymous true`
    2. **กรณีเชื่อมต่อผ่านสาย USB ด้วย Android Debug Bridge (ADB Reverse):** สามารถใช้ `127.0.0.1` ได้โดยรันคำสั่ง `adb reverse tcp:1883 tcp:1883` บนเครื่องคอมพิวเตอร์ เพื่อให้ Android ส่งต่อพอร์ต 1883 ผ่านสาย USB เข้ามายัง localhost ของคอมพิวเตอร์โดยตรง

---

### ข้อ 3: การตั้งค่า `keepAlivePeriod` มีความจำเป็นอย่างไรในสภาพแวดล้อมเครือข่ายไร้สาย?
* **คำตอบ:**
  * **การตรวจจับการตัดการเชื่อมต่อแบบเงียบ (Silent / Half-Open Connection Detection):** ในระบบเครือข่ายไร้สาย (Wi-Fi หรือ Mobile Data) สัญญาณอาจหลุด กะพริบ หรืออุปกรณ์แบตเตอรี่หมดโดยที่ไม่มีการส่งแพ็กเก็ต `DISCONNECT` หรือ TCP FIN/RST มาบอก Broker ค่า `keepAlivePeriod` (เช่น 20 วินาที) กำหนดให้ Client ต้องส่งแพ็กเก็ต `PINGREQ` และรอรับ `PINGRESP` จาก Broker หาก Broker ไม่ได้รับข้อมูลใดๆ เกินกว่า 1.5 เท่าของเวลา Keep-Alive Broker จะถือว่า Client หลุดการเชื่อมต่อ และจะส่งข้อความแจ้งเตือนฉุกเฉิน (LWT: Last Will and Testament) ให้ Subscriber ตัวอื่นทราบทันที
  * **ป้องกันไม่ให้เราเตอร์และไฟร์วอลล์ตัดการเชื่อมต่อ (NAT / Firewall Keep-Alive):** เราเตอร์ระดับบ้านหรือไฟร์วอลล์เครือข่ายมักมีตาราง Stateful NAT Mapping ซึ่งจะปิดพอร์ต TCP ที่ไม่มีการรับส่งข้อมูลทิ้งไป (NAT Timeout) ภายในเวลาสั้นๆ การส่ง Ping เป็นช่วงๆ จึงเป็นการรักษาเส้นทาง TCP Session ให้เปิดค้างไว้ตลอดเวลา ทำให้ Broker สามารถส่งข้อความกลับมายังสมาร์ตโฟนได้ทันทีโดยไม่ติดขัด
