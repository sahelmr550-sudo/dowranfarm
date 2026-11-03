@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Farm Database - allow network access
echo ============================================================
echo    Allow other computers on the network to open Farm Database
echo ============================================================
echo.
net session >nul 2>&1
if errorlevel 1 (
  echo This must run as Administrator.
  echo Right-click allow-network.bat and choose "Run as administrator".
  echo.
  pause
  exit /b 1
)
set "PORT=47831"
netsh advfirewall firewall delete rule name="Farm Database (network)" >nul 2>&1
netsh advfirewall firewall add rule name="Farm Database (network)" dir=in action=allow protocol=TCP localport=%PORT% profile=private,domain
if errorlevel 1 goto :fail
echo.
echo Done. Port %PORT% is now open for computers on your private/work network.
echo Other computers open:  http://THIS-COMPUTER-IP:%PORT%/   (the exact address is printed when you run start.bat)
echo.
pause
exit /b 0
:fail
echo.
echo Could not add the firewall rule. Open Windows Defender Firewall and allow TCP port %PORT% manually.
pause
exit /b 1
