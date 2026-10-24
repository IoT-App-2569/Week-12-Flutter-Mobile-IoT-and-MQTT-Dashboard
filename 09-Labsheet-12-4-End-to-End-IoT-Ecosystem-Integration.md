# ใบงานการทดลองที่ 12.4
### การทดสอบผสานรวมระบบครบวงจร (ESP32 Hardware <-> Mosquitto Broker <-> Flutter Mobile App)

> [!NOTE] **คำชี้แจง**
> ในใบงานนี้นักศึกษาจะได้นำทุกจิ๊กซอว์ที่พัฒนามาตั้งแต่สัปดาห์ที่ 11 และสัปดาห์ที่ 12 มาร้อยเรียงทำงานร่วมกันเป็น **ระบบนิเวศ IoT แบบครบวงจร (Complete End-to-End IoT Ecosystem)** โดยบอร์ดฮาร์ดแวร์จริง ESP32 จะสื่อสารกับแอปพลิเคชัน Flutter บนสมาร์ตโฟนผ่าน Mosquitto Broker เพื่อทดสอบการหมุนปรับค่า Potentiometer ทางกายภาพแล้วเห็นเข็มหน้าจอมือถือขยับทันที และการแตะสวิตช์บนมือถือแล้วหลอดไฟ LED จริงบนโต๊ะทดลองสว่างขึ้นในเสี้ยววินาที

---

## 1. วัตถุประสงค์การทดลอง
1. สามารถผสานรวมหน้าจอควบคุม Actuator และหน้าจอแสดงผล Telemetry เข้าเป็นแอปพลิเคชันรวมศูนย์ (Unified Multi-tab IoT App) ได้
2. สามารถเชื่อมต่อฮาร์ดแวร์บอร์ด ESP32 เข้ากับ Mosquitto Broker และสื่อสารกับแอป Flutter ได้สำเร็จ
3. สามารถวัดและวิเคราะห์ความหน่วงเวลาตอบสนองแบบไป-กลับ (Round-Trip Time - RTT) ของคำสั่งควบคุมได้
4. สามารถทดสอบความทนทานต่อสภาวะเครือข่ายล้มเหลว (Fault-Tolerance & LWT Handling) ในสถานการณ์จริงได้

---

## 2. แผนผังการทดสอบระบบแบบครบวงจรและโครงสร้างหัวข้อ (End-to-End Pipeline & Topic Architecture)

<p align="center"><img src="Images/Lab12.4-1_academic.svg" ></p>

| ชื่อหัวข้อ (Topic) | ทิศทางการส่ง | ชนิดข้อมูล (Payload Format) | วัตถุประสงค์ |
| :--- | :--- | :--- | :--- |
| `iot/esp32/status` | ESP32 -> Broker (LWT) | Plaintext: `"online"` หรือ `"offline"` | ตัวบ่งชี้ความพร้อมทำงานของบอร์ดฮาร์ดแวร์ (LWT Retained) |
| `iot/esp32/control` | Flutter -> ESP32 | JSON: `{"led": "ON"}` หรือ `{"led": "OFF"}` | ส่งคำสั่งเปิด-ปิดหลอดไฟ LED จากสมาร์ตโฟน |
| `iot/esp32/led_ack` | ESP32 -> Flutter | JSON: `{"led_state": true, "ack": true}` | ส่งการตอบรับสถานะจริงทางกายภาพของหลอดไฟกลับมายังแอป |
| `iot/esp32/telemetry` | ESP32 -> Flutter | JSON: `{"voltage": 2.50, "raw": 3102, "uptime": 10}` | ส่งค่าแรงดันตรวจวัดจาก Potentiometer และ Uptime แบบเรียลไทม์ |

---

## 3. ขั้นตอนการทดลอง (Step-by-Step Activities)

### กิจกรรมที่ 12-4.1: การเตรียมโปรเจกต์และสร้างแอปพลิเคชันรวมศูนย์ (`lib/main.dart`)

#### 1. คัดลอกโปรเจกต์และรวบรวมคอมโพเนนต์
ในแล็บนี้เราจะนำหน้าจอ `actuator_control_screen.dart` จาก Lab 12-2 และหน้าจอ `telemetry_dashboard_screen.dart` พร้อมกับ `radial_gauge_widget.dart` จาก Lab 12-3 มารวมกัน:

**คำสั่ง PowerShell:**
```powershell
# 1. คัดลอกโฟลเดอร์โปรเจกต์จาก Lab12-3 มาเป็น Lab12-4
Copy-Item -Recurse -Path "..\Lab12-3\iot_telemetry_gauge" -Destination "..\Lab12-4\iot_unified_dashboard"

# 2. คัดลอกหน้าจอ Actuator Control Screen จาก Lab12-2 มารวมในโฟลเดอร์ lib/
Copy-Item -Path "..\Lab12-2\iot_actuator_switch\lib\actuator_control_screen.dart" -Destination "..\Lab12-4\iot_unified_dashboard\lib\"

# 3. ย้ายเข้าไปยังโฟลเดอร์โปรเจกต์ใหม่
cd ..\Lab12-4\iot_unified_dashboard

# 4. ล้างแคชการคอมไพล์เดิมออก
flutter clean
```
*(หรือใช้ File Explorer ในการคัดลอกโฟลเดอร์และไฟล์ตามขั้นตอนข้างต้น)*

#### 2. ปรับปรุงโค้ดรวมศูนย์แอปพลิเคชัน (`lib/main.dart`)
เปิดไฟล์ `lib/main.dart` แล้วแทนที่ด้วยโค้ดต่อไปนี้ ซึ่งใช้ `IndexedStack` ร่วมกับ `NavigationBar` เพื่อรักษาสถานะ (State) และการเชื่อมต่อ MQTT ของทั้ง 2 หน้าจอให้ทำงานต่อเนื่องโดยไม่ตัดการเชื่อมต่อเมื่อสลับแท็บ:

