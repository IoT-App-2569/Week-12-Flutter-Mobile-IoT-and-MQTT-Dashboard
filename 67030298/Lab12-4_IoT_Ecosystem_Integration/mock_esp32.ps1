# mock_esp32.ps1 - ESP32 Hardware Simulator
param (
    [string]$Broker = "127.0.0.1",
    [int]$Port = 1883
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    [MOCK ESP32] Hardware Simulation Started             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Test-BrokerConnection {
    param([string]$Server, [int]$TargetPort)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($Server, $TargetPort, $null, $null)
        $success = $connect.AsyncWaitHandle.WaitOne(1000)
        if ($success -and $tcpClient.Connected) {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
        return $false
    } catch {
        return $false
    }
}

if (-not (Test-BrokerConnection -Server $Broker -TargetPort $Port)) {
    Write-Host "`n[ERROR] Cannot connect to MQTT Broker at ${Broker}:${Port}!" -ForegroundColor Red
    Write-Host "Mosquitto Broker is not running. Start it with: mosquitto -c mosquitto.conf -v" -ForegroundColor Yellow
    exit 1
}

# 1. Send Online status (Retained)
Write-Host "[1/3] Sending status ONLINE to iot/esp32/status (Retain)..." -ForegroundColor Green
mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "online" -r

# 2. Start streaming Telemetry in background
$job = Start-Job -ScriptBlock {
    param($b, $p)
    $t = 0
    while ($true) {
        $v = [Math]::Round(1.65 + 1.5 * [Math]::Sin($t * 0.2), 2)
        $raw = [int](($v / 3.3) * 4095)
        $payload = "{`"voltage`": $v, `"raw`": $raw, `"uptime`": $t}"
        mosquitto_pub -h $b -p $p -t "iot/esp32/telemetry" -m $payload
        $t++
        Start-Sleep -Milliseconds 500
    }
} -ArgumentList $Broker, $Port

Write-Host "[2/3] Streaming Telemetry Sine Wave data every 500 ms..." -ForegroundColor Yellow
Write-Host "[3/3] Listening for commands on iot/esp32/control..." -ForegroundColor Magenta
Write-Host "      (Tap switch on Flutter to test, or press Ctrl+C to simulate OFFLINE)" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

try {
    & mosquitto_sub -h $Broker -p $Port -t "iot/esp32/control" | ForEach-Object {
        $cmd = $_
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Received Command: $cmd" -ForegroundColor White
        
        $ledState = $false
        if ($cmd -match '"ON"' -or $cmd -match 'ON') {
            $ledState = $true
            Write-Host "  -> LED ON (GPIO 2 = HIGH) | Sent ACK confirmation" -ForegroundColor Green
        } else {
            Write-Host "  -> LED OFF (GPIO 2 = LOW) | Sent ACK confirmation" -ForegroundColor Red
        }

        $ackJson = "{`"led_state`": $(if($ledState){'true'}else{'false'}), `"ack`": true}"
        mosquitto_pub -h $Broker -p $Port -t "iot/esp32/led_ack" -m $ackJson
    }
}
finally {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    Write-Host "`n[STOP] Simulation stopped: Sending OFFLINE to iot/esp32/status..." -ForegroundColor Yellow
    mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "offline" -r
    Write-Host "Simulated ESP32 OFFLINE completed!" -ForegroundColor Red
}
