#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dedup_and_expand_pool.py - v7.7.31 (2026-05-18)

Phase 11 Sprint 11.1 - pool surgery: collapse 2 994 cards (97 % string-dup) into
~90 canonical buckets, then LLM-write enriched prose variants + DnD-style option
schema for each. Output is the source-of-truth for v7.7.31 retrieval.

Pipeline:
  1. Load `scenarios_reference_broceliande.json` (100 scenarios x ~29 cards).
  2. Group cards by canonical summary string -> ~90 buckets.
  3. For each bucket, call Ollama `gemma4:e2b` with a JSON-mode prompt to produce:
        - 2 prose summary variants (short ~2 phrases, long ~5 phrases)
        - 3 enriched options with DC, 3-outcome effects + prose, gating, cost
  4. Validate JSON; fallback to template if LLM mangles.
  5. Persist `data/ai/cards_meta_v2.json` (idempotent - skip already-enriched
     buckets on rerun, keyed by canonical_summary).

Input  : data/ai/scenarios_reference_broceliande.json
Output : data/ai/cards_meta_v2.json

Caller graph: standalone CLI - no other file imports this module.
See docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md Sprint 11.1.
User instruction (verbatim): "go !" (continuation of Phase 11 ask).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import logging
import os
import re
import sys
import time
from pathlib import Path
from typing import Optional
from urllib.error import URLError
from urllib.request import Request, urlopen

OLLAMA_BASE = "http://localhost:11434"
# gemma4:e4b is more capable on structured JSON; this is offline so latency
# matters less than yield. Override via MERLIN_ENRICH_MODEL env if needed.
LLM_MODEL = os.environ.get("MERLIN_ENRICH_MODEL", "gemma4:e4b")
THINK_MODE = os.environ.get("MERLIN_THINK", "false").lower() == "true"
ROOT = Path(__file__).resolve().parent.parent
INPUT_PATH = ROOT / "data" / "ai" / "scenarios_reference_broceliande.json"
OUTPUT_PATH = ROOT / "data" / "ai" / "cards_meta_v2.json"
PROGRESS_EVERY = 5
LLM_TIMEOUT_S = 240  # gemma4:e4b on JSON mode can take 2-3 min for rich schema

log = logging.getLogger("dedup_and_expand_pool")


# -- Ollama ------------------------------------------------------------------


