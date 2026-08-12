#!/usr/bin/env python3
"""Le registre du journal de bord — collecte déterministe, zéro LLM.

Pourquoi ce module existe : le journal n'était JAMAIS stocké. `probes.journal()`
recalculait cinq sources vivantes à chaque appel HTTP, sur une fenêtre dure de
48 h. Aucun récit ne pouvait donc dépasser deux jours, et dès qu'une source
était purgée (l'historique CI garde 15 lignes, le playtest 200 images),
l'événement disparaissait définitivement. Impossible de raconter « la semaine où
la CI est passée au rouge ».

Ici on GRAVE : une fiche de nuit par jour, append-only, hors du dépôt versionné,
dans ~/merlin-memory/journal/ (jamais purgé par le garde-disque).

Le pari, hérité de `runner.py` : **le Python porte les faits, la structure et le
volume ; le modèle ne fait que mettre en mots.** Ce fichier ne parle jamais au
LLM. Il produit une fiche de faits datés, pondérés et déjà rédigés en français —
`journal_gabarits.py` en tire un chapitre lisible, et seule l'étape 5 (le
narrateur de 05:50) l'embellira.

    python3 tools/gd_agents/journal.py --fiche      # voir la matière brute
    python3 tools/gd_agents/journal.py --ecrire     # graver le chapitre du jour

Stdlib seule. Ne lève jamais en lecture.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

BASE = Path.home() / "merlin-memory" / "journal"
CHAPITRES = BASE / "chapitres.jsonl"
FILS = BASE / "fils.json"
VUES = BASE / "vues"

CACHE = Path.home() / ".cache" / "merlin-agents"
PROPS = Path.home() / ".cache" / "merlin-proposals"
JEU = Path.home() / "workspace" / "merlin-game"
OUTILS = Path.home() / "workspace" / "M.E.R.L.I.N"
if not OUTILS.exists():
    OUTILS = HERE.parents[1]

# `20260812-1430-gd-balance-a1b2c3` — le format de proposals.new_id().
ID_PROP = re.compile(r"\b(\d{8}-\d{4}-[a-z0-9-]+?-[0-9a-f]{6})\b")

# Poids : ce qui mérite d'ouvrir un chapitre plutôt que d'y figurer en passant.
POIDS = {"resolution": 5, "echec": 4, "maxime": 4, "integration": 3,
         "parole": 3, "mesure": 2, "production": 1}


# ── outils communs ───────────────────────────────────────────────────────────

def _lire_json(p: Path, defaut):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return defaut


def _lire_jsonl(p: Path, limite: int = 500) -> list[dict]:
    out = []
    try:
        for ligne in p.read_text(encoding="utf-8").splitlines()[-limite:]:
            if ligne.strip():
                try:
                    out.append(json.loads(ligne))
                except Exception:
                    continue
    except Exception:
        pass
    return out


def _ts(s) -> float:
    """Horodatage ISO ou epoch → float. 0 si illisible."""
    try:
        return float(s)
    except (TypeError, ValueError):
        pass
    try:
        return time.mktime(time.strptime(str(s)[:19], "%Y-%m-%dT%H:%M:%S"))
    except Exception:
        return 0.0


def _heure(t: float) -> str:
    return time.strftime("%Hh%M", time.localtime(t))


def _git(*args, cwd: Path | None = None, timeout: int = 15) -> str:
    # `cwd=JEU` en valeur par défaut figerait le chemin au moment où Python lit
    # la définition : une redirection ultérieure de JEU (tests, autre clone)
    # serait ignorée en silence, et la collecte rendrait zéro commit sans dire
    # pourquoi. On résout à l'appel.
    try:
        p = subprocess.run(["git", "-C", str(cwd or JEU), *args],
                           capture_output=True, text=True, timeout=timeout)
        return p.stdout if p.returncode == 0 else ""
    except Exception:
        return ""


def _fait(t: float, acteur: str, type_: str, titre: str, detail: str = "",
          fil: str = "", refs=None, image: str = "", origine: str = "") -> dict:
    # `origine` dit de QUELLE source vient le fait. Sans elle, compter les
    # « changements entrés dans le jeu » additionnait les commits ET les jalons
    # « patchée »/« poussée » du même changement — un facteur deux ou trois.
    return {"t": t, "heure": _heure(t), "acteur": acteur, "type": type_,
            "poids": POIDS.get(type_, 1), "titre": titre[:180],
            "detail": detail[:600], "fil": fil, "refs": refs or [],
            "image": image, "origine": origine}


# ── les collecteurs, un par source ───────────────────────────────────────────

def _commits(depuis: float) -> tuple[list[dict], dict]:
    """Commits du jeu + INDEX DE CAUSALITÉ.

    Le corps du message (`%b`) porte déjà l'identifiant de la proposition —
    `coder_local.py` y écrit « Proposition <id> acceptée », `proposals.py`
    « merge(auto): … — <id> ». Personne ne le lisait : `probes.py` demandait
    `%ct|%h|%s` et jetait `%b`. C'est de là que vient tout le chaînage
    « ce commit vient de la décision que tu as prise mardi ».

    RÈGLE ABSOLUE : un commit sans identifiant est un « chantier libre ».
    On ne devine JAMAIS à quelle décision il se rattache."""
    if not (JEU / ".git").exists():
        return [], {}
    brut = _git("log", f"--since=@{int(depuis)}", "--all",
                "--format=%x1e%H%x1f%ct%x1f%s%x1f%b")
    faits, index = [], {}
    for bloc in brut.split("\x1e"):
        if not bloc.strip():
            continue
        parts = bloc.split("\x1f")
        if len(parts) < 3:
            continue
        sha, ct, sujet = parts[0].strip(), parts[1].strip(), parts[2].strip()
        corps = parts[3] if len(parts) > 3 else ""
        ids = ID_PROP.findall(corps)
        auto = sujet.startswith(("auto(", "merge(auto)"))
        for pid in ids:
            index.setdefault(pid, []).append(sha[:8])
        faits.append(_fait(
            _ts(ct), "le codeur" if auto else "le dépôt",
            "integration" if ids else "production",
            _sujet_lisible(sujet),
            ("suite à ta décision « " + ids[0] + " »") if ids
            else "chantier libre — aucune décision rattachée",
            fil=("proposition:" + ids[0]) if ids else "",
            refs=[sha[:8]] + ids, origine="commit"))
    return faits, index


def _sujet_lisible(s: str) -> str:
    """« feat(forge): generate --model e4b » → « Generate --model e4b »."""
    s = re.sub(r"^\w+(\([\w./-]+\))?\s*:\s*", "", s.strip())
    return (s[:1].upper() + s[1:])[:150] if s else "(sans titre)"


def _decisions(depuis: float) -> list[dict]:
    """Propositions décidées + leur PARCOURS horodaté.

    `trail[]` est la matière narrative la plus riche du système — acceptée à
    2 h 10, patchée à 2 h 12, smoke rouge à 2 h 14, annulée — et il n'entrait
    nulle part dans le journal."""
    faits = []
    for dossier, issue in ((PROPS / "accepted", "acceptée"),
                           (PROPS / "rejected", "écartée")):
        if not dossier.exists():
            continue
        for f in dossier.glob("*.json"):
            p = _lire_json(f, {})
            if not p:
                continue
            # On date sur `decided_at`, JAMAIS sur la date du fichier : le codeur
            # réécrit chaque proposition à chaque étape qu'il grave, ce qui
            # rafraîchit toutes les dates de fichier d'un coup. Filtrer dessus
            # faisait passer 39 décisions vieilles de plusieurs jours pour
            # « 39 décisions de ta main cette nuit ».
            if _ts(p.get("decided_at")) < depuis:
                continue
            fil = "proposition:" + str(p.get("id", ""))
            t0 = _ts(p.get("decided_at") or p.get("created"))
            raison = str(p.get("decision_reason", "")).strip()
            mienne = not raison.lstrip().startswith("auto ")
            verbe = "accepté" if issue == "acceptée" else "écarté"
            faits.append(_fait(
                t0, "toi" if mienne else "la chaîne", "maxime" if mienne else "production",
                f"Tu as {verbe} : {p.get('title', '')}" if mienne
                else f"Intégré automatiquement : {p.get('title', '')}",
                (f"tes mots : « {raison} »" if (mienne and raison) else
                 str(p.get("claim", ""))),
                fil=fil, refs=[p.get("id", "")]))
            # Chaque étape du parcours devient un fait à part entière.
            for e in (p.get("trail") or []):
                pas = str(e.get("step", ""))
                if pas in ("acceptée", "écartée"):
                    continue          # déjà porté par le fait ci-dessus
                dur = pas in ("smoke rouge", "poussée KO", "écartée",
                              "sans suite automatique")
                faits.append(_fait(
                    _ts(e.get("t")), "le codeur",
                    "echec" if dur else "resolution" if pas == "fusionnée" else "integration",
                    f"{p.get('title', '')[:80]} — {pas}",
                    str(e.get("detail", "")), fil=fil, refs=[p.get("id", "")]))
    return faits


def _agents(depuis: float) -> list[dict]:
    """Passages d'agents. Leur `summary` est UNE PHRASE FRANÇAISE écrite par
    l'agent lui-même — on ne la reformule pas, on la cite."""
    faits = []
    for f in (CACHE / "state").glob("*.json") if (CACHE / "state").exists() else []:
        st = _lire_json(f, {})
        t = _ts(st.get("last_run"))
        if t < depuis or not st.get("summary"):
            continue
        resume = str(st["summary"]).strip()
        if resume.lstrip().startswith("{"):          # certains résument en JSON
            resume = _json_en_phrase(resume)
        # Un agent qui n'a rien dit ne fournit pas un fait : « (sans résumé) »
        # est un marqueur d'absence, pas un événement. Le raconter donnerait un
        # chapitre entier construit sur du vide.
        if not resume or resume.strip("()").lower().startswith(("sans résumé", "sans resume")):
            continue
        echec = st.get("ok") is False
        faits.append(_fait(t, st.get("id", f.stem), "echec" if echec else "production",
                           resume, "", fil=f"agent:{st.get('id', f.stem)}"))
    return faits


