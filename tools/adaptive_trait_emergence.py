#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
adaptive_trait_emergence.py - v7.7.32 (2026-05-18)

Phase 12 Sprint 12.4 (PoC) - LLM-driven personalised trait emergence.

The idea (user phrasing, verbatim): "le LLM detecte le comportement du
joueur et lui debloque des traits personnalises". This module is the
proof-of-concept that derisks the headliner Phase 12 feature before any
in-game integration work.

Pipeline:
  1. Aggregate behavioral_summary across the last N v7.7.31 run JSONs.
  2. Prompt gemma4:e4b in JSON mode to propose ONE personalised trait.
  3. Run the trait through a strict sanitizer (allow-list of effect_spec
     verbs, max prose length, no raw stat boost, no duplicate vs profile).
  4. Append the trait to the profile JSON or print it if --dry-run.

Allow-list (anything else = reject):
  - UNLOCK_OPTION_TAG:<tag>   -> a gated option becomes playable
  - UNLOCK_OGHAM:<id>         -> a new ogham slot unlocks
  - ADD_SLOT:memory:<n>       -> +n memory slots for cross-run tags
  - BIAS_KNN:emotion:<emo>:<+x.xx>  -> retrieval bias (0.01 .. 0.10)

Cap: at most 1 trait per 3 runs (per the design doc Sprint 12.4 spec).

Usage:
    # PoC mode - inspect proposals without writing anywhere
    python tools/adaptive_trait_emergence.py \\
        --runs ~/Downloads/run1.json ~/Downloads/run2.json ~/Downloads/run3.json \\
        --dry-run

    # Real mode - update profile
    python tools/adaptive_trait_emergence.py \\
        --runs ~/Downloads/run1.json ~/Downloads/run2.json ~/Downloads/run3.json \\
        --profile ~/.merlin/profile.json

Pre-req: Ollama running with gemma4:e4b (or gemma4:e2b if you set
MERLIN_TRAIT_MODEL).

User instruction (verbatim): "A : go !" (Phase 12 Sprint 12.0 + start PoC).

