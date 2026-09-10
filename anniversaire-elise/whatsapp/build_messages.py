#!/usr/bin/env python3
"""Produit whatsapp/messages_prets.md, avec adresse et IBAN déjà remplis.

Le dépôt est public : `05_post_aix.md` garde donc ses placeholders `[ADRESSE]`
et `[IBAN]`. Ce script les remplace depuis `deploy/rib.env` (gitignoré) et écrit
un fichier lui aussi gitignoré, prêt à copier-coller dans WhatsApp.

    python3 whatsapp/build_messages.py [--url https://…]

Le lien de l'invitation est déjà écrit dans `05_post_aix.md` : il n'a rien de
secret, contrairement à l'adresse et à l'IBAN, qui viennent de `deploy/rib.env`.
`--url` ne sert donc qu'à le remplacer par un autre.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# L'invitation publiée. Publique par destination : elle est faite pour
# circuler, alors elle est écrite en clair plutôt que laissée en marqueur.
INVITATION = "https://claude.ai/code/artifact/29f10c22-6058-494a-bd9a-15bbab495e66"

HERE = Path(__file__).parent
SOURCE = HERE / "05_post_aix.md"
ENV = HERE.parent / "deploy" / "rib.env"
OUT = HERE / "messages_prets.md"


def charger_env() -> dict[str, str]:
    if not ENV.exists():
        sys.exit(f"{ENV} introuvable — copie rib.env.example et remplis-le.")
    return dict(re.findall(r'^(\w+)="(.*)"$', ENV.read_text(encoding="utf-8"), re.M))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=INVITATION,
                    help="URL du site (défaut : l'invitation déjà dans les messages)")
    args = ap.parse_args()

    env = charger_env()
    texte = SOURCE.read_text(encoding="utf-8")

    # On retire l'avertissement destiné au dépôt : il n'a pas de sens dans le
    # fichier rempli, qui ne quitte jamais la machine.
    texte = re.sub(r"> ⚠️ \*\*`\[ADRESSE\]`.*?gitignoré\.\n", "", texte, flags=re.S)

    remplacements = {
        "[ADRESSE]": env.get("ADRESSE", "[ADRESSE]"),
        "[IBAN]": env.get("RIB_IBAN", "[IBAN]"),
    }
    if args.url and args.url != INVITATION:
        remplacements[INVITATION] = args.url

    for cle, val in remplacements.items():
        texte = texte.replace(cle, val)

    OUT.write_text(texte, encoding="utf-8")

    restants = sorted(set(re.findall(r"\[[A-ZÉÈÊÀÎÔÛ' ]{3,}\]", texte)))
    print(f"{OUT.relative_to(HERE.parent.parent)} — {len(texte)} octets")
    print("adresse injectée :", env.get("ADRESSE", "(absente de rib.env)"))
    if not args.url:
        print("⚠️  URL vide — les messages gardent le lien gravé dans la source")
    if restants:
        print("placeholders restants, à remplir à la main :", ", ".join(restants))


if __name__ == "__main__":
    main()
