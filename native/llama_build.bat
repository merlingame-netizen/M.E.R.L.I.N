@echo off
set PATH=%APPDATA%\Python\Python311\Scripts;%PATH%
call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64
cd /d C:\Users\PGNK2128\DRU\native\llama.cpp
cmake -B build -S . -G Ninja -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_TESTS=OFF
cmake --build build --config Release