def _post(endpoint: str, payload: dict, timeout: int = LLM_TIMEOUT_S) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(
        f"{OLLAMA_BASE}{endpoint}",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def llm_json(
    system: str, user: str, num_predict: int = 600
) -> tuple[Optional[dict], float]:
    """Call Ollama with format=json. Returns (parsed dict or None, duration_s)."""
    payload = {
        "model": LLM_MODEL,
        "system": system,
        "prompt": user,
        "stream": False,
        "think": THINK_MODE,
        "format": "json",
        "options": {"temperature": 0.7, "num_predict": num_predict},
    }
    t0 = time.time()
    try:
        resp = _post("/api/generate", payload)
    except (URLError, TimeoutError, Exception) as e:
        log.error("LLM call failed: %s", e)
        return None, time.time() - t0
    raw = (resp.get("response", "") or "").strip()
    if not raw:
        return None, time.time() - t0
    m = re.search(r"\{.*\}", raw, re.DOTALL)
    if not m:
        log.warning("No JSON object in LLM response (got %d chars)", len(raw))
        return None, time.time() - t0
    candidate = m.group(0)
    # Pass 1: strict JSON
    try:
        return json.loads(candidate), time.time() - t0
    except json.JSONDecodeError as strict_err:
        pass
    # Pass 2: json-repair (handles missing commas, unescaped quotes, etc.)
    try:
        import json_repair  # type: ignore
        repaired = json_repair.loads(candidate)
        if isinstance(repaired, dict):
            log.info("json-repair recovered the payload (gemma JSON drift)")
            return repaired, time.time() - t0
    except Exception as repair_err:
        log.warning(
            "JSON repair also failed: %s (preview: %s)",
            repair_err,
            candidate[:200],
        )
    return None, time.time() - t0


# -- Pool dedup --------------------------------------------------------------


def collect_canonicals(scenarios: list[dict]) -> list[dict]:
    """Group cards by summary string. Returns one entry per unique summary."""
    buckets: dict[str, dict] = {}
    for s in scenarios:
        archetype = s.get("archetype_name") or s.get("archetype_id") or ""
        sid = s.get("id", "")
        for c in s.get("cards", []) or []:
            summary = (c.get("summary") or "").strip()
            if not summary:
                continue
            cid = c.get("card_id", "")
            uid = f"{sid}::{cid}"
            bucket = buckets.setdefault(
                summary,
                {
                    "canonical_summary": summary,
                    "source_card_ids": [],
                    "types": set(),
                    "rarities": set(),
                    "poles": set(),
                    "emotions": set(),
                    "archetypes": set(),
                    "sample_options": c.get("options", []) or [],
                },
            )
            bucket["source_card_ids"].append(uid)
            if c.get("type"):
                bucket["types"].add(c.get("type"))
            if c.get("rarity"):
                bucket["rarities"].add(c.get("rarity"))
            if c.get("pole"):
                bucket["poles"].add(c.get("pole"))
            if c.get("emotion"):
                bucket["emotions"].add(c.get("emotion"))
            if archetype:
                bucket["archetypes"].add(archetype)

    canonicals = []
    for summary, b in buckets.items():
        canonicals.append(
            {
                "canonical_summary": summary,
                "source_card_ids": b["source_card_ids"],
                "type": sorted(b["types"])[0] if b["types"] else "NARRATIVE",
                "rarity": sorted(b["rarities"])[0] if b["rarities"] else "COMMUNE",
                "pole": sorted(b["poles"])[0] if b["poles"] else "Neutre",
                "emotion": sorted(b["emotions"])[0] if b["emotions"] else "curiosite",
                "archetype_hint": sorted(b["archetypes"])[0] if b["archetypes"] else "",
                "sample_options": b["sample_options"],
                "source_count": len(b["source_card_ids"]),
            }
        )
    canonicals.sort(key=lambda x: -x["source_count"])
    return canonicals


# -- LLM prompt --------------------------------------------------------------


SYSTEM_PROMPT = """Tu es un game-designer-écrivain pour MERLIN, jeu narratif druidique.

Tu reçois une carte canonique (summary court) et tu produis une version enrichie au format JSON STRICT :

{
  "prose_short": "2 phrases d'ambiance sensorielle, 2eme personne. NE LISTE PAS d'actions explicites.",
  "prose_long":  "4-5 phrases : setup + tension narrative + détail sensoriel. La derniere phrase pose la question/dilemme SANS énumérer les options spécifiques.",
  "anchor_motif": "1-3 mots du motif central de la carte (objet, créature, lieu) pour callbacks ultérieurs",
  "cardinality": 2 ou 3,
  "binary_reason": "si cardinality=2, justifie en 1 phrase pourquoi la situation est binaire (ex: rencontre franche accepter/refuser, fuir/affronter, parler/se taire). Sinon: chaine vide.",
  "options": [
    {
      "label": "verbe d'action court 1-2 mots, doit correspondre exactement au verb",
      "verb": "verbe à l'infinitif minuscule",
      "primary_faction": "druides|anciens|korrigans|niamh|ankou",
      "dc_against": {"pole": "Ordre|Chaos|Liminal|Neutre", "threshold": 15-50},
      "cost": {"souffle": 0-2, "essence": 0-5},
      "success_effects":  ["ADD_REPUTATION:faction:N", "HEAL_LIFE:N", "ADD_TAG:nom_tag"],
      "partial_effects":  ["..."],
      "failure_effects":  ["DAMAGE_LIFE:N", "ADD_REPUTATION:faction:-N"],
      "success_prose": "1-2 phrases narratives du résultat positif",
      "partial_prose": "1-2 phrases du résultat mitigé",
      "failure_prose": "1-2 phrases du résultat négatif"
    }
  ]
}

CONTRAINTES OBLIGATOIRES :
- cardinality = 2 si la situation est NATURELLEMENT binaire (accepter/refuser un don, parler/garder le silence, suivre/abandonner, affronter/fuir). Choisis 2 quand 3 sonnerait forcé.
- cardinality = 3 quand 3 voies distinctes sont organiques (offrir/exiger/échanger, observer/refuser/détourner, etc.).
- Le nombre d'éléments dans "options" DOIT correspondre exactement à cardinality (2 OU 3, jamais autre).
- Chaque option doit avoir une faction primaire DIFFERENTE des autres.
- IMPORTANT : la prose ne doit PAS lister les verbes des options. Ecris l'ambiance et la tension, laisse les boutons révéler les actions concrètes. Pas de "Tu peux X, Y, ou Z" dans prose_long.
- Au moins 1 option avec un trade-off cross-pole (gain faction A, perte faction B).
- DC entre 15 (facile commune) et 50 (épique difficile).
- Effets sous la forme ACTION:CIBLE:VALEUR (verbes : ADD_REPUTATION, HEAL_LIFE, DAMAGE_LIFE, ADD_KARMA, ADD_TAG, PROMISE, ADD_ECLATS).
- Prose en français, 2eme personne du singulier, ton druidique brocéliandien.
- AUCUN texte hors JSON. Pas de markdown, pas de commentaire."""


def build_user_prompt(canonical: dict) -> str:
    return (
        f"Carte canonique à enrichir :\n"
        f"- summary court : {canonical['canonical_summary']}\n"
        f"- type : {canonical['type']}\n"
        f"- rareté : {canonical['rarity']}\n"
        f"- pôle dominant : {canonical['pole']}\n"
        f"- émotion : {canonical['emotion']}\n"
        f"- archétype : {canonical['archetype_hint']}\n"
        f"- options du pool original (à enrichir, pas copier) : "
        f"{', '.join(o.get('label', '') for o in canonical['sample_options'][:3])}\n\n"
        f"Produis le JSON enrichi conformément au schéma."
    )


# -- Validation --------------------------------------------------------------


REQUIRED_OPTION_FIELDS = (
    "label",
    "verb",
    "primary_faction",
    "success_effects",
    "failure_effects",
    "success_prose",
    "failure_prose",
)


def _repair_option(opt: dict, fallback: dict, idx: int) -> dict:
    """Fill missing fields on a partial LLM option from a template fallback."""
    out = dict(opt) if isinstance(opt, dict) else {}
    for field in REQUIRED_OPTION_FIELDS:
        if not out.get(field):
            out[field] = fallback.get(field, "")
    # Sensible defaults for non-required structured fields
    out.setdefault("dc_against", fallback.get("dc_against", {"pole": "Neutre", "threshold": 20}))
    out.setdefault("cost", fallback.get("cost", {"souffle": 0, "essence": 0}))
    out.setdefault("partial_effects", fallback.get("partial_effects", []))
    out.setdefault("partial_prose", fallback.get("partial_prose", ""))
    return out


# Phase 15 - pattern detection for prose that promises specific verbs. When
# the LLM (or the canonical pool's original summary) lists "Tu peux X, Y, Z"
# the buttons must match those verbs. We strip such sentences from prose so
# the buttons become the only source of truth for available actions.
_OPTION_PROMISE_RE = re.compile(
    r"\s*Tu\s+peux\s+[^.!?]{1,200}[.!?]",
    re.IGNORECASE,
)


def _scrub_prose(text: str) -> str:
    """Remove sentences that explicitly list options the buttons don't carry.

    Targets the "Tu peux X, Y, ou Z" pattern that turns into a UI contradiction
    when the button set is independent. Leaves the rest of the prose untouched.
    """
    if not text:
        return text
    scrubbed = _OPTION_PROMISE_RE.sub(" ", text)
    return re.sub(r"\s{2,}", " ", scrubbed).strip()


def validate_enriched(payload: dict, canonical: dict) -> tuple[bool, list[str], dict]:
    """Return (ok, warnings, repaired_payload).

    Lenient on prose, strict on cardinality. Accepts 2 OR 3 options as long
    as the count matches the LLM-declared ``cardinality`` field (default 3 if
    absent for legacy LLM responses).
    """
    warnings: list[str] = []
    if not isinstance(payload, dict):
        return False, ["payload is not a dict"], {}

    fallback = _fallback_enrichment(canonical)
    fb_options = fallback["options"]
    fb_cardinality = len(fb_options)

    repaired = dict(payload)
    # Prose: keep LLM prose if present, else fall back. Scrub option-listing.
    raw_short = (payload.get("prose_short") or fallback["prose_short"]).strip()
    raw_long = (payload.get("prose_long") or fallback["prose_long"]).strip()
    repaired["prose_short"] = _scrub_prose(raw_short)
    repaired["prose_long"] = _scrub_prose(raw_long)
    repaired["anchor_motif"] = (payload.get("anchor_motif") or "").strip()
    if raw_short != repaired["prose_short"] or raw_long != repaired["prose_long"]:
        warnings.append("scrubbed 'Tu peux X, Y, Z' option-promising sentence")

    # Phase 15 - cardinality : LLM declares it, default to 3 for legacy responses.
    raw_cardinality = payload.get("cardinality")
    try:
        cardinality = int(raw_cardinality) if raw_cardinality is not None else 3
    except (ValueError, TypeError):
        cardinality = 3
    if cardinality not in (2, 3):
        warnings.append(f"invalid cardinality {raw_cardinality} - coerced to 3")
        cardinality = 3
    repaired["cardinality"] = cardinality
    repaired["binary_reason"] = (payload.get("binary_reason") or "").strip()

    # Options: take what the LLM gave, repair partial ones, pad to cardinality.
    options = payload.get("options")
    if not isinstance(options, list):
        options = []

    repaired_options: list[dict] = []
    llm_complete_count = 0
    for i in range(cardinality):
        # If fallback has fewer entries, reuse last fallback as padding template.
        fb_template = fb_options[i] if i < fb_cardinality else fb_options[-1]
        llm_opt = options[i] if i < len(options) else {}
        if isinstance(llm_opt, dict) and all(
            llm_opt.get(f) for f in REQUIRED_OPTION_FIELDS
        ):
            llm_complete_count += 1
            repaired_options.append(_repair_option(llm_opt, fb_template, i))
        elif isinstance(llm_opt, dict) and llm_opt:
            warnings.append(f"option {i}: partial - repaired from template")
            repaired_options.append(_repair_option(llm_opt, fb_template, i))
        else:
            warnings.append(f"option {i}: missing - using template")
            repaired_options.append(fb_template)

    repaired["options"] = repaired_options

    # We accept the payload as "ok" if at least the prose came from the LLM
    # AND we have well-formed options matching the cardinality after repair.
    prose_from_llm = bool(payload.get("prose_short")) or bool(payload.get("prose_long"))
    if not prose_from_llm:
        return False, ["no LLM prose at all"] + warnings, repaired

    factions = {o.get("primary_faction") for o in repaired_options}
    if len(factions) < min(2, cardinality):
        warnings.append(f"options share factions ({factions})")
    return True, warnings, repaired


# Sprint 12.5b balance fixes (2026-05-18, from Monte-Carlo report):
# - Fix 4 lite (anciens 92% on greedy)  : rotate the 5 factions per canonical
#   using bucket_hash for determinism, so no single faction dominates fallbacks.
# - Fix 5 (tags P50 = 2)                : every fallback success_effect now
#   includes an ADD_TAG so inter-beat memory accumulates.
# Phase 16 Fix C (2026-05-20) : 4 alternate kits indexed by pole/emotion of
# the canonical, so the player no longer sees the same Accepter/Observer/Refuser
# trio 3+ times per run. Each kit keeps the 5-faction roster so the rotation
# bias from Sprint 12.5b still holds.
_FALLBACK_FACTION_KITS: dict[str, list[dict]] = {
    "default": [
        {"label": "Accepter",  "verb": "accueillir", "faction": "anciens",   "pole": "ordre",   "tag": "geste_accueil"},
        {"label": "Refuser",   "verb": "refuser",    "faction": "ankou",     "pole": "chaos",   "tag": "geste_refus"},
        {"label": "Observer",  "verb": "observer",   "faction": "druides",   "pole": "ordre",   "tag": "regard_attentif"},
        {"label": "Detourner", "verb": "detourner",  "faction": "korrigans", "pole": "chaos",   "tag": "ruse_korrigan"},
        {"label": "Ecouter",   "verb": "ecouter",    "faction": "niamh",     "pole": "liminal", "tag": "appel_niamh"},
    ],
    # Kit "engage" - physical/active confrontation (chaos pole + tension/peur).
    "engage": [
        {"label": "Affronter",  "verb": "affronter",  "faction": "ankou",     "pole": "chaos",   "tag": "geste_defi"},
        {"label": "Apaiser",    "verb": "apaiser",    "faction": "anciens",   "pole": "ordre",   "tag": "geste_paix"},
        {"label": "Provoquer",  "verb": "provoquer",  "faction": "korrigans", "pole": "chaos",   "tag": "ruse_provoc"},
        {"label": "Mesurer",    "verb": "mesurer",    "faction": "druides",   "pole": "ordre",   "tag": "regard_mesure"},
        {"label": "Chanter",    "verb": "chanter",    "faction": "niamh",     "pole": "liminal", "tag": "appel_chant"},
    ],
    # Kit "offrir" - giving/exchanging (liminal pole + sagesse/curiosite).
    "offrir": [
        {"label": "Offrir",     "verb": "offrir",     "faction": "anciens",   "pole": "ordre",   "tag": "geste_offrande"},
        {"label": "Garder",     "verb": "garder",     "faction": "ankou",     "pole": "chaos",   "tag": "geste_retenue"},
        {"label": "Echanger",   "verb": "échanger",   "faction": "druides",   "pole": "ordre",   "tag": "regard_echange"},
        {"label": "Detourner",  "verb": "detourner",  "faction": "korrigans", "pole": "chaos",   "tag": "ruse_detour"},
        {"label": "Negocier",   "verb": "négocier",   "faction": "niamh",     "pole": "liminal", "tag": "appel_negoce"},
    ],
    # Kit "explorer" - movement/discovery (neutre pole + fascination/curiosite).
    "explorer": [
        {"label": "Suivre",     "verb": "suivre",     "faction": "druides",   "pole": "ordre",   "tag": "piste_druidique"},
        {"label": "S'arreter",  "verb": "s'arreter",  "faction": "anciens",   "pole": "ordre",   "tag": "geste_pause"},
        {"label": "Fuir",       "verb": "fuir",       "faction": "korrigans", "pole": "chaos",   "tag": "ruse_fuite"},
        {"label": "Affronter",  "verb": "affronter",  "faction": "ankou",     "pole": "chaos",   "tag": "geste_defi"},
        {"label": "Pleurer",    "verb": "pleurer",    "faction": "niamh",     "pole": "liminal", "tag": "appel_larmes"},
    ],
}


def _pick_kit_id(canonical: dict) -> str:
    """Phase 16 Fix C : pick the verb kit that suits the canonical's pole+emotion.

    Deterministic on (pole, emotion) so the same canonical always uses the
    same kit. The mapping favours thematic fit ; if no rule matches we fall
    back to 'default' (historical Accepter/Refuser/Observer).
    """
    pole = (canonical.get("pole") or "").lower()
    emotion = (canonical.get("emotion") or "").lower()
    if pole == "chaos" and emotion in ("tension", "peur", "colere"):
        return "engage"
    if pole == "liminal" and emotion in ("sagesse", "curiosite", "fascination"):
        return "offrir"
    if pole == "neutre" and emotion in ("fascination", "curiosite", "tension"):
        return "explorer"
    return "default"


# Backwards-compat alias : old callers reference _FALLBACK_FACTION_KIT.
_FALLBACK_FACTION_KIT: list[dict] = _FALLBACK_FACTION_KITS["default"]


def _decide_fallback_cardinality(canonical: dict) -> tuple[int, str]:
    """Phase 15 heuristic binary detection for fallback entries (no LLM).

    Returns (cardinality, binary_reason). PROMISE and ~50% of NARRATIVE COMMUNE
    surface as binary (accept/refuse, hold/release). SHOP / EVENT /
    MERLIN_DIRECT keep 3-option richness. Deterministic on canonical hash.
    """
    type_ = (canonical.get("type") or "").upper()
    rarity = (canonical.get("rarity") or "").upper()
    if type_ == "PROMISE":
        return 2, "Une promesse appelle deux voies : la tenir ou la rompre."
    if type_ == "NARRATIVE" and rarity == "COMMUNE":
        seed = int(_bucket_hash(canonical), 16) % 2
        if seed == 0:
            return 2, "Le moment se resserre sur un choix franc."
    return 3, ""


def _fallback_enrichment(canonical: dict) -> dict:
    """Template fallback when LLM fails. Better than skipping.

    Sprint 12.5b: rotate the 5 factions deterministically using bucket_hash
    so a v2 pool with many fallbacks doesn't collapse to anciens-only. Each
    success_effect now also emits an ADD_TAG so inter-beat memory grows.
    Phase 15 : cardinality is now 2 OR 3 via _decide_fallback_cardinality.
    """
    summary = canonical["canonical_summary"]
    rarity_dc_base = {"COMMUNE": 18, "RARE": 26, "EPIQUE": 38}.get(canonical["rarity"], 22)

    cardinality, binary_reason = _decide_fallback_cardinality(canonical)

    # Phase 16 Fix C : pick the verb kit thematically (pole+emotion). The
    # historical "default" kit is still the fallback, keeping Sprint 12.5b's
    # faction rotation intact for entries that don't match a theme.
    kit_id = _pick_kit_id(canonical)
    kit = _FALLBACK_FACTION_KITS[kit_id]
    # Deterministic N-of-5 faction rotation per canonical (Fix 4 lite).
    rotation_seed = int(_bucket_hash(canonical), 16) % 5
    picked = [kit[(rotation_seed + i) % 5] for i in range(cardinality)]

    # Phase 14 - varied per-verb prose. Each of the 5 fallback verbs gets 3
    # distinct prose tones (success / partial / failure) instead of the
    # single generic "Le moment t'echappe" template. Indexed by verb.
    _PROSE_BY_VERB = {
        "accueillir": {
            "success": "Ta porte intérieure s'ouvre. La forêt te répond par un froissement complice.",
            "partial":  "Tu accueilles à moitié — la part qui reste fermée se souviendra.",
            "failure":  "L'accueil sonne creux. L'autre le sent, et la confiance se replie.",
        },
        "refuser": {
            "success": "Ton non est ferme et clair. La forêt respecte ce qui sait dire non.",
            "partial":  "Le refus tremble. Une porte se ferme à demi, l'autre reste entrebâillée.",
            "failure":  "Tu refuses trop vite. Ce que tu rejettes te revient par derrière.",
        },
        "observer": {
            "success": "Tu vois ce que d'autres traversent sans le voir. La forêt te récompense en silences.",
            "partial":  "L'œil saisit la surface mais manque la racine. Le détail vrai t'échappe encore.",
            "failure":  "Tu restes spectateur trop longtemps. Le moment passe sans toi.",
        },
        "detourner": {
            "success": "Tu glisses entre les pièges comme un korrigan qui rentre chez lui.",
            "partial":  "Le détour fonctionne mais coûte. Tu arrives plus tard, plus las.",
            "failure":  "La ruse se retourne. Ce que tu pensais éviter t'attend au tournant.",
        },
        "ecouter": {
            "success": "Tu entends ce que l'autre ne sait pas encore dire. Niamh hoche la tête.",
            "partial":  "L'écoute est partielle — tu prends les mots, pas la musique.",
            "failure":  "Tu écoutes sans entendre. Le silence qui suit t'accuse.",
        },
    }

    options: list[dict] = []
    for slot, kit in enumerate(picked):
        dc_threshold = rarity_dc_base + slot * 4
        faction = kit["faction"]
        verb = kit["verb"]
        success_eff = [f"ADD_REPUTATION:{faction}:5", f"ADD_TAG:{kit['tag']}"]
        if slot == 2:
            success_eff.append("ADD_KARMA:2")
        elif slot == 0:
            success_eff.append("HEAL_LIFE:2")
        prose_tones = _PROSE_BY_VERB.get(verb, {
            "success": f"Tu choisis de {verb}. La trame se réoriente sans bruit.",
            "partial":  f"Ta tentative de {verb} reste inachevée. Le moment garde sa propre logique.",
            "failure":  f"L'élan de {verb} se brise sur l'instant. Tu paies en certitude.",
        })
        options.append({
            "label": kit["label"],
            "verb": verb,
            "primary_faction": faction,
            "dc_against": {"pole": kit["pole"], "threshold": dc_threshold},
            "cost": {"souffle": slot, "essence": 0},
            "success_effects": success_eff,
            "partial_effects": [f"ADD_REPUTATION:{faction}:2"],
            "failure_effects": ["DAMAGE_LIFE:2"],
            "success_prose": prose_tones["success"],
            "partial_prose": prose_tones["partial"],
            "failure_prose": prose_tones["failure"],
        })

    return {
        "prose_short": _scrub_prose(summary),
        "prose_long": _scrub_prose(summary),
        "anchor_motif": "",
        "cardinality": cardinality,
        "binary_reason": binary_reason,
        "options": options,
        "_source": "fallback_template",
    }


# -- Cache / persistence -----------------------------------------------------


def _bucket_hash(canonical: dict) -> str:
    payload = (
        canonical["canonical_summary"]
        + "|"
        + canonical["type"]
        + "|"
        + canonical["pole"]
        + "|"
        + canonical["emotion"]
    )
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def _load_existing(path: Path) -> dict[str, dict]:
    """Index existing canonicals. Only LLM-source entries with the CURRENT
    schema are reused ; fallback entries (always) and legacy LLM entries
    without the Phase 15 ``cardinality`` field are retried so a re-run
    upgrades them to the binary/ternary co-authored shape.
    """
    if not path.exists():
        return {}
    try:
        prev = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        log.warning("Could not parse existing v2 file (%s) - rebuilding fresh", e)
        return {}
    cache: dict[str, dict] = {}
    for e in prev.get("canonicals", []):
        if e.get("enrichment_source") not in ("llm", "llm_partial"):
            continue
        # Phase 15 schema gate : entries must declare cardinality to be reused.
        if "cardinality" not in e:
            continue
        cache[e["canonical_summary"]] = e
    return cache


def _persist(canonicals_out: list[dict], stats: dict) -> None:
    output = {
        "model": LLM_MODEL,
        "source_pool": INPUT_PATH.name,
        "source_bucket_count": stats["bucket_count"],
        "enriched_count": len(canonicals_out),
        "llm_success": stats["llm_success"],
        "llm_fallback": stats["llm_fallback"],
        "status": "ok" if canonicals_out else "no_canonicals",
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "canonicals": canonicals_out,
    }
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False), encoding="utf-8")


