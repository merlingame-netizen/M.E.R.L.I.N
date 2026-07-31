@echo off
setlocal
rem ============================================================================
rem  Relit la derniere partie jouee et ouvre le tableau de controle.
rem
rem  Deux colonnes par carte : a gauche ce que tu as eu sous les yeux, a droite
rem  ce que le moteur a applique sans le dire. C'est cet ecart qui se controle.
rem ============================================================================

cd /d "%~dp0"

set "RUN=%CD%\docs\30_jdr\run_tourbe.json"
if not exist "%RUN%" (
  echo [ERREUR] Aucune partie enregistree.
  echo Joue d'abord une partie :  jouer_scenario.bat
  exit /b 1
)

where python >nul 2>&1 || (
  echo [ERREUR] python introuvable dans le PATH.
  exit /b 1
)

python tools\render_run_transcript.py --input "%RUN%" --out docs\30_jdr\RUN_TOURBE_TRANSCRIPT.md
python tools\render_run_dashboard.py  --input "%RUN%" --out docs\30_jdr\RUN_TOURBE_DASHBOARD.html
if errorlevel 1 (
  echo [ERREUR] Le rendu a echoue.
  exit /b 1
)

echo.
echo   Transcript : docs\30_jdr\RUN_TOURBE_TRANSCRIPT.md
echo   Tableau    : docs\30_jdr\RUN_TOURBE_DASHBOARD.html
echo.
start "" "docs\30_jdr\RUN_TOURBE_DASHBOARD.html"
endlocal