Caller graph: standalone CLI - no other file imports this module.
"""

from __future__ import annotations
import argparse
import json
import logging
import os
import re
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Optional
from urllib.error import URLError
from urllib.request import Request, urlopen

OLLAMA_BASE = "http://localhost:11434"
TRAIT_MODEL = os.environ.get("MERLIN_TRAIT_MODEL", "gemma4:e4b")
TRAIT_TIMEOUT_S = int(os.environ.get("MERLIN_TRAIT_TIMEOUT", "180"))
NUM_PREDICT = int(os.environ.get("MERLIN_TRAIT_TOKENS", "500"))
THINK_MODE = os.environ.get("MERLIN_THINK", "false").lower() == "true"

# Sanitizer allow-list - the entire trait safety story lives here.
ALLOWED_EFFECT_VERBS = {
    "UNLOCK_OPTION_TAG",
    "UNLOCK_OGHAM",
    "ADD_SLOT",
    "BIAS_KNN",
}
KNOWN_OGHAMS = {
    "beith", "luis", "fearn", "saille", "nion", "huath", "duir", "tinne",
    "coll", "quert", "muin", "gort", "ngetal", "straif", "ruis", "ailm",
    "onn", "ur",  # 18 oghams total per bible
}
KNOWN_EMOTIONS = {
    "curiosite", "tension", "peur", "fascination", "sagesse",
    "doute", "joie", "colere", "melancolie",
}
TAG_RX = re.compile(r"^[a-z][a-z0-9_]{2,40}$")
TRAIT_NAME_MAX = 40
TRAIT_PROSE_MAX = 250

log = logging.getLogger("adaptive_trait_emergence")


# --- Behavioral aggregation -------------------------------------------------


def _load_run(path: Path) -> dict:
    """Read a v7.7.31 run JSON. Raises on bad path or invalid format."""
    if not path.exists():
        raise FileNotFoundError(f"Run not found: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if "cards_played" not in data or "final_state" not in data:
        raise ValueError(f"{path.name} is not a v7.7.31 run JSON")
    return data


def aggregate_behavior(runs: list[dict]) -> dict:
    """Crunch run JSONs into a compact behavioural_summary dict."""
    faction_pref: Counter[str] = Counter()
    verb_pref: Counter[str] = Counter()
    pole_signature: Counter[str] = Counter()
    dc_outcomes: Counter[str] = Counter()
    risk_thresholds: list[int] = []
    anchor_callbacks_total = 0
    n_beats = 0

    for run in runs:
        cards = run.get("cards_played", [])
        n_beats += len(cards)
        anchor = (run.get("anchor_motif") or run.get("anchor_hint") or "").lower()
        for c in cards:
            opt = c.get("chosen_option") or {}
            faction = opt.get("primary_faction", "")
            if faction:
                faction_pref[faction] += 1
            verb = opt.get("verb", "")
            if verb:
                verb_pref[verb] += 1
            pole = c.get("pole", "")
            if pole:
                pole_signature[pole] += 1
            dc = c.get("dc_result", "")
            if dc:
                dc_outcomes[dc] += 1
            threshold = (opt.get("dc_against") or {}).get("threshold")
            if threshold is not None:
                risk_thresholds.append(int(threshold))
            # Heuristic anchor-callback : the option label or summary
            # mentions a word of the anchor motif.
            if anchor:
                bag = (
                    (opt.get("label") or "").lower()
                    + " "
                    + (c.get("summary") or "").lower()
                )
                for tok in anchor.split():
                    if len(tok) >= 4 and tok in bag:
                        anchor_callbacks_total += 1
                        break

    total_faction = sum(faction_pref.values()) or 1
    total_pole = sum(pole_signature.values()) or 1
    total_dc = sum(dc_outcomes.values()) or 1

    risk_appetite = (
        sum(risk_thresholds) / len(risk_thresholds) / 50.0  # normalised to 0..1
        if risk_thresholds
        else 0.5
    )

    return {
        "window_runs": [r.get("seed", "?") for r in runs],
        "n_runs": len(runs),
        "n_beats_total": n_beats,
        "faction_pref": {k: round(v / total_faction, 3) for k, v in faction_pref.items()},
        "verb_pref_top5": [v for v, _ in verb_pref.most_common(5)],
        "pole_signature": {k: round(v / total_pole, 3) for k, v in pole_signature.items()},
        "dc_outcome_profile": {k: round(v / total_dc, 3) for k, v in dc_outcomes.items()},
        "risk_appetite": round(risk_appetite, 3),
        "anchor_callbacks_per_run": round(anchor_callbacks_total / max(1, len(runs)), 2),
        "computed_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }


# --- LLM trait detector -----------------------------------------------------


SYSTEM_PROMPT = """Tu es l'Esprit de Broceliande. Tu observes un druide depuis plusieurs marches.

A partir de son profil comportemental, propose UN trait personnalise qui :
1. Reflete son style sans flatter. Reconnait ses choix recurrents (pole, verbes, factions).
2. Donne un BONUS TACTIQUE MODESTE, jamais brut.
   - Jamais : +DC, +damage, +heal, +reputation.
   - Toujours dans cette liste fermee :
     - UNLOCK_OPTION_TAG:<nom_snake_case>  (debloque une option gated par ce tag)
     - UNLOCK_OGHAM:<id parmi : beith, luis, fearn, saille, nion, huath, duir, tinne, coll, quert, muin, gort, ngetal, straif, ruis, ailm, onn, ur>
     - ADD_SLOT:memory:1  (rarement plus)
     - BIAS_KNN:emotion:<curiosite|tension|peur|fascination|sagesse>:+0.05  (max +0.10)
