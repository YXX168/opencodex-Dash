@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem 用法：install-opendash.bat [light^|dark]   不带参数时进入交互选择
set "THEME=%~1"
if "%THEME%"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-opendash.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-opendash.ps1" -Theme "%THEME%"
)
echo.
pause
