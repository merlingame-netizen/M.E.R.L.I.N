"""Migrate the FastRoute legacy card pool (810 cards across 16 sprint files) to the
RPG-test format used by the new walk_event flow (axis/dc/4-resolutions/minigame).

Reads:  data/cards/fastroute_sprint*.json   (legacy schema)
Writes: data/cards/rpg/{stem}_rpg.json      (RPG-augmented schema)

Augmentation per card (deterministic, no LLM call):
- choices[i]: derived from options[i].verb -> axis (souffle/esprit/coeur)
- dc:        derived from trust_tier         (T0=9, T1=10, T2=11, T3=12)
- resolutions: 4 keys (critical, success, failure, critical_failure)
              templated from the verb + card biome anchor (no per-choice copy
              since runtime selects the resolution text by axis/result tier
              after the choice is made)
- minigame: same axis as the *first* choice (overlay routes by chosen axis at
            play time, but the field is documented at the card level)

Run:
    python tools/migrate_fastroute_to_rpg.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "data" / "cards"
OUT_DIR = ROOT / "data" / "cards" / "rpg"

# Heuristic verb -> axis mapping. Default = esprit.
SOUFFLE_VERBS = {
    "suivre", "courir", "fuir", "frapper", "esquiver", "sauter", "attraper",
    "lancer", "trancher", "viser", "agir", "saisir", "bondir", "plonger",
    "grimper", "fendre", "secouer", "pister", "traverser",
}
ESPRIT_VERBS = {
    "observer", "ecouter", "scruter", "flairer", "dechiffrer", "comprendre",
    "mediter", "reflechir", "deviner", "lire", "etudier", "interpreter",
    "analyser", "deduire", "regarder", "examiner", "evaluer", "noter",
    "raisonner", "reconnaitre",
}
COEUR_VERBS = {
    "saluer", "parler", "negocier", "partager", "accueillir", "ouvrir",
    "rassurer", "apaiser", "consoler", "remercier", "promettre", "jurer",
    "implorer", "supplier", "convaincre", "honorer", "respecter", "donner",
    "echanger", "calmer",
}

# DC derived from trust_tier (T0 = early run, T3 = late). Source: BALANCE_FORMULA.
TIER_DC = {"T0": 9, "T1": 10, "T2": 11, "T3": 12}

# Resolution templates per axis x tier. Each entry has 3 variations selected
# pseudo-randomly via card_id hash so adjacent cards don't read identically.
RESOLUTIONS: dict[str, dict[str, list[str]]] = {
    "souffle": {
        "critical": [
            "Ton corps repond avant que tu n'y penses. Le geste est exact, fluide, presque instinctif. La foret te respecte un instant.",
            "Tu agis vite, et l'instant ne pese plus. Tu sens que les choses se sont alignees sous tes pieds.",
            "Ton souffle se cale sur celui de la foret. Le mouvement coule de toi, et la peur se tait.",
        ],
        "success": [
            "Tu agis. Le mouvement passe. La foret t'a laisse faire ton geste.",
            "Ton corps porte la decision. Tu reussis sans ceremonie.",
            "Tu te lances et tu tiens. C'est suffisant.",
        ],
        "failure": [
            "Le geste manque, juste un peu. Ton souffle se rompt et tu sens le moment se refermer.",
            "Tu trebuches sur ton elan. Rien de grave, mais l'instant glisse entre tes doigts.",
            "Tu agis trop tot ou trop tard. La foret n'attend pas.",
        ],
        "critical_failure": [
            "Tu te blesses dans ton elan. Une douleur sourde, une honte plus chaude encore.",
            "Le mouvement t'echappe. Quelque chose cede sous tes pieds, et tu sais que tu paieras.",
            "Tu tombes. La foret ne pardonne pas l'imprudence aux corps fatigues.",
        ],
    },
    "esprit": {
        "critical": [
            "Tu vois ce que les autres manquent. La forme cachee se decoupe d'un coup, comme une rune sur la peau.",
            "Ton regard se pose la ou il faut, et le sens jaillit. Tu sais sans hesiter.",
            "L'idee s'emboite, parfaite. Tu lis le monde comme une page eclairee de l'interieur.",
        ],
        "success": [
            "Tu comprends. Lentement, mais tu comprends — et c'est suffisant.",
            "La piste se dessine. Tu suis le fil sans le casser.",
            "Le sens vient. Tu le retiens.",
        ],
        "failure": [
            "Tu cherches encore. Le sens flotte, presque la — pas tout a fait.",
            "Ton regard glisse sur la chose sans s'y arreter. Quelque chose t'echappe.",
            "Tu doutes au mauvais moment. La piste s'efface dans la mousse.",
        ],
        "critical_failure": [
            "Tu te trompes — et tu en es certain. Une certitude fausse, pesante.",
            "Tu prends une rune pour une autre. La foret en garde la trace.",
            "Tu te perds dans tes propres deductions. Quand tu releves la tete, l'instant est passe.",
        ],
    },
    "coeur": {
        "critical": [
            "Quelque chose dans ta voix les touche. Plus que d'habitude. La foret enregistre l'echange.",
            "Tu trouves le mot qui ouvre. L'autre cede et te laisse passer le seuil.",
            "Ton geste de paix est entendu. Le silence qui suit est complice.",
        ],
        "success": [
            "On t'ecoute. Tu n'as pas besoin de tout dire.",
            "Tu trouves le ton, et la rencontre prend.",
            "Le lien tient. Pas spectaculaire — vrai.",
        ],
        "failure": [
            "Tes mots tombent a cote. Pas de drame, mais pas de lien non plus.",
            "Tu hesites trop, ou tu en fais trop. L'autre se ferme.",
            "Le moment passe sans s'accrocher. Tu repars seul.",
        ],
        "critical_failure": [
            "Tu blesses sans le vouloir. La foret note la maladresse, et l'autre ne reviendra pas.",
            "Ta voix tremble au pire moment. Quelque chose se brise entre toi et l'autre.",
            "Tu prends ce qui n'etait pas offert. Le visage de l'autre se durcit.",
        ],
    },
}


def verb_to_axis(verb: str) -> str:
    v = verb.lower().strip()
    if v in SOUFFLE_VERBS:
        return "souffle"
    if v in COEUR_VERBS:
        return "coeur"
    if v in ESPRIT_VERBS:
        return "esprit"
    return "esprit"


def pick_variation(card_id: str, axis: str, result_key: str) -> str:
    pool = RESOLUTIONS[axis][result_key]
    seed = sum(ord(c) for c in card_id) + len(result_key)
    return pool[seed % len(pool)]


def derive_dc(trust_tier: str) -> int:
    return TIER_DC.get(trust_tier, 10)


def migrate_card(card: dict[str, Any]) -> dict[str, Any]:
    out = dict(card)
    options = card.get("options", [])
    choices: list[dict[str, Any]] = []
    primary_axis = "esprit"
    for i, opt in enumerate(options):
        verb = str(opt.get("verb", ""))
        axis = verb_to_axis(verb)
        if i == 0:
            primary_axis = axis
        choices.append({
            "label": opt.get("label", ""),
            "verb": verb,
            "axis": axis,
            "dc_offset": 0,
        })
    out["choices"] = choices
    out["dc"] = derive_dc(str(card.get("trust_tier", "T1")))
    card_id = str(card.get("id", ""))
    out["resolutions"] = {
        key: pick_variation(card_id, primary_axis, key)
        for key in ("critical", "success", "failure", "critical_failure")
    }
    out["minigame"] = primary_axis
    out["risk_hint"] = _risk_hint_for(primary_axis)
    return out


def _risk_hint_for(axis: str) -> str:
    return {
        "souffle": "Le corps avant la pensee.",
        "esprit": "Lis avant d'agir.",
        "coeur": "L'orgueil les froisse souvent.",
    }.get(axis, "")


def main() -> int:
    if not SRC_DIR.exists():
        print(f"[ERROR] {SRC_DIR} not found", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sources = sorted(SRC_DIR.glob("fastroute_sprint*.json"))
    if not sources:
        print(f"[WARN] No fastroute_sprint*.json in {SRC_DIR}", file=sys.stderr)
        return 0
    total_in = 0
    total_out = 0
    for src in sources:
        try:
            data = json.loads(src.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"[SKIP] {src.name}: parse error {exc}", file=sys.stderr)
            continue
        if isinstance(data, list):
            cards = data
        elif isinstance(data, dict):
            cards = data.get("cards", [])
        else:
            cards = []
        migrated = [migrate_card(c) for c in cards]
        out_path = OUT_DIR / f"{src.stem}_rpg.json"
        out_path.write_text(json.dumps(migrated, ensure_ascii=False, indent=2), encoding="utf-8")
        total_in += len(cards)
        total_out += len(migrated)
        print(f"[OK]   {src.name:<48} -> {out_path.name:<52} ({len(migrated)} cards)")
    print(f"\n[DONE] {total_out}/{total_in} cards migrated -> {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