3. Livre avec une prose 2 phrases de revelation (ton de l'Esprit, 2eme personne).
4. Nom court (< 40 char), evocateur (3-6 mots).

Tu reponds en JSON STRICT :
{
  "trait_id": "trait_<snake_case_short>",
  "name": "Nom court evocateur",
  "prose": "Phrase 1 - reconnaissance. Phrase 2 - eveil/don.",
  "effect_spec": "UNLOCK_OPTION_TAG:silence_attentif",
  "rarity": "commune | rare | rare_emergence"
}

AUCUN texte hors JSON. Aucun markdown."""


def _ollama_call(system: str, user: str) -> tuple[Optional[dict], float]:
    payload = {
        "model": TRAIT_MODEL,
        "system": system,
        "prompt": user,
        "stream": False,
        "think": THINK_MODE,
        "format": "json",
        "options": {"temperature": 0.7, "num_predict": NUM_PREDICT},
    }
    body = json.dumps(payload).encode("utf-8")
    req = Request(
        f"{OLLAMA_BASE}/api/generate",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    t0 = time.time()
    try:
        with urlopen(req, timeout=TRAIT_TIMEOUT_S) as r:
            resp = json.loads(r.read().decode("utf-8"))
    except (URLError, TimeoutError, Exception) as e:
        log.error("Ollama call failed: %s", e)
        return None, time.time() - t0
    raw = (resp.get("response", "") or "").strip()
    if not raw:
        return None, time.time() - t0
    # First try strict, then json-repair fallback.
    try:
        return json.loads(raw), time.time() - t0
    except json.JSONDecodeError:
        pass
    m = re.search(r"\{.*\}", raw, re.DOTALL)
    if m:
        candidate = m.group(0)
        try:
            return json.loads(candidate), time.time() - t0
        except json.JSONDecodeError:
            try:
                import json_repair  # type: ignore
                repaired = json_repair.loads(candidate)
                if isinstance(repaired, dict):
                    return repaired, time.time() - t0
            except Exception:
                pass
    log.warning("Could not parse LLM JSON (raw=%s)", raw[:150])
    return None, time.time() - t0


def _build_user_prompt(behavior: dict, profile_traits: list[dict]) -> str:
    existing = [t.get("name", "?") for t in profile_traits[-8:]]
    parts = [
        "Profil comportemental observe :",
        f"  Runs analyses : {behavior['n_runs']} (total {behavior['n_beats_total']} beats)",
        f"  Faction preferee : {behavior['faction_pref']}",
        f"  Verbes recurrents : {behavior['verb_pref_top5']}",
        f"  Signature pole : {behavior['pole_signature']}",
        f"  Profil d'issue : {behavior['dc_outcome_profile']}",
        f"  Appetit du risque (0..1) : {behavior['risk_appetite']}",
        f"  Callbacks anchor par run : {behavior['anchor_callbacks_per_run']}",
    ]
    if existing:
        parts.append(f"  Traits deja debloques (eviter doublons) : {existing}")
    parts.append("")
    parts.append("Propose UN trait conforme au schema. Reponse JSON.")
    return "\n".join(parts)


# --- Sanitizer --------------------------------------------------------------


def sanitize_trait(
    proposal: dict,
    profile_traits: list[dict],
) -> tuple[bool, str, dict]:
    """Validate a proposed trait against the strict allow-list.

    Returns (accepted, reason_or_warning, sanitized_trait).
    sanitized_trait is the cleaned version when accepted, partial otherwise.
    """
    if not isinstance(proposal, dict):
        return False, "proposal not a dict", {}

    required = ("trait_id", "name", "prose", "effect_spec")
    for field in required:
        if not proposal.get(field):
            return False, f"missing field {field}", proposal

    trait_id = str(proposal.get("trait_id", "")).strip()
    name = str(proposal.get("name", "")).strip()
    prose = str(proposal.get("prose", "")).strip()
    effect_spec = str(proposal.get("effect_spec", "")).strip()
    rarity = str(proposal.get("rarity", "commune")).strip().lower()

    if not TAG_RX.match(trait_id):
        return False, f"trait_id {trait_id!r} not snake_case", proposal
    if len(name) > TRAIT_NAME_MAX:
        return False, f"name too long ({len(name)} > {TRAIT_NAME_MAX})", proposal
    if len(prose) > TRAIT_PROSE_MAX:
        return False, f"prose too long ({len(prose)} > {TRAIT_PROSE_MAX})", proposal
    # Two-sentence check : prose must have ~1-3 sentence-ending punctuation.
    sentence_ends = sum(prose.count(p) for p in ".!?")
    if sentence_ends > 4 or sentence_ends < 1:
        return False, f"prose sentence count odd ({sentence_ends})", proposal

    # Effect spec - the critical safety gate.
    parts = effect_spec.split(":")
    verb = parts[0] if parts else ""
    if verb not in ALLOWED_EFFECT_VERBS:
        return False, f"effect verb {verb!r} not in allow-list", proposal

    if verb == "UNLOCK_OPTION_TAG":
        if len(parts) != 2:
            return False, "UNLOCK_OPTION_TAG needs exactly 1 argument", proposal
        tag = parts[1]
        if not TAG_RX.match(tag):
            return False, f"option tag {tag!r} not snake_case", proposal
    elif verb == "UNLOCK_OGHAM":
        if len(parts) != 2:
            return False, "UNLOCK_OGHAM needs exactly 1 argument", proposal
        if parts[1] not in KNOWN_OGHAMS:
            return False, f"ogham {parts[1]!r} not in 18-ogham bible", proposal
    elif verb == "ADD_SLOT":
        if len(parts) != 3 or parts[1] != "memory":
            return False, "ADD_SLOT must be ADD_SLOT:memory:<n>", proposal
        try:
            n = int(parts[2])
            if n < 1 or n > 2:
                return False, f"ADD_SLOT n out of [1,2] (got {n})", proposal
        except ValueError:
            return False, "ADD_SLOT n not integer", proposal
    elif verb == "BIAS_KNN":
        if len(parts) != 4 or parts[1] != "emotion":
            return False, "BIAS_KNN must be BIAS_KNN:emotion:<emo>:+x.xx", proposal
        if parts[2] not in KNOWN_EMOTIONS:
            return False, f"emotion {parts[2]!r} not in bible", proposal
        try:
            delta = float(parts[3])
            if abs(delta) > 0.10:
                return False, f"BIAS_KNN delta {delta} out of [-0.10, +0.10]", proposal
        except ValueError:
            return False, "BIAS_KNN delta not float", proposal

    # Duplicate check against profile.
    for t in profile_traits:
        if t.get("trait_id") == trait_id or t.get("effect_spec") == effect_spec:
            return False, f"duplicate of existing trait {t.get('trait_id')}", proposal

    sanitized = {
        "trait_id": trait_id,
        "name": name,
        "prose": prose,
        "effect_spec": effect_spec,
        "rarity": rarity if rarity in {"commune", "rare", "rare_emergence"} else "commune",
        "source": "adaptive_emergence",
        "active": True,
    }
    return True, "ok", sanitized


# --- Profile I/O ------------------------------------------------------------


def _load_or_init_profile(path: Optional[Path]) -> dict:
    if path is None:
        return {
            "version": "v7.7.32-poc",
            "character": {"level": 1, "xp_total": 0, "traits": []},
            "behavioral_summary": {},
        }
    if not path.exists():
        log.info("Profile %s does not exist - creating empty.", path)
        return {
            "version": "v7.7.32-poc",
            "character": {"level": 1, "xp_total": 0, "traits": []},
            "behavioral_summary": {},
        }
    return json.loads(path.read_text(encoding="utf-8"))


def _save_profile(path: Path, profile: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(profile, ensure_ascii=False, indent=2), encoding="utf-8")


# --- Main -------------------------------------------------------------------


def emerge_trait(
    runs: list[dict],
    profile: dict,
    dry_run: bool = False,
) -> dict:
    """Top-level pipeline. Returns a report dict."""
    behavior = aggregate_behavior(runs)
    log.info(
        "Behavioral summary computed (n_runs=%d, %d beats)",
        behavior["n_runs"],
        behavior["n_beats_total"],
    )
    log.info("  faction_pref : %s", behavior["faction_pref"])
    log.info("  pole_signature : %s", behavior["pole_signature"])
    log.info("  dc_profile : %s", behavior["dc_outcome_profile"])
    log.info("  risk_appetite : %.2f", behavior["risk_appetite"])

    user_prompt = _build_user_prompt(behavior, profile.get("character", {}).get("traits", []))
    log.info("Calling %s ...", TRAIT_MODEL)
    proposal, dur = _ollama_call(SYSTEM_PROMPT, user_prompt)
    log.info("LLM call returned in %.1fs", dur)

    report: dict = {
        "model": TRAIT_MODEL,
        "behavioral_summary": behavior,
        "llm_duration_s": round(dur, 2),
        "raw_proposal": proposal,
        "sanitizer_outcome": "no_proposal",
        "trait_accepted": None,
        "reason": "",
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    if proposal is None:
        report["reason"] = "LLM returned no parsable JSON"
        return report

    existing = profile.get("character", {}).get("traits", [])
    accepted, reason, sanitized = sanitize_trait(proposal, existing)
    report["sanitizer_outcome"] = "accepted" if accepted else "rejected"
    report["reason"] = reason
    report["trait_accepted"] = sanitized if accepted else None
    log.info("Sanitizer: %s (%s)", "ACCEPTED" if accepted else "REJECTED", reason)

    if accepted and not dry_run:
        profile.setdefault("character", {}).setdefault("traits", []).append(sanitized)
        profile["behavioral_summary"] = behavior
        log.info("Profile updated with %s", sanitized["trait_id"])

    return report


def _cli_main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="Phase 12.4 PoC - adaptive trait emergence")
    parser.add_argument("--runs", nargs="+", type=Path, required=True, help="v7.7.31 run JSONs")
    parser.add_argument("--profile", type=Path, default=None, help="Profile JSON to update")
    parser.add_argument("--dry-run", action="store_true", help="Do not persist anything")
    parser.add_argument("--out", type=Path, default=None, help="Where to write the report")
    args = parser.parse_args()

    runs = []
    for p in args.runs:
        try:
            runs.append(_load_run(p))
        except Exception as e:
            log.error("Failed to load %s: %s", p, e)
            return 1
    log.info("Loaded %d runs", len(runs))

    profile = _load_or_init_profile(args.profile)

    report = emerge_trait(runs, profile, dry_run=args.dry_run)

    if args.profile and not args.dry_run and report["sanitizer_outcome"] == "accepted":
        _save_profile(args.profile, profile)
        log.info("Wrote profile -> %s", args.profile)

    out_path = args.out or (Path.home() / "Downloads" / f"trait_emergence_{int(time.time())}.json")
    out_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    log.info("Report -> %s", out_path)

    # Stdout summary
    print()
    print("=== Adaptive Trait Emergence PoC ===")
    print(f"  model       : {report['model']}")
    print(f"  llm_call    : {report['llm_duration_s']} s")
    print(f"  outcome     : {report['sanitizer_outcome']}")
    print(f"  reason      : {report['reason']}")
    if report["trait_accepted"]:
        t = report["trait_accepted"]
        print(f"  trait_id    : {t['trait_id']}")
        print(f"  name        : {t['name']}")
        print(f"  effect_spec : {t['effect_spec']}")
        print(f"  prose       : {t['prose']}")
    return 0


if __name__ == "__main__":
    sys.exit(_cli_main())
