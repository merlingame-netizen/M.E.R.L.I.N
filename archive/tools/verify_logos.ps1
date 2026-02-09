# Verify downloaded logo PNG files
$targetDir = 'C:\Users\PGNK2128\OneDrive - orange.com\Partage VOC\Data\__PPT_Orange\assets\logos\tech'

$files = Get-ChildItem $targetDir -Filter "*.png"
foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $header = [System.BitConverter]::ToString($bytes[0..7])
    $isPng = $header.StartsWith("89-50-4E-47")
    $status = if ($isPng) { "VALID PNG" } else { "NOT A PNG" }
    Write-Host ("{0} | {1:N0} bytes | {2} | Header: {3}" -f $f.Name, $f.Length, $status, $header)
}
