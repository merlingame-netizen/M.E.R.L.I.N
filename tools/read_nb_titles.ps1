$nbPath = "C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\Travaux cible IPSOS\Notebooks cible\CIBLE_T4_2025\Prepa_cible.ipynb"
$content = Get-Content $nbPath -Raw
$nb = $content | ConvertFrom-Json

Write-Host "=== STRUCTURE DU NOTEBOOK (284 cells) ==="
Write-Host ""

for ($i = 0; $i -lt $nb.cells.Count; $i++) {
    $cell = $nb.cells[$i]
    $src = $cell.source -join ""
    if ($cell.cell_type -eq "markdown") {
        # Show markdown cells that look like headers (start with #)
        if ($src -match "^#+\s") {
            Write-Host "[$i] $src"
        }
    }
}
