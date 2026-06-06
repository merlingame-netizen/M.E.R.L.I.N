@echo off
REM VoxCPM install wrapper — forwards all args to install.ps1
REM Usage: tools\voxcpm\install.bat            (CPU, VoxCPM-0.5B)
REM        tools\voxcpm\install.bat -Device cuda121 -Model openbmb/VoxCPM2 -Prefetch
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
