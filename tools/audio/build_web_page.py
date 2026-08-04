#!/usr/bin/env python3
"""Assemble la page HTML de presentation (stems audio embarques en base64).

La page est autonome : aucune requete reseau, l'audio est inline. Elle sert de
preview jouable de la palette (console 4 stems + analyseur temps reel).

Usage :
    python3 tools/audio/build_web_page.py --stems audio/music/menu --out /tmp/page.html
"""
import argparse, base64, json, os, subprocess, sys

STEMS = ["base", "rhythm", "melody", "climax"]
TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "page_template.html")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stems", default="audio/music/menu")
    ap.add_argument("--out", default="palette_broceliande.html")
    ap.add_argument("--quality", default="1", help="qualite Vorbis pour le web (defaut 1)")
    args = ap.parse_args()

    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    tmp = os.path.join(os.path.dirname(args.out) or ".", "_web_tmp")
    os.makedirs(tmp, exist_ok=True)

    audio = {}
    for name in STEMS:
        src = os.path.join(args.stems, f"{name}.ogg")
        dst = os.path.join(tmp, f"{name}.ogg")
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", src,
                        "-c:a", "libvorbis", "-q:a", args.quality, dst], check=True)
        with open(dst, "rb") as fh:
            audio[name] = base64.b64encode(fh.read()).decode()
        os.remove(dst)
    os.rmdir(tmp)

    with open(TEMPLATE, encoding="utf-8") as fh:
        tpl = fh.read()
    if "__AUDIO_JSON__" not in tpl:
        print("template sans marqueur __AUDIO_JSON__", file=sys.stderr)
        return 1
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(tpl.replace("__AUDIO_JSON__", json.dumps(audio)))
    print(f"[page] {args.out}  ({os.path.getsize(args.out)/1024/1024:.2f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
