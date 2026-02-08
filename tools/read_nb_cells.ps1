$cellIds = @(51,52,53,54,55,56,57,58,59,60)

$nbPath = "C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\Travaux cible IPSOS\Notebooks cible\CIBLE_T4_2025\Prepa_cible.ipynb"
$content = Get-Content $nbPath -Raw
$nb = $content | ConvertFrom-Json

foreach ($i in $cellIds) {
    $cell = $nb.cells[$i]
    $src = $cell.source -join ""
    Write-Host "=== CELL [$i] ($($cell.cell_type)) ==="
    Write-Host $src
    Write-Host ""
}
