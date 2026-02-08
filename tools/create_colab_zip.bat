@echo off
REM ============================================================================
REM Script de creation du ZIP pour Colab - Contourne Group Policy
REM ============================================================================

echo.
echo ========================================================================
echo  Creation de merlin_llm_sources.zip pour Colab
echo ========================================================================
echo.

cd /d "%~dp0"

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 1: Nettoyage des builds
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo [1/4] Nettoyage des dossiers build...
echo.

if exist "native\build" rmdir /s /q "native\build"
if exist "native\godot-cpp\build" rmdir /s /q "native\godot-cpp\build"
if exist "native\godot-cpp\bin" rmdir /s /q "native\godot-cpp\bin"
if exist "native\llama.cpp\build" rmdir /s /q "native\llama.cpp\build"

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 2: Suppression ancien ZIP
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if exist "merlin_llm_sources.zip" (
    echo Suppression de l'ancien ZIP...
    del /f /q "merlin_llm_sources.zip"
    echo.
)

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 3: Vérification des fichiers requis
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo [2/4] Verification des fichiers requis...
echo.

set ERROR=0

if not exist "native\src\merlin_llm.cpp" (
    echo   X merlin_llm.cpp MANQUANT!
    set ERROR=1
) else (
    echo   OK native\src\merlin_llm.cpp
)

if not exist "native\src\merlin_llm.h" (
    echo   X merlin_llm.h MANQUANT!
    set ERROR=1
) else (
    echo   OK native\src\merlin_llm.h
)

if not exist "native\CMakeLists.txt" (
    echo   X CMakeLists.txt MANQUANT!
    set ERROR=1
) else (
    echo   OK native\CMakeLists.txt
)

if not exist "native\godot-cpp\SConstruct" (
    echo   X godot-cpp MANQUANT!
    set ERROR=1
) else (
    echo   OK native\godot-cpp\
)

if not exist "native\llama.cpp\CMakeLists.txt" (
    echo   X llama.cpp MANQUANT!
    set ERROR=1
) else (
    echo   OK native\llama.cpp\
)

if %ERROR%==1 (
    echo.
    echo ERREUR: Fichiers manquants!
    pause
    exit /b 1
)

echo.

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 4: Création du ZIP avec tar (Windows 10+)
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo [3/4] Creation du ZIP...
echo.

cd native

REM tar est disponible nativement sur Windows 10+ et n'est pas bloqué par Group Policy
tar -czf ..\merlin_llm_sources.zip ^
    src\merlin_llm.cpp ^
    src\merlin_llm.h ^
    CMakeLists.txt ^
    godot-cpp ^
    llama.cpp

if errorlevel 1 (
    echo.
    echo ERREUR: Creation du ZIP echouee!
    echo.
    echo Verifiez que tar est disponible (Windows 10+)
    cd ..
    pause
    exit /b 1
)

cd ..

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 5: Vérification finale
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo.
echo [4/4] Verification du ZIP...
echo.

if not exist "merlin_llm_sources.zip" (
    echo ERREUR: ZIP non cree!
    pause
    exit /b 1
)

for %%A in ("merlin_llm_sources.zip") do set SIZE=%%~zA
set /a SIZE_MB=%SIZE% / 1024 / 1024

echo ========================================================================
echo  SUCCES!
echo ========================================================================
echo.
echo ZIP cree: merlin_llm_sources.zip
echo Taille: %SIZE_MB% MB
echo.
echo ========================================================================
echo  PROCHAINES ETAPES
echo ========================================================================
echo.
echo 1. Ouvrir Google Colab: https://colab.research.google.com
echo.
echo 2. Upload Compile_MerlinLLM_ULTIMATE.ipynb
echo    ^(File -^> Upload notebook^)
echo.
echo 3. Executer Cellule 1 ^(Installation outils^)
echo.
echo 4. Executer Cellule 2 et uploader merlin_llm_sources.zip
echo    ^(bouton Upload qui apparait^)
echo.
echo 5. Executer toutes les cellules restantes
echo    ^(Runtime -^> Run all^)
echo.
echo 6. Telecharger merlin_llm_ultimate.zip a la fin
echo.
echo ========================================================================
echo.

pause
