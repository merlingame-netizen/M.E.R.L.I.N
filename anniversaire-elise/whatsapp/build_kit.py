#!/usr/bin/env python3
"""Génère site/kit.html — la page-outil pour tout coller dans WhatsApp.

Les messages et sondages sont lus depuis 02_messages_prets.md et
03_sondages.md : la page ne peut pas diverger de la documentation, puisqu'elle
en est dérivée. Modifie le markdown, relance ce script.

    python3 whatsapp/build_kit.py
"""
from __future__ import annotations

import html
import json
import re
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE.parent / "site" / "kit.html"

FENCE = re.compile(r"^```\s*$", re.M)


def blocks_by_heading(md: str, level: str = "## ") -> list[tuple[str, str, list[str]]]:
    """Découpe le markdown en (titre, corps, [blocs de code]) par section.

    Le corps est renvoyé pour que l'appelant puisse y chercher des marqueurs
    (« choix multiple »…) sans fenêtre de caractères arbitraire : `split` sur
    le niveau de titre garantit qu'on ne déborde pas sur la section suivante.
    """
    sections: list[tuple[str, str, list[str]]] = []

    for chunk in md.split("\n" + level)[1:]:
        head, _, body = chunk.partition("\n")
        parts = FENCE.split(body)
        # parts alterne hors-bloc / dans-bloc : les indices impairs sont le code
        code = [parts[i].strip("\n") for i in range(1, len(parts), 2)]
        if code:
            sections.append((head.strip(), body, code))
    return sections


def clean_title(t: str) -> str:
    """« A — Message d'accueil ⏱ à la création, **à épingler** » -> titre + timing."""
    t = t.replace("**", "")
    label, _, timing = t.partition("⏱")
    return label.strip(" —·"), timing.strip()


def main() -> None:
    msgs = []
    for title, _body, code in blocks_by_heading((HERE / "02_messages_prets.md").read_text(encoding="utf-8")):
        label, timing = clean_title(title)
        msgs.append({"titre": label, "quand": timing, "blocs": code})

    polls = []
    for title, body, code in blocks_by_heading((HERE / "03_sondages.md").read_text(encoding="utf-8")):
        if not title.lower().startswith("sondage"):
            continue
        label, timing = clean_title(title)
        # bloc 0 = la question, bloc 1 = les options (une par ligne)
        question = code[0] if code else ""
        options = [o for o in (code[1].splitlines() if len(code) > 1 else []) if o.strip()]
        polls.append({"titre": label, "quand": timing, "question": question,
                      "options": options, "multi": "choix multiple" in body})

    data = json.dumps({"messages": msgs, "sondages": polls},
                      ensure_ascii=False, indent=1)

    OUT.write_text(TEMPLATE.replace("__DATA__", html.escape(data, quote=False)),
                   encoding="utf-8")
    print(f"{OUT.relative_to(HERE.parent.parent)} — {len(msgs)} messages, "
          f"{len(polls)} sondages, {OUT.stat().st_size} octets")


TEMPLATE = r"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<meta name="theme-color" content="#1c1714">
<title>Kit WhatsApp — 30 ans d'Elise</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght,SOFT,WONK@9..144,300..900,0..100,0..1&family=Karla:wght@300..800&display=swap" rel="stylesheet">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><text y='26' font-size='26'>📋</text></svg>">
<style>
:root{
  --paper:#f2e7d5;--paper-2:#e8d9c0;--paper-3:#dcc7a8;
  --ink:#241d17;--ink-soft:#4e4038;--ink-faint:#8a7869;
  --ocre:#c8791f;--ocre-deep:#a35a15;--sienna:#9e3b21;--rouge:#7d2417;
  --olive:#66714a;--wa:#25d366;--night:#1c1714;--night-2:#2a221c;--rule:#c3ac8c;
  --display:'Fraunces',Georgia,serif;--body:'Karla',-apple-system,'Segoe UI',sans-serif;
  --pad:clamp(1.1rem,4vw,3rem);
}
*,*::before,*::after{box-sizing:border-box}
@media (prefers-reduced-motion:reduce){*{transition-duration:.01ms!important}}
body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--body);
  font-size:1rem;line-height:1.6;overflow-x:hidden}
.wrap{max-width:860px;margin-inline:auto;padding-inline:var(--pad)}
h1,h2,h3{font-family:var(--display);font-weight:600;line-height:1.05;margin:0;
  font-variation-settings:'SOFT' 22,'WONK' 1;letter-spacing:-.02em}
p{margin:0 0 1em}
a{color:var(--sienna)}
header{background:var(--night);color:var(--paper);padding-block:clamp(2.4rem,7vh,4rem)}
header .kicker{font-size:.7rem;font-weight:800;letter-spacing:.3em;text-transform:uppercase;
  color:var(--ocre);margin-bottom:1rem}
