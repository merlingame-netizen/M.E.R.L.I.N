#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
profile_system.py - v7.7.32 (2026-05-18)

Phase 12 Sprint 12.3 - cross-run XP, level, unlocks, traits, memory slots.

This module is the Python-side foundation for the long-term progression loop.
It maintains a single JSON profile (per the PHASE_12 design doc §5) and
exposes a small API the in-game side can mirror in GDScript later (Sprint 12.4).

Public surface:
    Profile.load(path)             -> reads or initialises a profile
    Profile.save(path)             -> writes the JSON
    Profile.grant_xp(amount)       -> add xp, level-up if needed, return list[event]
    Profile.grant_xp_from_run(run) -> compute XP based on a v7.7.31 run JSON
    Profile.add_trait(trait_dict)  -> hook for adaptive_trait_emergence
    Profile.summary()              -> dict for HTML/CLI inspection

XP curve (Slay-the-Spire model - DCs stay fixed, XP only unlocks options):
    total_xp_at_level(L) = 100 * L * L
    => Level 5 = 2 500 XP, level 10 = 10 000, level 30 = 90 000

Unlock palier per level (Sprint 12.3 spec; per AskUserQuestion review 2026-05-18):
    L1  - Starters: 3 oghams (beith, luis, nion), 1 trait slot active
    L3  - +1 trait slot
    L5  - ogham T2 batch 1 (fearn, saille, huath), souffle_max +1, essence_max +5
    L7  - +1 trait slot, +1 memory slot
    L10 - ogham T2 batch 2 (duir, tinne, coll), souffle_max +1, essence_max +5, +1 memory slot
    L15 - ogham T2 batch 3 (quert, muin, gort), souffle_max +1, essence_max +5
    L20 - ogham T3 batch 1 (ngetal, straif, ruis), souffle_max +1, essence_max +5, +1 memory slot
    L25 - ogham T3 batch 2 (ailm, onn, ur), souffle_max +1, essence_max +5
    L30 - prestige

User instruction (verbatim): "l'ordre que tu preconises, go" (Sprint 12.3
+ 12.1 from PHASE_12_RPG_BRANCHING_PLAN.md).

Caller graph:
    - tools/adaptive_trait_emergence.py reads/writes a profile dict that
      MUST match this schema (verified - aligns with PHASE_12 doc §5).
    - Standalone CLI for inspection + manual XP grants.
