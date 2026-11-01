$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path $PSScriptRoot).Path
$labRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$repositoryRoot = (Resolve-Path (Join-Path $projectRoot '..\..\..')).Path
$mosquittoDirectory = Join-Path $env:ProgramFiles 'mosquitto'
$mosquitto = Join-Path $mosquittoDirectory 'mosquitto.exe'
$mosquittoPub = Join-Path $mosquittoDirectory 'mosquitto_pub.exe'
$brokerConfig = Join-Path $repositoryRoot 'mosquitto.conf'
$mockScript = Join-Path $labRoot 'mock_esp32.ps1'

if (-not (Test-Path -LiteralPath $mosquitto)) {
    throw "Mosquitto was not found at '$mosquitto'. Install Mosquitto before running this test."
}
if (-not (Test-Path -LiteralPath $mosquittoPub)) {
    throw "mosquitto_pub was not found at '$mosquittoPub'. Install the Mosquitto command-line tools."
}
if (-not (Test-Path -LiteralPath $brokerConfig)) {
    throw "Broker configuration was not found at '$brokerConfig'."
}
if (-not (Test-Path -LiteralPath $mockScript)) {
    throw "ESP32 simulator was not found at '$mockScript'."
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutter = $flutterCommand.Source
} elseif (Test-Path -LiteralPath 'C:\src\flutter\bin\flutter.bat') {
    $flutter = 'C:\src\flutter\bin\flutter.bat'
} else {
    throw 'Flutter was not found. Add Flutter to PATH and run this script again.'
}

$androidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
$adb = if ($androidSdk) { Join-Path $androidSdk 'platform-tools\adb.exe' } else { $null }
if (-not $adb -or -not (Test-Path -LiteralPath $adb)) {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) {
        $adb = $adbCommand.Source
    } else {
        throw 'Android adb was not found. Install Android SDK platform-tools and set ANDROID_HOME.'
    }
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
$mockJob = $null
$mappedDrive = $null
$originalLocation = Get-Location

try {
    $deviceList = & $adb devices
    if ($LASTEXITCODE -ne 0 -or ($deviceList -join "`n") -notmatch 'emulator-5554\s+device') {
        throw 'Android emulator emulator-5554 is not ready. Start the emulator, then run this script again.'
    }

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

    $mockJob = Start-Job -FilePath $mockScript -ArgumentList '127.0.0.1', 1883
    $mockReady = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if ($mockJob.State -in @('Failed', 'Stopped', 'Completed')) {
            $jobOutput = Receive-Job -Job $mockJob -Keep
            throw "ESP32 simulator did not start: $($jobOutput -join [Environment]::NewLine)"
        }
        $jobOutput = Receive-Job -Job $mockJob -Keep
        if ($jobOutput -contains '__MOCK_ESP32_READY__') {
            $mockReady = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $mockReady) {
        throw 'ESP32 simulator did not become ready.'
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

    Write-Host 'ESP32 mock and MQTT broker are ready. Launching Lab 12-4 on emulator-5554.'
    Write-Host 'Test telemetry, switch tabs, toggle the LED, then press Ctrl+C to stop.'
    & $flutter run -d emulator-5554
    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed with exit code $LASTEXITCODE."
    }
} finally {
    if ($mockJob) {
        if (Test-MqttBroker) {
            & $mosquittoPub -h 127.0.0.1 -p 1883 -t 'iot/esp32/status' -m 'offline' -r
        }
        Stop-Job -Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job -Job $mockJob -Force -ErrorAction SilentlyContinue
    }
    if ($brokerProcess -and -not $brokerProcess.HasExited) {
        Stop-Process -Id $brokerProcess.Id
    }
    if ($mappedDrive) {
        Set-Location $originalLocation
        & subst $mappedDrive /d
    }
}
