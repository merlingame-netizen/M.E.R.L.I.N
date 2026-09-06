#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique la version hébergée de la page, pour le serveur de `vm/app.py`.

La page publiée sur claude.ai garde les réponses dans le navigateur de chaque
invité : c'est tout ce qu'un artifact public peut faire. Ici, on ajoute ce qui
manque — les réponses partent sur le serveur, et chacun voit les compteurs des
autres.

Le principe est délibérément non invasif. On ne greffe rien au milieu du
document : `site/public.html` est repris tel quel, RIB et photos incrustés par
`site/build_public.py`, puis **un seul bloc est ajouté à la fin**. Les refontes
successives de la page ont cassé trois générations d'ancres au milieu du
HTML ; celle-ci n'en a aucune.

Le script ajouté lit l'état que la page écrit déjà dans `localStorage`, ce qui
lui évite de connaître quoi que ce soit de la logique interne du formulaire.

    python3 vm/build_template.py

Écrit `vm/templates/index.html` (gitignoré, il contient l'IBAN) et
`vm/valeurs.json`, la liste des réponses acceptées, extraite de la page
elle-même pour que le serveur ne puisse pas dériver du formulaire.
"""
from __future__ import annotations

import html
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "site"))
import build_public  # noqa: E402  (le chemin doit être posé avant l'import)

SORTIE_HTML = RACINE / "vm" / "templates" / "index.html"
SORTIE_VALEURS = RACINE / "vm" / "valeurs.json"

# Champs texte que le serveur accepte, avec leur longueur maximale.
CHAMPS_LIBRES = {"nom": 60, "nb": 4, "harr": 5, "num": 24, "hdep": 5, "idee": 140}

CSS = """
/* ── Compteurs en direct, ajoutés par la version hébergée ── */
.tally{display:inline-block;margin-left:.45rem;padding:.1rem .42rem;border-radius:2px;
  background:var(--craie-3);color:var(--encre);font-family:var(--texte);font-size:.68rem;
  font-weight:700;letter-spacing:.04em;vertical-align:.06em;font-variant-numeric:tabular-nums}
.opt input:checked+span .tally{background:var(--terre);color:var(--blanc)}
.pilules input:checked+span .tally{background:var(--blanc);color:var(--terre-fonce)}
.serveur{border:1px solid var(--craie-3);border-left:3px solid var(--pin);
  background:var(--blanc);padding:1rem 1.05rem;margin-bottom:1.4rem;font-size:.9rem;
  color:var(--encre-doux);line-height:1.5}
.serveur b{display:block;font-family:var(--display);font-size:1.05rem;color:var(--encre);
  margin-bottom:.3rem}
.serveur .chiffres{margin-top:.55rem;font-weight:600;color:var(--pin-fonce)}
.barre{flex-wrap:wrap}
.barre .bt{flex:1 1 10rem}
.bt.garder{background:var(--pin);border-color:var(--pin)}
.bt.garder:hover{background:var(--pin-fonce);border-color:var(--pin-fonce)}
.bt.garder[disabled]{opacity:.5}
"""

SCRIPT = r"""
/* ══════════════════════════════════════════════════════════════════
   Version hébergée : les réponses partent sur le serveur.

   Ce bloc ne connaît rien de la logique du formulaire. Il lit l'état
   que la page écrit déjà dans localStorage à chaque changement, et
   repose entièrement sur le DOM pour afficher les compteurs. C'est ce
   qui lui permet de survivre aux refontes de la page.
   ══════════════════════════════════════════════════════════════════ */
(function(){
  "use strict";
  var CLE = "elise-trente-ans";
  var etape3 = document.getElementById("e3");
  if (!etape3) return;

  function lu(){
    try { return JSON.parse(localStorage.getItem(CLE) || "{}"); } catch(e){ return {}; }
  }

  /* Le bandeau d'état, posé en tête de l'étape 3. */
  var bandeau = document.createElement("div");
  bandeau.className = "serveur";
  bandeau.innerHTML = '<b id="srv-titre">Enregistre ta réponse sur le site</b>' +
    '<span id="srv-mot">Elle rejoint celles des autres, et tu pourras la modifier ' +
    'quand tu veux depuis ce navigateur.</span>' +
    '<p class="chiffres" id="srv-chiffres"></p>';
  var fiche = etape3.querySelector(".fiche");
  etape3.insertBefore(bandeau, fiche ? fiche.nextSibling : etape3.firstChild);

  /* Le bouton d'enregistrement, devant l'envoi WhatsApp qui devient secondaire. */
  var barre = etape3.querySelector(".barre");
  var envoi = document.getElementById("envoi");
  var garder = document.createElement("button");
  garder.type = "button";
  garder.className = "bt garder";
  garder.id = "srv-garder";
  garder.textContent = "Enregistrer ma réponse";
  if (barre && envoi) barre.insertBefore(garder, envoi);
  if (envoi) envoi.textContent = "Envoyer aussi sur WhatsApp";

  function dire(t, titre){
    document.getElementById("srv-mot").textContent = t;
    if (titre) document.getElementById("srv-titre").textContent = titre;
  }

  /* Sur la version hébergée, le chemin principal n'est plus WhatsApp : la
     chapô de l'étape 3 le disait, elle ne le dit plus. */
  /* Le dernier paragraphe promettait que rien ne quittait le téléphone :
     sur cette version, si, et c'est tout l'intérêt. */
  var pieds = etape3.querySelectorAll("p");
  var pied = pieds[pieds.length - 1];
  if (pied && pied.textContent.indexOf("navigateur") !== -1){
    pied.textContent = "Ta réponse est gardée sur le site, et ce navigateur te " +
      "reconnaît : reviens quand tu veux la corriger, rien ne sera perdu.";
  }

  var chapo = etape3.querySelector(".chapo");
  if (chapo){
    chapo.innerHTML = "Relis, puis enregistre. Ta réponse part sur le site et rejoint " +
      "celles des autres — <strong>tu n'as rien d'autre à faire</strong>. Le bouton " +
      "WhatsApp reste là si tu préfères aussi nous l'écrire.";
  }

  /* Les compteurs : un badge par option, posé sur le <span> visible. */
  function compteurs(etat){
    var totaux = etat.choix || {};
    Object.keys(totaux).forEach(function(champ){
      Object.keys(totaux[champ]).forEach(function(valeur){
        var e = document.querySelector('input[name="' + champ + '"][value="' +
                                       (window.CSS && CSS.escape ? CSS.escape(valeur) : valeur) + '"]');
        if (!e || !e.nextElementSibling) return;
        var badge = e.nextElementSibling.querySelector(".tally");
        if (!badge){
          badge = document.createElement("b");
          badge.className = "tally";
          var cible = e.nextElementSibling.querySelector("b") || e.nextElementSibling;
          cible.appendChild(badge);
        }
        badge.textContent = totaux[champ][valeur];
        badge.title = totaux[champ][valeur] + " réponse(s)";
      });
    });
    var c = document.getElementById("srv-chiffres");
    var pl = function(n, un, plusieurs){ return n + " " + (n > 1 ? plusieurs : un); };
    c.textContent = etat.reponses
      ? pl(etat.presents, "oui", "oui") + ", " +
        pl(etat.personnes, "personne attendue", "personnes attendues") + ", " +
        pl(etat.escape_oui, "inscrit à l'escape game", "inscrits à l'escape game")
      : "Personne n'a encore répondu — sois le premier.";
  }

  function rafraichir(){
    fetch("/api/etat", { headers: { "Accept": "application/json" } })
      .then(function(r){ return r.ok ? r.json() : null; })
      .then(function(e){ if (e) compteurs(e); })
      .catch(function(){ /* hors ligne : la page reste utilisable */ });
  }

  garder.addEventListener("click", function(){
    var s = lu();
    if (!s.nom || !s.rsvp){
      dire("Il manque ton nom ou ta réponse — reviens à la première étape.");
      return;
    }
    garder.disabled = true;
    garder.textContent = "Enregistrement…";
    fetch("/api/reponse", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(s)
    }).then(function(r){
      return r.json().then(function(j){ return { ok: r.ok, corps: j }; });
    }).then(function(res){
      if (!res.ok){
        dire(res.corps.error || "Le serveur a refusé la réponse.");
        garder.textContent = "Réessayer";
        garder.disabled = false;
        return;
      }
      dire("Reviens quand tu veux la modifier : ce navigateur te reconnaît.",
           "C'est enregistré, merci");
      garder.textContent = "Mettre à jour ma réponse";
      garder.disabled = false;
      compteurs(res.corps.etat);
    }).catch(function(){
      dire("Pas de réseau. Réessaie, ou envoie le message WhatsApp.");
      garder.textContent = "Réessayer";
      garder.disabled = false;
    });
  });

  rafraichir();
  document.addEventListener("change", function(){ /* rien : on n'écrit qu'au clic */ });
})();
"""


def valeurs_acceptees(page: str) -> dict:
    """Relève dans la page toutes les paires name/value des boutons radio et
    des cases à cocher. C'est la page qui fait foi, pas une liste recopiée à
    la main dans le serveur — trois refontes ont montré ce que valait la
    recopie."""
    listes: dict[str, list] = {}
    motif = re.compile(
        r'<input\s+type="(radio|checkbox)"\s+name="([^"]+)"\s+value="([^"]+)"')
    for _genre, champ, valeur in motif.findall(page):
        listes.setdefault(champ, [])
        v = html.unescape(valeur)
        if v not in listes[champ]:
            listes[champ].append(v)
    if not listes:
        sys.exit("aucune valeur relevée : la page a-t-elle changé de forme ?")
    return listes


def main() -> None:
    page = build_public.SOURCE.read_text(encoding="utf-8")
    env = build_public.lire_env()
    for cle in build_public.DEFAUTS:
        page = page.replace("__%s__" % cle, env.get(cle, build_public.DEFAUTS[cle]))
    restants = re.findall(r"__RIB_\w+__", page)
    if restants:
        sys.exit("marqueurs non substitués : " + ", ".join(sorted(set(restants))))

    listes = valeurs_acceptees(page)
    SORTIE_VALEURS.write_text(
        json.dumps({"choix": listes, "libres": CHAMPS_LIBRES},
                   ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    page, combien, _ = build_public.incruster_photos(page)
    if 'src="photos/' in page:
        sys.exit("une photo n'a pas été incrustée")

    # Le seul ajout : une feuille de style et un script, à la fin du document.
    page += "\n<style>%s</style>\n<script>%s</script>\n" % (CSS, SCRIPT)

    SORTIE_HTML.parent.mkdir(parents=True, exist_ok=True)
    SORTIE_HTML.write_text(page, encoding="utf-8")
    print("%s — %.1f Mo (%d photos)" % (SORTIE_HTML, len(page.encode()) / 1e6, combien))
    print("%s — %d champs à liste fermée : %s"
          % (SORTIE_VALEURS, len(listes), ", ".join(sorted(listes))))


if __name__ == "__main__":
    main()