"""

from __future__ import annotations
import argparse
import json
import logging
import math
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

log = logging.getLogger("profile_system")

DEFAULT_PROFILE_PATH = Path.home() / ".merlin" / "profile.json"
PROFILE_VERSION = "v7.7.32"

# Level-unlock palier (per PHASE_12_PLAN review answers).
LEVEL_UNLOCKS: dict[int, dict] = {
    1: {
        "unlock_oghams": ["beith", "luis", "nion"],
        "souffle_max": 5,
        "essence_max": 20,
        "memory_slots_total": 1,
        "trait_slots_active": 1,
        "_label": "Starter druide",
    },
    3: {
        "trait_slots_active_delta": 1,
        "_label": "Eveil",
    },
    5: {
        "unlock_oghams": ["fearn", "saille", "huath"],
        "souffle_max_delta": 1,
        "essence_max_delta": 5,
        "_label": "Premiere lune",
    },
    7: {
        "trait_slots_active_delta": 1,
        "memory_slots_total_delta": 1,
        "_label": "Memoire ancienne",
    },
    10: {
        "unlock_oghams": ["duir", "tinne", "coll"],
        "souffle_max_delta": 1,
        "essence_max_delta": 5,
        "memory_slots_total_delta": 1,
        "_label": "Sceau de chene",
    },
    15: {
        "unlock_oghams": ["quert", "muin", "gort"],
        "souffle_max_delta": 1,
        "essence_max_delta": 5,
        "_label": "Vigne du temps",
    },
    20: {
        "unlock_oghams": ["ngetal", "straif", "ruis"],
        "souffle_max_delta": 1,
        "essence_max_delta": 5,
        "memory_slots_total_delta": 1,
        "_label": "Voile noir",
    },
    25: {
        "unlock_oghams": ["ailm", "onn", "ur"],
        "souffle_max_delta": 1,
        "essence_max_delta": 5,
        "_label": "Couronne de pin",
    },
    30: {
        "_label": "Prestige - Druide accompli",
    },
}


def total_xp_for_level(level: int) -> int:
    """Cumulative XP required to reach level L (curve : 100 * L * L)."""
    if level <= 0:
        return 0
    return 100 * level * level


def level_from_total_xp(xp_total: int) -> int:
    """Inverse curve - find the highest level reached given total XP."""
    if xp_total <= 0:
        return 1
    return max(1, int(math.sqrt(xp_total / 100)))


def xp_to_next_level(xp_total: int) -> int:
    """Remaining XP until the next level-up."""
    current_level = level_from_total_xp(xp_total)
    needed_total = total_xp_for_level(current_level + 1)
    return max(0, needed_total - xp_total)


# -- XP-from-run heuristic ---------------------------------------------------


def compute_xp_from_run(run: dict) -> tuple[int, dict]:
    """Score a v7.7.31 run JSON into XP.

    Returns (xp, breakdown_dict).

    Components:
      - base_completion : 100 (just finishing the run)
      - dc_success_bonus : 30 per success outcome  (rewards skill)
      - faction_emergence_bonus : 50 if max(faction_rep) >= 10 (clear identity)
      - tag_bonus : 10 per tag acquired (rewards long-game)
      - karma_bonus : 5 per karma point (rewards altruism)
      - life_bonus : 50 if life_essence_final >= 80 (rewards survival)
    """
    breakdown: dict = {"base_completion": 100}
    cards = run.get("cards_played", [])

    dc_success = sum(1 for c in cards if c.get("dc_result") == "success")
    breakdown["dc_success_bonus"] = dc_success * 30

    final_state = run.get("final_state", {})
    fr = final_state.get("faction_rep", {})
    max_rep = max(fr.values()) if fr else 0
    breakdown["faction_emergence_bonus"] = 50 if max_rep >= 10 else 0

    tag_count = len(final_state.get("tags", []))
    breakdown["tag_bonus"] = tag_count * 10

    karma = final_state.get("karma", 0)
    breakdown["karma_bonus"] = max(0, karma) * 5

    life = final_state.get("life_essence", 0)
    breakdown["life_bonus"] = 50 if life >= 80 else 0

    total = sum(breakdown.values())
    return total, breakdown


# -- Profile dataclass -------------------------------------------------------


@dataclass
class Profile:
    """Mutable profile container backed by a JSON file."""

    version: str = PROFILE_VERSION
    character: dict = field(default_factory=dict)
    behavioral_summary: dict = field(default_factory=dict)
    anam: int = 0
    completed_runs: int = 0
    created_at: str = field(default_factory=lambda: time.strftime("%Y-%m-%d %H:%M:%S"))
    last_updated: str = field(default_factory=lambda: time.strftime("%Y-%m-%d %H:%M:%S"))
    _path: Optional[Path] = None

    # ---------- I/O ----------

    @classmethod
    def load(cls, path: Path = DEFAULT_PROFILE_PATH) -> "Profile":
        path = Path(path)
        if not path.exists():
            log.info("Profile %s does not exist - initialising fresh.", path)
            p = cls()
            p._path = path
            p._apply_level_unlocks(target_level=1)
            return p
        raw = json.loads(path.read_text(encoding="utf-8"))
        p = cls(
            version=raw.get("version", PROFILE_VERSION),
            character=raw.get("character", {}),
            behavioral_summary=raw.get("behavioral_summary", {}),
            anam=raw.get("anam", 0),
            completed_runs=raw.get("completed_runs", 0),
            created_at=raw.get("created_at", time.strftime("%Y-%m-%d %H:%M:%S")),
            last_updated=raw.get("last_updated", time.strftime("%Y-%m-%d %H:%M:%S")),
        )
        p._path = path
        if "level" not in p.character:
            p._apply_level_unlocks(target_level=1)
        return p

    def save(self, path: Optional[Path] = None) -> Path:
        path = Path(path) if path else self._path
        if path is None:
            raise ValueError("Profile has no path - call save(path) explicitly.")
        path.parent.mkdir(parents=True, exist_ok=True)
        self.last_updated = time.strftime("%Y-%m-%d %H:%M:%S")
        payload = {
            "version": self.version,
            "character": self.character,
            "behavioral_summary": self.behavioral_summary,
            "anam": self.anam,
            "completed_runs": self.completed_runs,
            "created_at": self.created_at,
            "last_updated": self.last_updated,
        }
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        self._path = path
        return path

    # ---------- XP / level ----------

    def grant_xp(self, amount: int, source: str = "manual") -> list[dict]:
        """Apply XP. Returns a list of events (xp_gain, level_ups, unlocks)."""
        if amount <= 0:
            return []
        events: list[dict] = []
        before_level = self.character.get("level", 1)
        before_total = self.character.get("xp_total", 0)
        after_total = before_total + int(amount)
        after_level = level_from_total_xp(after_total)

        self.character["xp_total"] = after_total
        self.character["level"] = after_level
        self.character["xp_for_next_level"] = xp_to_next_level(after_total)

        events.append({
            "event": "xp_gain",
            "amount": int(amount),
            "source": source,
            "xp_total": after_total,
        })

        for level in range(before_level + 1, after_level + 1):
            self._apply_level_unlocks(level)
            events.append({
                "event": "level_up",
                "level": level,
                "label": LEVEL_UNLOCKS.get(level, {}).get("_label", "(palier)"),
            })

        return events

    def grant_xp_from_run(self, run: dict) -> list[dict]:
        """Convenience : compute XP from a v7.7.31 run + apply."""
        xp, breakdown = compute_xp_from_run(run)
        self.completed_runs += 1
        events = self.grant_xp(xp, source="run")
        events.insert(0, {
            "event": "run_completed",
            "completed_runs": self.completed_runs,
            "xp_breakdown": breakdown,
            "xp_total_from_run": xp,
        })
        return events

    def _apply_level_unlocks(self, target_level: int) -> None:
        """Apply the LEVEL_UNLOCKS palier for a given level."""
        unlocks = LEVEL_UNLOCKS.get(target_level)
        if not unlocks:
            return
        self.character.setdefault("level", target_level)
        self.character.setdefault("xp_total", 0)
        self.character.setdefault("xp_for_next_level", 100)
        self.character.setdefault("unlocked_oghams", [])
        self.character.setdefault("souffle_max", 5)
        self.character.setdefault("essence_max", 20)
        self.character.setdefault("traits", [])
        self.character.setdefault("memory_slots", [])
        self.character.setdefault("memory_slots_total", 0)
        self.character.setdefault("trait_slots_active", 1)

        for key, value in unlocks.items():
            if key == "_label":
                continue
            elif key == "unlock_oghams":
                for ogham in value:
                    if ogham not in self.character["unlocked_oghams"]:
                        self.character["unlocked_oghams"].append(ogham)
            elif key in ("souffle_max", "essence_max", "memory_slots_total", "trait_slots_active"):
                self.character[key] = value
            elif key == "souffle_max_delta":
                self.character["souffle_max"] = self.character.get("souffle_max", 5) + value
            elif key == "essence_max_delta":
                self.character["essence_max"] = self.character.get("essence_max", 20) + value
            elif key == "memory_slots_total_delta":
                self.character["memory_slots_total"] = self.character.get("memory_slots_total", 0) + value
            elif key == "trait_slots_active_delta":
                self.character["trait_slots_active"] = self.character.get("trait_slots_active", 1) + value
        self.character["level"] = max(self.character.get("level", 1), target_level)

    # ---------- Traits + memory ----------

    def add_trait(self, trait: dict) -> bool:
        """Hook for adaptive_trait_emergence. Returns True if added."""
        traits = self.character.setdefault("traits", [])
        existing = {t.get("trait_id") for t in traits}
        if trait.get("trait_id") in existing:
            log.info("Trait %s already in profile - skipping", trait.get("trait_id"))
            return False
        active_count = sum(1 for t in traits if t.get("active"))
        active_cap = self.character.get("trait_slots_active", 1)
        new_trait = dict(trait)
        new_trait.setdefault("acquired_at_run", self.completed_runs)
        new_trait.setdefault("active", active_count < active_cap)
        traits.append(new_trait)
        return True

    def add_memory_slot(self, tag: str, source_run: int) -> bool:
        """Pin a cross-run tag into a memory slot if cap allows."""
        slots = self.character.setdefault("memory_slots", [])
        cap = self.character.get("memory_slots_total", 0)
        if len(slots) >= cap:
            log.info("Memory slots full (%d/%d) - cannot pin %s", len(slots), cap, tag)
            return False
        if any(s.get("tag") == tag for s in slots):
            return False
        slots.append({"tag": tag, "source_run": source_run, "slot_idx": len(slots)})
        return True

    # ---------- Introspection ----------

    def summary(self) -> dict:
        ch = self.character
        return {
            "version": self.version,
            "level": ch.get("level", 1),
            "xp_total": ch.get("xp_total", 0),
            "xp_for_next_level": ch.get("xp_for_next_level", 100),
            "souffle_max": ch.get("souffle_max", 5),
            "essence_max": ch.get("essence_max", 20),
            "n_unlocked_oghams": len(ch.get("unlocked_oghams", [])),
            "unlocked_oghams": ch.get("unlocked_oghams", []),
            "n_traits": len(ch.get("traits", [])),
            "active_traits": [t for t in ch.get("traits", []) if t.get("active")],
            "memory_slots": ch.get("memory_slots", []),
            "anam": self.anam,
            "completed_runs": self.completed_runs,
            "last_updated": self.last_updated,
        }


# -- CLI ---------------------------------------------------------------------


def _cli_main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="MERLIN Sprint 12.3 - profile + XP system")
    parser.add_argument(
        "--profile",
        type=Path,
        default=DEFAULT_PROFILE_PATH,
        help=f"Profile path (default {DEFAULT_PROFILE_PATH})",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("inspect", help="Print profile summary")

    sp_grant = sub.add_parser("grant-xp", help="Add raw XP")
    sp_grant.add_argument("amount", type=int)
    sp_grant.add_argument("--source", default="manual")

    sp_run = sub.add_parser("grant-from-run", help="Compute XP from a v7.7.31 run JSON")
    sp_run.add_argument("run_path", type=Path)

    sub.add_parser("init", help="Force re-initialise the profile (level 1)")

    sub.add_parser("xp-curve", help="Show XP curve for levels 1..30")

    args = parser.parse_args()

    if args.cmd == "xp-curve":
        print(f"{'Level':>5}  {'Cumul XP':>10}  {'Delta':>8}  {'Unlock':>15}")
        prev = 0
        for L in range(1, 31):
            x = total_xp_for_level(L)
            unlock = LEVEL_UNLOCKS.get(L, {}).get("_label", "")
            print(f"{L:>5}  {x:>10}  {x - prev:>8}  {unlock:>15}")
            prev = x
        return 0

    if args.cmd == "init":
        profile = Profile()
        profile._path = args.profile
        profile._apply_level_unlocks(1)
        profile.save()
        log.info("Initialised profile at %s", args.profile)
        print(json.dumps(profile.summary(), ensure_ascii=False, indent=2))
        return 0

    profile = Profile.load(args.profile)

    if args.cmd == "inspect":
        print(json.dumps(profile.summary(), ensure_ascii=False, indent=2))
        return 0

    if args.cmd == "grant-xp":
        events = profile.grant_xp(args.amount, source=args.source)
        profile.save()
        for e in events:
            print(json.dumps(e, ensure_ascii=False))
        return 0

    if args.cmd == "grant-from-run":
        run = json.loads(args.run_path.read_text(encoding="utf-8"))
        events = profile.grant_xp_from_run(run)
        profile.save()
        for e in events:
            print(json.dumps(e, ensure_ascii=False, indent=2))
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(_cli_main())
