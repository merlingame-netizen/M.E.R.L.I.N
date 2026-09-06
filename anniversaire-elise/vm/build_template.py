#!/usr/bin/env python3
"""Génère vm/templates/index.html à partir de ../site/public.html.

La page n'existe qu'une fois : site/public.html est la source, ici on l'habille
pour Flask. Trois greffes, toutes additives — le JS d'origine (localStorage,
budget vivant, timeline) continue de tourner tel quel :

  1. le squelette HTML complet, que la publication d'artifact ajoutait ;
  2. une section « Les votes en direct » alimentée par Jinja au premier rendu ;
  3. un script qui envoie la réponse au serveur et rafraîchit les compteurs.

    python3 build_template.py
"""
from __future__ import annotations

import re
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE.parent / "site" / "public.html"
OUT = HERE / "templates" / "index.html"

CSS_LIVE = """
/* ══ VOTES EN DIRECT (ajouté par build_template.py) ══ */
.live{display:grid;gap:1.1rem;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));margin-top:1.5rem}
.live-card{background:var(--paper);border:2px solid var(--rule);padding:1.2rem}
.live-card h3{font-size:1.05rem;margin-bottom:.9rem}
.tally{display:grid;gap:.65rem}
.tally-row{display:grid;gap:.28rem}
.tally-top{display:flex;justify-content:space-between;gap:1rem;font-size:.9rem}
.tally-top b{font-variant-numeric:tabular-nums;color:var(--ocre-deep)}
.bar{height:7px;background:var(--paper-3);overflow:hidden}
.bar i{display:block;height:100%;background:var(--ocre);width:0;transition:width .5s ease}
.tally-row.lead .bar i{background:var(--rouge)}
.tally-row.lead .tally-top b::after{content:" ★";color:var(--rouge)}
.live-big{font-family:var(--display);font-size:2.6rem;font-weight:400;color:var(--ocre-deep);
  line-height:1;font-variant-numeric:tabular-nums;margin:0}
.live-big small{display:block;font-family:var(--body);font-size:.65rem;font-weight:800;
  letter-spacing:.16em;text-transform:uppercase;color:var(--ink-faint);margin-top:.45rem}
.prenoms{display:flex;flex-wrap:wrap;gap:.35rem;margin-top:.9rem}
.prenoms span{background:rgba(102,113,74,.16);color:var(--olive);padding:.25rem .6rem;
  font-size:.83rem;font-weight:700}
.live-empty{color:var(--ink-faint);font-style:italic;font-size:.9rem}
.sync{font-size:.85rem;font-weight:700;margin-top:1.1rem;min-height:1.2em}
.sync.ok{color:var(--olive)}
.sync.ko{color:var(--rouge)}
"""

