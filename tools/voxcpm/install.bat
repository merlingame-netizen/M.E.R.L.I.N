@echo off
REM Install the local TTS server. Window stays open so errors are visible.
REM Usage: tools\voxcpm\install.bat            (Piper, CPU, voix FR Merlin)
REM        tools\voxcpm\install.bat -Engine voxcpm -Device cuda121
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
echo ============================================================
if errorlevel 1 (
  echo INSTALLATION ECHOUEE — lis les messages d'erreur ci-dessus.
  echo Causes frequentes : pas de Python 3.10-3.12, ou telechargement bloque.
) else (
  echo Installation terminee. Lance maintenant : run.bat  (ou start.bat)
)
echo ============================================================
pause
