# env.ps1 - add Flutter and Mosquitto to PATH for THIS PowerShell window only (no permanent change).
# Usage (note the leading dot):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#   . .\Code\env.ps1
$env:Path = "C:\src\flutter\bin;C:\Program Files\mosquitto;$env:Path"
Write-Host "PATH ready: flutter, mosquitto, mosquitto_pub, mosquitto_sub" -ForegroundColor Green
