$basePath = "C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\Travaux cible IPSOS\Notebooks cible\CIBLE_T4_2025\Data"

Get-ChildItem $basePath -Directory | ForEach-Object {
    Write-Host "=== $($_.Name) ==="
    Get-ChildItem $_.FullName -File | ForEach-Object {
        $sizeMB = [math]::Round($_.Length/1MB, 2)
        Write-Host "  $($_.Name) - $sizeMB MB"
    }
}
