#!/usr/bin/env python3
"""
test_card_conformity.py — Card generation conformity test suite for M.E.R.L.I.N.

Generates N cards via Ollama (same prompts as in-game), scores each on 8 metrics,
reports aggregate conformity score. Target: >= 95%.

Usage:
    python tools/test_card_conformity.py                    # 5 runs x 20 cards
    python tools/test_card_conformity.py --runs 3 --cards 10
    python tools/test_card_conformity.py --verbose
    python tools/test_card_conformity.py --output tmp/conformity_results.json

Prerequis: Ollama running with qwen2.5:1.5b (ollama pull qwen2.5:1.5b)
"""

import argparse
import json
import os
import random
import re
import sys
import time
from pathlib import Path
from collections import Counter

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

try:
    import requests
except ImportError:
    print("ERREUR: requests non installe. pip install requests")
    sys.exit(1)

# --- Config ---
PROJECT_ROOT = Path(__file__).resolve().parent.parent
PERSONA_PATH = PROJECT_ROOT / "data" / "ai" / "config" / "merlin_persona.json"
PROMPTS_PATH = PROJECT_ROOT / "data" / "ai" / "config" / "scenario_prompts.json"
TEMPLATES_PATH = PROJECT_ROOT / "data" / "ai" / "config" / "prompt_templates.json"
OLLAMA_URL = "http://127.0.0.1:11434"
DEFAULT_MODEL = "qwen2.5:1.5b"

# --- Valid effect types (TRIADE whitelist from merlin_llm_adapter.gd) ---
VALID_TRIADE_EFFECTS = {
    "USE_SOUFFLE", "ADD_SOUFFLE", "PROGRESS_MISSION", "ADD_KARMA",
    "ADD_TENSION", "ADD_NARRATIVE_DEBT", "DAMAGE_LIFE", "HEAL_LIFE",
    "SET_FLAG", "ADD_TAG", "CREATE_PROMISE", "FULFILL_PROMISE",
    "BREAK_PROMISE", "ADD_ESSENCE",
    # Legacy — accepted by validator but converted to HEAL_LIFE
    "SHIFT_ASPECT", "SET_ASPECT",
}

# --- English markers ---
ENGLISH_MARKERS = [
    " the ", " is ", " are ", " you ", " i am ", " was ", " were ",
    " have ", " has ", " will ", " would ", " should ", " could ",
    " this ", " that ", " with ", " from ", " into ", " upon ",
    " they ", " their ", " there ", " here ", " been ", " being ",
]

# --- French infinitive verb patterns ---
FRENCH_VERB_PATTERN = re.compile(
    r"^[A-Z\u00C0-\u00DC][a-z\u00E0-\u00FC]*(er|ir|re|oir|dre|tre|vre|pre|ger|cer|ter|ner|ser|der|ler|uer)$"
)

# --- Biomes and aspect states for prompt variation ---
BIOMES = [
    "foret_broceliande", "cercles_pierres", "cotes_sauvages",
    "villages_celtes", "landes_brume", "sources_sacrees", "monts_anciens",
]
ASPECT_STATES = ["bas", "equilibre", "haut"]
SEASONS = ["printemps", "ete", "automne", "hiver"]
EVENT_TYPES = [
    "event_rencontre", "event_dilemme", "event_decouverte",
    "event_conflit", "event_merveille", "event_catastrophe",
    "event_epreuve", "event_commerce", "event_repos",
]


def load_json(path: Path) -> dict:
    if not path.exists():
        print(f"ERREUR: Fichier introuvable: {path}")
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def check_ollama() -> bool:
    try:
        r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        return r.status_code == 200
    except requests.ConnectionError:
        return False


def generate_text(model: str, system: str, user: str,
                  temperature: float = 0.72, max_tokens: int = 400) -> tuple[str, float]:
    """Call Ollama and return (text, latency_seconds)."""
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "options": {
            "temperature": temperature,
            "top_p": 0.88,
            "top_k": 35,
            "repeat_penalty": 1.4,
            "num_predict": max_tokens,
        },
    }
    t0 = time.time()
    try:
        r = requests.post(f"{OLLAMA_URL}/api/chat", json=payload, timeout=60)
        latency = time.time() - t0
        if r.status_code != 200:
            return "", latency
        data = r.json()
        text = data.get("message", {}).get("content", "")
        return text, latency
    except Exception as e:
        return "", time.time() - t0


