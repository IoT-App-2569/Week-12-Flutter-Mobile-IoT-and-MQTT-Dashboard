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
Write-Host "    [MOCK ESP32] Telemetry Gauge Simulator (Lab 12-3)     " -ForegroundColor Cyan
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

Write-Host "Streaming simulated Sine Wave to iot/esp32/telemetry every 500ms..." -ForegroundColor Yellow
Write-Host "(Press Ctrl+C to stop)" -ForegroundColor Gray

$t = 0
try {
    while ($true) {
        $v = [Math]::Round(1.65 + 1.5 * [Math]::Sin($t * 0.2), 2)
        $raw = [int](($v / 3.3) * 4095)
        $payload = "{`"voltage`": $v, `"raw`": $raw, `"uptime`": $t}"
        mosquitto_pub -h $Broker -p $Port -t "iot/esp32/telemetry" -m $payload
        Write-Host "[Uptime: ${t}s] Voltage: ${v} V | Raw ADC: ${raw}" -ForegroundColor Cyan
        $t++
        Start-Sleep -Milliseconds 500
    }
} finally {
    Write-Host "`nTelemetry streaming stopped." -ForegroundColor Yellow
}
