import paho.mqtt.client as mqtt
import time
import json
import math
from datetime import datetime

BROKER = "127.0.0.1"
PORT = 1883

def on_connect(client, userdata, flags, reason_code, properties):
    print("[1/3] ส่งสถานะ ONLINE ไปยัง iot/esp32/status (Retain)...")
    client.publish("iot/esp32/status", "online", retain=True)
    client.subscribe("iot/esp32/control")
    print("[2/3] เริ่มสตรีมข้อมูล Telemetry จำลอง Sine Wave (ทุก 500 ms)...")
    print("[3/3] กำลังดักฟังคำสั่งจากแอป Flutter บนหัวข้อ iot/esp32/control...")
    print("      (แตะสวิตช์บน Flutter เพื่อทดสอบ หรือกด Ctrl+C เพื่อหยุดและส่งสถานะ OFFLINE)")
    print("----------------------------------------------------------")

def on_message(client, userdata, msg):
    payload_str = msg.payload.decode("utf-8", errors="ignore")
    now_str = datetime.now().strftime("%H:%M:%S")
    print(f"[{now_str}] ได้รับคำสั่ง: {payload_str}")

    led_state = "ON" in payload_str.upper()
    if led_state:
        print("  -> เปิดไฟ LED (GPIO 2 = HIGH) และส่ง ACK ยืนยันสำเร็จ")
    else:
        print("  -> ปิดไฟ LED (GPIO 2 = LOW) และส่ง ACK ยืนยันสำเร็จ")

    ack_payload = json.dumps({"led_state": led_state, "ack": True})
    client.publish("iot/esp32/led_ack", ack_payload)

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "MockESP32_Python")
client.will_set("iot/esp32/status", payload="offline", qos=1, retain=True)
client.on_connect = on_connect
client.on_message = on_message

print("==========================================================")
print("    [MOCK ESP32] สคริปต์จำลองพฤติกรรมบอร์ด ESP32 ครบวงจร   ")
print("==========================================================")

client.connect(BROKER, PORT, 20)
client.loop_start()

t = 0
try:
    while True:
        voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
        raw = int((voltage / 3.3) * 4095)
        telemetry = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
        client.publish("iot/esp32/telemetry", telemetry)
        t += 1
        time.sleep(0.5)
except KeyboardInterrupt:
    print("\n[STOP] หยุดการจำลอง: ส่งสถานะ OFFLINE ไปยัง iot/esp32/status...")
    client.publish("iot/esp32/status", "offline", retain=True)
    time.sleep(0.2)
    client.loop_stop()
    client.disconnect()
    print("จำลองบอร์ดดับ/ตัดการเชื่อมต่อเรียบร้อยแล้ว!")
