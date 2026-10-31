#!/bin/bash
# จำลองส่งคลื่น Sine ของแรงดัน 0.0 - 3.3V ไปที่ iot/esp32/telemetry (ใช้แทน pyTeleSim.py)
# กด Ctrl+C เพื่อหยุด
t=0
while true; do
  voltage=$(awk -v t="$t" 'BEGIN { printf "%.2f", 1.65 + 1.5 * sin(t * 0.2) }')
  raw=$(awk -v v="$voltage" 'BEGIN { printf "%d", (v / 3.3) * 4095 }')
  payload="{\"voltage\": $voltage, \"raw\": $raw, \"uptime\": $t}"

  mosquitto_pub -h 127.0.0.1 -p 1883 -t "iot/esp32/telemetry" -m "$payload"
  echo "Published: $payload"
  t=$((t + 1))
  sleep 0.5
done