```dart
import 'package:flutter/material.dart';
import 'actuator_control_screen.dart';
import 'telemetry_dashboard_screen.dart';

void main() {
  runApp(const UnifiedIotApp());
}

class UnifiedIotApp extends StatelessWidget {
  const UnifiedIotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Smart IoT Commander',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const MainNavigationShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // หมายเลข IP ของเครื่องรัน Broker:
  // - ใช้ '127.0.0.1' หากรันบนคอมพิวเตอร์เครื่องเดียวกัน (Windows Desktop) สำหรับการทดสอบจำลอง
  // - เปลี่ยนเป็น IP วง LAN ของเครื่องคอมพิวเตอร์ (เช่น '192.168.1.100') เมื่อรันแอปบนมือถือ หรือเชื่อมต่อกับ ESP32 จริง
  final String brokerIp = '127.0.0.1';

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TelemetryDashboardScreen(brokerIp: brokerIp),
      ActuatorControlScreen(brokerIp: brokerIp),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ใช้ IndexedStack เพื่อรักษาสถานะและการเชื่อมต่อ MQTT ของทั้งสองหน้าจอให้ทำงานต่อเนื่อง
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed),
            selectedIcon: Icon(Icons.speed, color: Color(0xFF00E5FF)),
            label: 'Telemetry Gauge',
          ),
          NavigationDestination(
            icon: Icon(Icons.toggle_on_outlined),
            selectedIcon: Icon(Icons.toggle_on, color: Color(0xFF00E676)),
            label: 'Actuator Switch',
          ),
        ],
      ),
    );
  }
}
```

#### 3. สั่งรัน Flutter App
```powershell
# รันบน Windows Desktop
flutter run -d windows

# หรือรันบน Android Device / Emulator
flutter run -d <device-id>
```

> [!TIP]
> **การกำหนด Broker IP เมื่อทดสอบร่วมกับ ESP32 หรือสมาร์ตโฟนจริง:**  
> 1. ตรวจสอบหมายเลข IPv4 ของคอมพิวเตอร์ผ่าน PowerShell ด้วยคำสั่ง `ipconfig` (เช่น `192.168.1.105`)
> 2. แก้ไขตัวแปร `brokerIp = '192.168.1.105';` ใน `main.dart`
> 3. เปิดไฟล์ `mosquitto.conf` ที่มีคำสั่ง `listener 1883 0.0.0.0` และ `allow_anonymous true`
> 4. สตาร์ต Broker ด้วยคำสั่ง:
>    ```powershell
>    mosquitto -c mosquitto.conf -v
>    ```

---

### กิจกรรมที่ 12-4.2: การเตรียมและสตาร์ตเฟิร์มแวร์ ESP32 หรือตัวจำลองฮาร์ดแวร์

ในการทดลองนี้ นักศึกษาสามารถเลือกดำเนินการได้ 2 ทางเลือก:
- **ทางเลือก A (Hardware Mode):** ใช้บอร์ด ESP32 จริง ต่อเซนเซอร์และหลอดไฟบนเบรดบอร์ด
- **ทางเลือก B (Mock Simulation Mode):** ใช้สคริปต์ PowerShell จำลองการทำงานของบอร์ด ESP32 ทั้งหมด (สำหรับกรณีไม่มีฮาร์ดแวร์จริง หรือทดสอบระบบแอปพลิเคชันอย่างรวดเร็ว)

> [!IMPORTANT]
> **ข้อกำหนดเบื้องต้นที่สำคัญที่สุด (Prerequisite):**  
> ตรวจสอบให้แน่ใจว่า **Mosquitto MQTT Broker กำลังทำงานอยู่** ก่อนเริ่มรันแอปพลิเคชันหรือรันสคริปต์จำลอง หากยังไม่ได้เปิด ให้เปิดหน้าต่าง PowerShell ใหม่ (ที่โฟลเดอร์หลัก) แล้วสั่งรันคำสั่ง:
> ```powershell
> mosquitto -c mosquitto.conf -v
> ```
> *(หากไม่ได้เปิด Broker ไว้ ทั้งแอป Flutter และสคริปต์จำลองจะไม่สามารถเชื่อมต่อได้ และจะแจ้งเตือนข้อผิดพลาด `Error: No connection could be made because the target machine actively refused it.`)*

---

#### ทางเลือก A: การใช้งานฮาร์ดแวร์จริง (Physical ESP32 Board)

##### 1. การต่อวงจรฮาร์ดแวร์บนเบรดบอร์ด (Circuit Wiring)
- **Potentiometer (เซนเซอร์แอนะล็อก):**
  - ขาริมซ้าย: ต่อเข้าขา `GND` ของบอร์ด ESP32
  - ขาริมขวา: ต่อเข้าขา `3.3V` ของบอร์ด ESP32
  - ขากลาง (สัญญาณ): ต่อเข้าขา `GPIO 34` (ช่องต่อ ADC1_CH6)
- **หลอดไฟ LED ทดสอบ (ตัวกระทำ):**
  - ขา Anode (+) หรือ Onboard LED: ขา `GPIO 2` (หากต่อ LED ภายนอก ให้ต่อผ่านตัวต้านทาน `330Ω` หรือถ้าไม่มีก็ให้ใช้ `470Ω` แทนได้) 
  - ขา Cathode (-): ต่อเข้าขา `GND`

