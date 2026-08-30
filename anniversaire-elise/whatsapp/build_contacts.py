#!/usr/bin/env python3
"""Normalise les contacts invités en E.164 (+33) et produit contacts.vcf / contacts.csv.

Les numéros de la capture sont écrits dans des formats hétérogènes
(`063-998-1234`, `06 39 98 12 34`, `+33639981234`). Ce sont tous des mobiles
français à 10 chiffres commençant par 06 ou 07 : le tiret est un artefact
d'affichage, pas un indicatif étranger.

Entrée  : contacts_source.txt  (gitignoré — `Nom;Numéro brut` par ligne)
Sorties : contacts.vcf, contacts.csv  (gitignorés tous les deux)

    python3 build_contacts.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE / "contacts_source.txt"


def normalise(raw: str) -> str:
    """Rend un numéro au format E.164 français, ou lève ValueError."""
    digits = re.sub(r"[^\d+]", "", raw)

    if digits.startswith("+33"):
        national = digits[3:]
    elif digits.startswith("0033"):
        national = digits[4:]
    elif digits.startswith("0"):
        national = digits[1:]
    else:
        national = digits

    if len(national) != 9 or national[0] not in "67":
        raise ValueError(f"pas un mobile FR à 10 chiffres : {raw!r}")
    return "+33" + national


def pretty(e164: str) -> str:
    """+33639981234 -> 06 39 98 12 34 (lisible à l'oeil, pour relecture)."""
    national = "0" + e164[3:]
    return " ".join(national[i:i + 2] for i in range(0, 10, 2))


def load() -> list[tuple[str, str]]:
    if not SOURCE.exists():
        sys.exit(f"Fichier source absent : {SOURCE}\n"
                 "Crée-le avec une ligne `Nom;Numéro` par invité.")

    contacts, errors = [], []
    for lineno, line in enumerate(SOURCE.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, _, raw = line.partition(";")
        try:
            contacts.append((name.strip(), normalise(raw)))
        except ValueError as exc:
            errors.append(f"  ligne {lineno}: {exc}")

    if errors:
        sys.exit("Numéros non reconnus :\n" + "\n".join(errors))
    return contacts


def main() -> None:
    contacts = load()

    vcf = "".join(
        "BEGIN:VCARD\r\nVERSION:3.0\r\n"
        f"N:{name.split()[-1]};{' '.join(name.split()[:-1])};;;\r\n"
        f"FN:{name}\r\n"
        f"TEL;TYPE=CELL:{tel}\r\n"
        "CATEGORIES:Anniv Elise 30\r\n"
        "END:VCARD\r\n"
        for name, tel in contacts
    )
    (HERE / "contacts.vcf").write_text(vcf, encoding="utf-8")

    csv = "nom,e164,lisible\n" + "".join(
        f"{name},{tel},{pretty(tel)}\n" for name, tel in contacts
    )
    (HERE / "contacts.csv").write_text(csv, encoding="utf-8")

    print(f"{len(contacts)} contacts -> contacts.vcf + contacts.csv")
    for name, tel in contacts:
        print(f"  {name:<24} {pretty(tel)}  ({tel})")


if __name__ == "__main__":
    main()
