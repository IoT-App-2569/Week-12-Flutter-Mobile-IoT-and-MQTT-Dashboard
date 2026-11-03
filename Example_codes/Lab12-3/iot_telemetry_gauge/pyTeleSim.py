<<<<<<< HEAD
import paho.mqtt.client as mqtt
import time
import json
import math

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "PyTelemetrySim")
client.connect("127.0.0.1", 1883)

t = 0
while True:
    # สร้างคลื่น Sine จำลองแรงดัน 0.0 ถึง 3.3V
    voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
    raw = int((voltage / 3.3) * 4095)
    payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
    
    client.publish("iot/esp32/telemetry", payload)
    print(f"Published: {payload}")
    t += 1
=======
import paho.mqtt.client as mqtt
import time
import json
import math

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "PyTelemetrySim")
client.connect("127.0.0.1", 1883)

t = 0
while True:
    # สร้างคลื่น Sine จำลองแรงดัน 0.0 ถึง 3.3V
    voltage = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
    raw = int((voltage / 3.3) * 4095)
    payload = json.dumps({"voltage": voltage, "raw": raw, "uptime": t})
    
    client.publish("iot/esp32/telemetry", payload)
    print(f"Published: {payload}")
    t += 1
>>>>>>> ecaf15c033ba2b7e4c00cf4e7402a9b7fe88594a
    time.sleep(0.5)