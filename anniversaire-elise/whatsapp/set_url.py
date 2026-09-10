#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Change l'adresse de l'invitation partout, en une commande.

    python3 whatsapp/set_url.py https://mon-site.example

Le lien vit à trois endroits : le Markdown source (`05_post_aix.md`, cinq
occurrences) et la constante `INVITATION` des deux générateurs. Les tenir à
jour à la main, c'est se garantir qu'un jour l'un des trois traînera une
vieille adresse — d'où ce script, qui les réécrit ensemble puis régénère les
deux sorties.

L'URL est vérifiée avant d'être écrite : une invitation qui pointe dans le
vide part à neuf personnes et ne se rattrape pas. `--sans-verif` passe outre
(site pas encore en ligne, réseau coupé).
"""
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import urllib.request

ICI = pathlib.Path(__file__).resolve().parent
FICHIERS = [ICI / "05_post_aix.md", ICI / "build_kit.py", ICI / "build_messages.py"]
MOTIF_CONSTANTE = re.compile(r'^INVITATION = "(.+?)"$', re.M)


def url_actuelle() -> str:
    """L'adresse en place, lue là où elle est déclarée plutôt que recopiée."""
    m = MOTIF_CONSTANTE.search((ICI / "build_messages.py").read_text(encoding="utf-8"))
    if not m:
        sys.exit("constante INVITATION introuvable dans build_messages.py")
    return m.group(1)


def joignable(url: str) -> tuple[bool, str]:
    requete = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    try:
        with urllib.request.urlopen(requete, timeout=25) as r:
            return 200 <= r.status < 400, "HTTP %d" % r.status
    except Exception as e:                                   # noqa: BLE001
        return False, str(e)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("url", help="la nouvelle adresse de l'invitation")
    ap.add_argument("--sans-verif", action="store_true",
                    help="ne pas vérifier que l'adresse répond")
    args = ap.parse_args()

    neuve = args.url.strip().rstrip("/")
    if not neuve.startswith("https://"):
        sys.exit("l'adresse doit commencer par https:// — WhatsApp n'ouvre pas le reste")

    vieille = url_actuelle()
    if neuve == vieille:
        # Idempotent, et sans code d'erreur : `deploy.sh` finit par nous
        # appeler à chaque publication, y compris quand rien n'a bougé.
        print("déjà cette adresse, rien à changer : " + neuve)
        return

    if not args.sans_verif:
        ok, detail = joignable(neuve)
        if not ok:
            sys.exit("%s ne répond pas (%s) — corrige, ou force avec --sans-verif"
                     % (neuve, detail))
        print("%s répond (%s)" % (neuve, detail))

    total = 0
    for f in FICHIERS:
        texte = f.read_text(encoding="utf-8")
        combien = texte.count(vieille)
        if combien:
            f.write_text(texte.replace(vieille, neuve), encoding="utf-8")
        print("%-20s %d occurrence(s)" % (f.name, combien))
        total += combien
    if not total:
        sys.exit("aucune occurrence remplacée — l'adresse en place a dû dériver")

    for script in ("build_messages.py", "build_kit.py"):
        r = subprocess.run([sys.executable, str(ICI / script)],
                           capture_output=True, text=True)
        print("--- %s" % script)
        print((r.stdout + r.stderr).rstrip())
        if r.returncode:
            sys.exit("%s a échoué" % script)

    print("\nLien en place partout : %s" % neuve)


if __name__ == "__main__":
    main()
