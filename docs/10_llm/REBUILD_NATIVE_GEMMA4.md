# Rebuild Native Runtime for Gemma 4 — Manual Steps

> **Why this exists**: Phase 2 of the Qwen 3.5 → Gemma 4 migration discovered that
> Windows Group Policy on this workstation blocks `.bat` execution from the Claude
> Code bash subprocess. The rebuild has to be done by you, interactively, from a
> Windows Explorer / Command Prompt session. This document captures the exact
> steps and the source-code patches the new llama.cpp ABI requires.

## Why a rebuild is mandatory

The shipped `llama.dll` (Jan 15 2026) predates Google's Gemma 4 release. Phase 1
proved that the existing GDExtension, the path resolution, the GGUF download, and
the Godot scene wiring all work — but llama.cpp itself rejects the GGUF with
`unknown model architecture: 'gemma4'`.

Phase 2 verified that swapping in the **b9196** Windows prebuilt llama.dll
(downloaded from GitHub releases) makes the GDExtension load but produces a new
runtime error:

```
llama_model_load_from_file_impl: no backends are loaded.
hint: use ggml_backend_load() or ggml_backend_load_all() to load a backend
      before calling this function
```

That is, llama.cpp ≥ b9196 ships ggml-cpu as a *dynamically discovered* set of
arch-specific DLLs (`ggml-cpu-haswell.dll`, `ggml-cpu-zen4.dll`, …) and requires
the host to call `ggml_backend_load_all()` once at process start. The current
`native/src/merlin_llm.cpp` constructor still calls only the old
`llama_backend_init()` — which is a no-op on the new build.

## Source-code patches required

Apply these inside `native/src/merlin_llm.cpp`:

### Patch 1 — initialise backends in the constructor

```cpp
#include "llama.h"
#include "ggml-backend.h"   // <-- ADD if not already present
// ...
MerlinLLM::MerlinLLM() {
    if (backend_refs.fetch_add(1) == 0) {
        ggml_backend_load_all();   // <-- ADD before llama_backend_init
        llama_backend_init();
    }
    // ... rest unchanged ...
}
```

### Patch 2 — rename deprecated load/free calls

The 6-month-old API drift renames a handful of functions. Inside
`MerlinLLM::load_model`:

```diff
- model = llama_load_model_from_file(path.utf8().get_data(), mp);
+ model = llama_model_load_from_file(path.utf8().get_data(), mp);
// ...
- ctx = llama_new_context_with_model(model, cp);
+ ctx = llama_init_from_model(model, cp);
```

And in the destructor:

```diff
- llama_free_model(model);
+ llama_model_free(model);
```

> If the build complains about additional renamed symbols (sampler API,
> `llama_n_ctx_train` → `llama_model_n_ctx_train`, etc.), search the new header
> `native/llama.cpp/include/llama.h` for the closest match. The API drift is
> documented in `native/llama.cpp/ggml/include/ggml.h` changelog comments.

## Build sequence (run manually)

Open **Command Prompt** (not bash, not PowerShell — `cmd.exe` from Start menu;
this avoids the Group Policy block on subprocess `.bat` launching) and run:

```bat
REM 1. Wipe stale build artefacts
cd C:\Users\PGNK2128\Godot-MCP\native\llama.cpp
rmdir /s /q build_stale_nov2025 build_msbuild_fail_* build_failed_ninja_*

REM 2. Rebuild llama.cpp at tag b9196 (Ninja generator avoids the MSBuild policy block)
rebuild_b9196.bat
REM Expected: build\bin\Release\llama.dll plus build\ggml\src\ggml*.dll

REM 3. Rebuild merlin_llm.dll against the new llama.cpp (apply patches above first)
cd C:\Users\PGNK2128\Godot-MCP\native
rebuild_merlin_llm.bat
REM Expected: addons\merlin_llm\bin\merlin_llm.windows.release.x86_64.dll updated
```

If `rebuild_merlin_llm.bat` complains the CMakeCache references stale paths,
delete `native/build/` first.

## Copy DLLs into the worktree

The worktree at `C:\Users\PGNK2128\Godot-MCP\.claude\worktrees\zen-chatterjee-fd0b9c`
does **not** track `addons/merlin_llm/bin/*.dll` (gitignored), so it needs the
freshly built artefacts copied in:

```bat
copy C:\Users\PGNK2128\Godot-MCP\addons\merlin_llm\bin\merlin_llm.windows.release.x86_64.dll ^
     C:\Users\PGNK2128\Godot-MCP\.claude\worktrees\zen-chatterjee-fd0b9c\addons\merlin_llm\bin\

copy C:\Users\PGNK2128\Godot-MCP\native\llama.cpp\build\bin\Release\llama.dll ^
     C:\Users\PGNK2128\Godot-MCP\.claude\worktrees\zen-chatterjee-fd0b9c\addons\merlin_llm\bin\
REM Repeat for ggml.dll, ggml-base.dll, ggml-cpu*.dll, llama-common.dll, libomp140.x86_64.dll, mtmd.dll
```

## Verify

After the copy, re-run the probe:

```bash
"/c/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" \
  --path C:/Users/PGNK2128/Godot-MCP/.claude/worktrees/zen-chatterjee-fd0b9c \
  --headless --quit-after 60 \
  res://scenes/TestNativeProbe.tscn
```

Expected outcome on success:

```
[NATIVE-PROBE] MerlinLLM class registered
[NATIVE-PROBE] GGUF present (3106736256 bytes)
[NATIVE-PROBE] MerlinLLM instance created
[NATIVE-PROBE] load_model OK in <N>ms
[NATIVE-PROBE] Generated <N> chars in <N>ms
[NATIVE-PROBE]   -> <French druidic prose, no <start_of_turn> leaks>
[NATIVE-PROBE] VERDICT: GO_NATIVE_OK
```

Once that lands, the remaining work is:

1. Strip Ollama (delete `addons/merlin_ai/ollama_backend.gd`, remove its branches
   from `merlin_ai.gd::_init_local_models`, remove `MODEL_REGISTRY` qwen legacy,
   drop `use_legacy_qwen` flag, drop `force_narrator_tag` override).
2. Headless demo playthrough through the 7 scenes
   (MenuTest → SelectionSauvegarde → IntroCeltOS → MerlinCabinHub →
    BroceliandeForest3D → MerlinGame → EndRunScreen) with screenshots.
3. Update `merlin_human_run_test_v7.7.25.html` with the final SHIP-READY badge.

## Why this couldn't run from Claude's terminal

```text
Ce programme est bloqué par une stratégie de groupe.
Pour plus d'informations, contactez votre administrateur système.
```

Corporate Group Policy on this workstation blocks `.bat` execution when the
caller is a subprocess of `bash.exe`/`wsl.exe`/non-interactive `cmd.exe`. The
same scripts work fine when launched from a normal Explorer double-click or from
an interactive Command Prompt opened via the Start menu. There is no Claude-side
fix — the build has to happen from a shell the policy treats as interactive.