header h1{font-size:clamp(2.1rem,7vw,3.4rem);color:var(--paper)}
header p{margin-top:1rem;color:var(--paper-3);max-width:60ch}
.how{background:var(--paper-2);padding-block:clamp(1.8rem,5vh,2.8rem);border-bottom:1px solid var(--rule)}
.how h2{font-size:1.5rem;margin-bottom:1rem}
.how ol{margin:0;padding-left:1.3rem}
.how li{margin-bottom:.7rem;font-size:.97rem;color:var(--ink-soft)}
.how li b{color:var(--ink)}
section{padding-block:clamp(2.2rem,6vh,3.4rem)}
.sec-num{font-size:.68rem;font-weight:800;letter-spacing:.26em;text-transform:uppercase;
  color:var(--ocre-deep);display:block;margin-bottom:.7rem}
h2.big{font-size:clamp(1.7rem,5vw,2.5rem);margin-bottom:1.6rem}
.item{border:1px solid var(--rule);background:#fff;margin-bottom:1.5rem}
.item-head{padding:1rem 1.2rem;border-bottom:1px solid var(--rule);background:var(--paper-2);
  display:flex;justify-content:space-between;gap:1rem;align-items:baseline;flex-wrap:wrap}
.item-head h3{font-size:1.16rem}
.item-head .when{font-size:.68rem;font-weight:800;letter-spacing:.13em;text-transform:uppercase;
  color:var(--ocre-deep);max-width:100%}
pre{margin:0;padding:1.15rem 1.2rem;white-space:pre-wrap;word-break:break-word;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;font-size:.86rem;line-height:1.62;
  color:var(--ink);max-height:340px;overflow-y:auto;background:#fff}
pre+pre{border-top:1px dashed var(--rule)}
.acts{display:flex;gap:.6rem;padding:.9rem 1.2rem;border-top:1px solid var(--rule);
  flex-wrap:wrap;background:var(--paper)}
button,.btn{display:inline-flex;align-items:center;gap:.5rem;border:none;cursor:pointer;
  font-family:var(--body);font-weight:800;font-size:.76rem;letter-spacing:.11em;
  text-transform:uppercase;padding:.72rem 1.15rem;min-height:44px;text-decoration:none;
  transition:background .18s,transform .18s}
button:focus-visible,.btn:focus-visible{outline:2px solid var(--sienna);outline-offset:2px}
.b-copy{background:var(--ocre);color:var(--night)}
.b-copy:hover{background:#e08f2c;transform:translateY(-2px)}
.b-copy.done{background:var(--olive);color:var(--paper)}
.b-wa{background:var(--wa);color:#053b1c}
.b-wa:hover{background:#1fbb59;transform:translateY(-2px)}
.opts{list-style:none;margin:0;padding:.4rem 1.2rem 1rem}
.opts li{display:flex;justify-content:space-between;align-items:center;gap:1rem;
  padding:.55rem 0;border-bottom:1px solid var(--paper-2);font-size:.94rem}
.opts li:last-child{border-bottom:none}
.opts .b-copy{padding:.5rem .8rem;font-size:.66rem;min-height:36px;flex-shrink:0}
.qbox{padding:1.1rem 1.2rem;background:var(--night);color:var(--paper);
  display:flex;justify-content:space-between;gap:1rem;align-items:center;flex-wrap:wrap}
.qbox span{font-size:1.02rem;font-weight:700}
.badge{font-size:.63rem;font-weight:800;letter-spacing:.14em;text-transform:uppercase;
  padding:.24rem .6rem;background:var(--rouge);color:var(--paper)}
.badge.multi{background:var(--olive)}
.note{background:rgba(125,36,23,.08);border-left:4px solid var(--rouge);
  padding:1.1rem 1.3rem;margin-top:1.4rem;font-size:.94rem}
.note b{color:var(--rouge)}
footer{background:var(--night);color:var(--ink-faint);padding-block:2.4rem;font-size:.85rem}
footer a{color:var(--ocre)}
#toast{position:fixed;left:50%;bottom:1.6rem;transform:translate(-50%,140%);
  background:var(--night);color:var(--paper);padding:.85rem 1.5rem;font-weight:700;
  font-size:.88rem;z-index:99;transition:transform .28s ease;pointer-events:none;
  border:1px solid var(--ocre)}
#toast.on{transform:translate(-50%,0)}
</style>
</head>
<body>

<header>
  <div class="wrap">
    <p class="kicker">Outil d'organisation · ne pas partager</p>
    <h1>Kit WhatsApp</h1>
    <p>Chaque message et chaque sondage, avec un bouton pour le copier et un lien qui ouvre WhatsApp directement sur le choix du groupe. Poste-les dans l'ordre indiqué par le rétroplanning.</p>
  </div>
</header>

<div class="how">
  <div class="wrap">
    <h2>Comment ça marche</h2>
    <ol>
      <li><b>Ouvre cette page sur ton téléphone</b>, pas sur l'ordinateur — c'est là qu'est WhatsApp.</li>
      <li><b>« Envoyer sur WhatsApp »</b> ouvre l'application avec le message déjà écrit : tu choisis le groupe, tu vérifies, tu envoies. Deux gestes.</li>
      <li><b>« Copier »</b> met le texte dans le presse-papiers si tu préfères le coller toi-même — ou si le lien direct bute sur un message très long.</li>
      <li><b>Les sondages ne peuvent pas s'envoyer par lien</b> : WhatsApp ne le permet pas. Fais <b>＋ → Sondage</b>, puis copie la question et chaque option d'un tap.</li>
    </ol>
  </div>
</div>

<section>
  <div class="wrap">
    <span class="sec-num">01 — Les messages</span>
    <h2 class="big">À poster dans l'ordre</h2>
    <div id="messages"></div>
    <div class="note">
      <p><b>Remplace les crochets avant d'envoyer.</b> <code>[MOT DE PASSE]</code>, <code>[ADRESSE]</code>, <code>[CO-ADMIN]</code>, <code>[MONTANT]</code> : le message part tel quel, crochets compris, si tu ne les as pas remplis. Relis toujours dans WhatsApp avant d'appuyer sur envoyer.</p>
    </div>
  </div>
</section>

<section style="background:var(--paper-2)">
  <div class="wrap">
    <span class="sec-num">02 — Les sondages</span>
    <h2 class="big">＋ → Sondage, puis copie ligne par ligne</h2>
    <div id="sondages"></div>
  </div>
</section>

<footer>
  <div class="wrap">
    <p><strong>Kit d'organisation — 30 ans d'Elise, 3 &amp; 4 octobre 2026.</strong></p>
    <p>Page privée, réservée à l'organisation. <a href="index.html">← Le site des invités</a></p>
  </div>
</footer>

<div id="toast" role="status" aria-live="polite"></div>

<script type="application/json" id="data">__DATA__</script>
<script>
(function(){
  "use strict";
  var D = JSON.parse(document.getElementById("data").textContent);

  var toast = document.getElementById("toast"), tmr;
  function say(msg){
    toast.textContent = msg;
    toast.classList.add("on");
    clearTimeout(tmr);
    tmr = setTimeout(function(){ toast.classList.remove("on"); }, 2200);
  }

  function copyText(text){
    if (navigator.clipboard && window.isSecureContext){
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function(resolve, reject){
      var ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.cssText = "position:fixed;top:-9999px;opacity:0";
      document.body.appendChild(ta);
      ta.select(); ta.setSelectionRange(0, ta.value.length);
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
      document.body.removeChild(ta);
      ok ? resolve() : reject(new Error("copie impossible"));
    });
  }

  function copyBtn(text, label){
    var b = document.createElement("button");
    b.type = "button";
    b.className = "b-copy";
    b.textContent = label || "📋 Copier";
    b.addEventListener("click", function(){
      copyText(text).then(function(){
        b.textContent = "✓ Copié";
        b.classList.add("done");
        say("Copié dans le presse-papiers");
        setTimeout(function(){ b.textContent = label || "📋 Copier"; b.classList.remove("done"); }, 2200);
      }).catch(function(){
        say("Copie refusée par le navigateur — sélectionne le texte à la main");
      });
    });
    return b;
  }

  function waBtn(text){
    var a = document.createElement("a");
    a.className = "btn b-wa";
    // wa.me sans numéro ouvre le sélecteur de conversation : on choisit le groupe.
    a.href = "https://wa.me/?text=" + encodeURIComponent(text);
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = "💬 Envoyer sur WhatsApp";
    return a;
  }

  function el(tag, cls, txt){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (txt !== undefined) n.textContent = txt;
    return n;
  }

  /* ── Messages ─────────────────────────────────────────────────────────── */
  var mRoot = document.getElementById("messages");
  D.messages.forEach(function(m){
    var box  = el("div", "item");
    var head = el("div", "item-head");
    head.appendChild(el("h3", null, m.titre));
    if (m.quand) head.appendChild(el("span", "when", m.quand));
    box.appendChild(head);

    m.blocs.forEach(function(b){ box.appendChild(el("pre", null, b)); });

    var full = m.blocs.join("\n\n");
    var acts = el("div", "acts");
    acts.appendChild(copyBtn(full));
    acts.appendChild(waBtn(full));
    box.appendChild(acts);
    mRoot.appendChild(box);
  });

  /* ── Sondages ─────────────────────────────────────────────────────────── */
  var pRoot = document.getElementById("sondages");
  D.sondages.forEach(function(s){
    var box  = el("div", "item");
    var head = el("div", "item-head");
    head.appendChild(el("h3", null, s.titre));
    if (s.quand) head.appendChild(el("span", "when", s.quand));
    box.appendChild(head);

    var q = el("div", "qbox");
    q.appendChild(el("span", null, s.question));
    var badge = el("span", "badge" + (s.multi ? " multi" : ""),
                   s.multi ? "choix multiple" : "choix unique");
    q.appendChild(badge);
    q.appendChild(copyBtn(s.question, "📋 Question"));
    box.appendChild(q);

    var ul = el("ul", "opts");
    s.options.forEach(function(o){
      var li = el("li");
      li.appendChild(el("span", null, o));
      li.appendChild(copyBtn(o, "Copier"));
      ul.appendChild(li);
    });
    box.appendChild(ul);
    pRoot.appendChild(box);
  });
})();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
