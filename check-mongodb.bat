@echo off
chcp 65001 >nul
title Farm Database - MongoDB check
cd /d "%~dp0"
where node >nul 2>&1 || (echo Node.js was not found. & pause & exit /b 1)
node scripts\diagnose-mongo.js
echo.
pause
