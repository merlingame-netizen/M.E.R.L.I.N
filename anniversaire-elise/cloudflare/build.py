#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique la version Cloudflare : `cloudflare/public/index.html`.

Même greffe que la version VM — RIB et photos incrustés, puis un bloc ajouté à
la fin qui envoie les réponses au serveur et affiche les compteurs. Le script
et les styles sont importés de `vm/build_template.py` : les deux hébergements
parlent à la même API (`/api/etat`, `/api/reponse`), il n'y a donc aucune
raison d'en tenir deux copies.

    python3 cloudflare/build.py

Écrit aussi `cloudflare/valeurs.json`, que la fonction importe pour valider —
c'est la page elle-même qui fait foi sur les réponses acceptées.
"""
from __future__ import annotations

import json
import pathlib
import re
import shutil
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "site"))
sys.path.insert(0, str(RACINE / "vm"))
import build_public      # noqa: E402
import build_template    # noqa: E402

ICI = RACINE / "cloudflare"
PUBLIC = ICI / "public"


def main() -> None:
    page = build_public.SOURCE.read_text(encoding="utf-8")

    env = build_public.lire_env()
    for cle in build_public.DEFAUTS:
        page = page.replace("__%s__" % cle, env.get(cle, build_public.DEFAUTS[cle]))
    restants = re.findall(r"__(?:RIB_\w+|ADRESSE)__", page)
    if restants:
        sys.exit("marqueurs non substitués : " + ", ".join(sorted(set(restants))))

    # Les réponses acceptées, relevées dans la page — la fonction les importe.
    listes = build_template.valeurs_acceptees(page)
    (ICI / "valeurs.json").write_text(
        json.dumps({"choix": listes, "libres": build_template.CHAMPS_LIBRES},
                   ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    page, combien, _ = build_public.incruster_photos(page)
    if 'src="photos/' in page:
        sys.exit("une photo n'a pas été incrustée")

    # Le script d'hébergement se greffe sur le récapitulatif. S'il ne trouve
    # pas son point d'accroche il sort en silence : la page s'affiche, l'API
    # répond, et pas une réponse n'est enregistrée. C'est arrivé — l'ancre
    # était « #e3 », et l'entonnoir est passé à deux étapes. Donc on vérifie
    # ici, au build, plutôt que de le découvrir après le déploiement.
    for ancre in ('id="envoi"', 'class="barre"', 'class="fiche"'):
        if ancre not in page:
            sys.exit("point d'accroche manquant dans la page : " + ancre)

    # Un document complet : Pages sert un fichier, pas un gabarit.
    page = ("<!doctype html>\n<html lang=\"fr\">\n<head>\n"
            "<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n"
            "<meta name=\"color-scheme\" content=\"light\">\n"
            "</head>\n<body style=\"margin:0\">\n"
            + page
            + "\n<style>%s</style>\n<script>%s</script>\n" % (build_template.CSS,
                                                              build_template.SCRIPT)
            + "</body>\n</html>\n")

    PUBLIC.mkdir(parents=True, exist_ok=True)
    (PUBLIC / "index.html").write_text(page, encoding="utf-8")

    # Pages sert le dossier tel quel : pas de robots, pas d'indexation.
    (PUBLIC / "robots.txt").write_text("User-agent: *\nDisallow: /\n", encoding="utf-8")

    print("%s — %.1f Mo (%d photos)"
          % (PUBLIC / "index.html", len(page.encode()) / 1e6, combien))
    print("%s — %d champs à liste fermée" % (ICI / "valeurs.json", len(listes)))


if __name__ == "__main__":
    main()