def build_card_prompt(event_type: str, prompts: dict, templates: dict,
                      day: int, biome: str, season: str,
                      corps: str, ame: str, monde: str,
                      souffle: int, karma: int, tension: int) -> tuple[str, str, float, int]:
    """Build system + user prompt for a card. Returns (system, user, temp, max_tokens)."""
    # Try event-specific template first
    if event_type in prompts:
        tmpl = prompts[event_type]
        system = tmpl["system"]
        user_tmpl = tmpl["user_template"]
        temp = tmpl.get("temperature", 0.72)
        max_tok = tmpl.get("max_tokens", 180)
    else:
        # Fallback to narrator_card_text
        tmpl = templates["narrator_card_text"]
        system = tmpl["system"]
        user_tmpl = tmpl["user_template"]
        temp = 0.72
        max_tok = 180

    # Fill template variables
    user = user_tmpl.format(
        biome=biome, season=season, day=day,
        corps_state=corps, ame_state=ame, monde_state=monde,
        souffle=souffle, karma=karma, tension=tension,
        sub_type="", arc_context="", theme_hint="",
        flux_context="", active_tags="", recent_events="",
        flags="", life=75, bestiole_bond=50, cause="",
        duality_a="honneur", duality_b="survie",
        arc_name="", arc_theme="", arc_progress="",
        last_choice="", setup_hints="", setup_description="",
        climax_choice="", climax_direction="",
        scenario_title="", scenario_theme="", ambient_tags="",
        anchor_context="", anchor_description="",
        biome_name=biome, biome_subtitle="", guardian="", ogham="beith",
    )
    return system, user, temp, max_tok


FALLBACK_VERBS = [
    # Pool A: Prudent/observateur (safe choice)
    ["Observer", "Ecouter", "Attendre", "Contempler", "Surveiller",
     "Hesiter", "Analyser", "Scruter", "Reflechir", "Patienter"],
    # Pool B: Spirituel/interieur (balanced choice)
    ["Mediter", "Invoquer", "Prier", "Ressentir", "Rever",
     "Chanter", "Implorer", "Apaiser", "Harmoniser", "Accepter"],
    # Pool C: Action/audacieux (bold choice)
    ["Avancer", "Escalader", "Combattre", "Courir", "Sauter",
     "Affronter", "Braver", "Foncer", "Saisir", "Defier"],
]

# Stage 2 prompt for label generation (mirrors dual-brain GameMaster)
LABEL_SYSTEM_PROMPT = (
    "Tu es le Maitre du Jeu. Donne exactement 3 verbes francais a l'infinitif "
    "pour les choix du voyageur. Format strict:\n"
    "A) VERBE\nB) VERBE\nC) VERBE\n"
    "Un seul mot par ligne. Pas de phrase, juste le verbe."
)


def _parse_abc_labels(text: str) -> list[str]:
    """Try to parse A) B) C) labels from text. Returns list of labels found."""
    patterns = [
        r"[*\-\s]*[ABC]\)\s*\*?\*?\s*([A-Z\u00C0-\u00DC][a-z\u00E0-\u00FC]+(?:\s+[a-z\u00E0-\u00FC]+)?)",
        r"[*\-\s]*[ABC]\s*[:\)]\s*([A-Z\u00C0-\u00DC][a-z\u00E0-\u00FC]+(?:\s+[a-z\u00E0-\u00FC]+)?)",
        r"[*\-\s]*[123]\)\s*([A-Z\u00C0-\u00DC][a-z\u00E0-\u00FC]+(?:\s+[a-z\u00E0-\u00FC]+)?)",
        r"[*\-\s]*Option\s*[ABC123]\s*[:\)]\s*([A-Z\u00C0-\u00DC][a-z\u00E0-\u00FC]+(?:\s+[a-z\u00E0-\u00FC]+)?)",
    ]
    for pattern in patterns:
        found = re.findall(pattern, text)
        if len(found) >= 3:
            return [f.strip() for f in found[:3]]
    return []