##### 2. การกำหนดค่าและแฟลชเฟิร์มแวร์
1. เปิดโปรเจกต์เฟิร์มแวร์ที่เตรียมไว้ในโฟลเดอร์ `Example_codes/Lab12-4/esp32_firmware` (หรือคัดลอกมาจาก `Lab11-2_MQTT_Client` ในสัปดาห์ที่ 11)
2. ตรวจสอบและกำหนดค่าในไฟล์ `main/main.c`:
   * กำหนด `WIFI_SSID` และ `WIFI_PASS` ให้เชื่อมต่อเครือข่าย Wi-Fi เดียวกับคอมพิวเตอร์
   * กำหนด `MQTT_BROKER_URI` ชี้ไปยังหมายเลข IP ของคอมพิวเตอร์ (เช่น `mqtt://192.168.0.107:1883`)
   * มีการอ่านค่า Potentiometer บนขา `GPIO 34` (`ADC_CHANNEL_6`) และ Publish ไปยัง `iot/esp32/telemetry` ทุก 500 ms ในรูปแบบ JSON: `{"voltage": 2.50, "raw": 3102, "uptime": 10}`
   * มีการ Subscribe หัวข้อ `iot/esp32/control` และสั่งเปลี่ยนระดับสัญญาณบนขา `GPIO 2` ตามคำสั่ง `"ON"` หรือ `"OFF"`
   * มีการ Publish ข้อความยืนยันไปยัง `iot/esp32/led_ack` ในรูปแบบ JSON: `{"led_state": true, "ack": true}` เมื่อเปลี่ยนสถานะสำเร็จ
   * มีการกำหนด Last Will and Testament (LWT) ไปยัง `iot/esp32/status` ด้วยข้อความ `"offline"` (Retain = true)
3. สั่งคอมไพล์และแฟลชเฟิร์มแวร์ลงบอร์ด ESP32:
```powershell
idf.py set-target esp32
idf.py flash monitor
```

---

#### ทางเลือก B: การจำลองพฤติกรรม ESP32 ครบวงจรด้วย PowerShell (Mock ESP32 Simulator)

สำหรับนักศึกษาที่**ไม่มีฮาร์ดแวร์บอร์ด ESP32** หรือต้องการทดสอบระบบแอปพลิเคชันอย่างสะดวกรวดเร็ว สามารถใช้สคริปต์ `mock_esp32.ps1` ที่เตรียมไว้ในโฟลเดอร์ `Example_codes/Lab12-4/` เพื่อจำลองพฤติกรรมของฮาร์ดแวร์ครบวงจร:

##### พฤติกรรมที่สคริปต์จำลองให้โดยอัตโนมัติ:
1. **ตรวจสอบความพร้อมของ Broker:** ทดสอบการเชื่อมต่อกับ Broker พอร์ต 1883 ก่อน หาก Broker ยังไม่ทำงานจะแสดงข้อความแนะนำคำสั่งเปิด Broker ที่ถูกต้อง
2. **สถานะออนไลน์ (Online Beacon):** เมื่อเริ่มรัน สคริปต์จะ Publish ข้อความ `"online"` พร้อมแฟล็ก Retain ไปยังหัวข้อ `iot/esp32/status` ทำให้ป้ายสถานะบนหน้าต่างแอปเปลี่ยนเป็นสีเขียว "ONLINE" ทันที
3. **สตรีมข้อมูลเซนเซอร์อัตโนมัติ (Telemetry Streaming Background Job):** รันงานเบื้องหลังส่งคลื่นไซน์ (Sine Wave) เลียนแบบการหมุน Potentiometer ไปมาระหว่าง 0.15V – 3.15V (ค่า ADC ดิบ 0 – 4095) ทุก ๆ 500 มิลลิวินาที ไปยัง `iot/esp32/telemetry` ส่งผลให้เข็ม Gauge และกราฟเส้นแบบเรียลไทม์บน Flutter เคลื่อนไหวอย่างต่อเนื่อง
4. **การรับคำสั่งและตอบกลับ ACK (Actuator Control & ACK Loop):** ดักฟังคำสั่งบน `iot/esp32/control` เมื่อผู้ใช้กดสวิตช์บนแอป สคริปต์จะแสดงผลคำสั่งในหน้าต่างเทอร์มินัล และส่งสัญญาณยืนยัน `{"led_state": true/false, "ack": true}` ไปยัง `iot/esp32/led_ack` ทันที ทำให้สวิตช์บนแอปติดคงที่ตามหลักการ State Synchronization
5. **จำลองการดับของบอร์ด / LWT (Fault Tolerance):** เมื่อกด `Ctrl + C` เพื่อหยุดสคริปต์ บล็อก `finally` จะหยุด Background Job และส่งข้อความ `"offline"` พร้อม Retain ไปยัง `iot/esp32/status` ทันที เสมือนการถอดสายไฟออกจากบอร์ดฮาร์ดแวร์จริง

