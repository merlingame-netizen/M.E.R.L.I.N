@echo off
REM ============================================================
REM  Merlin TTS — lancement EN UN CLIC
REM  Installe si besoin (Piper + voix FR), puis demarre le serveur
REM  et ouvre la page de test dans le navigateur.
REM  Double-clique simplement ce fichier.
REM ============================================================
setlocal
set "HERE=%~dp0"

if not exist "%HERE%.venv-voxcpm\Scripts\python.exe" (
  echo [Merlin TTS] Premiere utilisation : installation de Piper...
  echo.
  call powershell -ExecutionPolicy Bypass -File "%HERE%install.ps1"
  if errorlevel 1 (
    echo.
    echo INSTALLATION ECHOUEE. Lis les messages ci-dessus.
    pause
    exit /b 1
  )
)

echo.
echo [Merlin TTS] Demarrage du serveur + ouverture du navigateur...
echo [Merlin TTS] Garde cette fenetre ouverte. Ferme-la pour arreter le serveur.
echo.
powershell -ExecutionPolicy Bypass -File "%HERE%start.ps1"
echo.
echo (Serveur arrete.)
pause
