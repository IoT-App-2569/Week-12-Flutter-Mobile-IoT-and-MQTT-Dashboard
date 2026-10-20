
import json
import math
import signal
import time

import paho.mqtt.client as mqtt

BROKER = "127.0.0.1"
PORT = 1883

TELEMETRY_TOPIC = "iot/esp32/telemetry"
STATUS_TOPIC = "iot/esp32/status"
CONTROL_TOPIC = "iot/esp32/control"
ACK_TOPIC = "iot/esp32/led_ack"

running = True
led_state = False
client = None


def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code.is_failure:
        print(f"[ERROR] MQTT connection failed: {reason_code}")
        return

    print("[MQTT] Connected to broker")
    client.subscribe(CONTROL_TOPIC)
    client.publish(STATUS_TOPIC, "online", retain=True)
    print("[STATUS] online")


def on_message(client, userdata, message):
    global led_state

    command = message.payload.decode("utf-8").strip()
    print(f"[CONTROL] Received: {command}")

    try:
        data = json.loads(command)
        command = data.get("command", command)
    except json.JSONDecodeError:
        pass

    command = command.upper()

    if command == "ON":
        led_state = True
    elif command == "OFF":
        led_state = False
    else:
        print("[WARN] Unknown command")
        return

    ack = {
        "led_state": led_state,
        "ack": True
    }

    client.publish(ACK_TOPIC, json.dumps(ack))
    print(f"[LED] {'ON' if led_state else 'OFF'}")
    print(f"[ACK] {json.dumps(ack)}")


def stop_simulator(signum=None, frame=None):
    global running
    running = False


def main():
    global client

    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id="mock-esp32-unified-dashboard"
    )

    # LWT: broker publishes offline if the simulator disconnects unexpectedly.
    client.will_set(STATUS_TOPIC, "offline", qos=1, retain=True)

    client.on_connect = on_connect
    client.on_message = on_message

    signal.signal(signal.SIGINT, stop_simulator)
    signal.signal(signal.SIGTERM, stop_simulator)

    print("=== MOCK ESP32 - Lab 12-4 ===")
    print(f"[MQTT] Connecting to {BROKER}:{PORT} ...")

    try:
        client.connect(BROKER, PORT, keepalive=30)
        client.loop_start()

        # Wait until MQTT connection is established.
        deadline = time.time() + 10
        while not client.is_connected() and time.time() < deadline:
            time.sleep(0.1)

        if not client.is_connected():
            raise ConnectionError("Could not connect to MQTT broker")

        print("[TELEMETRY] Streaming every 500 ms")
        print("[CONTROL] Waiting for ON/OFF commands; Ctrl+C to stop")

        uptime = 0
        while running:
            voltage = round(1.65 + 1.5 * math.sin(uptime * 0.2), 2)
            raw = round((voltage / 3.3) * 4095)

            payload = {
                "voltage": voltage,
                "raw": raw,
                "uptime": uptime
            }

            client.publish(TELEMETRY_TOPIC, json.dumps(payload))
            print(f"[TELEMETRY] {json.dumps(payload)}")

            uptime += 1
            # About 500 ms between samples
            for _ in range(5):
                if not running:
                    break
                time.sleep(0.1)

    except Exception as error:
        print(f"[ERROR] {error}")

    finally:
        if client is not None:
            if client.is_connected():
                client.publish(
                    STATUS_TOPIC, "offline", qos=1, retain=True
                ).wait_for_publish(timeout=3)

            client.disconnect()
            client.loop_stop()

        print("[STATUS] offline")
        print("[STOP] Simulator stopped")


if __name__ == "__main__":
    main()
