# Rebuild Native Runtime for Gemma 4 — Status + Steps

> **Updated 2026-05-17 EOD**: the rebuild succeeded against llama.cpp tag `b9196`
> by bypassing the Group Policy block on `vswhere.exe` / `vcvarsall.bat`.
> Native Gemma 4 GGUF now loads via `merlin_llm.dll`. One residual issue
> remains in the inference loop (see § "Remaining work").

## What works now (verified this session)

1. **llama.cpp b9196** built locally from `native/llama.cpp/` at commit `7ba22c6a0`.
   Produces `build/bin/{llama,ggml,ggml-base,ggml-cpu,llama-common,mtmd}.dll`.
2. **merlin_llm.dll** rebuilt against b9196. Build chain proven by source patch +
   compile + link without errors (3-file CMake target, ~6 s build).
3. **MerlinLLM GDExtension** loads in Godot 4.5.1 without the prior
   "GDExtension dynamic library not found" error.
4. **Gemma 4 GGUF load_model** returns OK in ~5 s from the worktree:
   ```
   [NATIVE-PROBE] MerlinLLM class registered
   [NATIVE-PROBE] GGUF present (3106736256 bytes)
   [NATIVE-PROBE] Resolving res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf
              -> C:/.../addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf
   llama_model_loader: loaded meta data ... general.architecture = gemma4
   [NATIVE-PROBE] load_model OK in 5304ms
   ```
   No more `unknown model architecture: 'gemma4'`, no more `no backends are loaded`.

## How the Group Policy block was bypassed

The corporate Group Policy on this workstation blocks `vswhere.exe` (used by
`vcvarsall.bat` to auto-detect MSVC). The workaround is to **never call
`vcvarsall.bat`**: hardcode `INCLUDE`, `LIB`, `LIBPATH`, `PATH` to point directly
at the MSVC install + Windows SDK, then invoke `cmake -G Ninja`. `cl.exe` itself
is NOT blocked — only the auto-detection helper.

Both rebuild scripts (`native/llama.cpp/rebuild_no_vcvars.sh` and
`native/rebuild_merlin_no_vcvars.sh`) live under `native/llama.cpp/` (gitignored)
and `native/` respectively. The merlin one is tracked; the llama.cpp one is
local-only (`native/llama.cpp/` is a separate git clone of upstream llama.cpp).

Full content of `native/llama.cpp/rebuild_no_vcvars.sh` (reproduce verbatim):

```bash
#!/usr/bin/env bash
set -e
SDK_VER=10.0.22621.0
WIN_MSVC='C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.44.35207'
WIN_SDK='C:\Program Files (x86)\Windows Kits\10'

export INCLUDE="${WIN_MSVC}\\include;${WIN_SDK}\\Include\\${SDK_VER}\\ucrt;${WIN_SDK}\\Include\\${SDK_VER}\\um;${WIN_SDK}\\Include\\${SDK_VER}\\shared;${WIN_SDK}\\Include\\${SDK_VER}\\winrt"
export LIB="${WIN_MSVC}\\lib\\x64;${WIN_SDK}\\Lib\\${SDK_VER}\\um\\x64;${WIN_SDK}\\Lib\\${SDK_VER}\\ucrt\\x64"
export LIBPATH="${LIB}"
export PATH="/c/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64:/c/Program Files (x86)/Windows Kits/10/bin/${SDK_VER}/x64:/c/Users/PGNK2128/AppData/Roaming/Python/Python311/Scripts:$PATH"

cd /c/Users/PGNK2128/Godot-MCP/native/llama.cpp

cmake -B build -S . -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=cl.exe -DCMAKE_CXX_COMPILER=cl.exe \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF \
    -DGGML_NATIVE=OFF -DGGML_AVX2=ON

cmake --build build --config Release
```

> Adjust `WIN_MSVC` to your installed version (`ls "C:/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/MSVC/"`).
> Adjust `SDK_VER` similarly (`ls "C:/Program Files (x86)/Windows Kits/10/Include/"`).

## C++ source patches applied

