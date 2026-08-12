#!/usr/bin/env bash
# Relevé quotidien des analyseurs — ZÉRO appel au modèle.
#
# Les cinq analyseurs (balance, content_gap, pacing, economy, audit) sont du
# Python déterministe : ils rendent en quelques secondes le nombre de cartes, la
# couverture des factions, les verbes hors liste, la marge de survie, les gains
# par run, les systèmes morts encore vivants. Trois d'entre eux sont désactivés
# comme AGENTS parce qu'un agent coûte un appel au modèle — mais leurs MESURES,
# elles, ne coûtent rien. On les relève tous les jours et le journal compare
# deux relevés : c'est la démonstration « ×2,5 → ×2,0 », sans un token.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
cd "$TOOLS_REPO" || { echo "dépôt d'outillage introuvable"; exit 1; }

OUT="$(nice -n 15 python3 - <<'PY' 2>&1 | tail -1
import json, sys, time
from pathlib import Path
sys.path.insert(0, "tools/gd_agents")
sys.path.insert(0, "tools/gd_agents/analyzers")

CLES = {
    "balance": ("cards", "part_faible", "ratio", "verbes_distincts",
                "verbes_hors_liste_n", "moyenne_amount"),
    "pacing": ("cartes_max_sans_degat", "marge_survie", "echecs_tolerables",
               "victoire_a"),
    "economy": ("faveurs_par_session", "anam_par_run", "multiplicateur_max",
                "cap_declare"),
    "audit": ("survivants_n", "occurrences_totales", "fichiers_analyses"),
    "content_gap": ("cards_total", "cards_for_biome"),
}
releve = {"t": time.strftime("%Y-%m-%d", time.localtime())}
rates = []
for nom, cles in CLES.items():
    try:
        mod = __import__(nom)
        a = mod.analyze()
        for k in cles:
            v = a.get(k)
            if isinstance(v, (int, float)):
                releve[f"{nom}.{k}"] = v
        # Les écarts mécaniques comptent aussi : leur nombre EST une mesure.
        if "code_ecarts" in a:
            releve[f"{nom}.ecarts"] = len(a["code_ecarts"])
    except Exception as exc:
        rates.append(f"{nom}({type(exc).__name__})")

dest = Path.home() / "merlin-memory" / "journal" / "mesures.jsonl"
dest.parent.mkdir(parents=True, exist_ok=True)
# Un relevé par jour : on remplace celui du jour s'il existe déjà.
vieux = []
if dest.exists():
    vieux = [l for l in dest.read_text(encoding="utf-8").splitlines()
             if l.strip() and f'"{releve["t"]}"' not in l.split(",")[0]]
dest.write_text("\n".join(vieux[-400:] + [json.dumps(releve, ensure_ascii=False)]) + "\n",
                encoding="utf-8")
print(f"{len(releve) - 1} mesure(s) relevée(s)"
      + (f" · {len(rates)} analyseur(s) en échec : {', '.join(rates)}" if rates else ""))
PY
)"
RC=$?
echo "$OUT"
exit $RC
