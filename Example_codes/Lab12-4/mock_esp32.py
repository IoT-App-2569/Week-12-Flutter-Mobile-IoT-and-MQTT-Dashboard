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

# Detect if mosquitto is in Program Files or in PATH
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

# Check which port is open: 1883 (TCP) or 9001 (WebSockets)
USE_WS = False
if check_port(BROKER, 1883):
    PORT = "1883"
elif check_port(BROKER, 9001):
    PORT = "9001"
    USE_WS = True
    print("[Notice] Port 1883 not responding, using WebSocket port 9001...")
else:
    PORT = "1883"
    print("[Warning] Neither port 1883 nor 9001 responded. Please ensure Mosquitto Broker is running (start_broker.bat)!")

def pub(topic, message, retain=False):
    cmd = [PUB_EXE, "-h", BROKER, "-p", PORT]
    if USE_WS:
        cmd.append("--ws")
    cmd += ["-t", topic, "-m", message]
    if retain:
        cmd.append("-r")
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
        if res.returncode != 0:
            print(f"[Publish Error on {PORT}] {res.stderr.strip()}")
    except Exception as e:
        print(f"[Error publishing] {e}")

print("=" * 60)
print(f"       [MOCK ESP32] Hardware Simulator (Port: {PORT}{' WebSockets' if USE_WS else ''})")
print("=" * 60)

# 1. Send Online status
print("[1/3] Sending ONLINE status to iot/esp32/status (Retain)...")
pub("iot/esp32/status", "online", retain=True)

# 2. Telemetry thread (Sine wave)
running = True
def telemetry_loop():
    t = 0
    while running:
        v = round(1.65 + 1.5 * math.sin(t * 0.2), 2)
        raw = int((v / 3.3) * 4095)
        payload = json.dumps({"voltage": v, "raw": raw, "uptime": t})
        pub("iot/esp32/telemetry", payload)
        print(f"[Telemetry] Uptime: {t}s | Voltage: {v:.2f} V | Raw ADC: {raw}")
        t += 1
        time.sleep(0.5)

t_thread = threading.Thread(target=telemetry_loop, daemon=True)
t_thread.start()
print("[2/3] Streaming Telemetry Sine Wave every 500ms...")
print("[3/3] Listening for commands on iot/esp32/control...")
print("      (Toggle switch on Flutter to test | Press Ctrl+C to stop and trigger OFFLINE)")
print("-" * 60)

# 3. Listen to commands
sub_cmd = [SUB_EXE, "-h", BROKER, "-p", PORT]
if USE_WS:
    sub_cmd.append("--ws")
sub_cmd += ["-t", "iot/esp32/control"]

try:
    sub_proc = subprocess.Popen(
        sub_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )

    for line in sub_proc.stdout:
        cmd = line.strip()
        if not cmd:
            continue
        print(f"\n[Command Received] -> {cmd}")
        is_on = "ON" in cmd.upper()
        ack = json.dumps({"led_state": is_on, "ack": True})
        pub("iot/esp32/led_ack", ack)
        print(f"  -> Physical LED is now: {'ON (GPIO 2 HIGH)' if is_on else 'OFF (GPIO 2 LOW)'}")
        print(f"  -> Sent ACK to iot/esp32/led_ack: {ack}\n")
except KeyboardInterrupt:
    pass
except Exception as e:
    print(f"[Error listening] {e}")
finally:
    running = False
    try:
        sub_proc.terminate()
    except:
        pass
    print("\n[STOP] Stopping simulation: Sending OFFLINE to iot/esp32/status...")
    pub("iot/esp32/status", "offline", retain=True)
    print("ESP32 Offline simulation complete!")
