@echo off
echo Starting GLB Viewer server on http://localhost:8080
echo Viewer URL: http://localhost:8080/tools/asset_forge/glb_viewer.html
echo.
echo Press Ctrl+C to stop.
cd /d "%~dp0..\.."
start http://localhost:8080/tools/asset_forge/glb_viewer.html
"C:\Users\PGNK2128\AppData\Local\Programs\Python\Python312\python.exe" -m http.server 8080
