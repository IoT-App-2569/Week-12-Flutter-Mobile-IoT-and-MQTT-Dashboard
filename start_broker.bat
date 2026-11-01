@echo off
set "PATH=C:\Program Files\mosquitto;%PATH%"
echo ===================================================
echo   Stopping any old Mosquitto process...
taskkill /F /IM mosquitto.exe >nul 2>&1
timeout /t 1 /nobreak >nul
echo   Starting Mosquitto (Port 1883 TCP and Port 9001 WebSockets)...
echo ===================================================
mosquitto -c mosquitto.conf -v
pause
