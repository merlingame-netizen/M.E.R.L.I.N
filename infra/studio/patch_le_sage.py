#!/usr/bin/env python3
"""Patch Studio — LE SAGE : la troisième voix du chat, mécaniques + lore sourcés.

Maxime (2026-08-25) : « je veux pouvoir parler simplement sur le studio de dev à MERLIN
et lui poser les questions sur les mécaniques de jeu et le lore ». L'orchestrateur connaît
le studio, le personnage connaît la forêt : aucun ne connaît la Bible. Le Sage (grimoire.py,
livré dans le même commit) répond depuis les textes et cite sa source.

Quatre fichiers : chat_reply.py (la branche du Sage), app.py (liste blanche), index.html
(3e bouton du duo), studio.js (avatar, nom, placeholder, suggestions)."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


# ═══ 1) chat_reply.py — la branche du Sage, avant toute machinerie du studio ═══
p = pathlib.Path("tools/gd_agents/chat_reply.py")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '    rows = memory.chat_read(conv, limit=10)\n'
    '    if not rows or rows[-1]["role"] != "user":\n'
    '        print("rien à répondre")\n'
    '        return 0\n',
    '    rows = memory.chat_read(conv, limit=10)\n'
    '    if not rows or rows[-1]["role"] != "user":\n'
    '        print("rien à répondre")\n'
    '        return 0\n'
    '    # ── LE SAGE — mécaniques + lore, réponses SOURCÉES (Maxime 2026-08-25) ──\n'
    '    # L\'orchestrateur connaît le studio, le personnage connaît la forêt : le\n'
    '    # Sage répond DEPUIS LES TEXTES (grimoire.py : Bible + code source de\n'
    '    # vérité), cite sa source, et avoue quand la Bible ne dit rien.\n'
    '    if adviser == "sage":\n'
    '        import grimoire\n'
    '        question = str(rows[-1]["text"]).strip()\n'
    '        echange = "\\n".join(\n'
    "            f\"{'Maxime' if r['role'] == 'user' else 'Le Sage'} : {r['text'][:280]}\"\n"
    '            for r in rows[-6:])\n'
    '        conf = Path.home() / ".config" / "merlin-llm.env"\n'
    '        model = "gemma4:e4b-it-qat"\n'
    '        try:\n'
    '            for line in conf.read_text().splitlines():\n'
    '                if "COPILOT_MODEL" in line:\n'
    '                    model = line.split("=", 1)[1].strip()\n'
    '        except Exception:\n'
    '            pass\n'
    '\n'
    '        def _sage(pr: str) -> str:\n'
    '            try:\n'
    '                r = subprocess.run(["bash", str(LLM_ASK), "--model", model,\n'
    '                                    "--predict", "380", "--timeout", "280",\n'
    '                                    "--ctx", "4096", "--temp", "0.3"],\n'
    '                                   input=pr, capture_output=True, text=True,\n'
    '                                   timeout=300)\n'
    '                return (r.stdout or "").strip()\n'
    '            except Exception:\n'
    '                return ""\n'
    '\n'
    '        # Même verrou et même double essai que les autres voix : la version\n'
    '        # sans historique est le repli quand le prompt complet fait rendre du\n'
    '        # vide au e4b.\n'
    '        with _verrou_llm():\n'
    '            texte = _sage(grimoire.prompt(question, echange))\n'
    '            if not texte:\n'
    '                texte = _sage(grimoire.prompt(question, ""))\n'
    '        if not texte:\n'
    '            texte = ("(le Sage n\'a pas pu consulter la Bible — le modèle local "\n'
    '                     "était indisponible ; réessaie dans une minute)")\n'
    '        else:\n'
    '            refs = grimoire.references(question)\n'
    '            if refs:\n'
    '                texte += "\\n\\n\ud83d\udcd6 " + refs\n'
    '        memory.chat_append(conv, "assistant", "le-sage", texte, to="sage")\n'
    '        print(f"le Sage a répondu ({len(texte)} car.)")\n'
    '        return 0\n',
    "S1-branche-sage")
p.write_text(t, encoding="utf-8")

# ═══ 2) app.py — la liste blanche des interlocuteurs ═══
p = pathlib.Path("tools/merlin_studio/app.py")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '        if to not in ("merlin", "jeu") \\\n'
    '                and not _re.fullmatch(r"\\.claude/agents/[\\w-]+\\.md", to):\n',
    '        # « sage » = l\'esprit de la Bible (grimoire.py) : mécaniques + lore,\n'
    '        # réponses sourcées — la troisième voix, à côté du studio et du personnage.\n'
    '        if to not in ("merlin", "jeu", "sage") \\\n'
    '                and not _re.fullmatch(r"\\.claude/agents/[\\w-]+\\.md", to):\n',
    "A1-liste-blanche")
p.write_text(t, encoding="utf-8")

# ═══ 3) index.html — le troisième bouton du duo (qui devient un trio) ═══
p = pathlib.Path("tools/merlin_studio/templates/index.html")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '     <button type="button" class="duo-btn" data-to="jeu" role="tab">\n'
    '      <span class="duo-av merlin-av" id="merlin-av"><i class="rune">\ud83d\udf01</i></span>\n'
    '      <span class="duo-txt"><b>Merlin</b><i>le personnage du jeu</i></span>\n'
    '     </button>\n'
    '    </div>\n',
    '     <button type="button" class="duo-btn" data-to="jeu" role="tab">\n'
    '      <span class="duo-av merlin-av" id="merlin-av"><i class="rune">\ud83d\udf01</i></span>\n'
    '      <span class="duo-txt"><b>Merlin</b><i>le personnage du jeu</i></span>\n'
    '     </button>\n'
    '     <button type="button" class="duo-btn" data-to="sage" role="tab">\n'
    '      <span class="duo-av">\ud83d\udcd6</span>\n'
    '      <span class="duo-txt"><b>Le Sage</b><i>mécaniques &amp; lore — la Bible répond</i></span>\n'
    '     </button>\n'
    '    </div>\n',
    "H1-bouton")
t = exact(t,
    '     <option value="jeu">jeu</option>\n'
    '    </select>\n',
    '     <option value="jeu">jeu</option>\n'
    '     <option value="sage">sage</option>\n'
    '    </select>\n',
    "H2-option")
p.write_text(t, encoding="utf-8")

# ═══ 4) studio.js — avatar, nom, placeholder, suggestions ═══
p = pathlib.Path("tools/merlin_studio/static/studio.js")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "const AV = { merlin: '\u25c8' };",
    "const AV = { merlin: '\u25c8', 'le-sage': '\ud83d\udcd6' };",
    "J1-avatar")
t = exact(t,
    "'selftest': 'Test' };",
    "'selftest': 'Test', 'le-sage': 'Le Sage' };",
    "J2-nom")
t = exact(t,
    "    $('#talk-suggest').classList.toggle('gone', b.dataset.to === 'jeu');",
    "    // Les suggestions sont celles de l'ORCHESTRATEUR : ni le personnage ni le\n"
    "    // Sage n'ont à proposer de régler un agent.\n"
    "    $('#talk-suggest').classList.toggle('gone', b.dataset.to !== 'merlin');",
    "J3-suggestions")
t = exact(t,
    "      ta.placeholder = b.dataset.to === 'jeu'\n"
    "        ? 'Parler à Merlin — il ne sait rien du studio, il est dans la forêt\u2026'\n"
    "        : 'Parler au studio — poser une question, régler un agent, prévoir une tâche\u2026';",
    "      ta.placeholder = b.dataset.to === 'jeu'\n"
    "        ? 'Parler à Merlin — il ne sait rien du studio, il est dans la forêt\u2026'\n"
    "        : (b.dataset.to === 'sage'\n"
    "          ? 'Demander au Sage — une mécanique, une règle, le lore : la Bible répond\u2026'\n"
    "          : 'Parler au studio — poser une question, régler un agent, prévoir une tâche\u2026');",
    "J4-placeholder")
p.write_text(t, encoding="utf-8")

print("Le Sage est en place : chat_reply + app + index + studio.js patchés.")
