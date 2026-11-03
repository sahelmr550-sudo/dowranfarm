@echo off
chcp 65001 >nul
title Farm Database - license information
cd /d "%~dp0"
where node >nul 2>&1 || (echo Node.js was not found. & pause & exit /b 1)
node scripts\license-status.js
pause
