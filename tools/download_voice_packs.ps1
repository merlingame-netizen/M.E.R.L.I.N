# download_voice_packs.ps1
# Downloads 4 voice packs from equalo-official/animalese-generator
# Renames sound01-sound30 to a.wav-z.wav + th.wav, sh.wav, blank.wav, longblank.wav

$ErrorActionPreference = "Stop"

$baseUrl = "https://raw.githubusercontent.com/equalo-official/animalese-generator/master/sounds"
$targetBase = Join-Path $PSScriptRoot "..\addons\acvoicebox"

# Mapping: sound01=a, sound02=b, ..., sound26=z, sound27=th, sound28=sh, sound29=blank, sound30=longblank
$mapping = @{
    "sound01" = "a"; "sound02" = "b"; "sound03" = "c"; "sound04" = "d";
    "sound05" = "e"; "sound06" = "f"; "sound07" = "g"; "sound08" = "h";
    "sound09" = "i"; "sound10" = "j"; "sound11" = "k"; "sound12" = "l";
    "sound13" = "m"; "sound14" = "n"; "sound15" = "o"; "sound16" = "p";
    "sound17" = "q"; "sound18" = "r"; "sound19" = "s"; "sound20" = "t";
    "sound21" = "u"; "sound22" = "v"; "sound23" = "w"; "sound24" = "x";
    "sound25" = "y"; "sound26" = "z"; "sound27" = "th"; "sound28" = "sh";
    "sound29" = "blank"; "sound30" = "longblank"
}

$packs = @("high", "low", "lowest", "med")

foreach ($pack in $packs) {
    $targetDir = Join-Path $targetBase "sounds_$pack"

    if (!(Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Write-Host "=== Downloading voice pack: $pack ===" -ForegroundColor Cyan

    foreach ($entry in $mapping.GetEnumerator()) {
        $sourceFile = "$($entry.Key).wav"
        $targetFile = "$($entry.Value).wav"
        $url = "$baseUrl/$pack/$sourceFile"
        $dest = Join-Path $targetDir $targetFile

        if (Test-Path $dest) {
            Write-Host "  [SKIP] $targetFile (already exists)" -ForegroundColor Gray
            continue
        }

        try {
            Write-Host "  [DL] $sourceFile -> $targetFile" -ForegroundColor Green
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        }
        catch {
            Write-Host "  [FAIL] $sourceFile : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $count = (Get-ChildItem -Path $targetDir -Filter "*.wav" | Measure-Object).Count
    Write-Host "  Pack '$pack': $count files downloaded" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All voice packs downloaded! ===" -ForegroundColor Green
Write-Host "Packs: sounds_high, sounds_low, sounds_lowest, sounds_med" -ForegroundColor Cyan