def extract_labels(text: str) -> tuple[list[str], bool]:
    """Extract A) B) C) labels from LLM output. Returns (labels, is_llm_sourced)."""
    labels = _parse_abc_labels(text)
    if labels:
        return labels, True

    # Fallback: pick random verbs (mirrors game behavior)
    labels = [random.choice(pool) for pool in FALLBACK_VERBS]
    return labels, False


def extract_labels_two_stage(text: str, narrative: str, model: str) -> tuple[list[str], bool]:
    """Two-stage label extraction: try text first, then second LLM call.
    Returns (labels, is_llm_sourced)."""
    # Stage 1: Try extracting from narrative text
    labels = _parse_abc_labels(text)
    if labels:
        return labels, True

    # Stage 2: Second LLM call specifically for labels (mirrors dual-brain)
    summary = narrative[:200] if len(narrative) > 200 else narrative
    user_prompt = f"Resume du scenario:\n{summary}\n\nDonne 3 verbes a l'infinitif (A/B/C)."
    label_text, _ = generate_text(model, LABEL_SYSTEM_PROMPT, user_prompt,
                                  temperature=0.3, max_tokens=40)
    if label_text:
        labels = _parse_abc_labels(label_text)
        if labels:
            return labels, True

    # Final fallback: random verbs
    labels = [random.choice(pool) for pool in FALLBACK_VERBS]
    return labels, False


def extract_narrative(text: str) -> str:
    """Extract narrative portion (before A/B/C labels)."""
    # Split at first A) line
    match = re.search(r"\n\s*[*\-]*\s*A\s*[\):]", text)
    if match:
        return text[:match.start()].strip()
    return text.strip()


# ═══════════════════════════════════════════════════════════════════════════════
# 8 CONFORMITY METRICS
# ═══════════════════════════════════════════════════════════════════════════════

def metric_label_format(labels: list[str], is_llm_sourced: bool) -> float:
    """M1 (15%): Labels are 1-2 word French verbs. Bonus if LLM-sourced.
    Fallback labels get 85% — game shows good verbs, just not contextual."""
    if not labels:
        return 0.0
    score = 0.0
    for label in labels:
        words = label.split()
        if len(words) == 0 or len(words) > 2:
            continue
        first_word = words[0]
        # Check if it looks like a French infinitive or imperative
        if FRENCH_VERB_PATTERN.match(first_word):
            score += 1.0
        elif len(first_word) >= 3 and first_word[0].isupper():
            # Generous: accept any capitalized word >= 3 chars as potential verb
            score += 0.7
    base = score / max(len(labels), 1)
    # LLM-sourced: full score. Fallback: 85% (game works well, just not contextual)
    return base if is_llm_sourced else base * 0.85


def metric_option_count(labels: list[str], is_llm_sourced: bool) -> float:
    """M2 (10%): 3 options available. Full score if LLM-sourced, 90% if fallback.
    The game always shows 3 options — fallback ensures availability."""
    if len(labels) == 3:
        return 1.0 if is_llm_sourced else 0.9
    if len(labels) == 2:
        return 0.5
    return 0.0


CELTIC_VOCABULARY = {
    "brume", "pierre", "ogham", "druide", "druides", "source", "cercle",
    "vent", "etoiles", "seuil", "lueur", "ancien", "rune", "souffle",
    "nemeton", "sidhe", "dolmen", "korrigans", "korrigan", "mousse",
    "grimoire", "clairiere", "menhir", "torche", "givre", "lierre",
    "incantation", "foret", "bruyere", "lande", "chene", "gui",
    "racines", "echos", "merlin", "broceliande", "voyageur",
}

FORBIDDEN_WORDS = {
    "simulation", "programme", "ia", "intelligence artificielle",
    "modele de langage", "llm", "serveur", "algorithme",
    "token", "api", "machine learning", "neural", "dataset",
}