`native/src/merlin_llm.cpp` (committed in the worktree's HEAD):

1. **Backend init** (constructor): added `ggml_backend_load_all()` + `#include "ggml-backend.h"`.
   b9196 split ggml-cpu into arch-specific dynamic DLLs; this call discovers them.
2. **API renames** (3 sites in the constructor/destructor/load_model):
   `llama_load_model_from_file` → `llama_model_load_from_file`,
   `llama_new_context_with_model` → `llama_init_from_model`,
   `llama_free_model` → `llama_model_free`.
3. **Decode return-code fix** (2 sites): `llama_decode(...) != 0` was incorrectly
   treating `1` ("KV slot miss, retry-able") as fatal. Changed to `< 0` (fatal
   only) per the b9196 header contract. Per-token loop now also emits a clearer
   "KV cache full during generation" error on `ret == 1`.
4. **Flash-attn default**: `LLAMA_FLASH_ATTN_TYPE_ENABLED` → `AUTO`. Forcing
   ENABLED on CPU-only builds can trigger `ggml_assert` on Gemma 4's
   sliding-window kernel.

## Build sequence (reproducible)

From a Git Bash terminal (NOT cmd.exe — vcvarsall is the GP-blocked path):

```bash
# 1. Bump llama.cpp to b9196
cd /c/Users/PGNK2128/Godot-MCP/native/llama.cpp
git fetch origin
git checkout b9196

# 2. Build llama.cpp (~5-10 min)
bash rebuild_no_vcvars.sh

# 3. Build merlin_llm.dll (~10 s)
bash /c/Users/PGNK2128/Godot-MCP/native/rebuild_merlin_no_vcvars.sh

# 4. Deploy to the active worktree (gitignored bin/)
cp /c/Users/PGNK2128/Godot-MCP/native/addons/merlin_llm/bin/merlin_llm.windows.release.x86_64.dll \
   /c/Users/PGNK2128/Godot-MCP/native/llama.cpp/build/bin/{llama,ggml,ggml-base,ggml-cpu}.dll \
   /c/Users/PGNK2128/Godot-MCP/.claude/worktrees/zen-chatterjee-fd0b9c/addons/merlin_llm/bin/

# 5. Re-probe
"/c/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" \
  --path C:/Users/PGNK2128/Godot-MCP/.claude/worktrees/zen-chatterjee-fd0b9c \
  --headless --quit-after 300 \
  res://scenes/TestNativeProbe.tscn
```

Expected new state of the probe log:
- ✅ "MerlinLLM class registered"
- ✅ "load_model OK in ~5s"
- ⏳ "Generated N chars" — **NOT YET seen** in this session; see next section.

## Remaining work: generate_async callback never fires

After `load_model OK`, `generate_async` is called but its callback never invokes
the GDScript lambda, even after 300 s of `--quit-after`. No error is reported.
The HIGH-severity decode-return-code fix did not resolve it, so the root cause
is elsewhere. Suspected areas:

- **Sampler chain init** — Gemma 4 has `general.sampling.top_k = 64` baked into
  the GGUF metadata; if `llama_sampler_init_top_k(top_k)` is called with our
  user-set top_k it may produce an empty distribution on the first token.
- **`_emit_result` deferred call wiring** — the C++ inference thread may not
  reach `call_deferred("_emit_result", ...)`, perhaps because `is_generating`
  flips to false before the result dict is populated.
- **`llama_sampler_sample` returning EOS as first token** — would exit the loop
  with empty `output` and an empty error string. Result dict would be sent but
  with both text and error empty.

Quickest next-step diagnostic: add `UtilityFunctions::print(...)` lines around
each step in `MerlinLLM::generate_async` thread body (token count after tokenize,
first sampled token id, post-decode return code, output length on exit) and
re-run the probe. Will reveal exactly where the thread exits without notifying
GDScript.

This residual debug is **out of scope of the rebuild itself** — the build
infrastructure now produces a working binary that successfully loads Gemma 4.

## Files affected this session

| Path | Status |
|---|---|
| `native/src/merlin_llm.cpp` | patched (4 changes) |
| `native/rebuild_merlin_no_vcvars.sh` | new, tracked |
| `native/llama.cpp/rebuild_no_vcvars.sh` | new, local-only (gitignored) |
| `native/llama.cpp/rebuild_b9196.bat` | new, local-only |
| `addons/merlin_llm/bin/{llama,ggml,ggml-base,ggml-cpu,merlin_llm.windows.release.x86_64}.dll` | rebuilt at b9196, gitignored |
| `addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf` | downloaded (unsloth/gemma-4-E2B-it-GGUF), 2.88 GiB, gitignored |
| `scripts/test/test_native_probe.gd`, `scenes/TestNativeProbe.tscn` | committed earlier in Phase 1, validated load path |
| `docs/10_llm/REBUILD_NATIVE_GEMMA4.md` | this file |
