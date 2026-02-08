# Script de création du ZIP pour Colab - Version ULTIMATE
# Inclut les sources à compiler avec TOUS les patchs MinGW

Write-Host "Creating merlin_llm_sources.zip for Colab compilation..." -ForegroundColor Cyan
Write-Host ""

$rootDir = "c:\Users\PGNK2128\Godot-MCP"
$nativeDir = "$rootDir\native"
$zipPath = "$rootDir\merlin_llm_sources.zip"

# Vérification
if (-not (Test-Path $nativeDir)) {
    Write-Host "ERROR: native/ directory not found!" -ForegroundColor Red
    exit 1
}

# Nettoyer builds existants
Write-Host "[1/4] Cleaning build directories..." -ForegroundColor Yellow

$buildDirs = @(
    "$nativeDir\build",
    "$nativeDir\godot-cpp\build",
    "$nativeDir\godot-cpp\bin",
    "$nativeDir\llama.cpp\build"
)

foreach ($dir in $buildDirs) {
    if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force
        Write-Host "  - Removed: $dir" -ForegroundColor Gray
    }
}

# Supprimer ancien ZIP
if (Test-Path $zipPath) {
    Remove-Item $zipPath
}

Write-Host ""
Write-Host "[2/4] Compressing files..." -ForegroundColor Yellow

# Créer le ZIP avec TOUT le contenu nécessaire
Set-Location $nativeDir

# Structure attendue par Colab
Compress-Archive -Path @(
    "src\*",
    "CMakeLists.txt",
    "godot-cpp",
    "llama.cpp"
) -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host ""
Write-Host "[3/4] Verifying ZIP contents..." -ForegroundColor Yellow

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
$files = $zip.Entries | Select-Object -ExpandProperty FullName
$zip.Dispose()

$required = @(
    "src/merlin_llm.cpp",
    "src/merlin_llm.h",
    "CMakeLists.txt",
    "godot-cpp/",
    "llama.cpp/"
)

$allFound = $true
foreach ($file in $required) {
    $found = $files | Where-Object { $_ -like "*$file*" }
    if ($found) {
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  MISSING: $file" -ForegroundColor Red
        $allFound = $false
    }
}

Write-Host ""
Write-Host "[4/4] Summary" -ForegroundColor Yellow

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host "  ZIP created: $zipPath"
Write-Host "  Size: $([math]::Round($zipSize, 2)) MB"

Write-Host ""
if ($allFound) {
    Write-Host "SUCCESS! Ready for Colab upload" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Upload Compile_MerlinLLM_ULTIMATE.ipynb to Google Colab"
    Write-Host "  2. In Cellule 2, upload merlin_llm_sources.zip"
    Write-Host "  3. Run all cells (Runtime > Run all)"
    Write-Host "  4. Download merlin_llm_ultimate.zip at the end"
    Write-Host ""
    Write-Host "Improvements in ULTIMATE version:" -ForegroundColor Yellow
    Write-Host "  - Fixed ggml-cpu.c patch (robust #ifndef method)"
    Write-Host "  - NEW: Patched merlin_llm.cpp mutex for MinGW"
    Write-Host "  - NEW: Patched merlin_llm.h mutex declarations"
    Write-Host "  - All 3 blocking issues resolved!"
} else {
    Write-Host "ERROR: Some required files are missing!" -ForegroundColor Red
    exit 1
}