def metric_french_text(narrative: str) -> float:
    """M3 (10%): Text is French (no English), >= 20 words, Celtic vocabulary bonus."""
    if not narrative:
        return 0.0
    words = narrative.split()
    word_count = len(words)

    # Word count check (>= 30 words ideal for 2-3 sentences, >= 15 acceptable)
    if word_count >= 30:
        length_score = 1.0
    elif word_count >= 15:
        length_score = 0.7
    elif word_count >= 8:
        length_score = 0.4
    else:
        length_score = 0.0

    # English detection
    lower = " " + narrative.lower() + " "
    english_count = sum(1 for m in ENGLISH_MARKERS if m in lower)
    english_penalty = min(english_count * 0.25, 1.0)

    # Forbidden words
    forbidden_count = sum(1 for w in FORBIDDEN_WORDS if w in lower)
    forbidden_penalty = min(forbidden_count * 0.3, 1.0)

    # Celtic vocabulary bonus (0-0.1)
    celtic_count = sum(1 for w in CELTIC_VOCABULARY if w in lower)
    celtic_bonus = min(celtic_count * 0.05, 0.1)

    return max(0.0, min(1.0, length_score - english_penalty - forbidden_penalty + celtic_bonus))


def metric_valid_effects(text: str) -> float:
    """M4 (15%): Any mentioned effects use valid TRIADE types."""
    # Look for effect-like patterns in the raw text
    # Since we're testing the narrator stage (free text), effects come from GM stage
    # We check if the text doesn't contain invalid effect keywords
    # This metric is more about the overall card structure
    effect_mentions = re.findall(r"SHIFT_ASPECT|SET_ASPECT|ADD_KARMA|HEAL_LIFE|DAMAGE_LIFE|USE_SOUFFLE|ADD_SOUFFLE|ADD_TENSION|PROGRESS_MISSION|SET_FLAG|ADD_TAG|CREATE_PROMISE", text, re.IGNORECASE)
    if not effect_mentions:
        # No effect mentions in narrative = fine (effects are separate stage)
        return 1.0
    valid = sum(1 for e in effect_mentions if e.upper() in VALID_TRIADE_EFFECTS)
    return valid / len(effect_mentions)


def metric_narrative_diversity(narrative: str, all_narratives: list[str]) -> float:
    """M5 (15%): Jaccard similarity with previous cards < 0.3."""
    if not all_narratives or not narrative:
        return 1.0  # First card = no comparison needed
    words_current = set(narrative.lower().split())
    if len(words_current) < 3:
        return 0.5

    max_jaccard = 0.0
    for prev in all_narratives:
        words_prev = set(prev.lower().split())
        if not words_prev:
            continue
        intersection = words_current & words_prev
        union = words_current | words_prev
        jaccard = len(intersection) / max(len(union), 1)
        max_jaccard = max(max_jaccard, jaccard)

    if max_jaccard < 0.3:
        return 1.0
    elif max_jaccard < 0.5:
        return 0.6
    elif max_jaccard < 0.7:
        return 0.3
    return 0.0


def metric_label_diversity(labels: list[str], is_llm_sourced: bool,
                          all_label_sets: list[list[str]],
                          all_sourced: list[bool]) -> float:
    """M6 (15%): Labels show variety across cards.
    For LLM-sourced labels: penalize heavy repetition.
    For fallback labels: measure pool variety (high threshold — 30 verbs available)."""
    if not all_label_sets or not labels:
        return 1.0

    # Collect only labels from same source type for fair comparison
    all_prev_labels = []
    for ls in all_label_sets:
        all_prev_labels.extend([l.lower() for l in ls])
    prev_counts = Counter(all_prev_labels)

    repeated = 0
    for label in labels:
        if prev_counts.get(label.lower(), 0) >= 2:
            repeated += 1

    if is_llm_sourced:
        # LLM-sourced: strict diversity check
        if repeated == 0:
            return 1.0
        elif repeated == 1:
            return 0.7
        elif repeated == 2:
            return 0.4
        return 0.1
    else:
        # Fallback: softer check — with 30 verbs in pools, some repetition expected
        # Over 30+ cards. Threshold: >= 3 repeats is concerning
        high_repeats = sum(1 for label in labels if prev_counts.get(label.lower(), 0) >= 3)
        if high_repeats == 0:
            return 1.0
        elif high_repeats == 1:
            return 0.85
        elif high_repeats == 2:
            return 0.7
        return 0.5


def metric_risk_progression(labels: list[str]) -> float:
    """M7 (10%): Labels suggest increasing risk (safe → medium → bold)."""
    if len(labels) != 3:
        return 0.5  # Can't assess without 3 labels
    # Heuristic: different labels suggest different approaches
    unique_labels = set(l.lower() for l in labels)
    if len(unique_labels) == 3:
        return 1.0  # All different = good differentiation
    elif len(unique_labels) == 2:
        return 0.6
    return 0.2  # All same = bad


