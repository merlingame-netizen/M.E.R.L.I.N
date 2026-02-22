param(
    [string]$WatchPath = $PSScriptRoot,

    [string]$NameContains = "MAE",

    [string]$Delimiter = ";",

    [int]$PollSeconds = 2,

    [int]$MaxIterations = 0,

    [switch]$Recurse,

    [switch]$RunOnce,

    [switch]$NewOnlyAtStartup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Quote-Cell {
    param([object]$Value)

    $text = ""
    if ($null -ne $Value) {
        $text = [string]$Value
    }

    # CSV escaping: duplicate inner quotes, then wrap with quotes.
    return '"' + ($text -replace '"', '""') + '"'
}

function Convert-FileToQuotedCsvInPlace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$Delimiter = ";"
    )

    $headerLine = Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($headerLine)) {
        Write-Log "Skipped empty file: $Path"
        return
    }

    $headers = $headerLine -split [regex]::Escape($Delimiter)
    if ($headers.Count -gt 0) {
        $headers[0] = $headers[0].TrimStart([char]0xFEFF)
    }

    $rows = Import-Csv -LiteralPath $Path -Delimiter $Delimiter

    $outputLines = @()
    $outputLines += (($headers | ForEach-Object { Quote-Cell $_ }) -join $Delimiter)

    if ($null -ne $rows) {
        foreach ($row in $rows) {
            $quotedCells = @()
            foreach ($header in $headers) {
                $prop = $row.PSObject.Properties[$header]
                if ($null -ne $prop) {
                    $quotedCells += (Quote-Cell $prop.Value)
                }
                else {
                    $quotedCells += (Quote-Cell "")
                }
            }
            $outputLines += ($quotedCells -join $Delimiter)
        }
    }

    $tmpPath = "$Path.tmp_quote_all"
    Set-Content -LiteralPath $tmpPath -Value $outputLines -Encoding UTF8
    Move-Item -LiteralPath $tmpPath -Destination $Path -Force
}

function Get-CandidateCsvFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [string]$NameContains,

        [switch]$Recurse
    )

    $list = if ($Recurse) {
        Get-ChildItem -Path $RootPath -File -Filter "*.csv" -Recurse -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem -Path $RootPath -File -Filter "*.csv" -ErrorAction SilentlyContinue
    }

    return $list | Where-Object { $_.Name -like "*$NameContains*" }
}

if ([string]::IsNullOrWhiteSpace($WatchPath)) {
    $WatchPath = (Get-Location).Path
}

if (-not (Test-Path -LiteralPath $WatchPath)) {
    throw "Folder does not exist: $WatchPath"
}

$resolvedWatchPath = (Resolve-Path -LiteralPath $WatchPath).Path
Write-Log "Watching folder: $resolvedWatchPath"
Write-Log "File filter: *$NameContains*.csv"
Write-Log ("Recursive mode: " + [string]$Recurse.IsPresent)
Write-Log ("Poll interval (seconds): " + $PollSeconds)
Write-Log "Output mode: in-place overwrite"
if ($RunOnce) {
    Write-Log "Run mode: one pass then exit"
}
else {
    Write-Log "Run mode: continuous watch (stop with Ctrl+C)"
}

$lastSeenSignature = @{}
$stableCount = @{}
$processedSignature = @{}
$iteration = 0

$existing = Get-CandidateCsvFiles -RootPath $resolvedWatchPath -NameContains $NameContains -Recurse:$Recurse
Write-Log ("Matching CSV count at startup: " + @($existing).Count)
if ($NewOnlyAtStartup) {
    foreach ($file in $existing) {
        $signature = "$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
        $path = $file.FullName
        $lastSeenSignature[$path] = $signature
        $stableCount[$path] = 1
        $processedSignature[$path] = $signature
    }
    Write-Log "Startup mode: existing matching files are ignored (new arrivals only)."
}
else {
    foreach ($file in $existing) {
        $signature = "$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
        $path = $file.FullName
        $lastSeenSignature[$path] = $signature
        $stableCount[$path] = 1
    }
    Write-Log "Startup mode: existing matching files are processed."
}

while ($true) {
    if ($MaxIterations -gt 0 -and $iteration -ge $MaxIterations) {
        Write-Log "Auto-stop reached (MaxIterations=$MaxIterations)"
        break
    }

    $currentPaths = @{}
    $candidates = Get-CandidateCsvFiles -RootPath $resolvedWatchPath -NameContains $NameContains -Recurse:$Recurse

    foreach ($file in $candidates) {
        $fullPath = $file.FullName
        $currentPaths[$fullPath] = $true
        $signature = "$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"

        if ($lastSeenSignature.ContainsKey($fullPath) -and $lastSeenSignature[$fullPath] -eq $signature) {
            $stableCount[$fullPath] = [int]$stableCount[$fullPath] + 1
        }
        else {
            $lastSeenSignature[$fullPath] = $signature
            $stableCount[$fullPath] = 0
            continue
        }

        if ($stableCount[$fullPath] -lt 1) {
            continue
        }

        if ($processedSignature.ContainsKey($fullPath) -and $processedSignature[$fullPath] -eq $signature) {
            continue
        }

        try {
            $sizeMb = "{0:N2}" -f ($file.Length / 1MB)
            Write-Log "Converting started: $fullPath ($sizeMb MB)"
            Convert-FileToQuotedCsvInPlace -Path $fullPath -Delimiter $Delimiter
            $updated = Get-Item -LiteralPath $fullPath
            $updatedSignature = "$($updated.Length)|$($updated.LastWriteTimeUtc.Ticks)"
            $processedSignature[$fullPath] = $updatedSignature
            $lastSeenSignature[$fullPath] = $updatedSignature
            $stableCount[$fullPath] = 1
            Write-Log "Converted in-place: $fullPath"
        }
        catch {
            Write-Log "Error on '$fullPath' : $($_.Exception.Message)"
        }
    }

    foreach ($knownPath in @($lastSeenSignature.Keys)) {
        if (-not $currentPaths.ContainsKey($knownPath)) {
            $lastSeenSignature.Remove($knownPath) | Out-Null
            $stableCount.Remove($knownPath) | Out-Null
            $processedSignature.Remove($knownPath) | Out-Null
        }
    }

    $iteration += 1
    if ($RunOnce) {
        Write-Log "RunOnce completed."
        break
    }

    Start-Sleep -Seconds $PollSeconds
}