SECTION_LIVE = """
      <h3 style="font-family:var(--display);font-size:1.15rem;font-weight:700;color:var(--ocre-deep);margin:2rem 0 .3rem">Où en est le groupe</h3>
      <p style="font-size:.9rem;color:var(--ink-faint);margin-bottom:1rem">Mis à jour à chaque réponse. Ton vote est déjà compté.</p>
      <div class="live-card">
        <p class="live-big" id="lv-personnes">{{ etat.personnes }}<small>personnes attendues</small></p>
        <p style="margin:.7rem 0 0;font-size:.87rem;color:var(--ink-faint)">
          <span id="lv-reponses">{{ etat.reponses }}</span> réponse(s) ·
          <span id="lv-presents">{{ etat.presents }}</span> qui viennent
        </p>
        <div class="prenoms" id="lv-prenoms">
          {% for p in etat.prenoms %}<span>{{ p }}</span>{% endfor %}
        </div>
      </div>
      <div class="live-card" style="margin-top:.8rem">
        <h4 style="font-family:var(--display);font-size:1rem;margin:0 0 .8rem">Les couchages — <b style="color:var(--rouge)">{{ etat.lits_a_sortir }}</b> lit(s) à sortir</h4>
        <div class="tally" id="lv-couchages">
          {% for nom, n in etat.couchages.items() %}
          <div class="tally-row" data-cle="{{ nom }}">
            <div class="tally-top"><span>{{ nom }}</span><b>{{ n }}</b></div>
            <div class="bar"><i style="width:{{ (n * 100 // (etat.presents or 1)) if etat.presents else 0 }}%"></i></div>
          </div>
          {% endfor %}
        </div>
      </div>
      <div class="live-card" style="margin-top:.8rem">
        <h4 style="font-family:var(--display);font-size:1rem;margin:0 0 .8rem">Les arrivées en train</h4>
        {% if etat.trains %}
        <div class="tally">
          {% for t in etat.trains %}
          <div class="tally-top"><span>{{ t.qui }}</span><b style="font-weight:600">{{ t.quand }}</b></div>
          {% endfor %}
        </div>
        {% else %}<p class="live-empty">Personne n'a encore annoncé son train.</p>{% endif %}
      </div>
      <div class="live-card" style="margin-top:.8rem">
        <h4 style="font-family:var(--display);font-size:1rem;margin:0 0 .8rem">Les activités</h4>
        <div class="tally" id="lv-activites">
          {% for nom, n in etat.activites.items() %}
          <div class="tally-row" data-cle="{{ nom }}">
            <div class="tally-top"><span>{{ nom }}</span><b>{{ n }}</b></div>
            <div class="bar"><i style="width:{{ (n * 100 // (etat.presents or 1)) if etat.presents else 0 }}%"></i></div>
          </div>
          {% endfor %}
        </div>
      </div>
      <p class="sync" id="sync"></p>
"""

SCRIPT_API = """
<script>
/* ── Synchronisation serveur (ajouté par build_template.py) ────────────────
   Greffe additive : le script d'origine garde localStorage, le budget vivant
   et la timeline. On ajoute l'envoi au serveur et les compteurs partagés. */
(function(){
  "use strict";

  var sync = document.getElementById("sync");
  var timer = null, dernierEnvoi = "";

  function etatLocal(){
    var coche = function(n){
      var e = document.querySelector('input[name="' + n + '"]:checked');
      return e ? e.value : "";
    };
    return {
      nom: document.getElementById("nom").value.trim(),
      presence: coche("rsvp"),
      nb: parseInt(document.getElementById("nb").value, 10) || 1,
      couchage: coche("couchage"),
      transport: coche("transport"),
      train: document.getElementById("train").value.trim(),
      activites: Array.prototype.map.call(
        document.querySelectorAll('input[name="act"]:checked'),
        function(e){ return e.value; })
    };
  }

  function dire(msg, ok){
    sync.textContent = msg;
    sync.className = "sync " + (ok ? "ok" : "ko");
  }

  function pourcent(n, total){ return total > 0 ? Math.round(n / total * 100) : 0; }

  function peindre(etat){
    document.getElementById("lv-personnes").firstChild.nodeValue = etat.personnes;
    document.getElementById("lv-reponses").textContent = etat.reponses;
    document.getElementById("lv-presents").textContent = etat.presents;

    var box = document.getElementById("lv-prenoms");
    box.textContent = "";
    etat.prenoms.forEach(function(p){
      var s = document.createElement("span");
      s.textContent = p;              // textContent : jamais d'injection HTML
      box.appendChild(s);
    });

    [["lv-couchages", etat.couchages, null],
     ["lv-activites", etat.activites, null]].forEach(function(pair){
      var racine = document.getElementById(pair[0]), compte = pair[1];
      Array.prototype.forEach.call(racine.querySelectorAll(".tally-row"), function(row){
        var n = compte[row.dataset.cle] || 0;
        row.querySelector("b").textContent = n;
        row.querySelector(".bar i").style.width = pourcent(n, etat.presents) + "%";
        row.classList.toggle("lead", !!pair[2] && n > 0 && pair[2] === row.dataset.cle);
      });
    });
  }

  function envoyer(){
    var s = etatLocal();
    if (!s.nom || !s.presence) return;          // rien à envoyer tant que c'est incomplet
    var signature = JSON.stringify(s);
    if (signature === dernierEnvoi) return;     // pas de POST si rien n'a bougé

    fetch("/api/reponse", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: signature
    }).then(function(r){
      return r.json().then(function(j){ return { ok: r.ok, j: j }; });
    }).then(function(res){
      if (!res.ok) { dire(res.j.error || "Enregistrement refusé.", false); return; }
      dernierEnvoi = signature;
      peindre(res.j.etat);
      dire("✓ Ta réponse est enregistrée et comptée ci-dessus.", true);
    }).catch(function(){
      dire("Pas de connexion — ta réponse est gardée ici, elle repartira toute seule.", false);
    });
  }

  function planifier(){ clearTimeout(timer); timer = setTimeout(envoyer, 900); }
  document.addEventListener("input", planifier);
  document.addEventListener("change", planifier);

  // Rafraîchissement des compteurs des autres, sans écraser la saisie en cours.
  function rafraichir(){
    fetch("/api/etat").then(function(r){ return r.json(); }).then(peindre).catch(function(){});
  }
  setInterval(rafraichir, 30000);
  document.addEventListener("visibilitychange", function(){
    if (!document.hidden) rafraichir();
  });

  envoyer();
})();
</script>
"""


