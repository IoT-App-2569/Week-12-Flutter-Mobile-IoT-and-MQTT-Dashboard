#!/bin/bash
# mock_esp32.sh - จำลองบอร์ด ESP32 ของใบงาน 12.4 บน macOS/Linux (เทียบเท่า mock_esp32.ps1)
# Usage: ./mock_esp32.sh [-b BROKER] [-p PORT]
BROKER=127.0.0.1
PORT=1883
while getopts "b:p:" opt; do
    case $opt in
        b) BROKER=$OPTARG ;;
        p) PORT=$OPTARG ;;
        *) echo "usage: $0 [-b broker] [-p port]"; exit 2 ;;
    esac
done

STATUS=iot/esp32/status
CONTROL=iot/esp32/control
ACK=iot/esp32/led_ack
TELEMETRY=iot/esp32/telemetry

echo "=========================================================="
echo "  [MOCK ESP32] ESP32 behaviour simulator (broker ${BROKER}:${PORT})"
echo "=========================================================="

# 0. ตรวจว่า Broker เปิดอยู่ก่อนเริ่ม
if ! nc -z -G 1 "$BROKER" "$PORT" 2>/dev/null; then
    echo "[ERROR] cannot reach MQTT broker at ${BROKER}:${PORT}"
    echo "Start the broker first:  mosquitto -c mosquitto.conf -v"
    exit 1
fi

TELEMETRY_PID=
SUB_PID=
cleanup() {
    trap - INT TERM EXIT
    [ -n "$TELEMETRY_PID" ] && kill "$TELEMETRY_PID" 2>/dev/null
    [ -n "$SUB_PID" ] && kill "$SUB_PID" 2>/dev/null
    echo
    echo "[STOP] publishing OFFLINE to ${STATUS} (retained)"
    mosquitto_pub -h "$BROKER" -p "$PORT" -t "$STATUS" -m offline -r -q 1
    exit 0
}
trap cleanup INT TERM EXIT

# 1. ส่ง online แบบ Retain เหมือนบอร์ดบูตเสร็จ
echo "[1/3] publish ONLINE to ${STATUS} (retained)"
mosquitto_pub -h "$BROKER" -p "$PORT" -t "$STATUS" -m online -r -q 1

# 2. ส่ง Telemetry คลื่น Sine ทุก 500 ms เบื้องหลัง
(
    start=$(date +%s)
    t=0
    while true; do
        v=$(awk -v t=$t 'BEGIN { printf "%.2f", 1.65 + 1.5 * sin(t * 0.2) }')
        raw=$(awk -v v=$v 'BEGIN { printf "%d", (v / 3.3) * 4095 }')
        up=$(( $(date +%s) - start ))
        mosquitto_pub -h "$BROKER" -p "$PORT" -t "$TELEMETRY" -m "{\"voltage\": $v, \"raw\": $raw, \"uptime\": $up}"
        t=$((t + 1))
        sleep 0.5
    done
) &
TELEMETRY_PID=$!
echo "[2/3] streaming sine-wave telemetry to ${TELEMETRY} every 500 ms"

# 3. รอคำสั่งจากแอป แล้วตอบ ACK ทันที
#    Subscriber ตัวนี้ตั้ง LWT ไว้ด้วย: ถ้าโปรเซสถูก kill -9 จน cleanup ไม่ทำงาน Broker จะส่ง offline ให้แทน
echo "[3/3] waiting for commands on ${CONTROL} (Ctrl+C = power off)"
echo "----------------------------------------------------------"
exec 3< <(mosquitto_sub -h "$BROKER" -p "$PORT" -t "$CONTROL" -q 1 -k 10 \
    --will-topic "$STATUS" --will-payload offline --will-retain --will-qos 1)
SUB_PID=$!
while IFS= read -r cmd <&3; do
    echo "[$(date +%H:%M:%S)] command: $cmd"
    if [[ $cmd =~ \"led\"[[:space:]]*:[[:space:]]*\"[Oo][Nn]\" ]]; then
        led=true
        echo "  -> LED ON  (GPIO 2 = HIGH), ACK sent"
    elif [[ $cmd =~ \"led\"[[:space:]]*:[[:space:]]*\"[Oo][Ff][Ff]\" ]]; then
        led=false
        echo "  -> LED OFF (GPIO 2 = LOW), ACK sent"
    else
        echo "  -> unknown command, ignored"
        continue
    fi
    mosquitto_pub -h "$BROKER" -p "$PORT" -t "$ACK" -m "{\"led_state\": $led, \"ack\": true}" -q 1
done