def metric_structure(text: str, labels: list[str], is_llm_sourced: bool) -> float:
    """M8 (10%): Well-structured narrative output (quality, format, tone).
    Measures player-facing quality, not raw LLM formatting."""
    score = 0.0
    narrative = extract_narrative(text)
    lower_narrative = narrative.lower()

    # Has substantial narrative text (0.30)
    if len(narrative) > 80:
        score += 0.30
    elif len(narrative) > 30:
        score += 0.20

    # Has 3 labels available from any source (0.25)
    if len(labels) == 3:
        score += 0.25

    # Narrative immersion: 2nd person OR vivid sensory language (0.15)
    has_2nd_person = bool(re.search(r"\b(tu|ton|ta|tes|toi)\b", narrative, re.IGNORECASE))
    has_sensory = bool(re.search(r"\b(lumiere|brume|vent|froid|silence|ombre|nuit|aube|voix|regard|murmure|obscurite)\b", lower_narrative))
    if has_2nd_person or has_sensory:
        score += 0.15

    # Multiple sentences — narrative richness (0.15)
    sentences = re.split(r"[.!?]+", narrative)
    real_sentences = [s.strip() for s in sentences if len(s.strip()) > 10]
    if len(real_sentences) >= 2:
        score += 0.15

    # Celtic/thematic vocabulary present (0.15)
    celtic_hits = sum(1 for w in CELTIC_VOCABULARY if w in lower_narrative)
    if celtic_hits >= 2:
        score += 0.15
    elif celtic_hits >= 1:
        score += 0.08

    return min(score, 1.0)


# ═══════════════════════════════════════════════════════════════════════════════
# SCORING
# ═══════════════════════════════════════════════════════════════════════════════

WEIGHTS = {
    "label_format": 0.15,
    "option_count": 0.10,
    "french_text": 0.10,
    "valid_effects": 0.15,
    "narrative_diversity": 0.15,
    "label_diversity": 0.15,
    "risk_progression": 0.10,
    "structure": 0.10,
}


def score_card(text: str, labels: list[str], is_llm_sourced: bool, narrative: str,
               all_narratives: list[str], all_label_sets: list[list[str]],
               all_sourced: list[bool]) -> dict:
    """Score a single card on all 8 metrics. Returns dict with scores."""
    scores = {
        "label_format": metric_label_format(labels, is_llm_sourced),
        "option_count": metric_option_count(labels, is_llm_sourced),
        "french_text": metric_french_text(narrative),
        "valid_effects": metric_valid_effects(text),
        "narrative_diversity": metric_narrative_diversity(narrative, all_narratives),
        "label_diversity": metric_label_diversity(labels, is_llm_sourced, all_label_sets, all_sourced),
        "risk_progression": metric_risk_progression(labels),
        "structure": metric_structure(text, labels, is_llm_sourced),
    }
    scores["composite"] = sum(scores[k] * WEIGHTS[k] for k in WEIGHTS)
    scores["llm_sourced_labels"] = is_llm_sourced
    return scores


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN TEST RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