RIB_ENV = HERE.parent / "deploy" / "rib.env"


def injecter_rib(html: str) -> str:
    """Remplace les placeholders __RIB_*__ par les vraies coordonnées.

    Elles vivent dans deploy/rib.env, gitignoré : la page versionnée ne contient
    jamais l'IBAN. Sans ce fichier, la page reste servie mais la cagnotte affiche
    un texte d'attente plutôt qu'un placeholder brut.
    """
    import re

    defauts = {"RIB_TITULAIRE": "coordonnées à venir", "RIB_IBAN": "communiqué dans le groupe",
               "RIB_BIC": "—", "RIB_BANQUE": "—"}
    valeurs = dict(defauts)
    if RIB_ENV.exists():
        valeurs.update(dict(re.findall(r'^(\w+)="(.*)"$', RIB_ENV.read_text(encoding="utf-8"), re.M)))
    else:
        print(f"  ⚠️  {RIB_ENV} absent — la cagnotte affichera un texte d'attente")

    for cle, val in valeurs.items():
        html = html.replace(f"__{cle}__", val)
    restants = re.findall(r"__RIB_\w+__", html)
    if restants:
        raise SystemExit(f"Placeholders non résolus : {sorted(set(restants))}")
    return html


def main() -> None:
    src = injecter_rib(SOURCE.read_text(encoding="utf-8"))

    src = src.replace("</style>", CSS_LIVE + "</style>", 1)

    # Les compteurs vont dans l'étape 3, sous le récapitulatif : c'est là que
    # l'invité arrive une fois son vote posé.
    ancre = '      <p style="margin-top:1.2rem;font-size:.87rem;color:var(--ink-faint)">'
    if ancre not in src:
        raise SystemExit("Ancre de fin d'étape 3 introuvable dans site/public.html")
    src = src.replace(ancre, SECTION_LIVE.strip() + "\n" + ancre, 1)

    src = src.rstrip() + "\n" + SCRIPT_API

    doc = ("<!doctype html>\n<html lang=\"fr\">\n<head>\n"
           "<meta charset=\"utf-8\">\n"
           "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
           "<meta name=\"theme-color\" content=\"#1c1714\">\n"
           "<link rel=\"icon\" href=\"data:image/svg+xml,"
           "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
           "%3Ctext y='26' font-size='26'%3E%F0%9F%8E%82%3C/text%3E%3C/svg%3E\">\n"
           + src + "\n</body>\n</html>\n")
    # <title>, <link> et <style> appartiennent au <head>.
    doc = doc.replace("<header class=\"hero\">", "</head>\n<body>\n<header class=\"hero\">", 1)

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(doc, encoding="utf-8")
    print(f"{OUT.relative_to(HERE.parent.parent)} — {len(doc)} octets")


if __name__ == "__main__":
    main()