##### ซอร์สโค้ดสคริปต์ `mock_esp32.ps1` (สร้างไว้ใน `Example_codes/Lab12-4/mock_esp32.ps1`):
```powershell
# mock_esp32.ps1 - สคริปต์จำลองการทำงานของบอร์ด ESP32 บน PowerShell
param (
    [string]$Broker = "127.0.0.1",
    [int]$Port = 1883
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    [MOCK ESP32] สคริปต์จำลองพฤติกรรมบอร์ด ESP32 ครบวงจร   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# ตรวจสอบการเชื่อมต่อกับ Broker ก่อนเริ่มทำงาน
function Test-BrokerConnection {
    param([string]$Server, [int]$TargetPort)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($Server, $TargetPort, $null, $null)
        $success = $connect.AsyncWaitHandle.WaitOne(1000)
        if ($success -and $tcpClient.Connected) {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
        return $false
    } catch {
        return $false
    }
}

if (-not (Test-BrokerConnection -Server $Broker -TargetPort $Port)) {
    Write-Host "`n[ERROR] ไม่สามารถเชื่อมต่อไปยัง MQTT Broker ที่ ${Broker}:${Port} ได้!" -ForegroundColor Red
    Write-Host "สาเหตุ: ยังไม่ได้สตาร์ต Mosquitto Broker หรือระบุ IP / Port ไม่ถูกต้อง`n" -ForegroundColor Yellow
    Write-Host "วิธีแก้ไข:" -ForegroundColor White
    Write-Host "  1. เปิด PowerShell หน้าต่างใหม่ (ที่รูทโฟลเดอร์ของสัปดาห์ที่ 12)" -ForegroundColor Cyan
    Write-Host "  2. สั่งสตาร์ต Mosquitto Broker ด้วยคำสั่ง:" -ForegroundColor Cyan
    Write-Host "     mosquitto -c mosquitto.conf -v" -ForegroundColor Green
    Write-Host "     (หรือ: mosquitto -v)" -ForegroundColor DarkGray
    Write-Host "  3. จากนั้นจึงสั่งรันสคริปต์นี้ใหม่อีกครั้ง`n" -ForegroundColor Cyan
    exit 1
}

# 1. ส่งสถานะ Online เสมือนบอร์ดบูตเสร็จและเชื่อมต่อสำเร็จ
Write-Host "[1/3] ส่งสถานะ ONLINE ไปยัง iot/esp32/status (Retain)..." -ForegroundColor Green
mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "online" -r

# 2. เริ่มส่ง Telemetry จำลองเซนเซอร์ใน Background Job
$job = Start-Job -ScriptBlock {
    param($b, $p)
    $t = 0
    while ($true) {
        $v = [Math]::Round(1.65 + 1.5 * [Math]::Sin($t * 0.2), 2)
        $raw = [int](($v / 3.3) * 4095)
        $payload = "{`"voltage`": $v, `"raw`": $raw, `"uptime`": $t}"
        mosquitto_pub -h $b -p $p -t "iot/esp32/telemetry" -m $payload
        $t++
        Start-Sleep -Milliseconds 500
    }
} -ArgumentList $Broker, $Port

Write-Host "[2/3] เริ่มสตรีมข้อมูล Telemetry จำลอง Sine Wave (ทุก 500 ms)..." -ForegroundColor Yellow
Write-Host "[3/3] กำลังดักฟังคำสั่งจากแอป Flutter บนหัวข้อ iot/esp32/control..." -ForegroundColor Magenta
Write-Host "      (แตะสวิตช์บน Flutter เพื่อทดสอบ หรือกด Ctrl+C เพื่อหยุดและส่งสถานะ OFFLINE)" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

try {
    # 3. ดักฟังคำสั่งควบคุม LED แล้วส่ง ACK ตอบกลับทันที
    & mosquitto_sub -h $Broker -p $Port -t "iot/esp32/control" | ForEach-Object {
        $cmd = $_
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ได้รับคำสั่ง: $cmd" -ForegroundColor White
        
        $ledState = $false
        if ($cmd -match '"ON"' -or $cmd -match 'ON') {
            $ledState = $true
            Write-Host "  -> เปิดไฟ LED (GPIO 2 = HIGH) และส่ง ACK ยืนยันสำเร็จ" -ForegroundColor Green
        } else {
            Write-Host "  -> ปิดไฟ LED (GPIO 2 = LOW) และส่ง ACK ยืนยันสำเร็จ" -ForegroundColor Red
        }

        $ackJson = "{`"led_state`": $(if($ledState){'true'}else{'false'}), `"ack`": true}"
        mosquitto_pub -h $Broker -p $Port -t "iot/esp32/led_ack" -m $ackJson
    }
}
finally {
    # เมื่อกด Ctrl+C ให้หยุด Job และส่งสถานะ OFFLINE เสมือนบอร์ดดับ
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    Write-Host "`n[STOP] หยุดการจำลอง: ส่งสถานะ OFFLINE ไปยัง iot/esp32/status..." -ForegroundColor Yellow
    mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "offline" -r
    Write-Host "จำลองบอร์ดดับ/ตัดการเชื่อมต่อเรียบร้อยแล้ว!" -ForegroundColor Red
}
```

##### วิธีการสั่งรันสคริปต์จำลอง ESP32
เปิดหน้าต่าง PowerShell ใหม่ แล้วสั่งรันคำสั่ง:
```powershell
# ย้ายไปยังโฟลเดอร์ของใบงาน
cd Example_codes/Lab12-4

# รันสคริปต์จำลองชี้ไปยัง Local Broker (127.0.0.1)
powershell -ExecutionPolicy Bypass -File .\mock_esp32.ps1

