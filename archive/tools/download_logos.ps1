# Download remaining tech logos for PPT presentation
# Python and PowerBI already downloaded successfully

$targetDir = 'C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\__PPT_Orange\assets\logos\tech'

# Ensure directory exists
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$logos = @{
    # Qlik - SeekLogo high-res PNG (2000x620)
    'qlik.png' = 'https://images.seeklogo.com/logo-png/33/1/qlik-logo-png_seeklogo-333923.png'

    # Dataiku - SeekLogo high-res PNG (2000x901)
    'dataiku.png' = 'https://images.seeklogo.com/logo-png/44/1/dataiku-logo-png_seeklogo-442441.png'
}

foreach ($entry in $logos.GetEnumerator()) {
    $filename = $entry.Key
    $url = $entry.Value
    $outPath = Join-Path $targetDir $filename

    Write-Host "Downloading $filename from $url ..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing -TimeoutSec 30
        $size = (Get-Item $outPath).Length
        Write-Host "  SUCCESS: $filename ($size bytes)" -ForegroundColor Green
    }
    catch {
        Write-Host "  FAILED: $filename - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== All logos in directory ==="
Get-ChildItem $targetDir -Filter "*.png" | ForEach-Object {
    Write-Host ("  {0} - {1:N0} bytes" -f $_.Name, $_.Length)
}
