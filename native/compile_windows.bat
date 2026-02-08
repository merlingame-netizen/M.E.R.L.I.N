@echo off
REM ============================================================================
REM Script de compilation Windows native avec Visual Studio 2022
REM ============================================================================

echo.
echo ========================================================================
echo  Compilation MerlinLLM - Windows Native (MSVC)
echo ========================================================================
echo.
echo Parametres optimises Colab:
echo  - Contexte: 8192 tokens (x4)
echo  - max_tokens: 256
echo  - temperature: 0.7
echo  - top_k: 50
echo  - repetition_penalty: 1.1
echo.
echo ========================================================================
echo.

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 1: Compilation godot-cpp
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo [1/3] Compilation de godot-cpp...
echo.

cd godot-cpp

REM Vérifier si déjà compilé
if exist "bin\libgodot-cpp.windows.template_release.x86_64.lib" (
    echo godot-cpp deja compile. Voulez-vous recompiler? (o/N)
    set /p recompile=
    if /i not "%recompile%"=="o" goto skip_godot
)

echo Compilation en cours (5-8 min)...
scons platform=windows target=template_release arch=x86_64 -j8

if errorlevel 1 (
    echo.
    echo ERREUR: Compilation godot-cpp echouee!
    pause
    exit /b 1
)

:skip_godot
echo.
echo ✓ godot-cpp OK
echo.
dir /b bin\*.lib

cd ..

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 2: Compilation llama.cpp
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo [2/3] Compilation de llama.cpp...
echo.

cd llama.cpp

REM Nettoyer et créer build
if exist build rmdir /s /q build
mkdir build
cd build

echo Configuration CMake...
cmake .. -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_SHARED_LIBS=OFF ^
  -DLLAMA_CURL=OFF ^
  -DGGML_OPENMP=OFF ^
  -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TESTS=OFF ^
  -DLLAMA_BUILD_SERVER=OFF

if errorlevel 1 (
    echo.
    echo ERREUR: Configuration CMake llama.cpp echouee!
    pause
    exit /b 1
)

echo.
echo Compilation en cours (3-5 min)...
ninja

if errorlevel 1 (
    echo.
    echo ERREUR: Compilation llama.cpp echouee!
    pause
    exit /b 1
)

echo.
echo ✓ llama.cpp OK
echo.
echo Bibliotheques generees:
dir /b /s *.lib | findstr /i llama

cd ..\..

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM ÉTAPE 3: Compilation merlin_llm.dll
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo [3/3] Compilation de merlin_llm.dll...
echo.

REM Nettoyer et créer build
if exist build rmdir /s /q build
mkdir build
cd build

echo Configuration CMake...
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release

if errorlevel 1 (
    echo.
    echo ERREUR: Configuration CMake merlin_llm echouee!
    echo.
    echo Verifiez que godot-cpp et llama.cpp sont compiles.
    pause
    exit /b 1
)

echo.
echo Compilation en cours...
ninja

if errorlevel 1 (
    echo.
    echo ERREUR: Compilation merlin_llm echouee!
    pause
    exit /b 1
)

cd ..

REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM VÉRIFICATION FINALE
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo.
echo ========================================================================
echo  VERIFICATION FINALE
echo ========================================================================
echo.

if exist "addons\merlin_llm\bin\merlin_llm.windows.release.x86_64.dll" (
    echo ✓ DLL generee avec succes!
    echo.
    echo Emplacement:
    echo   %~dp0addons\merlin_llm\bin\merlin_llm.windows.release.x86_64.dll
    echo.
    for %%A in ("addons\merlin_llm\bin\merlin_llm.windows.release.x86_64.dll") do echo Taille: %%~zA octets
    echo.
    echo ========================================================================
    echo  COMPILATION REUSSIE!
    echo ========================================================================
    echo.
    echo Prochaines etapes:
    echo  1. Fermez Godot si ouvert
    echo  2. Relancez Godot
    echo  3. Testez avec TestMerlinGBA.tscn
    echo.
    echo Ameliorations attendues:
    echo  - Reponses: 200-350 mots (vs 50-100)
    echo  - Creativite: 8/10 (vs 3/10)
    echo  - Contexte: 8192 tokens (stable!)
    echo  - Repetitions: quasi nulles
    echo.
) else (
    echo ✗ ERREUR: DLL non trouvee!
    echo.
    echo Verifiez les etapes precedentes pour les erreurs.
)

echo.
pause
