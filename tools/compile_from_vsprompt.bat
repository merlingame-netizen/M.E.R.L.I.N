@echo off
echo ========================================
echo Compilation MerlinLLM (Colab Alignment)
echo ========================================
echo.

cd /d "%~dp0\native"

echo [1/3] Nettoyage...
if exist build rmdir /s /q build
mkdir build

echo.
echo [2/3] Configuration CMake...
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release

if %errorlevel% neq 0 (
    echo ERREUR: Configuration echouee!
    pause
    exit /b 1
)

echo.
echo [3/3] Compilation...
cmake --build build --config Release

if %errorlevel% neq 0 (
    echo ERREUR: Compilation echouee!
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ COMPILATION REUSSIE!
echo ========================================
echo.
echo DLL generee dans: addons\merlin_llm\bin\
echo.
echo Prochaines etapes:
echo 1. Fermez Godot si ouvert
echo 2. Relancez Godot
echo 3. Testez TestMerlin
echo.
echo Ameliorations attendues:
echo - Reponses: 200-350 mots (vs 50-100)
echo - Creativite: 8/10 (vs 3/10)
echo - Contexte: 8192 tokens (vs 2048)
echo - Repetitions: quasi nulles
echo.
pause
