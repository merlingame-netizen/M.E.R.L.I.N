#!/usr/bin/env bash
set -euo pipefail

# Cross-compile Windows GDExtension on Google Colab using MinGW
# Usage: bash scripts/voice_robot/colab_build_windows_mingw.sh /content/Godot-MCP
REPO_ROOT="${1:-/content/Godot-MCP}"

GODOT_CPP="$REPO_ROOT/native/godot-cpp"
THIRD_PARTY="$REPO_ROOT/native/third_party"
FLITE_DIR="$THIRD_PARTY/flite"
FLITE_OUT="$THIRD_PARTY/flite_win"
EXT_DIR="$REPO_ROOT/native/robot_voice"

sudo apt-get update -y
sudo apt-get install -y build-essential git mingw-w64 cmake ninja-build zip python3-pip
python3 -m pip install --upgrade pip scons

mkdir -p "$THIRD_PARTY"

if [ ! -d "$GODOT_CPP" ]; then
  echo "Cloning godot-cpp into $GODOT_CPP"
  git clone https://github.com/godotengine/godot-cpp.git "$GODOT_CPP"
else
  echo "godot-cpp already present: $GODOT_CPP"
fi

if [ ! -d "$FLITE_DIR" ]; then
  echo "Cloning flite into $FLITE_DIR"
  git clone https://github.com/festvox/flite.git "$FLITE_DIR"
else
  echo "flite already present: $FLITE_DIR"
fi

# Build godot-cpp (MinGW)
cd "$GODOT_CPP"
scons platform=windows target=template_release use_mingw=yes -j"$(nproc)"

# Build flite (MinGW)
cd "$FLITE_DIR"
make distclean || true
CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ \
  ./configure --host=x86_64-w64-mingw32 --prefix="$FLITE_OUT" --disable-shared
make -j"$(nproc)"
make install

# Build GDExtension (if present)
if [ -d "$EXT_DIR" ]; then
  mkdir -p "$EXT_DIR/build-mingw"
  cd "$EXT_DIR/build-mingw"
  cmake -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DGODOT_CPP_ROOT="$GODOT_CPP" \
    -DFLITE_ROOT="$FLITE_OUT" \
    ..
  ninja
else
  echo "Missing $EXT_DIR. Extension not built."
fi

echo "Windows build (MinGW) done."
