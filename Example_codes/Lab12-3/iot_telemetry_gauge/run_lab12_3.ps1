$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path $PSScriptRoot).Path
$repositoryRoot = (Resolve-Path (Join-Path $projectRoot '..\..\..')).Path
$mosquittoDirectory = Join-Path $env:ProgramFiles 'mosquitto'
$mosquitto = Join-Path $mosquittoDirectory 'mosquitto.exe'
$mosquittoPub = Join-Path $mosquittoDirectory 'mosquitto_pub.exe'
$brokerConfig = Join-Path $repositoryRoot 'mosquitto.conf'

if (-not (Test-Path -LiteralPath $mosquitto)) {
    throw "Mosquitto was not found at '$mosquitto'. Install Mosquitto before running this test."
}
if (-not (Test-Path -LiteralPath $mosquittoPub)) {
    throw "mosquitto_pub was not found at '$mosquittoPub'. Install the Mosquitto command-line tools."
}
if (-not (Test-Path -LiteralPath $brokerConfig)) {
    throw "Broker configuration was not found at '$brokerConfig'."
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutter = $flutterCommand.Source
} elseif (Test-Path -LiteralPath 'C:\src\flutter\bin\flutter.bat') {
    $flutter = 'C:\src\flutter\bin\flutter.bat'
} else {
    throw 'Flutter was not found. Add Flutter to PATH and run this script again.'
}

function Test-MqttBroker {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $client.BeginConnect('127.0.0.1', 1883, $null, $null)
        if (-not $connect.AsyncWaitHandle.WaitOne(1000)) {
            return $false
        }
        $client.EndConnect($connect)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

$brokerProcess = $null
$telemetryJob = $null
$mappedDrive = $null
$originalLocation = Get-Location

try {
    if (-not (Test-MqttBroker)) {
        Write-Host 'Starting Mosquitto broker...'
        $arguments = "-c `"$brokerConfig`" -v"
        $brokerProcess = Start-Process -FilePath $mosquitto -ArgumentList $arguments -WorkingDirectory $repositoryRoot -WindowStyle Hidden -PassThru

        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            if (Test-MqttBroker) {
                break
            }
            if ($brokerProcess.HasExited) {
                throw "Mosquitto exited with code $($brokerProcess.ExitCode)."
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not (Test-MqttBroker)) {
            throw 'Mosquitto did not start listening on port 1883.'
        }
    } else {
        Write-Host 'Using the MQTT broker already listening on port 1883.'
    }

    $telemetryJob = Start-Job -ArgumentList $mosquittoPub -ScriptBlock {
        param($publisher)
        $time = 0
        while ($true) {
            $voltage = [Math]::Round(1.65 + 1.5 * [Math]::Sin($time * 0.2), 2)
            $raw = [int](($voltage / 3.3) * 4095)
            $payload = "{`"voltage`": $voltage, `"raw`": $raw, `"uptime`": $time}"
            $argumentPayload = $payload.Replace('"', '\"')
            & $publisher -h 127.0.0.1 -p 1883 -t 'iot/esp32/telemetry' -m $argumentPayload
            if ($LASTEXITCODE -ne 0) {
                throw 'mosquitto_pub failed while publishing telemetry.'
            }
            $time++
            Start-Sleep -Milliseconds 500
        }
    }

    $driveLetter = 'Z'
    while (Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue) {
        if ($driveLetter -eq 'D') {
            throw 'No free drive letter is available for a short project path.'
        }
        $driveLetter = [char]([int][char]$driveLetter - 1)
    }

    $mappedDrive = "${driveLetter}:"
    & subst $mappedDrive $projectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Could not map the project to drive $mappedDrive."
    }

    Set-Location "$mappedDrive\"
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE."
    }

    Write-Host 'Publishing simulated telemetry and launching the app on emulator-5554.'
    Write-Host 'Press Ctrl+C to stop the app and simulation.'
    & $flutter run -d emulator-5554
    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed with exit code $LASTEXITCODE."
    }
} finally {
    if ($telemetryJob) {
        Stop-Job -Job $telemetryJob -ErrorAction SilentlyContinue
        Remove-Job -Job $telemetryJob -Force -ErrorAction SilentlyContinue
    }
    if ($brokerProcess -and -not $brokerProcess.HasExited) {
        Stop-Process -Id $brokerProcess.Id
    }
    if ($mappedDrive) {
        Set-Location $originalLocation
        & subst $mappedDrive /d
    }
}
