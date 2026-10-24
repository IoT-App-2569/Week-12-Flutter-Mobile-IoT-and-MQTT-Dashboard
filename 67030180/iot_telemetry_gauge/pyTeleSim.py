import paho.mqtt.client as mqtt
import time
import json
import math

# สร้าง MQTT Client กำหนดเวอร์ชัน Callback API ให้ถูกต้อง
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="PyTelemetrySim")
client.connect("127.0.0.1", 1883)

t = 0
while True:
    # คำนวณคลื่น Sine จำลองแรงดัน 0.0 ถึง 3.3V
    voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
    raw = int((voltage / 3.3) * 4095)
    payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
    
    # ส่งข้อมูลไปยัง Topic iot/esp32/telemetry
    client.publish("iot/esp32/telemetry", payload)
    print(f"Published: {payload}")
    
    t += 1
    time.sleep(0.5)