# (กรณี Broker อยู่บน IP อื่น ให้ระบุพารามิเตอร์ -Broker)
# powershell -ExecutionPolicy Bypass -File .\mock_esp32.ps1 -Broker 192.168.1.105
```

---

### กิจกรรมที่ 12-4.3: การทดสอบ 4 กรณีทดสอบวิกฤต (Verification Test Matrix)

ให้นักศึกษาทำการทดสอบระบบครบวงจรและบันทึกผลการทดลองลงในตาราง:

| รายการทดสอบ | การกระทำเชิงกายภาพ (Hardware Action) / การจำลอง (Mock Action) | พฤติกรรมที่คาดหวังบน Flutter App | ผลการทดลองจริง (ผ่าน/ไม่ผ่าน) |
| :--- | :--- | :--- | :--- |
| **Test Case 1: Telemetry Monitoring** | **ฮาร์ดแวร์:** หมุน Potentiometer จากซ้ายสุดไปขวาสุด<br>**จำลอง:** สคริปต์ PowerShell สตรีมค่า Sine Wave อัตโนมัติ | เข็มบน Radial Gauge หมุนระหว่าง 0.0V ถึง 3.3V อย่างนุ่มนวล ค่าดิบ ADC เปลี่ยนแปลง และกราฟประวัติ Live Sparkline ขยับต่อเนื่อง | ✅ ผ่าน |
| **Test Case 2: Actuator Remote Control** | แตะสวิตช์บนแอปเพื่อเปิดหรือปิดไฟ LED | **ฮาร์ดแวร์:** หลอดไฟ LED บนขา GPIO 2 สว่างขึ้น<br>**จำลอง:** PowerShell แสดงข้อความ `ได้รับคำสั่ง: {"command": "ON"}` สวิตช์และไอคอนบนแอปเรืองแสงสีเขียว พร้อมการสั่นตอบสนอง (Haptic Feedback) | ✅ ผ่าน |
| **Test Case 3: State Sync & Physical ACK** | ปลดสายหรือสลับสถานะหลอดไฟโดยตรง หรือปล่อยให้สคริปต์ส่งสัญญาณ ACK | แอปพลิเคชันได้รับค่า ACK และปรับปรุงสวิตช์ตามความเป็นจริง หากไม่ได้รับ ACK สวิตช์จะไม่อัปเดตสถานะคงที่ | ✅ ผ่าน |
| **Test Case 4: Fault Tolerance (LWT)** | **ฮาร์ดแวร์:** ถอดสาย USB จ่ายไฟของบอร์ด ESP32 ออกกะทันหัน<br>**จำลอง:** กด `Ctrl + C` บนหน้าต่าง PowerShell ที่รัน `mock_esp32.ps1` | ป้ายสถานะฮาร์ดแวร์บนแอปเปลี่ยนเป็น "OFFLINE" สีแดง และสวิตช์สั่งการจะถูกปิดกั้น (Disabled) ไม่ให้ส่งคำสั่ง | ✅ ผ่าน |

> [!TIP]
> **คำสั่งจำลองแบบทีละขั้นตอนด้วยตนเอง (Manual PowerShell One-Liners):**  
> หากต้องการทดสอบทีละคำสั่งด้วยตนเองโดยไม่ใช้สคริปต์ `mock_esp32.ps1` สามารถใช้คำสั่งเหล่านี้ได้:
> - **จำลองสถานะ Online:**
>   ```powershell
>   mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/status" -m "online" -r
>   ```
> - **จำลอง Test Case 1 (Telemetry):**
>   ```powershell
>   mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/telemetry" -m '{"voltage": 2.10, "raw": 2608, "uptime": 45}'
>   ```
> - **จำลอง Test Case 2 (รับคำสั่งควบคุม):**
>   ```powershell
>   mosquitto_sub -h 127.0.0.1 -p 1883 -t "iot/esp32/control" -v
>   ```
> - **จำลอง Test Case 3 (ส่ง ACK ยืนยันกลับ):**
>   ```powershell
>   mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/led_ack" -m '{"led_state": true, "ack": true}'
>   ```
> - **จำลอง Test Case 4 (จำลอง LWT ออฟไลน์):**
>   ```powershell
>   mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/status" -m "offline" -r
>   ```

---

### กิจกรรมที่ 12-4.4: การวัดความหน่วงเวลาในการควบคุม (Control Latency Benchmark)

1. วัดเวลาตั้งแต่แตะสวิตช์ในแอป จนกระทั่งได้รับข้อความยืนยัน `iot/esp32/led_ack` กลับมายังสมาร์ตโฟน (Round-Trip Time - RTT)
2. สังเกตความหน่วงและบันทึกผลเปรียบเทียบในตาราง:

| สภาพแวดล้อมเครือข่าย | ประเภทการเชื่อมต่อ | เวลาตอบสนองโดยเฉลี่ย (RTT: ms) | ความเสถียร / ข้อสังเกต |
| :--- | :--- | :--- | :--- |
| **Local Wi-Fi LAN** | สมาร์ตโฟนและบอร์ด ESP32 ต่อเข้ากับ Wi-Fi Router เดียวกันในห้องทดลอง | ประมาณ 20 – 60 ms | รวดเร็ว ตอบสนองแทบจะทันที |
| **Mobile Hotspot / 4G** | สมาร์ตโฟนเชื่อมต่อ 4G/5G ชี้มายัง Broker ผ่าน Public IP หรือ Tailscale/VPN | ประมาณ 80 – 250 ms | ขึ้นอยู่กับความแรงสัญญาณและ Routing |

## ผลการทดลอง

### กิจกรรม 12-4.1 แอปพลิเคชันรวมศูนย์ (Unified Multi-tab App)

<img width="1456" height="820" alt="image" src="https://github.com/user-attachments/assets/91da94f0-1b06-4374-8068-a497fe2361e6" />

แอปมี 2 แท็บผ่าน `NavigationBar` คือ **Telemetry Gauge** และ **Actuator Switch** โดยใช้ `IndexedStack` รักษาการเชื่อมต่อ MQTT ของทั้งสองหน้าไว้พร้อมกัน

### กิจกรรม 12-4.2 เฟิร์มแวร์ ESP32 (ทางเลือก A: Hardware Mode)

| รายการ | ค่า |
|:---|:---|
| เฟิร์มแวร์ | `Example_codes/Lab12-4/esp32_firmware/main/main.c` |
| ESP-IDF | v6.0.2 |
| IP ของ ESP32 | 172.20.10.3 |
| Broker | `mqtt://172.20.10.4:1883` |
| Client ID | `ESP32_0dD204` |
| อัตราการส่ง Telemetry | ทุก 500 ms |

<img width="1472" height="742" alt="image" src="https://github.com/user-attachments/assets/f9c981c3-7660-4fcc-97cb-83125b548abe" />