# -- Main --------------------------------------------------------------------


def main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="Phase 11 pool dedup + LLM enrich")
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Process at most N canonicals (default: all)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Group + report stats only, no LLM calls",
    )
    parser.add_argument(
        "--type",
        type=str,
        default=None,
        help=(
            "Phase 16 Fix F : restrict processing to canonicals of this type "
            "(NARRATIVE|EVENT|SHOP|MERLIN_DIRECT|PROMISE). Combined with the "
            "cache invalidation gate, lets you regen one type at a time."
        ),
    )
    args = parser.parse_args()

    if not INPUT_PATH.exists():
        log.error("Input not found: %s", INPUT_PATH)
        return 1
    scenarios = json.loads(INPUT_PATH.read_text(encoding="utf-8"))
    log.info("Loaded %d scenarios", len(scenarios))

    canonicals = collect_canonicals(scenarios)
    bucket_count = len(canonicals)
    total_source = sum(c["source_count"] for c in canonicals)
    log.info(
        "Pool dedup: %d cards -> %d canonical buckets (%.1f%% dup)",
        total_source,
        bucket_count,
        (1 - bucket_count / total_source) * 100 if total_source else 0,
    )
    log.info("Top 5 buckets:")
    for c in canonicals[:5]:
        log.info("  %4dx  %s", c["source_count"], c["canonical_summary"][:80])

    if args.dry_run:
        return 0

    existing = _load_existing(OUTPUT_PATH)
    log.info("Cache: %d existing canonicals", len(existing))

    # Phase 16 Fix F : when --type is set, also load the previous pool so we
    # can preserve OUT-of-scope canonicals verbatim, AND invalidate matching
    # canonicals from the cache so they get re-LLMed.
    fallback_preserved: dict[str, dict] = {}
    if args.type and OUTPUT_PATH.exists():
        try:
            prev_pool = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
            for entry in prev_pool.get("canonicals", []):
                fallback_preserved[entry.get("canonical_summary", "")] = entry
            log.info(
                "Type filter active (%s) - preserving %d untouched canonicals from previous pool",
                args.type, len(fallback_preserved),
            )
        except (json.JSONDecodeError, OSError) as e:
            log.warning("Could not load previous pool for type-filter preservation: %s", e)
        type_upper = args.type.upper()
        cache_canonical_to_type = {
            c["canonical_summary"]: (c.get("type") or "").upper() for c in canonicals
        }
        cache_drops = [
            s for s in list(existing.keys())
            if cache_canonical_to_type.get(s, "") == type_upper
        ]
        for s in cache_drops:
            del existing[s]
        log.info(
            "Type filter : invalidated %d cache entries for re-LLM (type=%s)",
            len(cache_drops), args.type,
        )

    out: list[dict] = []
    stats = {"bucket_count": bucket_count, "llm_success": 0, "llm_fallback": 0}
    process_count = args.limit or bucket_count
    start = time.time()

    for idx, canonical in enumerate(canonicals[:process_count]):
        summary = canonical["canonical_summary"]
        # Phase 16 Fix F : skip canonicals outside the type filter, preserving
        # whatever entry was already in the pool. This lets us regen one type
        # at a time without losing the rest of the pool.
        if args.type and (canonical.get("type") or "").upper() != args.type.upper():
            if summary in fallback_preserved:
                out.append(fallback_preserved[summary])
            continue
        if summary in existing:
            out.append(existing[summary])
            continue

        parsed, dur = llm_json(
            SYSTEM_PROMPT, build_user_prompt(canonical), num_predict=1500
        )
        ok, warnings, repaired = (False, ["no parse"], {})
        if parsed is not None:
            ok, warnings, repaired = validate_enriched(parsed, canonical)

        if ok:
            enriched = repaired
            # Mark as llm-prose even if some options were template-padded.
            enriched["_source"] = "llm" if not any(
                "missing - using template" in w for w in warnings
            ) else "llm_partial"
            stats["llm_success"] += 1
            if warnings:
                log.info(
                    "Bucket %d/%d OK with warnings: %s",
                    idx + 1,
                    process_count,
                    "; ".join(warnings)[:120],
                )
        else:
            log.warning(
                "Bucket %d/%d LLM failed (%s) - using fallback. Summary: %s",
                idx + 1,
                process_count,
                ",".join(warnings)[:80],
                summary[:60],
            )
            enriched = _fallback_enrichment(canonical)
            stats["llm_fallback"] += 1

        entry = {
            "canonical_summary": summary,
            "bucket_hash": _bucket_hash(canonical),
            "source_card_ids": canonical["source_card_ids"],
            "source_count": canonical["source_count"],
            "type": canonical["type"],
            "rarity": canonical["rarity"],
            "pole": canonical["pole"],
            "emotion": canonical["emotion"],
            "archetype_hint": canonical["archetype_hint"],
            "anchor_motif": enriched.get("anchor_motif", ""),
            "prose_short": enriched.get("prose_short", summary),
            "prose_long": enriched.get("prose_long", summary),
            "cardinality": enriched.get("cardinality", len(enriched.get("options", []) or []) or 3),
            "binary_reason": enriched.get("binary_reason", ""),
            "enriched_options": enriched.get("options", []),
            "enrichment_source": enriched.get("_source", "unknown"),
            "llm_duration_s": round(dur, 2),
        }
        out.append(entry)

        if (idx + 1) % PROGRESS_EVERY == 0:
            _persist(out, stats)
            elapsed = time.time() - start
            rate = (idx + 1) / elapsed if elapsed > 0 else 0
            eta = (process_count - (idx + 1)) / rate if rate > 0 else 0
            log.info(
                "%d/%d enriched . %.2f/s . LLM ok=%d fallback=%d . ETA %.0fs",
                idx + 1,
                process_count,
                rate,
                stats["llm_success"],
                stats["llm_fallback"],
                eta,
            )

    _persist(out, stats)
    elapsed = time.time() - start
    log.info(
        "Done. %d canonicals written to %s (%.1f MB) in %.0fs",
        len(out),
        OUTPUT_PATH.name,
        OUTPUT_PATH.stat().st_size / 1024 / 1024,
        elapsed,
    )
    log.info(
        "LLM stats: success=%d, fallback=%d (%.0f%% LLM yield)",
        stats["llm_success"],
        stats["llm_fallback"],
        100 * stats["llm_success"] / max(1, stats["llm_success"] + stats["llm_fallback"]),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
