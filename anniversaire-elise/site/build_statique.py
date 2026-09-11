#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique un dossier — et son zip — à déposer chez n'importe quel hébergeur.

    python3 site/build_statique.py

Sort `site/statique/` (index.html + robots.txt) et `site/anniv-elise.zip`.

C'est la page seule, sans appel réseau : le glisser-déposer du tableau de bord
Cloudflare Pages ne compile pas le dossier `functions/`, donc une page qui
appellerait `/api/…` ne récolterait que des 404 et afficherait « Pas de
réseau » à chaque envoi. Les réponses restent donc dans le navigateur de
l'invité, comme aujourd'hui sur l'artifact, et le bouton WhatsApp du
récapitulatif reste le chemin qui prévient Maxime.

Pour la version qui garde les réponses côté serveur, c'est `cloudflare/` et
son `deploy.sh` — qui, lui, a besoin de wrangler.
"""
from __future__ import annotations

import pathlib
import re
import sys
import zipfile

import build_public

ICI = pathlib.Path(__file__).resolve().parent
SORTIE = ICI / "statique"
ZIP = ICI / "anniv-elise.zip"

ENTETE = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="robots" content="noindex,nofollow">
</head>
<body style="margin:0">
"""


def main() -> None:
    page = build_public.SOURCE.read_text(encoding="utf-8")

    env = build_public.lire_env()
    for cle, defaut in build_public.DEFAUTS.items():
        page = page.replace("__%s__" % cle, env.get(cle, defaut))
    restants = re.findall(r"__(?:RIB_\w+|ADRESSE)__", page)
    if restants:
        sys.exit("marqueurs non substitués : " + ", ".join(sorted(set(restants))))

    page, combien, _ = build_public.incruster_photos(page)
    if 'src="photos/' in page:
        sys.exit("une photo n'a pas été incrustée")

    SORTIE.mkdir(exist_ok=True)
    index = SORTIE / "index.html"
    index.write_text(ENTETE + page + "\n</body>\n</html>\n", encoding="utf-8")
    # La page porte une adresse et un IBAN : rien à indexer.
    (SORTIE / "robots.txt").write_text("User-agent: *\nDisallow: /\n", encoding="utf-8")

    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(SORTIE.iterdir()):
            z.write(f, f.name)

    poids = index.stat().st_size / 1e6
    print("%s — %.1f Mo (%d photos)" % (index, poids, combien))
    print("%s — %.1f Mo compressé" % (ZIP, ZIP.stat().st_size / 1e6))
    # Le glisser-déposer du tableau de bord plafonne à 25 Mio par fichier.
    if poids > 25:
        sys.exit("index.html dépasse les 25 Mio du glisser-déposer")


if __name__ == "__main__":
    main()
