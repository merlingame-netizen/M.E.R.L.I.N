# CLI-Anything adapters — tool-specific CLI wrappers for agent-native usage

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from adapters.base_adapter import BaseAdapter

# Registry: tool_name -> (module_path, class_name, external_path_or_None)
ADAPTER_REGISTRY: dict[str, tuple[str, str, str | None]] = {
    # ── Original (pre-migration) ──────────────────────────────────────────
    "godot":       ("adapters.godot_adapter",       "GodotAdapter",       None),
    "ollama":      ("adapters.ollama_adapter",      "OllamaAdapter",      None),
    "git":         ("adapters.git_adapter",         "GitAdapter",         None),
    "powerbi":     ("adapters.powerbi_adapter",     "PowerBIAdapter",     "~/.claude/tools"),
    # ── Wave 1 — REST API direct ──────────────────────────────────────────
    "n8n":         ("adapters.n8n_adapter",         "N8NAdapter",         None),
    "dbeaver":     ("adapters.dbeaver_adapter",     "DBeaverAdapter",     None),
    "mermaid":     ("adapters.mermaid_adapter",     "MermaidAdapter",     None),
    "context7":    ("adapters.context7_adapter",    "Context7Adapter",    None),
    # ── Wave 2 — Node.js server replacements ──────────────────────────────
    "nano-banana": ("adapters.nano_banana_adapter", "NanoBananaAdapter",  None),
    "pageindex":   ("adapters.pageindex_adapter",   "PageIndexAdapter",   None),
    "magic":       ("adapters.magic_adapter",       "MagicAdapter",       None),
    # ── Wave 3 — Complex / multi-layer ────────────────────────────────────
    "datagouv":    ("adapters.datagouv_adapter",    "DataGouvAdapter",    None),
    "figma":       ("adapters.figma_adapter",       "FigmaAdapter",       None),
    "stitch":      ("adapters.stitch_adapter",      "StitchAdapter",      None),
    "trellis":     ("adapters.trellis_adapter",     "TrellisAdapter",     None),
    # ── Wave 4 — PBI Preview pipeline ────────────────────────────────────
    "pbi-preview": ("adapters.pbi_preview_adapter", "PBIPreviewAdapter",  None),
    # ── Wave 5 — PBI Visual CLI (pixel-precise PBIR control) ─────────
    "pbi-visual":  ("adapters.pbi_visual_adapter",  "PBIVisualAdapter",   None),
    # ── Wave 6 — OneNote dedicated (full COM headless) ─────────────
    "onenote":     ("adapters.onenote_adapter",     "OneNoteAdapter",     None),
    # ── Wave 7 — Communications (Outlook COM + Teams cache/PA) ───
    "outlook":     ("adapters.outlook_adapter",     "OutlookAdapter",     None),
    "teams":       ("adapters.teams_adapter",       "TeamsAdapter",       None),
    # ── Wave 8 — 3D asset generation (Blender headless) ──────────────
    "blender":     ("adapters.blender_adapter",     "BlenderAdapter",     None),
    # ── Wave 9 — Downloads organizer ────────────────────────────────
    "downloads":   ("adapters.downloads_adapter",   "DownloadsAdapter",   None),
    # ── Wave 10 — Data Explorer (local web app) ─────────────────────
    "data-explorer": ("adapters.data_explorer_adapter", "DataExplorerAdapter", None),
    # ── Wave 11 — RAG (local vector search) ──────────────────────────
    "rag":           ("adapters.rag_adapter",           "RagAdapter",          None),
    # ── Wave 12 — Studio Bridge (autonomous orchestrator) ────────────
    "studio":        ("adapters.studio_adapter",        "StudioAdapter",       None),
}


def load_adapter(tool: str) -> "BaseAdapter":
    """Lazily import and instantiate an adapter by tool name."""
    import importlib
    import importlib.util
    import sys
    from pathlib import Path

    if tool not in ADAPTER_REGISTRY:
        available = ", ".join(sorted(ADAPTER_REGISTRY.keys()))
        raise ValueError(f"Unknown tool: {tool!r}. Available: {available}")

    module_path, class_name, external_path = ADAPTER_REGISTRY[tool]

    if external_path:
        # External adapters: load from file directly to avoid package conflicts
        resolved = Path(external_path).expanduser()
        parts = module_path.split(".")
        file_path = resolved / "/".join(parts[:-1]) / f"{parts[-1]}.py"
        if not file_path.exists():
            raise ImportError(f"Adapter not found: {file_path}")
        spec = importlib.util.spec_from_file_location(module_path, str(file_path))
        if spec is None or spec.loader is None:
            raise ImportError(f"Cannot load adapter from {file_path}")
        module = importlib.util.module_from_spec(spec)
        # Ensure base_adapter is importable from the external module
        if str(resolved) not in sys.path:
            sys.path.insert(0, str(resolved))
        spec.loader.exec_module(module)
    else:
        module = importlib.import_module(module_path)

    cls = getattr(module, class_name)
    return cls()


def list_tools() -> list[str]:
    """Return sorted list of available tool names."""
    return sorted(ADAPTER_REGISTRY.keys())
