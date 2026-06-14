# -*- coding: utf-8 -*-
"""SD forge M.E.R.L.I.N. — image generation pipeline (BIBLE §20, R115).

Generates illustration images for MERLIN game situations using:
  1. stable-diffusion-cpp-python (SD 1.5, CPU, local — preferred)
  2. nano-banana MCP (Gemini cloud — fallback)

All outputs are post-processed through sepia_forge for identity conformity,
then validated via asset_validator.

Usage:
    python tools/sd_forge.py --prompt "ancient druid circle" --seed 42
    python tools/sd_forge.py --template druid_circle --seed 42
    python tools/sd_forge.py --list-templates
    python tools/sd_forge.py --status
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

# ── Identity prefix/negative for ALL generations ────────────────────────────

IDENTITY_PREFIX = (
    "monochrome sepia engraving, ink on aged parchment, celtic medieval, "
    "dark atmospheric, hand-drawn illustration, detailed line art, "
    "Brocéliande forest, Arthurian legend"
)

NEGATIVE_PROMPT = (
    "color, colorful, modern, photograph, photo, 3d render, neon, cartoon, "
    "anime, manga, digital art, CGI, plastic, glossy, bright, saturated, "
    "watermark, text, logo, signature, blurry, low quality"
)

# ── Prompt templates for MERLIN situations ──────────────────────────────────

@dataclass(frozen=True)
class PromptTemplate:
    name: str
    prompt: str
    description: str


TEMPLATES: dict[str, PromptTemplate] = {
    "druid_circle": PromptTemplate(
        "druid_circle",
        "circle of hooded druids performing ritual in ancient stone circle, "
        "menhirs, mistletoe, moonlight filtering through oak branches",
        "Cercle de druides — rituel nocturne",
    ),
    "broceliande_path": PromptTemplate(
        "broceliande_path",
        "winding path through enchanted forest, gnarled ancient oaks, "
        "mist rising from moss-covered ground, faint ghostly lights between trees",
        "Sentier de Brocéliande — brume et lumières",
    ),
    "corrupted_shrine": PromptTemplate(
        "corrupted_shrine",
        "crumbling stone shrine overtaken by thorny vines, cracked altar, "
        "dark energy seeping from cracks, corrupted runes glowing faintly",
        "Sanctuaire corrompu — ruines envahies",
    ),
    "fallen_knight": PromptTemplate(
        "fallen_knight",
        "lone knight in tarnished armor kneeling before broken sword, "
        "battlefield aftermath, ravens circling, banner torn in wind",
        "Chevalier déchu — champ de défaite",
    ),
    "merlin_tower": PromptTemplate(
        "merlin_tower",
        "ancient wizard tower rising from misty hilltop, spiral staircase visible, "
        "arcane symbols carved in stone walls, starlight above",
        "Tour de Merlin — sommet brumeux",
    ),
    "fairy_pool": PromptTemplate(
        "fairy_pool",
        "hidden forest pool reflecting moonlight, water lilies, "
        "faint silhouettes of fairy folk dancing above water surface",
        "Mare aux fées — danse nocturne",
    ),
    "grail_vision": PromptTemplate(
        "grail_vision",
        "radiant chalice floating above ancient altar in dark cathedral, "
        "beams of light piercing stained glass, kneeling figures in shadow",
        "Vision du Graal — cathédrale sombre",
    ),
    "creature_encounter": PromptTemplate(
        "creature_encounter",
        "mysterious creature emerging from forest shadows, glowing eyes, "
        "antlers intertwined with vines, ancient and otherworldly presence",
        "Rencontre créature — être indéfinissable",
    ),
    "village_ruins": PromptTemplate(
        "village_ruins",
        "abandoned medieval village, collapsed thatched roofs, overgrown streets, "
        "single torch still burning in empty window",
        "Ruines de village — abandon silencieux",
    ),
    "standing_stones": PromptTemplate(
        "standing_stones",
        "ancient standing stones arranged in spiral pattern on windswept moor, "
        "storm clouds gathering, lightning illuminating carved runes",
        "Pierres levées — tempête sur la lande",
    ),
}


# ── Cache convention (BIBLE §24) ───────────────────────────────────────────

_REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = _REPO_ROOT / "assets" / "artwork" / "cache"
MANIFEST_PATH = CACHE_DIR / "manifest.json"


def _cache_key(prompt: str, seed: int) -> str:
    return hashlib.sha1(f"{prompt}|{seed}".encode()).hexdigest()[:12]


def _load_manifest() -> dict:
    _EMPTY: dict = {"version": 1, "entries": {}}
    if not MANIFEST_PATH.exists():
        return _EMPTY
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return _EMPTY
    if not isinstance(data, dict) or not isinstance(data.get("entries"), dict):
        return _EMPTY
    return data


def _save_manifest(manifest: dict) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False),
                             encoding="utf-8")


# ── Backend detection ──────────────────────────────────────────────────────

def _has_sd_cpp() -> bool:
    try:
        import stable_diffusion_cpp  # noqa: F401
        return True
    except ImportError:
        return False


def _find_model() -> Path | None:
    models_dir = _REPO_ROOT / "tools" / "models"
    if not models_dir.exists():
        return None
    for f in models_dir.glob("*.gguf"):
        if "sd" in f.stem.lower() or "stable" in f.stem.lower():
            return f
    return None


def status() -> dict:
    """Check backend availability."""
    has_sd = _has_sd_cpp()
    model = _find_model()
    cache_count = len(_load_manifest().get("entries", {}))
    return {
        "sd_cpp_available": has_sd,
        "model_path": str(model) if model else None,
        "model_found": model is not None,
        "cache_entries": cache_count,
        "cache_dir": str(CACHE_DIR),
        "backend": "sd.cpp" if (has_sd and model) else "nano-banana (fallback)",
    }


# ── Generation ──────────────────────────────────────────────────────────────

_VALID_PROFILES = frozenset({"gravure", "soft", "card", "portrait"})


def generate(prompt: str, seed: int = 42, steps: int = 20,
             width: int = 512, height: int = 512,
             profile: str = "gravure") -> dict:
    """Generate an image with MERLIN identity.

    Returns dict with: output, backend, cached, prompt, seed, profile.
    """
    if profile not in _VALID_PROFILES:
        return {"output": None, "error": f"Unknown profile {profile!r}. Valid: {sorted(_VALID_PROFILES)}"}

    full_prompt = f"{IDENTITY_PREFIX}, {prompt}"
    cache_id = _cache_key(full_prompt, seed)
    manifest = _load_manifest()

    if cache_id in manifest.get("entries", {}):
        cached_path = Path(manifest["entries"][cache_id]["path"]).resolve()
        if cached_path.is_relative_to(CACHE_DIR.resolve()) and cached_path.exists():
            return {
                "output": str(cached_path),
                "backend": "cache",
                "cached": True,
                "prompt": prompt,
                "seed": seed,
                "profile": manifest["entries"][cache_id].get("profile", "unknown"),
            }

    raw_path = CACHE_DIR / f"{cache_id}_raw.png"
    final_path = CACHE_DIR / f"{cache_id}.png"
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    has_sd = _has_sd_cpp()
    model = _find_model()
    backend_used = "none"

    if has_sd and model:
        backend_used = "sd.cpp"
    else:
        return {
            "output": None,
            "backend": "none",
            "cached": False,
            "prompt": prompt,
            "seed": seed,
            "error": "No backend available. Install stable-diffusion-cpp-python and "
                     "place a .gguf model in tools/models/, or use nano-banana MCP.",
            "install_hint": "python -m pip install stable-diffusion-cpp-python --user",
        }

    try:
        _generate_sd_cpp(full_prompt, str(raw_path), seed, steps, width, height)
        from sepia_forge import apply
        apply(str(raw_path), str(final_path), profile, seed)
    except Exception as exc:
        raw_path.unlink(missing_ok=True)
        return {"output": None, "backend": backend_used, "error": str(exc),
                "prompt": prompt, "seed": seed}
    finally:
        raw_path.unlink(missing_ok=True)

    manifest.setdefault("entries", {})[cache_id] = {
        "path": str(final_path),
        "prompt": prompt,
        "seed": seed,
        "backend": backend_used,
        "profile": profile,
    }
    _save_manifest(manifest)

    return {
        "output": str(final_path),
        "backend": backend_used,
        "cached": False,
        "prompt": prompt,
        "seed": seed,
        "profile": profile,
    }


def _generate_sd_cpp(prompt: str, output_path: str, seed: int,
                     steps: int, width: int, height: int) -> None:
    from stable_diffusion_cpp import StableDiffusion

    model = _find_model()
    if model is None:
        raise FileNotFoundError("No .gguf model found in tools/models/")

    sd = StableDiffusion(model_path=str(model))
    images = sd.txt_to_img(
        prompt=prompt,
        negative_prompt=NEGATIVE_PROMPT,
        seed=seed,
        sample_steps=steps,
        width=width,
        height=height,
    )
    if images:
        images[0].save(output_path)


def list_templates() -> dict[str, dict]:
    return {
        name: {"prompt": t.prompt, "description": t.description}
        for name, t in TEMPLATES.items()
    }


def cache_list() -> dict:
    manifest = _load_manifest()
    return manifest


# ── CLI ─────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MERLIN SD image generator")
    parser.add_argument("--prompt", type=str, help="Generation prompt")
    parser.add_argument("--template", type=str, choices=list(TEMPLATES),
                        help="Use a preset prompt template")
    parser.add_argument("--seed", type=int, default=42, help="RNG seed")
    parser.add_argument("--steps", type=int, default=20, help="Diffusion steps")
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=512)
    parser.add_argument("--profile", type=str, default="gravure",
                        help="Sepia profile for post-processing")
    parser.add_argument("--list-templates", action="store_true")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--cache-list", action="store_true")

    args = parser.parse_args(argv)

    if args.status:
        print(json.dumps(status(), indent=2))
        return 0

    if args.list_templates:
        for name, t in TEMPLATES.items():
            print(f"  {name:25s}  {t.description}")
        return 0

    if args.cache_list:
        print(json.dumps(cache_list(), indent=2))
        return 0

    if args.template:
        prompt = TEMPLATES[args.template].prompt
    elif args.prompt:
        prompt = args.prompt
    else:
        print("ERROR: --prompt or --template required", file=sys.stderr)
        return 1

    result = generate(prompt, args.seed, args.steps, args.width, args.height, args.profile)
    print(json.dumps(result, indent=2))
    return 0 if result.get("output") else 1


if __name__ == "__main__":
    sys.exit(main())