def _json_en_phrase(brut: str) -> str:
    o = _lire_json_str(brut)
    if not isinstance(o, dict):
        return ""
    acc, rej = o.get("accepted"), o.get("rejected")
    if acc is not None:
        return f"{acc} carte(s) écrite(s)" + (f", {rej} refusée(s)" if rej else "")
    if o.get("skipped"):
        return f"passage sauté ({o['skipped']})"
    return ""


def _lire_json_str(s: str):
    try:
        return json.loads(s)
    except Exception:
        return None


def _ci(depuis: float) -> list[dict]:
    """Verdicts du vérificateur : le nom de la scène qui casse et le diagnostic
    français du LLM local étaient réduits à « Le test a échoué ✗ »."""
    faits = []
    for r in _lire_jsonl(CACHE / "ci" / "history.jsonl", 40):
        t = _ts(r.get("t"))
        if t < depuis:
            continue
        ko = int(r.get("scenes_failing") or 0)
        sha = str(r.get("sha", ""))[:8]
        scenes = _scenes_en_echec(sha)
        faits.append(_fait(
            t, "le vérificateur", "echec" if ko else "resolution",
            (f"{ko} scène refuse de démarrer" if ko == 1 else
             f"{ko} scènes refusent de démarrer" if ko
             else f"Les {r.get('scenes_total', '?')} scènes démarrent"),
            " · ".join(x for x in [str(r.get("diag", "")).strip(),
                                   ("scènes : " + ", ".join(scenes)) if scenes else ""] if x),
            fil=("scene:" + scenes[0]) if scenes else "ci",
            refs=[sha],
            image=f"/api/ci/shot/{sha}" if r.get("shot") else ""))
    return faits


