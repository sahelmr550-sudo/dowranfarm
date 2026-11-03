@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Farm Database - Installation
cd /d "%~dp0"
echo ============================================================
echo    Farm Database - one-time installation
echo ============================================================
echo Project folder: %CD%
echo Nothing is deleted. Your existing data and files stay as they are.
echo.

echo [0/5] Checking that all program files are present ...
set "MISSING="
for %%F in (server\config.js server\mongo-launcher.js server\store.js server\server.js server\web.js server\license\index.js server\license\crypto.js server\license\public-key.js scripts\prepare-ui.js scripts\setup-db.js ui\license-ui.js ui\farmstore-mongo.js app\farm-database-ps.html package.json) do if not exist "%%F" (echo       MISSING: %%F& set "MISSING=1")
if defined MISSING goto :incomplete
echo       OK
echo.

echo [1/5] Checking Node.js ...
where node >nul 2>&1
if errorlevel 1 for %%P in ("%ProgramFiles%\nodejs" "%ProgramFiles(x86)%\nodejs" "%LocalAppData%\Programs\nodejs" "%AppData%\nvm\current") do if exist "%%~P\node.exe" set "PATH=%%~P;%PATH%"
where node >nul 2>&1
if errorlevel 1 goto :no_node
set "NODEMAJOR=0"
for /f "tokens=1 delims=v." %%a in ('node -v') do set "NODEMAJOR=%%a"
if %NODEMAJOR% LSS 18 goto :old_node
for /f "delims=" %%v in ('node -v') do echo       OK - Node.js %%v
where npm >nul 2>&1
if errorlevel 1 goto :no_npm
echo.

echo [2/5] Checking MongoDB ...
set "MONGO_OK="
for /d %%D in ("%ProgramFiles%\MongoDB\Server\*") do if exist "%%D\bin\mongod.exe" set "MONGO_OK=1"
sc query MongoDB >nul 2>&1
if not errorlevel 1 set "MONGO_OK=1"
powershell -NoProfile -Command "try{$c=New-Object Net.Sockets.TcpClient('127.0.0.1',27017);$c.Close();exit 0}catch{exit 1}" >nul 2>&1
if not errorlevel 1 set "MONGO_OK=1"
if defined MONGO_OK (echo       OK - MongoDB found.) else (echo       MongoDB was not found - that is fine: the application will use its own built-in local storage.)
echo.

echo [3/5] Installing required packages (internet is needed for this step only) ...
call npm install --omit=dev --no-audit --no-fund
if errorlevel 1 goto :npm_fail
if not exist "node_modules\mongodb\package.json" goto :npm_fail
if not exist "node_modules\xlsx-js-style\dist\xlsx.bundle.js" goto :npm_fail
echo       OK - packages installed.
echo.

echo [4/5] Preparing the application files (offline version) ...
node scripts\prepare-ui.js
if errorlevel 1 goto :ui_fail
if not exist "ui\index.html" goto :ui_fail
echo.

echo [5/5] Preparing the local database ...
node scripts\setup-db.js
if errorlevel 1 echo       Note: the database check reported a problem. You can still try start.bat.
echo.
echo ============================================================
echo    INSTALLATION COMPLETE
echo    From now on just double-click  start.bat
echo    On the first start you will be asked for a license key
echo    (offline activation - the Computer ID is shown on that screen).
echo    (no internet is needed to use the application)
echo ============================================================
echo.
pause
exit /b 0

:incomplete
echo.
echo ERROR: The files listed above are missing, so this folder is incomplete (the ZIP was not fully extracted).
echo   Delete this folder, right-click the ZIP file, choose "Extract All...", open the NEW folder and run install.bat from there.
goto :fail
:no_node
echo.
echo ERROR: Node.js was not found on this computer.
echo   1. Download "LTS" from  https://nodejs.org
echo   2. Install it (keep the default options), then close this window.
echo   3. Double-click install.bat again.
goto :fail
:old_node
echo.
echo ERROR: Node.js version %NODEMAJOR% is too old. Version 18 or newer is required.
echo   Install the current "LTS" from https://nodejs.org and run install.bat again.
goto :fail
:no_npm
echo.
echo ERROR: npm was not found. Re-install Node.js from https://nodejs.org (it includes npm).
goto :fail
:no_mongo
echo.
echo ERROR: MongoDB was not found (no installation, no "MongoDB" service, nothing listening on port 27017).
echo   1. Download "MongoDB Community Server" (Windows MSI) from https://www.mongodb.com/try/download/community
echo   2. In the installer keep "Install MongoDB as a Service" ticked.
echo   3. Run install.bat again.
goto :fail
:npm_fail
echo.
echo ERROR: Package installation failed. Check your internet connection (needed only now) and read the messages above.
echo   If you use a proxy or firewall, allow npm to reach registry.npmjs.org, then run install.bat again.
goto :fail
:ui_fail
echo.
echo ERROR: Preparing the application files failed. Read the message above.
echo   Make sure the file app\farm-database-ps.html exists, then run install.bat again.
goto :fail
:db_fail
echo.
echo ERROR: The database could not be prepared. Read the message above.
echo   Double-click check-mongodb.bat: it shows exactly why the connection fails (service stopped, password, wrong port ...).
echo   Or start the MongoDB service (Win+R, type services.msc, start "MongoDB Server") and run install.bat again.
goto :fail
:fail
echo.
echo Installation was NOT completed. This window stays open so you can read the messages.
echo.
pause
exit /b 1
