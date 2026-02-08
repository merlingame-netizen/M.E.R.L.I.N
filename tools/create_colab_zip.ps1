# Script PowerShell pour créer le ZIP pour Google Colab
# Exécutez depuis: c:\Users\PGNK2128\Godot-MCP

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Création du ZIP pour Google Colab" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier qu'on est dans le bon dossier
$currentPath = Get-Location
if (-not (Test-Path "native\src\merlin_llm.cpp")) {
    Write-Host "ERREUR: Exécutez ce script depuis c:\Users\PGNK2128\Godot-MCP\" -ForegroundColor Red
    exit 1
}

# Aller dans le dossier native
Set-Location "native"

Write-Host "[1/4] Vérification des fichiers requis..." -ForegroundColor Yellow

$requiredItems = @(
    "src\merlin_llm.cpp",
    "src\register_types.cpp",
    "CMakeLists.txt",
    "godot-cpp",
    "llama.cpp"
)

$allPresent = $true
foreach ($item in $requiredItems) {
    if (Test-Path $item) {
        Write-Host "  ✓ $item" -ForegroundColor Green
    } else {
        Write-Host "  ✗ MANQUANT: $item" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Host ""
    Write-Host "ERREUR: Fichiers manquants!" -ForegroundColor Red
    Write-Host "Assurez-vous que godot-cpp et llama.cpp sont clonés dans native/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "[2/4] Nettoyage des dossiers de build..." -ForegroundColor Yellow

# Supprimer les builds pour réduire la taille du ZIP
$buildDirs = @(
    "build",
    "godot-cpp\build",
    "godot-cpp\bin",
    "llama.cpp\build",
    "llama.cpp\bin"
)

$totalSaved = 0
foreach ($dir in $buildDirs) {
    if (Test-Path $dir) {
        $size = (Get-ChildItem -Path $dir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        $totalSaved += $size
        Write-Host "  ✓ Supprimé: $dir ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
    }
}

Write-Host "  → Espace économisé: $([math]::Round($totalSaved, 2)) MB" -ForegroundColor Cyan

Write-Host ""
Write-Host "[3/4] Création du ZIP..." -ForegroundColor Yellow

$zipPath = "..\merlin_llm_sources.zip"

# Supprimer l'ancien ZIP si existant
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Créer le ZIP
try {
    Compress-Archive -Path "src", "CMakeLists.txt", "godot-cpp", "llama.cpp" `
                     -DestinationPath $zipPath `
                     -CompressionLevel Optimal `
                     -Force

    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-Host "  ✓ ZIP créé: merlin_llm_sources.zip" -ForegroundColor Green
    Write-Host "  → Taille: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Cyan

    if ($zipSize -gt 100) {
        Write-Host ""
        Write-Host "  ⚠ ATTENTION: ZIP > 100 MB!" -ForegroundColor Yellow
        Write-Host "  Colab peut avoir des problèmes d'upload." -ForegroundColor Yellow
        Write-Host "  Considérez supprimer plus de fichiers temporaires." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ ERREUR lors de la création du ZIP: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[4/4] Vérification du contenu..." -ForegroundColor Yellow

# Lister le contenu
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $zipPath))
$fileCount = $zip.Entries.Count
$zip.Dispose()

Write-Host "  ✓ Nombre de fichiers: $fileCount" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "ZIP CRÉÉ AVEC SUCCÈS!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Fichier: $zipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. Allez sur: https://colab.research.google.com/" -ForegroundColor White
Write-Host "  2. Importez: Compile_MerlinLLM_Colab.ipynb" -ForegroundColor White
Write-Host "  3. Uploadez ce ZIP dans la Cellule 2" -ForegroundColor White
Write-Host "  4. Exécutez toutes les cellules dans l'ordre" -ForegroundColor White
Write-Host ""
Write-Host "Consultez GUIDE_COMPILATION_COLAB.md pour plus de détails." -ForegroundColor Cyan
Write-Host ""

# Revenir au dossier racine
Set-Location ..

Read-Host "Appuyez sur Entrée pour terminer"
