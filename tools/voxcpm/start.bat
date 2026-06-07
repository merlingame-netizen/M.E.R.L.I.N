@echo off
REM Start the local TTS server. Window stays open so you can read any error.
REM Usage: tools\voxcpm\start.bat   [-Engine piper|voxcpm] [-Port 8808] [-NoRobot]
powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" %*
echo.
echo ============================================================
echo Le serveur s'est arrete (ou n'a pas pu demarrer).
echo Lis les messages ci-dessus. Si "venv not found" : lance install.bat.
echo ============================================================
pause
