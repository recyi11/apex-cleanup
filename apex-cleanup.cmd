@echo off
setlocal

set "SCRIPT=%~dp0apex-cleanup.ps1"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File ""%SCRIPT%""' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%SCRIPT%" %*
