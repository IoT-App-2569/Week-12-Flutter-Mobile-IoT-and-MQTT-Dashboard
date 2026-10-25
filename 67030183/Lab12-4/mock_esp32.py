#!/usr/bin/env python3
"""
mock_esp32.py - สคริปต์จำลองการทำงานของบอร์ด ESP32 ครบวงจรสำหรับ macOS / Linux / Windows
รองรับ:
1. ส่งสถานะ ONLINE (Retained) ไปยัง iot/esp32/status
2. ส่งข้อมูล Telemetry (Sine wave 0.15V - 3.15V) ไปยัง iot/esp32/telemetry ทุก 500 ms
3. ดักฟังคำสั่งบน iot/esp32/control แล้วส่ง ACK ตอบกลับไปยัง iot/esp32/led_ack
4. เมื่อกด Ctrl+C จะส่งสถานะ OFFLINE (Retained) จำลอง LWT ทันที
"""

import time
import json
import math
import threading
import sys
import paho.mqtt.client as mqtt

BROKER = "127.0.0.1"
PORT = 1883
running = True

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "Mock_ESP32_Device")

def on_connect(c, userdata, flags, rc, properties=None):
    print(f"\033[92m[1/3] เชื่อมต่อ Broker สำเร็จ! ส่งสถานะ ONLINE ไปยัง iot/esp32/status (Retain)...\033[0m")
    client.publish("iot/esp32/status", "online", qos=1, retain=True)
    client.subscribe("iot/esp32/control", qos=1)
    print(f"\033[95m[3/3] กำลังดักฟังคำสั่งบนหัวข้อ iot/esp32/control...\033[0m")

def on_message(c, userdata, msg):
    payload = msg.payload.decode('utf-8')
    now = time.strftime('%H:%M:%S')
    print(f"[{now}] ได้รับคำสั่ง: {payload}")
    
    led_state = False
    if '"ON"' in payload or 'ON' in payload:
        led_state = True
        print(f"  \033[92m-> เปิดไฟ LED (GPIO 2 = HIGH) และส่ง ACK ยืนยันสำเร็จ\033[0m")
    else:
        print(f"  \033[91m-> ปิดไฟ LED (GPIO 2 = LOW) และส่ง ACK ยืนยันสำเร็จ\033[0m")

    ack_json = json.dumps({"led_state": led_state, "ack": True})
    client.publish("iot/esp32/led_ack", ack_json, qos=1)

def telemetry_worker():
    t = 0
    while running:
        voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
        raw = int((voltage / 3.3) * 4095)
        telemetry_payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
        client.publish("iot/esp32/telemetry", telemetry_payload, qos=0)
        t += 1
        time.sleep(0.5)

client.on_connect = on_connect
client.on_message = on_message

try:
    print("\033[96m==========================================================\033[0m")
    print("\033[96m    [MOCK ESP32] สคริปต์จำลองพฤติกรรมบอร์ด ESP32 ครบวงจร   \033[0m")
    print("\033[96m==========================================================\033[0m")
    
    # กำหนด Last Will and Testament
    client.will_set("iot/esp32/status", "offline", qos=1, retain=True)
    client.connect(BROKER, PORT, keepalive=20)
    
    print("\033[93m[2/3] เริ่มสตรีมข้อมูล Telemetry จำลอง Sine Wave (ทุก 500 ms)...\033[0m")
    t_thread = threading.Thread(target=telemetry_worker, daemon=True)
    t_thread.start()
    
    client.loop_forever()

except KeyboardInterrupt:
    print("\n\033[93m[STOP] หยุดการจำลอง: กำลังส่งสถานะ OFFLINE ไปยัง iot/esp32/status...\033[0m")
    running = False
    client.publish("iot/esp32/status", "offline", qos=1, retain=True)
    time.sleep(0.5)
    client.disconnect()
    print("\033[91mจำลองบอร์ดดับ/ตัดการเชื่อมต่อเรียบร้อยแล้ว!\033[0m")
    sys.exit(0)