### กิจกรรม 12-4.3 Verification Test Matrix

| รายการทดสอบ | การกระทำเชิงกายภาพ | พฤติกรรมที่สังเกตได้บน Flutter App | ผล |
|:---|:---|:---|:---:|
| **Test Case 1: Telemetry Monitoring** | หมุน Potentiometer จากสุดด้านหนึ่งไปอีกด้าน | เข็มเปลี่ยนจาก 3.30 V เป็น 0.00 V อย่างนุ่มนวล ค่า ADC เปลี่ยนจาก 4095 เป็น 0 การ์ดสูงสุด/ต่ำสุดเป็น 3.30 V / 0.00 V และกราฟ Live Trend ลดลงตามการหมุน | ✅ ผ่าน |
| **Test Case 2: Actuator Remote Control** | แตะสวิตช์บนแอป | LED สีแดงที่ GPIO 2 และ Onboard LED สีน้ำเงินติด/ดับตามคำสั่ง หลอดไฟในแอปเรืองแสงสีเขียว | ✅ ผ่าน |
| **Test Case 3: State Sync & Physical ACK** | ESP32 ส่ง ACK กลับหลังเปลี่ยนสถานะ GPIO | สวิตช์เปลี่ยนตาม `led_state` ใน ACK จากบอร์ดจริง สถานะ Waiting ACK แสดงเพียงชั่วครู่เพราะบอร์ดตอบกลับเร็ว | ✅ ผ่าน |
| **Test Case 4: Fault Tolerance (LWT)** | ถอดสาย USB ของบอร์ดออกกะทันหัน | หลัง Keep Alive หมดเวลา Broker ส่ง LWT `offline` แถบสถานะเปลี่ยนเป็น OFFLINE สีแดง และสวิตช์ถูกปิดกั้น | ✅ ผ่าน |

**Test Case 1**

<img width="1456" height="813" alt="image" src="https://github.com/user-attachments/assets/8986ae54-95a8-42e6-9c3e-e799795c9d92" />


**Test Case 2–3**

<img width="1917" height="1136" alt="image" src="https://github.com/user-attachments/assets/07da9160-72d2-414f-b9f8-2d147b717fad" />

<img width="1108" height="1477" alt="image" src="https://github.com/user-attachments/assets/4fdfcc5e-3e33-464e-80a4-e7eaf5004dc1" />

<img width="1917" height="1132" alt="image" src="https://github.com/user-attachments/assets/ee8b2729-ae6f-4426-ba5f-449b2938ba8d" />

<img width="819" height="1456" alt="image" src="https://github.com/user-attachments/assets/e905fb74-9d66-40a4-95ac-5a88992a9883" />


**Test Case 4**

<img width="1917" height="1138" alt="image" src="https://github.com/user-attachments/assets/3fb07e80-57c0-4bbe-bd1c-ae679fad75d3" />


**ข้อสังเกต:** บอร์ด ESP32 DevKit ต่อ Onboard LED สีน้ำเงินไว้ที่ GPIO 2 จึงติดพร้อมกับ LED ภายนอก

### กิจกรรม 12-4.4 การวัดความหน่วงเวลา (Control Latency Benchmark)

วัดด้วยสคริปต์ Python (`rtt_test.py`) ที่ส่ง `{"led": "ON/OFF"}` ไป `iot/esp32/control` แล้วจับเวลาจนได้รับ `iot/esp32/led_ack` จากบอร์ดจริง จำนวน 20 ครั้ง ซึ่งเป็นเส้นทางเดียวกับแอป Flutter


<img width="927" height="320" alt="image" src="https://github.com/user-attachments/assets/150428f0-53a4-4338-8004-d510e0fa89a5" />


| สภาพแวดล้อมเครือข่าย | ประเภทการเชื่อมต่อ | สำเร็จ | Min | Max | เฉลี่ย | Std Dev | ข้อสังเกต |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---|
| **Local LAN ผ่าน Mobile Hotspot** | ESP32 และคอมพิวเตอร์ต่อ iPhone Hotspot เดียวกัน | 20/20 | 108.84 ms | 602.92 ms | **254.43 ms** | 106.15 ms | ไม่มีคำสั่งสูญหาย แต่หน่วงกว่าค่าคาดหวัง |
| **Mobile 4G ผ่าน Public IP / VPN** | สมาร์ตโฟนต่อ 4G ชี้มายัง Broker | – | – | – | – | – | ไม่ได้ทดสอบ เพราะต้องเปิด Broker สู่ Public IP หรือตั้งค่า VPN เพิ่มเติม |

**วิเคราะห์ผล**
- RTT เฉลี่ย 254 ms สูงกว่าค่าที่ใบงานคาดไว้สำหรับ LAN (20–60 ms) สาเหตุหลักคือ ESP32 เปิดโหมดประหยัดพลังงาน Wi-Fi (Modem Sleep) เป็นค่าเริ่มต้น (log แสดง `wifi:pm start, type: 1` และ `listen interval 307200 us`) บอร์ดจะปิดวิทยุและตื่นมาฟังทุกประมาณ 300 ms คำสั่งที่มาถึงขณะบอร์ดหลับจึงต้องรอ ทำให้ RTT กระจายตัวสูง (Std Dev 106 ms)
- การใช้ iPhone Hotspot เป็นตัวกลางเพิ่มความหน่วงจากการ Forward แพ็กเก็ตระหว่างอุปกรณ์ และรบกวนจากเครือข่ายรอบข้างทำให้บางครั้งสูงถึง 602 ms
- แม้หน่วงกว่าที่คาด แต่ยังต่ำกว่า 1 วินาที ผู้ใช้รู้สึกว่าตอบสนองทันใจพอสำหรับการเปิด-ปิดไฟ และสำเร็จครบทุกครั้ง
- หากต้องการความหน่วงต่ำ สามารถเรียก `esp_wifi_set_ps(WIFI_PS_NONE)` เพื่อปิดโหมดประหยัดพลังงาน แลกกับการใช้พลังงานที่สูงขึ้น

