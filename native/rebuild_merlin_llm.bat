@echo off
REM ============================================================================
REM Script de recompilation de MerlinLLM avec paramètres optimisés (Colab-like)
REM ============================================================================

echo.
echo ========================================================================
echo  Recompilation de MerlinLLM avec parametres optimises
echo ========================================================================
echo.
echo Changements appliques:
echo  - Contexte: 2048 -^> 8192 tokens (x4)
echo  - max_tokens: 150 -^> 256 (par defaut)
echo  - temperature: 0.7 (alignee avec Colab)
echo  - top_k: 50 (nouveau)
echo  - repetition_penalty: 1.1 (nouveau)
echo.
echo ========================================================================
echo.

REM Configuration de l'environnement
set PATH=%APPDATA%\Python\Python311\Scripts;%PATH%

REM Vérifier que Visual Studio est installé
if not exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" (
    if not exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" (
        echo ERREUR: Visual Studio 2022 non trouve!
        echo Installez Visual Studio 2022 avec C++ Build Tools
        pause
        exit /b 1
    )
    call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
) else (
    call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64
)

REM Aller dans le dossier native
cd /d "%~dp0"

echo [1/3] Nettoyage des anciens fichiers de build...
if exist build (
    rmdir /s /q build
)
mkdir build

echo.
echo [2/3] Configuration CMake...
cmake -B build -S . -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=cl ^
    -DCMAKE_CXX_COMPILER=cl

if errorlevel 1 (
    echo.
    echo ERREUR: Configuration CMake echouee!
    echo Verifiez que:
    echo  - CMake est installe
    echo  - Ninja est installe
    echo  - godot-cpp est compile
    echo  - llama.cpp est compile
    pause
    exit /b 1
)

echo.
echo [3/3] Compilation de MerlinLLM...
cmake --build build --config Release

if errorlevel 1 (
    echo.
    echo ERREUR: Compilation echouee!
    pause
    exit /b 1
)

echo.
echo ========================================================================
echo  Compilation REUSSIE!
echo ========================================================================
echo.
echo La DLL a ete generee dans:
echo   %~dp0..\addons\merlin_llm\bin\
echo.
echo Prochaines etapes:
echo  1. Fermez Godot si ouvert
echo  2. Relancez Godot
echo  3. Testez la scene TestMerlin
echo.
echo Vous devriez observer:
echo  - Reponses plus longues et detaillees (jusqu'a 512 tokens)
echo  - Plus de creativite (temperature 0.7)
echo  - Moins de repetitions (repetition_penalty 1.1)
echo  - Pas d'erreurs llama_decode (contexte 8192)
echo.
pause