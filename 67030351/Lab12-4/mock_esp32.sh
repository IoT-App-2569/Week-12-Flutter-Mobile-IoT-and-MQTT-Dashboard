#!/usr/bin/env bash
# mock_esp32.sh - สคริปต์จำลองการทำงานของบอร์ด ESP32 บน macOS / Linux
# ใช้งาน: ./mock_esp32.sh [BROKER] [PORT]
#   ตัวอย่าง: ./mock_esp32.sh                 (ค่าเริ่มต้น 127.0.0.1 1883)
#             ./mock_esp32.sh 192.168.1.105

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

BROKER="${1:-127.0.0.1}"
PORT="${2:-1883}"

# สี ANSI
CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
MAGENTA='\033[0;35m'; GRAY='\033[0;37m'; DGRAY='\033[1;30m'; WHITE='\033[1;37m'; NC='\033[0m'

echo -e "${CYAN}==========================================================${NC}"
echo -e "${CYAN}    [MOCK ESP32] สคริปต์จำลองพฤติกรรมบอร์ด ESP32 ครบวงจร   ${NC}"
echo -e "${CYAN}==========================================================${NC}"

# ตรวจสอบการเชื่อมต่อกับ Broker ก่อนเริ่มทำงาน (timeout 1 วินาที)
if ! nc -z -G 1 "$BROKER" "$PORT" >/dev/null 2>&1 && ! nc -z -w 1 "$BROKER" "$PORT" >/dev/null 2>&1; then
  echo -e "\n${RED}[ERROR] ไม่สามารถเชื่อมต่อไปยัง MQTT Broker ที่ ${BROKER}:${PORT} ได้!${NC}"
  echo -e "${YELLOW}สาเหตุ: ยังไม่ได้สตาร์ต Mosquitto Broker หรือระบุ IP / Port ไม่ถูกต้อง\n${NC}"
  echo -e "${WHITE}วิธีแก้ไข:${NC}"
  echo -e "${CYAN}  1. เปิด Terminal หน้าต่างใหม่ (ที่รูทโฟลเดอร์ของสัปดาห์ที่ 12)${NC}"
  echo -e "${CYAN}  2. สั่งสตาร์ต Mosquitto Broker ด้วยคำสั่ง:${NC}"
  echo -e "${GREEN}     mosquitto -c mosquitto.conf -v${NC}"
  echo -e "${DGRAY}     (หรือ: mosquitto -v)${NC}"
  echo -e "${CYAN}  3. จากนั้นจึงสั่งรันสคริปต์นี้ใหม่อีกครั้ง\n${NC}"
  exit 1
fi

# 1. ส่งสถานะ Online เสมือนบอร์ดบูตเสร็จและเชื่อมต่อสำเร็จ
echo -e "${GREEN}[1/3] ส่งสถานะ ONLINE ไปยัง iot/esp32/status (Retain)...${NC}"
mosquitto_pub -h "$BROKER" -p "$PORT" -t "iot/esp32/status" -m "online" -r

# 2. เริ่มส่ง Telemetry จำลองเซนเซอร์ใน Background
(
  t=0
  while true; do
    v=$(awk -v t=$t 'BEGIN{printf "%.2f", 1.65 + 1.5*sin(t*0.2)}')
    raw=$(awk -v v=$v 'BEGIN{printf "%.0f", (v/3.3)*4095}')
    payload="{\"voltage\": $v, \"raw\": $raw, \"uptime\": $t}"
    mosquitto_pub -h "$BROKER" -p "$PORT" -t "iot/esp32/telemetry" -m "$payload"
    t=$((t + 1))
    sleep 0.5
  done
) &
TELEMETRY_PID=$!

# เมื่อกด Ctrl+C ให้หยุด Telemetry และส่งสถานะ OFFLINE เสมือนบอร์ดดับ
cleanup() {
  trap - INT TERM EXIT
  kill "$TELEMETRY_PID" 2>/dev/null
  wait "$TELEMETRY_PID" 2>/dev/null
  echo -e "\n${YELLOW}[STOP] หยุดการจำลอง: ส่งสถานะ OFFLINE ไปยัง iot/esp32/status...${NC}"
  mosquitto_pub -h "$BROKER" -p "$PORT" -t "iot/esp32/status" -m "offline" -r
  echo -e "${RED}จำลองบอร์ดดับ/ตัดการเชื่อมต่อเรียบร้อยแล้ว!${NC}"
  exit 0
}
trap cleanup INT TERM EXIT

echo -e "${YELLOW}[2/3] เริ่มสตรีมข้อมูล Telemetry จำลอง Sine Wave (ทุก 500 ms)...${NC}"
echo -e "${MAGENTA}[3/3] กำลังดักฟังคำสั่งจากแอป Flutter บนหัวข้อ iot/esp32/control...${NC}"
echo -e "${GRAY}      (แตะสวิตช์บน Flutter เพื่อทดสอบ หรือกด Ctrl+C เพื่อหยุดและส่งสถานะ OFFLINE)${NC}"
echo -e "${DGRAY}----------------------------------------------------------${NC}"

# 3. ดักฟังคำสั่งควบคุม LED แล้วส่ง ACK ตอบกลับทันที
mosquitto_sub -h "$BROKER" -p "$PORT" -t "iot/esp32/control" | while IFS= read -r cmd; do
  echo -e "${WHITE}[$(date +%H:%M:%S)] ได้รับคำสั่ง: $cmd${NC}"

  if [[ "$cmd" == *ON* ]]; then
    led_state=true
    echo -e "${GREEN}  -> เปิดไฟ LED (GPIO 2 = HIGH) และส่ง ACK ยืนยันสำเร็จ${NC}"
  else
    led_state=false
    echo -e "${RED}  -> ปิดไฟ LED (GPIO 2 = LOW) และส่ง ACK ยืนยันสำเร็จ${NC}"
  fi

  ack_json="{\"led_state\": $led_state, \"ack\": true}"
  mosquitto_pub -h "$BROKER" -p "$PORT" -t "iot/esp32/led_ack" -m "$ack_json"
done