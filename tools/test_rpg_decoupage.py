#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests for rpg_decoupage — the acts -> cards -> beats segmentation layer.

Backend-agnostic: operates on a v731-shaped trace dict, so the same module
runs on the native (embedded llama.cpp) trace once the GDExtension .dll lands.

Run:  python -m pytest tools/test_rpg_decoupage.py -q
  or: python tools/test_rpg_decoupage.py     (built-in fallback runner)
"""
from __future__ import annotations
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from rpg_decoupage import build_acts, card_to_beats, decoupage_metrics, ACT_NAMES  # noqa: E402

VERBS = ["Escalader", "Plonger", "Traverser", "Cueillir", "Invoquer"]


def _card(beat: int, movement: int, dc: str = "success") -> dict:
    verb = VERBS[(beat - 1) % len(VERBS)]
    return {
        "beat": beat,
        "movement": movement,
        "transition_prose": f"Transition vers {beat}.",
        "card_uid": f"card_{beat}",
        "type": "NARRATIVE",
        "rarity": "COMMUNE",
        "pole": "druides",
        "emotion": "tension",
        "summary": f"Resume concret de la carte {beat}",
        "prose_long": f"Prose longue immersive de la carte {beat}.",
        "option_signals": [
            {"label": f"{verb} le passage", "verb": verb, "faction": "druides", "signal": "Favorable"},
            {"label": "Observer la scene", "verb": "Observer", "faction": "", "signal": "Neutre"},
            {"label": "Reculer", "verb": "Reculer", "faction": "ankou", "signal": "Risque"},
        ],
        "chosen_option_idx": 0,
        "chosen_option": {"label": f"{verb} le passage", "verb": verb},
        "dc_result": dc,
        "effects_applied": ["ADD_REPUTATION:druides:3", "ADD_ECLATS:2"],
        "resolution_prose": f"Resolution narrative de la carte {beat}.",
        "state_after": {"life": 78, "karma": 1, "factions": {"druides": 53}, "tags": [], "eclats": 5},
    }


def _movement_band(i: int, n: int) -> int:
    pct = i / max(1, n - 1)
    if pct < 0.20:
        return 1
    if pct < 0.45:
        return 2
    if pct < 0.55:
        return 3
    if pct < 0.85:
        return 4
    return 5


def _trace(n: int = 25) -> dict:
    cards = [_card(i + 1, _movement_band(i, n)) for i in range(n)]
    return {
        "version": "test",
        "biome": "broceliande",
        "n_cards": n,
        "cards_played": cards,
        "intro": "Intro de test.",
        "outro": "Outro de test.",
    }


# --- ACT layer --------------------------------------------------------------

def test_build_acts_returns_five_acts_for_full_run():
    acts = build_acts(_trace(25))
    assert len(acts) == 5
    assert [a.index for a in acts] == [1, 2, 3, 4, 5]


def test_build_acts_assigns_every_card_to_exactly_one_act():
    acts = build_acts(_trace(25))
    assert sum(len(a.cards) for a in acts) == 25
    for a in acts:
        assert all(c.act_index == a.index for c in a.cards)


def test_acts_have_concrete_names_not_enigmatic():
    acts = build_acts(_trace(25))
    assert [a.name for a in acts] == [
        "L'Appel", "La Descente", "La Bascule", "L'Épreuve", "Le Dénouement"
    ]


def test_build_acts_returns_five_acts_even_when_a_movement_is_empty():
    # n=8 leaves the pivot band (movement 3) empty; still 5 acts must come back.
    acts = build_acts(_trace(8))
    assert len(acts) == 5
    bascule = acts[2]
    assert bascule.index == 3
    assert bascule.cards == []


# --- BEAT layer -------------------------------------------------------------

def test_card_to_beats_returns_four_ordered_beats():
    beats = card_to_beats(_card(3, 2))
    assert [b.kind for b in beats] == [
        "mise_en_scene", "choix", "resolution", "consequence"
    ]


def test_choix_beat_exposes_three_options_and_the_chosen_index():
    choix = next(b for b in card_to_beats(_card(3, 2)) if b.kind == "choix")
    assert len(choix.data["options"]) == 3
    assert choix.data["chosen_idx"] == 0


def test_resolution_beat_marks_failure_outcome_in_plain_words():
    res = next(b for b in card_to_beats(_card(3, 2, dc="failure")) if b.kind == "resolution")
    assert "Echec" in res.title


def test_resolution_beat_marks_success_outcome_in_plain_words():
    res = next(b for b in card_to_beats(_card(3, 2, dc="success")) if b.kind == "resolution")
    assert "Reussite" in res.title


def test_consequence_beat_humanizes_effects_into_readable_french():
    cons = next(b for b in card_to_beats(_card(3, 2)) if b.kind == "consequence")
    low = cons.text.lower()
    assert "druides" in low          # reputation faction surfaced
    assert "eclat" in low            # currency surfaced
    assert "ADD_REPUTATION" not in cons.text  # raw token NOT shown to player


# --- CAUSAL linking (logique, pas enigmatique) ------------------------------

def test_causal_bridge_links_consecutive_cards_referencing_prior_action():
    acts = build_acts(_trace(25))
    seg_card2 = acts[0].cards[1]
    assert seg_card2.causal_link != ""
    assert "Escalader" in seg_card2.causal_link  # card 1's verb threaded forward


def test_first_card_has_no_backward_causal_link():
    acts = build_acts(_trace(25))
    assert acts[0].cards[0].causal_link == ""


# --- METRICS (variété + logique) --------------------------------------------

def test_metrics_counts_unique_chosen_verbs_for_variety():
    m = decoupage_metrics(build_acts(_trace(25)))
    # fixture cycles 5 verbs across 25 cards -> exactly 5 unique chosen verbs
    assert m["variete"]["unique_verbs"] == 5
    assert m["variete"]["total_cards"] == 25


def test_metrics_logique_causal_coverage_excludes_first_card():
    m = decoupage_metrics(build_acts(_trace(25)))
    assert m["logique"]["causal_links"] == 24
    assert m["logique"]["causal_coverage_pct"] == 96.0


def test_metrics_handles_empty_run_without_dividing_by_zero():
    m = decoupage_metrics(build_acts(_trace(0)))
    assert m["variete"]["total_cards"] == 0
    assert m["logique"]["causal_coverage_pct"] == 0.0


# --- built-in runner (pytest-free fallback) ---------------------------------

if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    passed = failed = 0
    for fn in fns:
        try:
            fn()
            passed += 1
            print(f"PASS {fn.__name__}")
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"FAIL {fn.__name__}: {type(e).__name__}: {e}")
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
