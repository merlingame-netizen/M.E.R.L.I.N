# -*- coding: utf-8 -*-
"""fetch_soundfont.py - Recupere le SoundFont GM utilise par melody_forge (backend SF2).

Le backend `sf2` de `tools/melody_forge.py` rend la musique de gameplay avec de VRAIS
echantillons d'instruments (harpe, flute, cordes, percussion) au lieu de synthes. La
banque d'echantillons (fichier .sf2 ~32 Mo) est trop grosse pour le depot : elle est
GITIGNOREE et re-telechargeable avec ce script.

SoundFont retenu : GeneralUser GS v2.0.3
  - Auteur   : S. Christian Collins
  - Licence  : GeneralUser GS License v2.0 - usage LIBRE, prive ET COMMERCIAL, sans
               restriction ; redistribution/modification autorisees. (Banque GM 100%
               echantillons reels ; texte complet : documentation/LICENSE.txt du depot.)
  - Source   : https://github.com/mrbumpy409/GeneralUser-GS (raw main)
  - Taille   : 32 319 396 octets
  - SHA-256  : 9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe
  - Local    : resources/soundfonts/GeneralUser-GS.sf2  (gitignore)

Le SF2 contient tout ce dont le jeu a besoin dans un seul fichier :
  Orchestral Harp (prog 46), Slow Strings (49), Pizzicato (45), Flute (73),
  Recorder (74), Pan Flute (75), Whistle (78), et le kit de percussion GM (bank 128).

Usage :
    python tools/fetch_soundfont.py            # telecharge si absent, verifie le hash
    python tools/fetch_soundfont.py --force    # re-telecharge meme si present
    python tools/fetch_soundfont.py --verify   # verifie seulement (pas de download)
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "resources" / "soundfonts" / "GeneralUser-GS.sf2"
URL = "https://github.com/mrbumpy409/GeneralUser-GS/raw/main/GeneralUser-GS.sf2"
SHA256 = "9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe"
SIZE = 32319396


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def verify(path: Path) -> bool:
    if not path.exists():
        print(f"[--] absent : {path}")
        return False
    got = _sha256(path)
    ok = got == SHA256
    print(f"[{'OK' if ok else 'KO'}] {path.name}  {path.stat().st_size} octets  sha256={got[:16]}...")
    if not ok:
        print(f"     attendu sha256={SHA256[:16]}... (fichier corrompu ou version differente)")
    return ok


def download(dest: Path) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"Telechargement GeneralUser GS v2.0.3 (~{SIZE // (1 << 20)} Mo)\n  {URL}\n  -> {dest}")
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": "merlin-fetch-soundfont/1.0"})
        with urllib.request.urlopen(req, timeout=180) as r, dest.open("wb") as f:
            f.write(r.read())
    except Exception as e:  # pragma: no cover
        print(f"[ERREUR] echec du telechargement : {e}")
        print("  Reseau/GPO bloque ? Deposer manuellement un .sf2 GM a l'emplacement ci-dessus,")
        print("  ou telecharger depuis https://www.schristiancollins.com (GeneralUser GS).")
        return False
    return verify(dest)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Recupere le SoundFont GM de melody_forge (backend SF2)")
    p.add_argument("--force", action="store_true", help="re-telecharger meme si present")
    p.add_argument("--verify", action="store_true", help="verifier le hash seulement")
    a = p.parse_args()

    if a.verify:
        return 0 if verify(DEST) else 1
    if DEST.exists() and not a.force:
        if verify(DEST):
            print("Deja present et valide. Rien a faire (--force pour re-telecharger).")
            return 0
        print("Present mais invalide -> re-telechargement.")
    return 0 if download(DEST) else 1


if __name__ == "__main__":
    raise SystemExit(main())
