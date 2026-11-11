#!/usr/bin/env python3
"""
mock_esp32.py - สคริปต์จำลองพฤติกรรมบอร์ด ESP32 ครบวงจร (Cross-platform Python)
รองรับทั้ง macOS, Linux และ Windows
"""

import sys
import time
import json
import math
import signal
import paho.mqtt.client as mqtt

BROKER = "127.0.0.1"
PORT = 1883

if len(sys.argv) > 1:
    BROKER = sys.argv[1]
if len(sys.argv) > 2:
    PORT = int(sys.argv[2])

print("=" * 60)
print("    [MOCK ESP32] สคริปต์จำลองพฤติกรรมบอร์ด ESP32 ครบวงจร")
print("=" * 60)

# สร้าง MQTT Client
try:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "MockESP32_Device")
except AttributeError:
    client = mqtt.Client("MockESP32_Device")

# ตั้งค่า LWT (Last Will and Testament)
client.will_set("iot/esp32/status", payload="offline", qos=1, retain=True)

led_state = False

def on_connect(c, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[1/3] เชื่อมต่อ MQTT Broker สำเร็จ ({BROKER}:{PORT})")
        print("[1/3] ส่งสถานะ ONLINE ไปยัง iot/esp32/status (Retain)...")
        c.publish("iot/esp32/status", "online", qos=1, retain=True)
        print("[3/3] ติดตาม (Subscribe) หัวข้อคำสั่ง: iot/esp32/control")
        c.subscribe("iot/esp32/control", qos=1)
    else:
        print(f"[ERROR] เชื่อมต่อ Broker ล้มเหลว (code: {rc})")

def on_message(c, userdata, msg):
    global led_state
    try:
        payload_str = msg.payload.decode('utf-8')
        now = time.strftime('%H:%M:%S')
        print(f"[{now}] ได้รับคำสั่ง: {payload_str}")
        
        if '"ON"' in payload_str or payload_str == 'ON':
            led_state = True
            print("  -> เปิดไฟ LED (GPIO 2 = HIGH) และส่ง ACK ยืนยันสำเร็จ")
        else:
            led_state = False
            print("  -> ปิดไฟ LED (GPIO 2 = LOW) และส่ง ACK ยืนยันสำเร็จ")
            
        ack_payload = json.dumps({"led_state": led_state, "ack": True})
        c.publish("iot/esp32/led_ack", ack_payload, qos=1)
    except Exception as e:
        print(f"[ERROR] ประมวลผลคำสั่งไม่สำเร็จ: {e}")

client.on_connect = on_connect
client.on_message = on_message

def cleanup(sig=None, frame=None):
    print("\n[STOP] หยุดการจำลอง: ส่งสถานะ OFFLINE ไปยัง iot/esp32/status...")
    try:
        client.publish("iot/esp32/status", "offline", qos=1, retain=True)
        time.sleep(0.5)
        client.loop_stop()
        client.disconnect()
    except Exception:
        pass
    print("จำลองบอร์ดดับ/ตัดการเชื่อมต่อเรียบร้อยแล้ว!")
    sys.exit(0)

signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

try:
    client.connect(BROKER, PORT, keepalive=60)
except Exception as e:
    print(f"\n[ERROR] ไม่สามารถเชื่อมต่อไปยัง MQTT Broker ที่ {BROKER}:{PORT} ได้!")
    print(f"รายละเอียด: {e}")
    print("\nวิธีแก้ไข:")
    print("  1. สตาร์ต Mosquitto Broker ด้วยคำสั่ง: mosquitto -c mosquitto.conf -v")
    print("  2. จากนั้นสั่งรันสคริปต์นี้ใหม่อีกครั้ง: python3 mock_esp32.py\n")
    sys.exit(1)

client.loop_start()

print("[2/3] เริ่มสตรีมข้อมูล Telemetry จำลอง Sine Wave (ทุก 500 ms)...")
print("      (แตะสวิตช์บน Flutter เพื่อทดสอบ หรือกด Ctrl+C เพื่อหยุดและส่งสถานะ OFFLINE)")
print("-" * 60)

t = 0
try:
    while True:
        voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
        raw = int((voltage / 3.3) * 4095)
        payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
        client.publish("iot/esp32/telemetry", payload, qos=0)
        t += 1
        time.sleep(0.5)
except KeyboardInterrupt:
    cleanup()

