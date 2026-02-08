@echo off
echo Initialisation de l'environnement Visual Studio...

REM Initialiser l'environnement Visual Studio
if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" (
    call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
) else (
    echo ERREUR: Visual Studio 2022 non trouve!
    exit /b 1
)

echo.
echo Configuration CMake...
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl

if %errorlevel% neq 0 (
    echo ERREUR: Configuration CMake echouee!
    exit /b 1
)

echo.
echo Compilation...
cmake --build build --config Release

if %errorlevel% neq 0 (
    echo ERREUR: Compilation echouee!
    exit /b 1
)

echo.
echo ========================================
echo Compilation REUSSIE!
echo ========================================
