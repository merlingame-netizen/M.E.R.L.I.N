# ACVoicebox - Script d'installation des sons
# Execute ce script pour telecharger les fichiers audio depuis GitHub

$soundsDir = "$PSScriptRoot\sounds"

# Creer le dossier sounds si necessaire
if (-not (Test-Path $soundsDir)) {
    New-Item -ItemType Directory -Path $soundsDir -Force | Out-Null
}

Write-Host "=== ACVoicebox - Installation des sons ===" -ForegroundColor Cyan
Write-Host ""

# URL de base du repo ACVoicebox
$baseUrl = "https://raw.githubusercontent.com/mattmarch/ACVoicebox/master/Sounds"

# Liste des fichiers a telecharger
$letters = @("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
$special = @("th", "sh", "blank", "longblank")

$total = $letters.Count + $special.Count
$current = 0

Write-Host "Telechargement de $total fichiers audio..." -ForegroundColor Yellow
Write-Host ""

# Telecharger les lettres
foreach ($letter in $letters) {
    $current++
    $url = "$baseUrl/$letter.wav"
    $dest = "$soundsDir\$letter.wav"

    Write-Progress -Activity "Telechargement des sons" -Status "$letter.wav" -PercentComplete (($current / $total) * 100)

    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host "  [OK] $letter.wav" -ForegroundColor Green
    } catch {
        Write-Host "  [ERREUR] $letter.wav - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Telecharger les sons speciaux
foreach ($sound in $special) {
    $current++
    $url = "$baseUrl/$sound.wav"
    $dest = "$soundsDir\$sound.wav"

    Write-Progress -Activity "Telechargement des sons" -Status "$sound.wav" -PercentComplete (($current / $total) * 100)

    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host "  [OK] $sound.wav" -ForegroundColor Green
    } catch {
        Write-Host "  [ERREUR] $sound.wav - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Progress -Activity "Telechargement des sons" -Completed

Write-Host ""
Write-Host "=== Installation terminee ===" -ForegroundColor Cyan
Write-Host ""

# Verifier le nombre de fichiers telecharges
$downloadedCount = (Get-ChildItem "$soundsDir\*.wav" -ErrorAction SilentlyContinue).Count
Write-Host "Fichiers telecharges: $downloadedCount / $total" -ForegroundColor $(if ($downloadedCount -eq $total) { "Green" } else { "Yellow" })

if ($downloadedCount -eq $total) {
    Write-Host ""
    Write-Host "Tous les sons sont installes! Vous pouvez utiliser ACVoicebox." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Certains fichiers n'ont pas ete telecharges." -ForegroundColor Yellow
    Write-Host "Vous pouvez les telecharger manuellement depuis:" -ForegroundColor Yellow
    Write-Host "https://github.com/mattmarch/ACVoicebox/tree/master/Sounds" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
