@echo off
setlocal
rem ============================================================================
rem  Joue « Deux Assiettes » — le scenario type de reference, 25 cartes.
rem
rem  Double-clic, ou depuis un terminal :  jouer_scenario.bat
rem
rem  Ce que ca lance : le jeu, avec le scenario ecrit d'avance au lieu du tirage
rem  dans le pool. Tu joues normalement — c'est TOI qui choisis, aucune limite
rem  de temps. Chaque option affiche son epreuve avant le choix
rem  (« [Logic 60%%] Lire les traces »), et une resolution est narree apres.
rem
rem  Tout ce que tu vois et tout ce que le moteur applique derriere est
rem  enregistre dans docs\30_jdr\run_tourbe.json. Ensuite : voir_le_run.bat
rem ============================================================================

cd /d "%~dp0"

rem --- Godot : surchargeable via la variable GODOT ---------------------------
if "%GODOT%"=="" set "GODOT=C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64.exe"
if not exist "%GODOT%" (
  echo [ERREUR] Godot introuvable ici :
  echo          %GODOT%
  echo.
  echo Corrige le chemin, ou lance avec :
  echo     set "GODOT=C:\chemin\vers\Godot.exe" ^&^& jouer_scenario.bat
  exit /b 1
)

rem --- Le scenario joue -------------------------------------------------------
set "SCENARIO=%CD%\data\ai\scenario_type_reference.json"
if not exist "%SCENARIO%" (
  echo [ERREUR] Scenario introuvable : %SCENARIO%
  echo Regenere-le avec :  python tools\build_scenario_type.py --out "%SCENARIO%"
  exit /b 1
)

set "MERLIN_SCENARIO=%SCENARIO%"
set "MERLIN_TRANSCRIPT=%CD%\docs\30_jdr\run_tourbe.json"
set "MERLIN_BIOME_OVERRIDE=marais_korrigans"

rem Pas d'autoplay : c'est toi qui joues.
set "MERLIN_AUTOPLAY="

rem MERLIN_SEED rend les epreuves reproductibles — pratique pour rejouer la
rem meme partie apres une correction. Decommente pour t'en servir.
rem set "MERLIN_SEED=11"

echo.
echo   Scenario   : Deux Assiettes  (25 cartes, marais des Korrigans)
echo   Transcript : %MERLIN_TRANSCRIPT%
echo.
echo   Les cinq actes s'affichent en haut au centre, la progression en haut a
echo   droite. Prends ton temps : aucune carte ne se joue toute seule.
echo.

"%GODOT%" --path "%CD%" scenes/BoardNarration.tscn

echo.
if exist "%MERLIN_TRANSCRIPT%" (
  echo   Partie enregistree. Pour la relire :  voir_le_run.bat
) else (
  echo   [!] Aucun transcript ecrit — la partie n'est pas allee jusqu'au bout.
)
endlocal