def _scenes_en_echec(sha: str) -> list[str]:
    """En-têtes « === <Scene>.tscn === » du log d'erreurs d'un commit."""
    f = CACHE / "ci" / f"{sha}-errors.log"
    try:
        txt = f.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return []
    return list(dict.fromkeys(re.findall(r"===\s*([\w/.-]+\.tscn)\s*===", txt)))[:3]


def _rejets(depuis: float) -> list[dict]:
    """Cartes recalées par le validateur : le motif exact dit ce que le modèle
    rate, et c'est le meilleur sujet de conversation avec Maxime."""
    src = OUTILS / "data" / "ai" / "training" / "auto_rejects.jsonl"
    motifs: dict[str, int] = {}
    dernier = 0.0
    for r in _lire_jsonl(src, 300):
        t = _ts(r.get("ts"))
        if t < depuis:
            continue
        dernier = max(dernier, t)
        for e in (r.get("errors") or [])[:2]:
            cle = re.sub(r"\d+", "N", str(e))[:70]
            motifs[cle] = motifs.get(cle, 0) + 1
    if not motifs:
        return []
    top = sorted(motifs.items(), key=lambda x: -x[1])
    total = sum(motifs.values())
    return [_fait(dernier, "le contrôle qualité", "production",
                  f"{total} texte(s) recalé(s)",
                  " · ".join(f"{n}× {m}" for m, n in top[:3]),
                  fil="qualite:" + top[0][0][:30])]