### ปัญหาที่พบและการแก้ไข

| ปัญหา | สาเหตุ | วิธีแก้ |
|:---|:---|:---|
| เฟิร์มแวร์ 11.2 ใช้กับแอป 12.4 ไม่ได้ | ใช้ topic `iot/node01/...` ไม่ตรงกับ `iot/esp32/...` ของสัปดาห์ที่ 12 | ใช้เฟิร์มแวร์จาก `Example_codes/Lab12-4` และแก้ SSID, รหัสผ่าน และ IP Broker |
| แฟลชครั้งแรก build ไม่ผ่าน `expected '}' before 'P'` | พิมพ์ตัวอักษรเกินท้ายบรรทัด `MQTT_BROKER_URI` | ลบตัวอักษรที่เกินออก |
| `ModuleNotFoundError: No module named 'paho'` | รันใน ESP-IDF Terminal ที่ใช้ Python คนละตัว | รันใน PowerShell ธรรมดาที่ติดตั้ง paho-mqtt ไว้ |
| กราฟ Live Trend ถูก NavigationBar บังบางส่วน | หน้าต่างแอปมีความสูงไม่พอ | ขยายหน้าต่างหรือเลื่อนหน้าจอลง |

---
---

## 4. สรุปผลและคำถามท้ายบทเรียน
1. เหตุใดการใช้ `IndexedStack` ใน `MainNavigationShell` จึงมีความสำคัญอย่างยิ่งสำหรับแอปพลิเคชัน IoT แบบ Multi-tab เมื่อเทียบกับการสลับวิดเจ็ตด้วย `body: _pages[_currentIndex]`?

| ประเด็น | `body: _pages[_currentIndex]` | `IndexedStack` |
|:---|:---|:---|
| วิดเจ็ตหน้าอื่น | ถูกถอดออกจาก Widget Tree และเรียก `dispose()` ทุกครั้งที่สลับแท็บ | ถูกสร้างไว้ครบทุกหน้าและคงอยู่ตลอด แสดงเฉพาะหน้าที่เลือก |
| การเชื่อมต่อ MQTT | `dispose()` เรียก `_client?.disconnect()` เมื่อกลับมาต้อง `initState()` และ Connect ใหม่ เสียเวลาและเกิด Client ID ใหม่ทุกครั้ง | ทั้ง 2 หน้าเชื่อมต่อ Broker ค้างไว้ตลอด |
| ข้อมูลระหว่างอยู่หน้าอื่น | Telemetry ที่ส่งมาระหว่างอยู่หน้า Switch จะหายไป | หน้า Gauge ยังรับข้อมูลต่อเนื่อง กลับมาเห็นกราฟครบ |
| สถานะหน้าจอ | ค่าสูงสุด/ต่ำสุด, ประวัติ 30 จุด และสถานะ LED รีเซ็ตเป็นค่าเริ่มต้น | คงค่าเดิมทั้งหมด |
| สถานะ ONLINE | ต้องพึ่ง Retained Message ทุกครั้งที่กลับมาหน้า Switch | รู้สถานะตลอด และได้ LWT ทันทีแม้อยู่หน้าอื่น |

แอป IoT ต้องรับข้อมูลจากอุปกรณ์อย่างต่อเนื่อง การตัดและต่อการเชื่อมต่อทุกครั้งที่สลับแท็บทำให้ข้อมูลขาดช่วงและสิ้นเปลืองทรัพยากร จากการทดลองเมื่อกลับมาแท็บ Telemetry Gauge กราฟยังมีข้อมูลต่อเนื่อง ข้อแลกเปลี่ยนคือทุกหน้าใช้หน่วยความจำพร้อมกัน ในแอปที่มีหลายหน้ามาก ควรย้ายการเชื่อมต่อ MQTT ไปไว้ใน Service กลางเพียงตัวเดียว (เช่น ใช้ Provider หรือ Riverpod) แทนให้แต่ละหน้าเปิดการเชื่อมต่อของตัวเอง ซึ่งปัจจุบันแอปเปิดไว้ 2 การเชื่อมต่อ

2. เมื่อเปรียบเทียบการพัฒนาด้วย Flutter ในสัปดาห์นี้ กับการเปิดหน้าเว็บ HTTP บนเบราว์เซอร์ในสัปดาห์ที่ 8-10 ข้อใดให้ประสบการณ์การใช้งาน (UX) และความเสถียรที่ดีกว่าเมื่อข้อมูลเซนเซอร์มาด้วยความถี่สูง? เพราะเหตุใด?

