@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64
cd /D "%~dp0"
cmake --build build --config Release
echo BUILD_EXIT_CODE=%ERRORLEVEL%