def _paroles(depuis: float) -> list[dict]:
    """Ce que les agents t'ont dit, et ce que tu leur as répondu."""
    faits = []
    try:
        import memory
    except Exception:
        return faits
    for conv in memory.chat_list(limit=20):
        cid = conv.get("id") or conv.get("conv") or ""
        if not cid:
            continue
        for m in memory.chat_read(cid, limit=8):
            t = _ts(m.get("t"))
            if t < depuis:
                continue
            qui = str(m.get("who") or m.get("role") or "")
            faits.append(_fait(t, "toi" if m.get("role") == "user" else qui,
                               "maxime" if m.get("role") == "user" else "parole",
                               str(m.get("text", ""))[:160], "", fil=f"fil:{cid}"))
    return faits


def _playtest(depuis: float) -> list[dict]:
    """La pellicule du robot testeur — la seule source qui montre le jeu JOUÉ.

    (La capture CI, elle, est toujours le premier écran neuf secondes après le
    boot : jamais une carte, jamais Brocéliande. Elle ne raconte rien.)"""
    dossier = CACHE / "playtest"
    if not dossier.exists():
        return []
    sessions: dict[str, list[Path]] = {}
    for p in sorted(dossier.glob("*.png")):
        try:
            if p.stat().st_mtime < depuis:
                continue
        except Exception:
            continue
        sessions.setdefault(p.name[:13], []).append(p)
    faits = []
    for tag, images in sessions.items():
        t = images[-1].stat().st_mtime
        faits.append(_fait(t, "le robot testeur", "production",
                           f"Il a joué — {len(images)} écrans parcourus",
                           "clics et touches comme un vrai joueur",
                           fil=f"playtest:{tag}",
                           image=f"/api/playtest/shot/{images[-1].name}"))
    return faits


def _chiffres() -> dict:
    """Les deux derniers relevés d'avancement : ce qui a bougé depuis hier."""
    pts = _lire_jsonl(Path.home() / "merlin-memory" / "progress.jsonl", 60)
    if not pts:
        return {}
    dernier = pts[-1]
    veille = pts[-2] if len(pts) > 1 else {}
    bouge = {}
    for k, v in dernier.items():
        if k == "t" or not isinstance(v, (int, float)):
            continue
        av = veille.get(k)
        if isinstance(av, (int, float)) and av != v:
            bouge[k] = {"avant": av, "apres": v, "delta": round(v - av, 2)}
    return {"dernier": dernier, "bouge": bouge}


# ── les fils : ce qui relie les jours entre eux ──────────────────────────────

def _majfils(faits: list[dict], jour: str) -> dict:
    """Ouvre un fil au premier signe, le ferme à la résolution. Aucun LLM.

    La clé est déterministe (`scene:X`, `proposition:<id>`, `agent:<id>`) : deux
    nuits différentes qui parlent du même problème atterrissent dans le même fil,
    et c'est ce qui permet d'écrire « troisième nuit consécutive »."""
    fils = _lire_json(FILS, {}) or {}
    for f in sorted(faits, key=lambda x: x["t"]):
        cle = f.get("fil")
        if not cle:
            continue
        d = fils.get(cle)
        # Seul un ÉCHEC ouvre un fil. Une décision de Maxime est un événement,
        # pas une question en suspens : ouvrir un fil à chaque « oui » ou « non »
        # remplissait la rubrique de choses déjà tranchées.
        if f["type"] == "echec" and not d:
            fils[cle] = {"ouvert": jour, "sujet": f["titre"][:120],
                         "jours": [jour], "clos": None, "dernier": f["titre"][:120]}
        elif d and not d.get("clos"):
            if jour not in d["jours"]:
                d["jours"].append(jour)
            d["dernier"] = f["titre"][:120]
            if f["type"] == "resolution":
                d["clos"] = jour
    BASE.mkdir(parents=True, exist_ok=True)
    FILS.write_text(json.dumps(fils, ensure_ascii=False, indent=1), encoding="utf-8")
    return fils


