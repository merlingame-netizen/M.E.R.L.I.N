# Script de compilation avec environnement Visual Studio
Write-Host "Compilation de MerlinLLM avec parametres optimises Colab" -ForegroundColor Cyan
Write-Host ""

# Chercher vcvarsall.bat
$vcvarsall = $null
$possiblePaths = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $vcvarsall = $path
        break
    }
}

if (-not $vcvarsall) {
    Write-Host "ERREUR: Visual Studio 2022 non trouve!" -ForegroundColor Red
    exit 1
}

# Se placer dans le dossier native
Set-Location $PSScriptRoot

# Nettoyer le dossier build
Write-Host "[1/3] Nettoyage du dossier build..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
}
New-Item -ItemType Directory -Path "build" | Out-Null

# Créer un batch temporaire qui initialise l'environnement et compile
$tempBat = Join-Path $env:TEMP "compile_merlin_temp.bat"
@"
@echo off
call "$vcvarsall" x64 >nul
cd /d "$PSScriptRoot"
echo [2/3] Configuration CMake...
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release
if errorlevel 1 exit /b 1
echo.
echo [3/3] Compilation...
cmake --build build --config Release
"@ | Out-File -FilePath $tempBat -Encoding ASCII

# Exécuter le batch
& cmd.exe /c $tempBat

# Vérifier le résultat
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host "Compilation REUSSIE!" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "La DLL a ete generee. Relancez Godot pour tester!" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "ERREUR: Compilation echouee!" -ForegroundColor Red
    exit 1
}

# Nettoyer
Remove-Item $tempBat -ErrorAction SilentlyContinue
