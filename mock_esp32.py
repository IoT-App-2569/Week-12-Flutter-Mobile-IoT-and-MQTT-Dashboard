import subprocess
import time
import json
import math
import threading
import sys
import os
import socket

PUB_EXE = r"C:\Program Files\mosquitto\mosquitto_pub.exe"
SUB_EXE = r"C:\Program Files\mosquitto\mosquitto_sub.exe"
BROKER = "127.0.0.1"
PORT = "1883"

if not os.path.exists(PUB_EXE):
    PUB_EXE = "mosquitto_pub"
    SUB_EXE = "mosquitto_sub"

def check_port(host, port):
    try:
        s = socket.create_connection((host, int(port)), timeout=1)
        s.close()
        return True
    except:
        return False

def pub(topic, message, retain=False):
    cmd = [PUB_EXE, "-h", BROKER, "-p", PORT, "-t", topic, "-m", message]
    if retain:
        cmd.append("-r")
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=2)
    except:
        pass

print("=" * 60)
print(f"       [MOCK ESP32] Hardware Simulator (Port: {PORT})")
print("=" * 60)

# Check broker
if not check_port(BROKER, 1883):
    print("[Warning] Port 1883 not reachable yet. Will keep retrying...")

running = True

# 1. Telemetry loop (runs forever in background thread)
def telemetry_loop():
    t = 0
    while running:
        try:
            # Send online status every 2 seconds
            if t % 2 == 0:
                pub("iot/esp32/status", "online", retain=True)

            v = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
            raw = int((v / 3.3) * 4095)
            payload = json.dumps({"voltage": v, "raw": raw, "uptime": t})
            pub("iot/esp32/telemetry", payload)
            print(f"[Telemetry] Uptime: {t:3d}s | Voltage: {v:.2f} V | Raw ADC: {raw:4d} | Status: ONLINE")
            t += 1
        except Exception as e:
            print(f"[Telemetry Error] {e}")
        time.sleep(0.5)

t_thread = threading.Thread(target=telemetry_loop, daemon=True)
t_thread.start()

print("[1] Telemetry Stream: ACTIVE (Sine Wave 0.15V - 3.15V every 500ms)")
print("[2] Status Topic: PUBLISHING 'online' to iot/esp32/status")
print("[3] Command Listener: WAITING for switch events on iot/esp32/control...")
print("-" * 60)

# 2. Command listener with auto-reconnect
while running:
    try:
        sub_cmd = [SUB_EXE, "-h", BROKER, "-p", PORT, "-t", "iot/esp32/control"]
        sub_proc = subprocess.Popen(
            sub_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )

        for line in sub_proc.stdout:
            if not running:
                break
            cmd = line.strip()
            if not cmd:
                continue
            print(f"\n>>> [Command Received from Flutter] -> {cmd}")
            is_on = "ON" in cmd.upper() or "TRUE" in cmd.upper()
            ack = json.dumps({"led_state": is_on, "ack": True})
            pub("iot/esp32/led_ack", ack)
            print(f"    Physical LED: {'[ ON  - GPIO 2 HIGH ]' if is_on else '[ OFF - GPIO 2 LOW  ]'}")
            print(f"    Sent ACK -> iot/esp32/led_ack: {ack}\n")

    except KeyboardInterrupt:
        print("\nStopping simulation by user...")
        running = False
        break
    except Exception as e:
        time.sleep(1)

# Cleanup
running = False
print("[STOP] Sending 'offline' to iot/esp32/status...")
pub("iot/esp32/status", "offline", retain=True)
print("Simulation finished.")