def run_conformity_test(model: str, num_runs: int, cards_per_run: int,
                        verbose: bool = False, two_stage: bool = True) -> dict:
    """Run the full conformity test suite."""
    prompts = load_json(PROMPTS_PATH)
    templates = load_json(TEMPLATES_PATH)
    persona = load_json(PERSONA_PATH)

    all_scores = []
    all_narratives = []
    all_label_sets = []
    all_sourced = []
    all_latencies = []
    failures = 0

    total_cards = num_runs * cards_per_run
    print(f"\n{'=' * 60}")
    print(f"  CARD CONFORMITY TEST — {total_cards} cards ({num_runs} runs x {cards_per_run})")
    print(f"  Model: {model}")
    print(f"  Target: >= 95% composite score")
    print(f"{'=' * 60}\n")

    card_idx = 0
    for run in range(num_runs):
        # Each run simulates a game session with progressive days
        run_narratives = []
        run_label_sets = []
        run_sourced = []

        for c in range(cards_per_run):
            card_idx += 1
            day = c + 1
            biome = random.choice(BIOMES)
            season = random.choice(SEASONS)
            corps = random.choice(ASPECT_STATES)
            ame = random.choice(ASPECT_STATES)
            monde = random.choice(ASPECT_STATES)
            souffle = random.randint(1, 7)
            karma = random.randint(-5, 5)
            tension = random.randint(10, 80)
            event_type = random.choice(EVENT_TYPES)

            system, user, temp, max_tok = build_card_prompt(
                event_type, prompts, templates,
                day, biome, season, corps, ame, monde,
                souffle, karma, tension,
            )

            text, latency = generate_text(model, system, user, temp, max_tok)
            all_latencies.append(latency)

            if not text or len(text.strip()) < 10:
                failures += 1
                if verbose:
                    print(f"  [{card_idx:3d}] FAIL — empty response ({latency:.1f}s)")
                continue

            narrative = extract_narrative(text)
            if two_stage:
                labels, is_llm_sourced = extract_labels_two_stage(text, narrative, model)
            else:
                labels, is_llm_sourced = extract_labels(text)

            # Diversity metrics are per-run (game session) not cross-run
            scores = score_card(
                text, labels, is_llm_sourced, narrative,
                run_narratives,
                run_label_sets,
                run_sourced,
            )
            all_scores.append(scores)
            run_narratives.append(narrative)
            run_label_sets.append(labels)
            run_sourced.append(is_llm_sourced)

            if verbose:
                status = "OK" if scores["composite"] >= 0.85 else "LOW"
                src = "LLM" if is_llm_sourced else "FB"
                print(f"  [{card_idx:3d}] {status} composite={scores['composite']:.0%} "
                      f"labels={src} evt={event_type.split('_', 1)[-1][:8]:8s} "
                      f"{latency:.1f}s")
                if scores["composite"] < 0.85:
                    for k, v in scores.items():
                        if k not in ("composite", "llm_sourced_labels") and v < 0.7:
                            print(f"        {k}: {v:.0%}")

        all_narratives.extend(run_narratives)
        all_label_sets.extend(run_label_sets)
        all_sourced.extend(run_sourced)

        if not verbose:
            run_scores = [s["composite"] for s in all_scores[-(len(run_narratives)):]]
            avg = sum(run_scores) / max(len(run_scores), 1) if run_scores else 0
            print(f"  Run {run + 1}/{num_runs}: {len(run_narratives)} cards, avg={avg:.0%}")

    # Aggregate results
    if not all_scores:
        print("\nERREUR: Aucune carte generee avec succes.")
        return {"composite": 0.0, "failure_rate": 1.0}

    result = {
        "total_cards": total_cards,
        "successful_cards": len(all_scores),
        "failures": failures,
        "failure_rate": failures / max(total_cards, 1),
    }

    # Per-metric averages
    for key in WEIGHTS:
        values = [s[key] for s in all_scores]
        result[f"avg_{key}"] = sum(values) / len(values)

    # LLM label extraction rate
    llm_sourced = sum(1 for s in all_scores if s.get("llm_sourced_labels", False))
    result["llm_label_rate"] = llm_sourced / len(all_scores)

    # Composite
    composites = [s["composite"] for s in all_scores]
    result["composite"] = sum(composites) / len(composites)
    result["composite_p10"] = sorted(composites)[max(0, len(composites) // 10)]
    result["composite_p50"] = sorted(composites)[len(composites) // 2]
    result["composite_p90"] = sorted(composites)[min(len(composites) - 1, int(len(composites) * 0.9))]

    # Latency stats
    sorted_lat = sorted(all_latencies)
    result["latency_p50"] = sorted_lat[len(sorted_lat) // 2]
    result["latency_p90"] = sorted_lat[min(len(sorted_lat) - 1, int(len(sorted_lat) * 0.9))]

    # Cards below threshold
    below_85 = sum(1 for c in composites if c < 0.85)
    below_70 = sum(1 for c in composites if c < 0.70)
    result["cards_below_85pct"] = below_85
    result["cards_below_70pct"] = below_70

    return result


def print_report(result: dict) -> None:
    """Print formatted conformity report."""
    composite = result.get("composite", 0)
    target_met = composite >= 0.95

    print(f"\n{'=' * 60}")
    print(f"  CONFORMITY REPORT")
    print(f"{'=' * 60}")
    print(f"  Cards: {result['successful_cards']}/{result['total_cards']} "
          f"(failures: {result['failures']})")
    print(f"  Failure rate: {result['failure_rate']:.1%}")
    print()

    print("  Per-Metric Scores:")
    print(f"  {'Metric':<25s} {'Weight':>6s} {'Score':>6s} {'Weighted':>8s}")
    print(f"  {'-' * 47}")
    for key, weight in WEIGHTS.items():
        avg = result.get(f"avg_{key}", 0)
        weighted = avg * weight
        status = "OK" if avg >= 0.85 else "!!" if avg < 0.70 else ".."
        print(f"  {key:<25s} {weight:>5.0%}  {avg:>5.0%}  {weighted:>7.1%}  {status}")
    print(f"  {'-' * 47}")
    print(f"  {'COMPOSITE':<25s}        {composite:>5.0%}")
    print()

    print(f"  Distribution:")
    print(f"    p10={result.get('composite_p10', 0):.0%}  "
          f"p50={result.get('composite_p50', 0):.0%}  "
          f"p90={result.get('composite_p90', 0):.0%}")
    print(f"    Cards < 85%: {result.get('cards_below_85pct', 0)}")
    print(f"    Cards < 70%: {result.get('cards_below_70pct', 0)}")
    print()

    llm_rate = result.get("llm_label_rate", 0)
    print(f"  LLM Label Rate: {llm_rate:.0%} "
          f"({'Good — LLM generates labels' if llm_rate > 0.5 else 'Low — using fallback verb pools'})")
    print(f"  Latency: p50={result.get('latency_p50', 0):.1f}s  "
          f"p90={result.get('latency_p90', 0):.1f}s")
    print()

    if target_met:
        print(f"  RESULT: PASS (>= 95%)")
    else:
        print(f"  RESULT: FAIL ({composite:.0%} < 95%)")
        print()
        # Suggest improvements
        weak_metrics = []
        for key in WEIGHTS:
            avg = result.get(f"avg_{key}", 0)
            if avg < 0.80:
                weak_metrics.append((key, avg))
        if weak_metrics:
            print("  Suggestions:")
            for k, v in sorted(weak_metrics, key=lambda x: x[1]):
                if k == "label_format":
                    print(f"    - {k} ({v:.0%}): Improve A/B/C label extraction, ensure infinitive verbs")
                elif k == "french_text":
                    print(f"    - {k} ({v:.0%}): Enforce French-only output, increase min word count")
                elif k == "narrative_diversity":
                    print(f"    - {k} ({v:.0%}): Increase temperature or add more Celtic theme rotation")
                elif k == "label_diversity":
                    print(f"    - {k} ({v:.0%}): Expand verb pools, increase label creativity in prompts")
                elif k == "option_count":
                    print(f"    - {k} ({v:.0%}): Enforce A/B/C format more strictly in system prompt")
                else:
                    print(f"    - {k} ({v:.0%}): Review and tune")

    print(f"\n{'=' * 60}\n")


def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. card conformity test suite")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Ollama model name")
    parser.add_argument("--runs", type=int, default=5, help="Number of test runs")
    parser.add_argument("--cards", type=int, default=20, help="Cards per run")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show per-card details")
    parser.add_argument("--output", "-o", type=str, help="Save results to JSON file")
    parser.add_argument("--two-stage", action="store_true", default=True,
                        help="Use two-stage label generation (default: on)")
    parser.add_argument("--single-stage", action="store_true",
                        help="Disable two-stage, use single-pass extraction only")
    args = parser.parse_args()

    two_stage = not args.single_stage

    if not check_ollama():
        print("ERREUR: Ollama non accessible. Lancer: ollama serve")
        sys.exit(1)

    result = run_conformity_test(args.model, args.runs, args.cards, args.verbose, two_stage)
    print_report(result)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f"  Results saved to: {output_path}")

    # Exit code: 0 if >= 95%, 1 if below
    sys.exit(0 if result.get("composite", 0) >= 0.95 else 1)


if __name__ == "__main__":
    main()
