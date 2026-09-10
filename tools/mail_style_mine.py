"""Extract Maxime's recurring email formulations from Outlook Sent Items.

Feeds section 5 of memory/_shared__business_rules.md with real phrasings so that
drafted emails match the actual writing style instead of a generic LLM register.

Windows only (Outlook desktop + pywin32 required).

    python tools/mail_style_mine.py --limit 200
    python tools/mail_style_mine.py --limit 200 --write
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

MEMORY_FILE = Path(__file__).resolve().parents[1] / "memory" / "_shared__business_rules.md"
SECTION_HEADER = "## 5. Formulations extraites du corpus"

# Everything below these markers is quoted history, not Maxime's own writing.
QUOTE_MARKERS = re.compile(
    r"^(?:-{2,}\s*Message d'origine|De\s*:|From\s*:|Envoy[ée]\s*:|Sent\s*:|_{5,}|>)",
    re.IGNORECASE,
)
SIGNATURE_MARKERS = re.compile(
    r"(orange\.com|t[ée]l\s*:|mobile\s*:|ce message et ses pi[èe]ces|this message)",
    re.IGNORECASE,
)

OPENINGS = re.compile(r"^(bonjour|bonsoir|salut|hello|re)\b", re.IGNORECASE)
CLOSINGS = re.compile(
    r"^(merci|cordialement|bien [àa]|bonne (journ[ée]e|soir[ée]e|fin)|[àa] (bient[ôo]t|demain)"
    r"|je reste|dis-moi|bonne r[ée]ception|au plaisir)",
    re.IGNORECASE,
)
REQUESTS = re.compile(
    r"\b(peux-tu|pouvez-vous|pourrais-tu|pourriez-vous|j'aurais besoin|il me manque"
    r"|je relance|petit rappel|merci de|est-ce que tu peux|est-ce que vous pouvez)\b",
    re.IGNORECASE,
)


def own_lines(body: str) -> list[str]:
    """Keep only the lines Maxime actually typed (drop quoted thread + signature)."""
    lines: list[str] = []
    for raw in body.splitlines():
        line = raw.strip()
        if not line:
            continue
        if QUOTE_MARKERS.search(line):
            break
        if SIGNATURE_MARKERS.search(line):
            break
        lines.append(line)
    return lines


def sentences(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        for part in re.split(r"(?<=[.!?])\s+", line):
            part = part.strip()
            if 3 <= len(part) <= 140:
                out.append(part)
    return out


def normalize(sentence: str) -> str:
    """Collapse names/dates/numbers so variants of the same phrasing group together."""
    s = re.sub(r"\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?", "[date]", sentence)
    s = re.sub(r"\b\d+\b", "[n]", s)
    return s.strip()


def fetch_sent(limit: int) -> list[str]:
    try:
        import win32com.client
    except ImportError:
        sys.exit("pywin32 requis (poste Windows) : pip install pywin32")
    try:
        ns = win32com.client.Dispatch("Outlook.Application").GetNamespace("MAPI")
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"Outlook COM indisponible (ouvrir Outlook desktop). Detail: {exc}")
    items = ns.GetDefaultFolder(5).Items  # 5 = olFolderSentMail
    items.Sort("[SentOn]", True)
    bodies: list[str] = []
    for i, item in enumerate(items):
        if i >= limit:
            break
        try:
            bodies.append(item.Body or "")
        except Exception:  # noqa: BLE001, PERF203
            continue
    return bodies


def mine(bodies: list[str]) -> dict[str, list[tuple[str, int]]]:
    buckets: dict[str, Counter] = {
        "Ouvertures": Counter(),
        "Demandes / relances": Counter(),
        "Clotures": Counter(),
        "Phrases recurrentes": Counter(),
    }
    for body in bodies:
        lines = own_lines(body)
        for sent in sentences(lines):
            key = normalize(sent)
            if OPENINGS.match(sent):
                buckets["Ouvertures"][key] += 1
            elif CLOSINGS.match(sent):
                buckets["Clotures"][key] += 1
            elif REQUESTS.search(sent):
                buckets["Demandes / relances"][key] += 1
            else:
                buckets["Phrases recurrentes"][key] += 1
    return {
        name: [(phrase, n) for phrase, n in counter.most_common(25) if n >= 2]
        for name, counter in buckets.items()
    }


def render(result: dict[str, list[tuple[str, int]]], sample: int) -> str:
    out = [SECTION_HEADER, "", f"_Genere par `tools/mail_style_mine.py` sur {sample} mails envoyes._", ""]
    for name, phrases in result.items():
        out.append(f"**{name}**")
        if not phrases:
            out.append("- (aucune occurrence repetee)")
        for phrase, count in phrases:
            out.append(f"- « {phrase} » ({count}x)")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def write_section(section: str) -> None:
    text = MEMORY_FILE.read_text(encoding="utf-8")
    idx = text.find(SECTION_HEADER)
    if idx == -1:
        text = text.rstrip() + "\n\n" + section
    else:
        text = text[:idx] + section
    MEMORY_FILE.write_text(text, encoding="utf-8")
    print(f"Section 5 mise a jour : {MEMORY_FILE}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=200, help="nombre de mails envoyes analyses")
    parser.add_argument("--write", action="store_true", help="ecrire dans le fichier memoire")
    args = parser.parse_args()

    bodies = fetch_sent(args.limit)
    section = render(mine(bodies), len(bodies))
    print(section)
    if args.write:
        write_section(section)


if __name__ == "__main__":
    main()
