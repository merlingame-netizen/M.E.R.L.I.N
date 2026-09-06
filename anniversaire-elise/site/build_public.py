#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique la page publiable à partir de `site/public.html`.

Deux greffes, toutes deux imposées par la publication :

1. **Le RIB.** Le dépôt est public : l'IBAN vit dans `deploy/rib.env`, gitignoré,
   et la page versionnée ne porte que des marqueurs `__RIB_*__`.
2. **Les photos.** La politique de sécurité des artifacts bloque toute image
   externe, y compris depuis un CDN. Les huit photos du programme sont donc
   encodées en `data:` URI — la page publiée ne charge rien d'autre que ses
   polices.

    python3 site/build_public.py [-o chemin/de/sortie.html]

Sans `-o`, écrit `site/public.build.html` (gitignoré).
"""
import argparse
import base64
import mimetypes
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = RACINE / "site" / "public.html"
ENV = RACINE / "deploy" / "rib.env"

DEFAUTS = {
    "RIB_TITULAIRE": "coordonnées à venir",
    "RIB_IBAN": "communiqué dans le groupe",
    "RIB_BIC": "—",
}


def lire_env() -> dict:
    """Lit `deploy/rib.env`. Absent, on retombe sur des mentions neutres :
    la page reste publiable pour une relecture sans exposer quoi que ce soit."""
    if not ENV.exists():
        print("deploy/rib.env absent — mentions neutres à la place du RIB", file=sys.stderr)
        return dict(DEFAUTS)
    valeurs = dict(DEFAUTS)
    for ligne in ENV.read_text(encoding="utf-8").splitlines():
        if ligne.lstrip().startswith("#"):
            continue
        m = re.match(r'^\s*(\w+)\s*=\s*"?(.*?)"?\s*$', ligne)
        if m:
            valeurs[m.group(1)] = m.group(2)
    return valeurs


def incruster_photos(html: str) -> tuple:
    """Remplace chaque src="photos/x.jpg" par le data: URI du fichier."""
    dossier = RACINE / "site" / "photos"
    incrustees, octets = 0, 0

    def remplace(m):
        nonlocal incrustees, octets
        chemin = dossier / m.group(1)
        if not chemin.exists():
            sys.exit("photo introuvable : " + str(chemin))
        brut = chemin.read_bytes()
        type_mime = mimetypes.guess_type(chemin.name)[0] or "image/jpeg"
        incrustees += 1
        octets += len(brut)
        return 'src="data:%s;base64,%s"' % (type_mime, base64.b64encode(brut).decode("ascii"))

    return re.sub(r'src="photos/([^"]+)"', remplace, html), incrustees, octets


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-o", "--sortie", default=str(RACINE / "site" / "public.build.html"))
    args = ap.parse_args()

    html = SOURCE.read_text(encoding="utf-8")
    env = lire_env()
    for cle in DEFAUTS:
        html = html.replace("__%s__" % cle, env.get(cle, DEFAUTS[cle]))

    restants = re.findall(r"__RIB_\w+__", html)
    if restants:
        sys.exit("marqueurs non substitués : " + ", ".join(sorted(set(restants))))

    html, combien, octets = incruster_photos(html)
    if 'src="photos/' in html:
        sys.exit("une photo n'a pas été incrustée")

    sortie = pathlib.Path(args.sortie)
    sortie.write_text(html, encoding="utf-8")
    print("%s — %.1f Mo (%d photos, %.1f Mo d'images)"
          % (sortie, len(html.encode("utf-8")) / 1e6, combien, octets / 1e6))


if __name__ == "__main__":
    main()
