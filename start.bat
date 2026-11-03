@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Farm Database
cd /d "%~dp0"
echo ============================================================
echo    Farm Database
echo ============================================================

where node >nul 2>&1
if errorlevel 1 for %%P in ("%ProgramFiles%\nodejs" "%ProgramFiles(x86)%\nodejs" "%LocalAppData%\Programs\nodejs" "%AppData%\nvm\current") do if exist "%%~P\node.exe" set "PATH=%%~P;%PATH%"
where node >nul 2>&1
if errorlevel 1 goto :no_node
if not exist "server\web.js" goto :broken
if not exist "node_modules\mongodb\package.json" goto :not_installed
if not exist "ui\index.html" goto :not_installed

node server\web.js
if errorlevel 1 goto :failed
timeout /t 3 >nul
exit /b 0

:no_node
echo.
echo ERROR: Node.js was not found. Install "LTS" from https://nodejs.org, then run install.bat once and start.bat again.
goto :fail
:not_installed
echo.
echo The application is not installed yet. Double-click install.bat first (only once), then start.bat.
goto :fail
:broken
echo.
echo ERROR: The file server\web.js is missing. Keep start.bat in the project folder (next to package.json).
goto :fail
:failed
echo.
echo The application stopped because of the error shown above.
echo Details are also in the console output; nothing was deleted from your database.
echo If the problem is the MongoDB connection, double-click check-mongodb.bat for a full report.
goto :fail
:fail
echo.
echo This window stays open so you can read the messages.
echo.
pause
exit /b 1
