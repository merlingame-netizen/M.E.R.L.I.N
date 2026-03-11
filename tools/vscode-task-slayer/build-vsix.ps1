$src = 'C:\Users\PGNK2128\Godot-MCP\tools\vscode-task-slayer'
$destZip  = 'C:\Users\PGNK2128\Downloads\task-slayer-1.0.0.zip'
$dest     = 'C:\Users\PGNK2128\Downloads\task-slayer-1.0.0.vsix'

$tmp = Join-Path $env:TEMP 'vsix-build'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$tmp\extension" | Out-Null
New-Item -ItemType Directory -Path "$tmp\extension\src" | Out-Null
New-Item -ItemType Directory -Path "$tmp\extension\media" | Out-Null

# Contenu de l'extension dans extension/
Copy-Item "$src\package.json"  "$tmp\extension\"
Copy-Item "$src\extension.js"  "$tmp\extension\"
Copy-Item "$src\src\*.js"      "$tmp\extension\src\"
Copy-Item "$src\media\*.svg"   "$tmp\extension\media\"

# Manifests VSIX a la racine du ZIP
Copy-Item "$src\[Content_Types].xml"     "$tmp\[Content_Types].xml"
Copy-Item "$src\extension.vsixmanifest"  "$tmp\extension.vsixmanifest"

# Construire le ZIP puis renommer en .vsix (Compress-Archive n'accepte pas .vsix)
Remove-Item $destZip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$tmp\*" -DestinationPath $destZip -Force
Remove-Item $dest -Force -ErrorAction SilentlyContinue
Rename-Item -Path $destZip -NewName (Split-Path $dest -Leaf)

$size = (Get-Item $dest).Length
Write-Host "OK: $dest ($size bytes)"
