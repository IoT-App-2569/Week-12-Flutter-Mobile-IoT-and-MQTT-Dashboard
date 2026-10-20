import paho.mqtt.client as mqtt
import time
import json
import math

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "PyTelemetrySim")
client.connect("127.0.0.1", 1883)
# ให้ paho ทำ Network Loop (PINGREQ/ACK) ใน Thread แยก
client.loop_start()

start = time.monotonic()
t = 0
try:
    while True:
        # สร้างคลื่น Sine จำลองแรงดัน 0.0 ถึง 3.3V
        voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
        raw = int((voltage / 3.3) * 4095)
        # uptime เป็นวินาทีจริง (เดิมใช้ t ซึ่งเพิ่มทุก 0.5 วินาที จึงเร็วกว่าเวลาจริง 2 เท่า)
        uptime = int(time.monotonic() - start)
        payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": uptime})

        client.publish("iot/esp32/telemetry", payload)
        print(f"Published: {payload}")
        t += 1
        time.sleep(0.5)
except KeyboardInterrupt:
    print("Stopped")
finally:
    client.loop_stop()
    client.disconnect()
