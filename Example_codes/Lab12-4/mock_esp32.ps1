param (
    [string]$Broker = "127.0.0.1",
    [int]$Port = 1883
)

$mosquittoPaths = @(
    "C:\Program Files\mosquitto",
    "C:\Program Files (x86)\mosquitto"
)
foreach ($p in $mosquittoPaths) {
    if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
        $env:PATH = "$p;$env:PATH"
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       [MOCK ESP32] Full Hardware Simulator               " -ForegroundColor Cyan
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
    Write-Host "Please start Mosquitto first: run start_broker.bat" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/3] Sending ONLINE status to iot/esp32/status (Retain)..." -ForegroundColor Green
mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "online" -r

$job = Start-Job -ScriptBlock {
    param($b, $p)
    $mosquittoPaths = @(
        "C:\Program Files\mosquitto",
        "C:\Program Files (x86)\mosquitto"
    )
    foreach ($path in $mosquittoPaths) {
        if ((Test-Path $path) -and ($env:PATH -notlike "*$path*")) {
            $env:PATH = "$path;$env:PATH"
        }
    }

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

Write-Host "[2/3] Streaming Telemetry Sine Wave every 500ms..." -ForegroundColor Yellow
Write-Host "[3/3] Listening for commands on iot/esp32/control..." -ForegroundColor Magenta
Write-Host "      (Toggle switch on Flutter to test | Press Ctrl+C to stop and trigger OFFLINE)" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

try {
    & mosquitto_sub -h $Broker -p $Port -t "iot/esp32/control" | ForEach-Object {
        $cmd = $_
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Received Command: $cmd" -ForegroundColor White
        
        $ledState = $false
        if ($cmd -match '"ON"' -or $cmd -match 'ON') {
            $ledState = $true
            Write-Host "  -> LED: ON (GPIO 2 = HIGH) | Sent ACK" -ForegroundColor Green
        } else {
            Write-Host "  -> LED: OFF (GPIO 2 = LOW) | Sent ACK" -ForegroundColor Red
        }

        $ackJson = "{`"led_state`": $(if($ledState){'true'}else{'false'}), `"ack`": true}"
        mosquitto_pub -h $Broker -p $Port -t "iot/esp32/led_ack" -m $ackJson
    }
}
finally {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    Write-Host "`n[STOP] Stopping simulation: Sending OFFLINE to iot/esp32/status..." -ForegroundColor Yellow
    mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "offline" -r
    Write-Host "ESP32 Offline simulation complete!" -ForegroundColor Red
}