# ── la fiche de nuit ─────────────────────────────────────────────────────────

def collecte(heures: int = 24) -> dict:
    """La matière du chapitre : des faits datés, pondérés, déjà en français."""
    depuis = time.time() - heures * 3600
    jour = time.strftime("%Y-%m-%d", time.localtime())
    faits, index = _commits(depuis)
    for source in (_decisions, _agents, _ci, _rejets, _paroles, _playtest):
        try:
            faits += source(depuis)
        except Exception as exc:            # une source morte n'annule pas la nuit
            faits.append(_fait(time.time(), "le registre", "production",
                               f"source indisponible : {source.__name__}",
                               f"{type(exc).__name__}: {exc}"[:120]))
    faits = [f for f in faits if f["t"] >= depuis]
    faits.sort(key=lambda f: f["t"])
    fils = _majfils(faits, jour)
    ouverts = {k: v for k, v in fils.items() if not v.get("clos")}
    n = len(_lire_jsonl(CHAPITRES, 5000)) + 1
    return {
        "n": n, "jour": jour, "depuis": depuis, "heures": heures,
        "faits": faits,
        "saillants": sorted(faits, key=lambda f: (-f["poids"], -f["t"]))[:5],
        "causalite": index,
        "chiffres": _chiffres(),
        "fils_ouverts": [{"cle": k, **v} for k, v in
                         sorted(ouverts.items(), key=lambda x: x[1].get("ouvert", ""))][:6],
        "images": [f["image"] for f in faits if f.get("image")][:3],
    }


def ecrire(fiche: dict, texte: str, redige_par: str = "gabarits",
           cout: dict | None = None) -> Path:
    """Grave le chapitre. Append-only, hors du dépôt versionné.

    Le rappel vaut d'être écrit : la première version des propositions écrivait
    dans un fichier suivi par git, et `git pull` refusait de tourner sur la VM —
    plus aucun déploiement. Voir overrides.py. Rien de ce module ne s'écrit sous
    le dépôt."""
    BASE.mkdir(parents=True, exist_ok=True)
    chap = {"n": fiche["n"], "jour": fiche["jour"], "t": _now_iso(),
            "titre": _titre(fiche), "texte": texte, "redige_par": redige_par,
            "cout": cout or {}, "images": fiche.get("images", []),
            "fils_ouverts": [f["cle"] for f in fiche.get("fils_ouverts", [])],
            "faits": len(fiche.get("faits", []))}
    with CHAPITRES.open("a", encoding="utf-8") as f:
        f.write(json.dumps(chap, ensure_ascii=False) + "\n")
    return CHAPITRES


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _titre(fiche: dict) -> str:
    """Même règle que les gabarits : une tension plutôt qu'une conclusion."""
    try:
        import journal_gabarits as G
        return G._titre_court(fiche)[:90]
    except Exception:
        s = fiche.get("saillants") or []
        return s[0]["titre"][:90] if s else "Une nuit sans histoire"


def chapitres(limite: int = 30) -> list[dict]:
    """Les chapitres, du plus récent au plus ancien — lus par le portail."""
    return _lire_jsonl(CHAPITRES, limite)[::-1]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Registre du journal de bord")
    ap.add_argument("--fiche", action="store_true", help="afficher la matière brute")
    ap.add_argument("--ecrire", action="store_true", help="graver le chapitre du jour")
    ap.add_argument("--gabarits", action="store_true", help="rédiger sans LLM")
    ap.add_argument("--heures", type=int, default=24)
    a = ap.parse_args(argv)
    fiche = collecte(a.heures)
    if a.fiche or not (a.ecrire):
        print(json.dumps(fiche, ensure_ascii=False, indent=1)[:6000])
        print(f"\n{len(fiche['faits'])} fait(s) · {len(fiche['fils_ouverts'])} fil(s) ouvert(s)"
              f" · {len(fiche['causalite'])} commit(s) rattaché(s) à une décision")
        return 0
    import journal_gabarits as G
    texte = G.rediger(fiche)
    p = ecrire(fiche, texte, "gabarits")
    print(f"chapitre {fiche['n']} gravé ({len(texte)} caractères) → {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
