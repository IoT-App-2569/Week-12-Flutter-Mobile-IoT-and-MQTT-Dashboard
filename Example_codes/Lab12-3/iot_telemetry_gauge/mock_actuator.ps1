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
Write-Host "    [MOCK ESP32] Actuator Switch Simulator (Lab 12-2)     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($Broker, $Port, $null, $null)
    $success = $connect.AsyncWaitHandle.WaitOne(1000)
    if (-not ($success -and $tcpClient.Connected)) {
        Write-Host "`n[ERROR] Cannot connect to Broker ${Broker}:${Port}!" -ForegroundColor Red
        Write-Host "Please start Mosquitto first: run start_broker.bat" -ForegroundColor Yellow
        exit 1
    }
    $tcpClient.EndConnect($connect)
    $tcpClient.Close()
} catch {
    Write-Host "`n[ERROR] Cannot connect to Broker: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[1/2] Sending ONLINE status to iot/esp32/status (Retain)..." -ForegroundColor Green
mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "online" -r

Write-Host "[2/2] Waiting for control commands on iot/esp32/control..." -ForegroundColor Magenta
Write-Host "      (Tap switch on Flutter to test | Press Ctrl+C to disconnect and send OFFLINE)" -ForegroundColor Gray

try {
    & mosquitto_sub -h $Broker -p $Port -t "iot/esp32/control" | ForEach-Object {
        $cmd = $_
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Command received: $cmd" -ForegroundColor White
        $ledState = $false
        if ($cmd -match '"ON"' -or $cmd -match 'ON') {
            $ledState = $true
            Write-Host "  -> LED: ON | Sent ACK" -ForegroundColor Green
        } else {
            Write-Host "  -> LED: OFF | Sent ACK" -ForegroundColor Red
        }
        $ack = "{`"led_state`": $(if($ledState){'true'}else{'false'}), `"ack`": true}"
        mosquitto_pub -h $Broker -p $Port -t "iot/esp32/led_ack" -m $ack
    }
} finally {
    Write-Host "`n[STOP] Sending OFFLINE status to iot/esp32/status..." -ForegroundColor Yellow
    mosquitto_pub -h $Broker -p $Port -t "iot/esp32/status" -m "offline" -r
    Write-Host "Mock ESP32 offline complete!" -ForegroundColor Red
}
