#!/usr/bin/env python3
"""Audit de la sortie RÉELLE du pipeline scénario contre le contrat.

Consomme le dump produit par `tools/godot/conformance_pipeline.gd` (exécution
du vrai code d'équilibrage du jeu, `ScenarioPlanner._balance_skeleton`) et
vérifie, règle par règle, ce que le jeu produit aujourd'hui face à ce
qu'exige `data/ai/scenario_templates.json`.

Deux familles de verdicts, à ne pas confondre :

  CAPACITÉ  — le pipeline peut-il seulement produire la FORME décrite par le
              contrat (longueur, routes, options, checks, effets) ? Un échec
              ici est structurel : aucun réglage ne le corrige.
  RÉGLAGE   — sur ce qu'il produit effectivement, respecte-t-il les règles
              d'équilibrage (caps de types, raretés, placement du légendaire,
              adjacence, arc émotionnel, biais de pôle) ?

Usage :
  godot --headless --path . --script res://tools/godot/conformance_pipeline.gd
  python tools/check_pipeline_output.py --report docs/30_jdr/PIPELINE_OUTPUT_AUDIT.md
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DUMP = REPO / ".tmp_pipeline_output.json"
TPL = REPO / "data/ai/scenario_templates.json"


class Result:
    __slots__ = ("rule", "family", "ok", "detail")

    def __init__(self, rule: str, family: str, ok: bool, detail: str):
        self.rule, self.family, self.ok, self.detail = rule, family, ok, detail

    @property
    def mark(self) -> str:
        return "PASS" if self.ok else "FAIL"


# ─────────────────────────────────────────────────────── règles CAPACITÉ ──

def cap_length(beats: list, tpl: dict, sample: dict) -> Result:
    lengths = tpl["structure_constraints"]["canonical_lengths"]
    n = len(beats)
    return Result(
        "longueur canonique", "CAPACITE", n in lengths,
        f"{n} beats produits ; le contrat attend une longueur parmi {lengths} "
        f"(cible canonique 25 = 5 actes x 5)")


def cap_routes(beats: list, tpl: dict, sample: dict) -> Result:
    has = any("route_mask" in b or "branch_label" in b for b in beats)
    return Result(
        "branchement 3 routes", "CAPACITE", has,
        "aucun champ de branchement (route_mask / branch_label / leads_to_card_id) "
        "sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies"
        if not has else "champs de branchement presents")


def cap_options(beats: list, tpl: dict, sample: dict) -> Result:
    has = any(b.get("options") for b in beats)
    return Result(
        "options portees par le beat", "CAPACITE", has,
        "le squelette ne porte aucune option : les 3 choix sont generes plus tard, "
        "carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario"
        if not has else "options presentes")


def cap_checks(beats: list, tpl: dict, sample: dict) -> Result:
    has = any("check" in o for b in beats for o in (b.get("options") or []))
    return Result(
        "checks de stats (white/red/fatal)", "CAPACITE", has,
        "aucun champ check : les 4 stats Disco et les act gates du contrat ne sont "
        "pas exprimables dans le squelette" if not has else "checks presents")


def cap_acts(beats: list, tpl: dict, sample: dict) -> Result:
    has = any("act" in b for b in beats)
    return Result(
        "actes materialises", "CAPACITE", has,
        "aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de "
        "danger ne sont pas portes par la structure" if not has else "actes presents")


# ─────────────────────────────────────────────────────── règles RÉGLAGE ──

def bal_card_type_caps(beats: list, tpl: dict, sample: dict) -> Result:
    caps = tpl["structure_constraints"]["card_type_caps"]
    n = len(beats)
    types = Counter(b.get("card_type") for b in beats)
    problems = []
    share = types.get("NARRATIVE", 0) / max(n, 1)
    lo, hi = caps["NARRATIVE"]["min_share"], caps["NARRATIVE"]["max_share"]
    if not (lo <= share <= hi + 1e-9):
        problems.append(f"NARRATIVE {share:.0%} hors [{lo:.0%}-{hi:.0%}]")
    for ct, rule in caps.items():
        if "min_count" not in rule:
            continue
        c = types.get(ct, 0)
        if c < rule["min_count"]:
            problems.append(f"{ct}={c} < {rule['min_count']}")
        if c > rule["max_count"]:
            problems.append(f"{ct}={c} > {rule['max_count']}")
    return Result("caps de types de carte", "REGLAGE", not problems,
                  ", ".join(problems) if problems else f"{dict(types)} — conforme")


def bal_adjacency(beats: list, tpl: dict, sample: dict) -> Result:
    no_rep = set(tpl["structure_constraints"]["no_repeat_cardtypes"])
    bad = [f"pos {i}" for i, (a, b) in enumerate(zip(beats, beats[1:]), start=1)
           if a.get("card_type") == b.get("card_type") and a.get("card_type") in no_rep]
    return Result("adjacence des types uniques", "REGLAGE", not bad,
                  ", ".join(bad) if bad else "aucun doublon adjacent")


def bal_rarity(beats: list, tpl: dict, sample: dict) -> Result:
    targets = tpl["structure_constraints"]["rarity_targets"]
    n = len(beats)
    rar = Counter(b.get("rarity") for b in beats)
    drift = []
    for r, target in targets.items():
        actual = rar.get(r, 0) / max(n, 1)
        if abs(actual - target) > 0.15:
            drift.append(f"{r} {actual:.0%} vs {target:.0%}")
    return Result("distribution des raretes", "REGLAGE", not drift,
                  ", ".join(drift) if drift else f"{dict(rar)} — dans la tolerance")


def bal_legendary(beats: list, tpl: dict, sample: dict) -> Result:
    share = tpl["structure_constraints"]["legendary_start_share"]
    n = len(beats)
    threshold = math.ceil(n * share)
    early = [i for i, b in enumerate(beats, start=1)
             if b.get("rarity") == "LEGENDAIRE" and i < threshold]
    present = any(b.get("rarity") == "LEGENDAIRE" for b in beats)
    if not present:
        return Result("placement du LEGENDAIRE", "REGLAGE", False,
                      "aucune carte LEGENDAIRE")
    return Result("placement du LEGENDAIRE", "REGLAGE", not early,
                  f"positions precoces {early} < seuil {threshold}" if early
                  else f"uniquement dans le dernier {(1 - share):.0%}")


def bal_climax(beats: list, tpl: dict, sample: dict) -> Result:
    if not beats:
        return Result("climax", "REGLAGE", False, "aucun beat")
    sc = tpl["structure_constraints"]
    last = beats[-1]
    ok = (last.get("rarity") == sc["climax_rarity"]
          and last.get("card_type") == sc["climax_card_type"])
    return Result("climax LEGENDAIRE + MERLIN_DIRECT", "REGLAGE", ok,
                  f"dernier beat : {last.get('rarity')} / {last.get('card_type')}")


def bal_emotions(beats: list, tpl: dict, sample: dict) -> Result:
    w = tpl["writing_constraints"]
    arc = [b.get("emotion") for b in beats]
    problems = []
    if arc and arc[0] not in w["first_beat_emotions"]:
        problems.append(f"ouverture '{arc[0]}'")
    if arc and arc[-1] not in w["final_beat_emotions"]:
        problems.append(f"finale '{arc[-1]}'")
    reps = sum(1 for a, b in zip(arc, arc[1:]) if a == b)
    if reps:
        problems.append(f"{reps} repetitions consecutives")
    bad = sorted({e for e in arc if e not in w["emotions_allowed"]})
    if bad:
        problems.append(f"emotions inconnues {bad}")
    return Result("arc emotionnel", "REGLAGE", not problems,
                  ", ".join(problems) if problems else "conforme")


def bal_pole_bias(beats: list, tpl: dict, sample: dict) -> Result:
    biome = sample.get("biome_id", "")
    bias = (tpl.get("_biome_pole_bias") or {}).get(biome)
    poles = Counter(b.get("pole") for b in beats)
    dominant = poles.most_common(1)[0][0] if poles else None
    if not bias:
        return Result("biais de pole par biome", "REGLAGE", True,
                      f"repartition {dict(poles)} (dominant observe : {dominant})")
    ok = dominant == bias.get("dominant")
    return Result("biais de pole par biome", "REGLAGE", ok,
                  f"dominant {dominant}, attendu {bias.get('dominant')}")


CAPACITY_RULES = [cap_length, cap_routes, cap_options, cap_checks, cap_acts]
BALANCE_RULES = [bal_card_type_caps, bal_adjacency, bal_rarity, bal_legendary,
                 bal_climax, bal_emotions, bal_pole_bias]


def audit_sample(sample: dict, tpl: dict) -> list:
    beats = (sample.get("balanced") or {}).get("beats", [])
    return [rule(beats, tpl, sample) for rule in CAPACITY_RULES + BALANCE_RULES]


def render_report(payload: dict, tpl: dict, audits: dict) -> str:
    L = ["# Audit de la sortie réelle du pipeline scénario", ""]
    L.append("> Généré par `tools/check_pipeline_output.py` à partir du dump de "
             "`tools/godot/conformance_pipeline.gd`, qui exécute le **vrai code "
             "d'équilibrage du jeu** (`ScenarioPlanner._balance_skeleton`) sans Ollama.")
    L.append("")
    L.append(f"Godot {payload.get('godot_version', '?')} — "
             f"{len(payload.get('samples', []))} échantillons.")
    L.append("")
    L.append("Deux familles de verdicts : **CAPACITÉ** (le pipeline peut-il produire la "
             "forme décrite par le contrat ?) et **RÉGLAGE** (sur ce qu'il produit, "
             "respecte-t-il les règles d'équilibrage ?). Un échec de capacité est "
             "structurel — aucun réglage ne le corrige.")
    L.append("")

    # Synthèse par règle, agrégée sur tous les échantillons
    L.append("## Synthèse par règle")
    L.append("")
    L.append("| Règle | Famille | Échantillons conformes |")
    L.append("|---|---|---|")
    rule_names = [r.rule for r in next(iter(audits.values()))]
    for name in rule_names:
        oks = sum(1 for res in audits.values()
                  for r in res if r.rule == name and r.ok)
        tot = len(audits)
        fam = next(r.family for res in audits.values() for r in res if r.rule == name)
        flag = "" if oks == tot else "  ⚠" if oks else "  ✗"
        L.append(f"| {name} | {fam} | {oks}/{tot}{flag} |")
    L.append("")

    # Détail par échantillon
    L.append("## Détail par échantillon")
    L.append("")
    for sid, res in audits.items():
        sample = next(s for s in payload["samples"]
                      if f"{s['sample_id']}/{s['biome_id']}" == sid)
        failed = [r for r in res if not r.ok]
        head = "conforme" if not failed else f"{len(failed)} règle(s) en échec"
        L.append(f"### `{sid}` — {sample['beats_in']} beats en entrée → "
                 f"{sample['beats_out']} en sortie — {head}")
        L.append("")
        for r in res:
            if not r.ok:
                L.append(f"- **{r.mark}** — {r.rule} : {r.detail}")
        if not failed:
            L.append("- toutes les règles applicables passent")
        L.append("")

    # Constantes du planner vs contrat
    L.append("## Constantes du code vs contrat")
    L.append("")
    pc = payload.get("planner_constants", {})
    sc = tpl["structure_constraints"]
    rows = [
        ("CARD_TYPE_CAPS", pc.get("CARD_TYPE_CAPS"), sc["card_type_caps"]),
        ("RARITY_TARGETS", pc.get("RARITY_TARGETS"), sc["rarity_targets"]),
        ("LEGENDARY_START_SHARE", pc.get("LEGENDARY_START_SHARE"), sc["legendary_start_share"]),
        ("NO_REPEAT_CARDTYPES", pc.get("NO_REPEAT_CARDTYPES"), sc["no_repeat_cardtypes"]),
    ]
    L.append("| Constante | Code | Contrat | Aligné |")
    L.append("|---|---|---|---|")
    for name, code_v, contract_v in rows:
        same = json.dumps(code_v, sort_keys=True) == json.dumps(contract_v, sort_keys=True)
        L.append(f"| `{name}` | `{json.dumps(code_v, ensure_ascii=False)[:60]}` | "
                 f"`{json.dumps(contract_v, ensure_ascii=False)[:60]}` | "
                 f"{'oui' if same else '**non**'} |")
    L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dump", default=str(DUMP))
    ap.add_argument("--templates", default=str(TPL))
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    dump_path = Path(args.dump)
    if not dump_path.exists():
        print(f"Dump introuvable : {dump_path}\n"
              "Lance d'abord :\n"
              "  godot --headless --path . --script res://tools/godot/conformance_pipeline.gd")
        return 2

    payload = json.load(open(dump_path, encoding="utf-8"))
    tpl = json.load(open(args.templates, encoding="utf-8"))
    # Le biais de pôle par biome vit dans le code (BIOME_POLE_BIAS), pas dans le
    # contrat : on l'injecte depuis le dump pour pouvoir le vérifier.
    tpl["_biome_pole_bias"] = payload.get("planner_constants", {}).get("BIOME_POLE_BIAS", {})

    audits = {}
    for s in payload.get("samples", []):
        audits[f"{s['sample_id']}/{s['biome_id']}"] = audit_sample(s, tpl)

    cap_fail = set()
    bal_fail = set()
    for sid, res in audits.items():
        for r in res:
            if not r.ok:
                (cap_fail if r.family == "CAPACITE" else bal_fail).add(r.rule)

    for sid, res in audits.items():
        bad = [r for r in res if not r.ok]
        status = "OK" if not bad else f"{len(bad)} echec(s)"
        print(f"{sid:<38} {status}")
        for r in bad:
            print(f"    [{r.family}] {r.rule} : {r.detail}")

    print()
    print(f"=== Regles de CAPACITE en echec : {len(cap_fail)} ===")
    for r in sorted(cap_fail):
        print(f"  - {r}")
    print(f"=== Regles de REGLAGE en echec : {len(bal_fail)} ===")
    for r in sorted(bal_fail):
        print(f"  - {r}")

    if args.report:
        Path(args.report).write_text(render_report(payload, tpl, audits), encoding="utf-8")
        print(f"\nRapport ecrit : {args.report}")

    return 1 if cap_fail or bal_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
