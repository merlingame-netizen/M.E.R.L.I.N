$nbPath = "C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\Travaux cible IPSOS\Notebooks cible\CIBLE_T4_2025\Prepa_cible.ipynb"
$content = Get-Content $nbPath -Raw
$nb = $content | ConvertFrom-Json

Write-Host "Total cells: $($nb.cells.Count)"
Write-Host ""

for ($i = 0; $i -lt $nb.cells.Count; $i++) {
    $cell = $nb.cells[$i]
    $src = $cell.source -join ""
    if ($cell.cell_type -eq "markdown") {
        $preview = $src.Substring(0, [Math]::Min(150, $src.Length)) -replace "`n", " "
        Write-Host "[$i] MARKDOWN: $preview..."
    } else {
        $preview = $src.Substring(0, [Math]::Min(100, $src.Length)) -replace "`n", " "
        Write-Host "[$i] CODE: $preview..."
    }
}