**Flutter + MQTT ดีกว่า** ด้วยเหตุผลดังนี้
| ประเด็น | หน้าเว็บ HTTP บน ESP32 (สัปดาห์ 8–10) | Flutter + MQTT (สัปดาห์ 12) |
|:---|:---|:---|
| รูปแบบการรับข้อมูล | Polling: เบราว์เซอร์ต้องส่ง Request ถามซ้ำๆ แต่ละครั้งต้องเปิด TCP ใหม่และมี HTTP Header หลายร้อยไบต์ | Push: เปิดการเชื่อมต่อค้างไว้ Broker ส่งข้อมูลมาทันทีที่มี โดย MQTT Fixed Header เพียง 2 ไบต์ |
| ภาระของ ESP32 | ต้องเป็นเว็บเซิร์ฟเวอร์ ตอบ Request ทุกครั้ง หากเปิดหลายเครื่องพร้อมกัน ภาระเพิ่มตามจำนวนผู้ใช้ | ส่งข้อมูลครั้งเดียวไป Broker แล้ว Broker กระจายให้ทุก Client ภาระคงที่ |
| ความลื่นไหล | ช่วง Polling ทำให้ข้อมูลมาเป็นจังหวะ หากถี่เกินไปจะคิวค้างและหน้าเว็บกระตุก | Render ด้วย Engine กราฟิกแบบ Native 60 fps พร้อม `TweenAnimationBuilder` ทำให้เข็มเคลื่อนนุ่มนวล |
| การรู้สถานะอุปกรณ์ | รู้ว่าบอร์ดดับเมื่อ Request Timeout เท่านั้น | รู้ทันทีผ่าน LWT และ Retained Message |
| ความเสถียรเมื่อเน็ตไม่ดี | Request ล้มเหลวทีละครั้ง ต้องเขียนจัดการเอง | มี Keep Alive, Auto-reconnect และเลือก QoS ได้ |
| การเข้าถึง | ต้องอยู่วง LAN เดียวกับบอร์ด | ผ่าน Broker ข้ามเครือข่ายได้ |

ข้อดีของหน้าเว็บคือเปิดได้ทันทีจากทุกอุปกรณ์โดยไม่ต้องติดตั้งแอป และไม่ต้องมี Broker เหมาะกับหน้าตั้งค่าที่ใช้นานๆ ครั้ง แต่สำหรับข้อมูลความถี่สูงทุก 500 ms แบบในใบงานนี้ สถาปัตยกรรม Push ของ MQTT ร่วมกับ Native UI ของ Flutter ให้ทั้งความลื่นไหลและความเสถียรที่ดีกว่า


3. หากต้องการนำแอปพลิเคชันนี้ไปเผยแพร่จริงบน Google Play Store หรือ Apple App Store ขั้นตอนความปลอดภัยที่ต้องปรับปรุงเพิ่มเติมมีอะไรบ้าง? (พิจารณาเรื่อง MQTTS / TLS พอร์ต 8883, การเข้ารหัส Token ยืนยันตัวตน, และการเก็บรักษา Credential)
```
ระบบปัจจุบันเหมาะกับห้องทดลองเท่านั้น เพราะใช้พอร์ต 1883 แบบไม่เข้ารหัส, `allow_anonymous true` และ IP แบบ Hard-code ใครอยู่วงเดียวกันก็ดักฟังหรือสั่งงานอุปกรณ์ได้ ก่อนเผยแพร่ต้องปรับปรุง
1. เข้ารหัสด้วย MQTTS (TLS พอร์ต 8883): ใช้ `client.secure = true` ใน `mqtt_client` ร่วมกับใบรับรองที่ออกโดย CA สาธารณะ (เช่น Let's Encrypt) และให้ ESP32 ใช้ MQTTS แบบใบงาน 11.3 ปิดพอร์ต 1883 ทั้งหมด สำหรับแอปควรทำ Certificate Pinning ป้องกัน Man-in-the-Middle และ Apple App Transport Security / Android Network Security Config ก็บังคับใช้ TLS อยู่แล้ว
2. ยืนยันตัวตนผู้ใช้ด้วย Token: ห้ามฝัง Username/Password ของ Broker ในแอป เพราะถอดรหัสไฟล์ APK/IPA ได้ ให้ผู้ใช้ Login ผ่านระบบ Authentication (เช่น OAuth 2.0 / OpenID Connect) แล้วได้ Token อายุสั้น (JWT) ไปใช้เชื่อมต่อ Broker และต่ออายุด้วย Refresh Token
3. ควบคุมสิทธิ์ราย Topic (ACL): แต่ละผู้ใช้ Publish/Subscribe ได้เฉพาะ Topic ของอุปกรณ์ตัวเอง เช่น `users/{userId}/devices/{deviceId}/#` ปิด `allow_anonymous` และห้ามใช้ Wildcard `#` ระดับบนสุด ส่วน ESP32 แต่ละตัวยืนยันตัวตนด้วยใบรับรองเฉพาะเครื่อง (mTLS) แบบใบงาน 11.3
4. เก็บ Credential อย่างปลอดภัย: เก็บ Token ใน Keychain (iOS) และ Android Keystore ผ่านแพ็กเกจ `flutter_secure_storage` ห้ามเก็บใน SharedPreferences หรือไฟล์ธรรมดา และห้ามพิมพ์ Credential ลง Log
5. ตั้งค่า Broker ผ่านแอป ไม่ Hard-code IP: ใช้โดเมนพร้อมใบรับรอง หรือให้ผู้ใช้ตั้งค่าในแอป
6. ตรวจสอบข้อมูลขาเข้า: ตรวจรูปแบบและช่วงค่าของ JSON ก่อนใช้ ป้องกันข้อมูลปลอมทำให้แอปทำงานผิด
7. ความปลอดภัยฝั่งอุปกรณ์: เปิด Secure Boot และ Flash Encryption บน ESP32 และไม่ฝังรหัส Wi-Fi ในเฟิร์มแวร์ ใช้ BLE Provisioning แบบใบงาน 11.4 แทน
8. ข้อกำหนดของ Store: มีนโยบายความเป็นส่วนตัว (Privacy Policy) แจ้งการเก็บข้อมูล ขอสิทธิ์เท่าที่จำเป็น และทำ Code Obfuscation (`flutter build --obfuscate`)

ทางเลือกที่ง่ายกว่าคือใช้แพลตฟอร์มที่มีระบบเหล่านี้ครบแล้ว เช่น ESP RainMaker (ใบงาน 11.4) หรือ AWS IoT Core ซึ่งมี mTLS, Token และ ACL ในตัว
```
