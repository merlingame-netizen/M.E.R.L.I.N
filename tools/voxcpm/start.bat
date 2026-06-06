@echo off
REM Start the VoxCPM TTS server. Forwards args to start.ps1.
REM Usage: tools\voxcpm\start.bat
REM        tools\voxcpm\start.bat -Model openbmb/VoxCPM2 -Port 8808
powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" %*
