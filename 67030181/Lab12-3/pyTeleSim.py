import paho.mqtt.client as mqtt
import time
import json
import math

# กำหนด Client ID สำหรับนักศึกษา 67030281
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "PyTelemetrySim_67030281")

# เชื่อมต่อไปยัง Local Mosquitto Broker (พอร์ต 1883)
broker_ip = "127.0.0.1"
broker_port = 1883

print(f"กำลังเชื่อมต่อไปยัง Broker: {broker_ip}:{broker_port}...")
client.connect(broker_ip, broker_port)

t = 0
print("เริ่มการจำลองส่งข้อมูลเซนเซอร์ Telemetry (Topic: iot/esp32/telemetry) ทุก 500 ms...")
print("กด Ctrl+C เพื่อหยุดการทำงาน\n")

try:
    while True:
        # สร้างสัญญาณรูปคลื่นไซน์ (Sine Wave) จำลองแรงดันไฟฟ้า 0.15V ถึง 3.15V (0 - 3.3V)
        voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
        raw = int((voltage / 3.3) * 4095)
        payload = json.dumps({
            "voltage": voltage,
            "raw": raw,
            "uptime": t
        })
        
        client.publish("iot/esp32/telemetry", payload)
        print(f"[{time.strftime('%H:%M:%S')}] Published: {payload}")
        t += 1
        time.sleep(0.5)
except KeyboardInterrupt:
    print("\n[STOP] หยุดการส่งข้อมูลจำลองเรียบร้อยแล้ว")
    client.disconnect()

