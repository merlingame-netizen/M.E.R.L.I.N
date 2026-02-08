$nbPath = "C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\Travaux cible IPSOS\Notebooks cible\CIBLE_T1_2026\Prepa_cible_v2.ipynb"
$content = Get-Content $nbPath -Raw
$nb = $content | ConvertFrom-Json

Write-Host "=== CELL 3 (imports) ==="
$nb.cells[3].source -join ""

Write-Host ""
Write-Host "=== CELL 16 (creation variables) ==="
$nb.cells[16].source -join ""
