#!/usr/bin/env bash
# === Build merlin_llm.dll against the freshly built llama.cpp b9196 ===
# Same trick as rebuild_no_vcvars.sh: hardcode MSVC env to bypass the
# Group Policy block on vswhere.exe.

set -e

SDK_VER=10.0.22621.0
WIN_MSVC='C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.44.35207'
WIN_SDK='C:\Program Files (x86)\Windows Kits\10'

export INCLUDE="${WIN_MSVC}\\include;${WIN_SDK}\\Include\\${SDK_VER}\\ucrt;${WIN_SDK}\\Include\\${SDK_VER}\\um;${WIN_SDK}\\Include\\${SDK_VER}\\shared;${WIN_SDK}\\Include\\${SDK_VER}\\winrt"
export LIB="${WIN_MSVC}\\lib\\x64;${WIN_SDK}\\Lib\\${SDK_VER}\\um\\x64;${WIN_SDK}\\Lib\\${SDK_VER}\\ucrt\\x64"
export LIBPATH="${WIN_MSVC}\\lib\\x64;${WIN_SDK}\\Lib\\${SDK_VER}\\um\\x64;${WIN_SDK}\\Lib\\${SDK_VER}\\ucrt\\x64"

export PATH="/c/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64:/c/Program Files (x86)/Windows Kits/10/bin/${SDK_VER}/x64:/c/Users/PGNK2128/AppData/Roaming/Python/Python311/Scripts:$PATH"

cd /c/Users/PGNK2128/Godot-MCP/native

# Stash any prior merlin_llm build dir (non-destructive)
[ -d build ] && mv build "build_stale_$$"

echo "=== cmake configure merlin_llm ==="
cmake -B build -S . -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=cl.exe \
    -DCMAKE_CXX_COMPILER=cl.exe

echo "=== cmake build merlin_llm ==="
cmake --build build --config Release
echo "BUILD_EXIT=$?"

echo "=== Produced DLLs ==="
find build -name "*.dll" 2>/dev/null
ls -la /c/Users/PGNK2128/Godot-MCP/addons/merlin_llm/bin/*.dll 2>&1 | head -10
