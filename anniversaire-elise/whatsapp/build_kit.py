#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique le kit à coller dans WhatsApp Web, depuis `05_post_aix.md`.

Le fichier Markdown reste la source unique : les messages y sont écrits une
fois, et cette page les rend copiables en un clic, dans l'ordre où on les
envoie. Aucune recopie, donc aucune divergence.

Deux valeurs manquent volontairement au Markdown versionné — l'URL du site et
l'adresse du domicile, que le dépôt public ne doit pas porter. La page les
demande à l'ouverture et les garde dans le navigateur : elles ne sont ni dans
le fichier produit, ni transmises nulle part.

    python3 whatsapp/build_kit.py [-o kit.html]
"""
from __future__ import annotations

import argparse
import html
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
SOURCE = HERE / "05_post_aix.md"

# Quand envoyer chaque bloc, et à qui. L'ordre de ce tableau est l'ordre de
# la page — c'est-à-dire l'ordre des clics dans WhatsApp.
CALENDRIER = {
    "Nom du groupe": ("À la création", "Le champ « Nom du groupe »"),
    "Description du groupe": ("À la création", "Infos du groupe → Description"),
    "Message A": ("Tout de suite", "Dans le groupe, puis à épingler"),
    "Message B": ("Vers le 12 septembre", "En privé, un par un"),
    "Message C": ("Vers le 20 septembre", "Dans le groupe"),
    "Message D": ("Vendredi 9 octobre", "Dans le groupe"),
}

# Ce qui reste à remplir à la main, et qu'on surligne pour qu'il saute aux yeux.
A_REMPLIR = re.compile(r"\[(PRÉNOM|PRÉNOMS|N|X|HEURE|ACTIVITÉ)\]")


def blocs(md: str) -> list[tuple[str, str, str]]:
    """Renvoie (titre, sous-titre, contenu) pour chaque bloc de code d'un
    titre de niveau 2. On ne garde que les titres attendus : le fichier
    contient aussi de la procédure, qui n'a rien à coller."""
    trouves = []
    motif = re.compile(r"^## (.+?)\s*$\n(.*?)```\n(.*?)```", re.M | re.S)
    for titre, _entre, contenu in motif.findall(md):
        # « Message A — l'annonce ⏱ maintenant » -> clé « Message A »
        cle = titre.split("—")[0].strip()
        if cle not in CALENDRIER:
            continue
        quand, ou = CALENDRIER[cle]
        propre = re.sub(r"\s*⏱.*$", "", titre).replace("**", "").strip(" ,—-")
        trouves.append((propre, quand, ou, contenu.rstrip("\n")))
    manquants = set(CALENDRIER) - {t.split("—")[0].strip() for t, _, _, _ in trouves}
    if manquants:
        sys.exit("blocs introuvables dans 05_post_aix.md : " + ", ".join(sorted(manquants)))
    return trouves


def echappe(t: str) -> str:
    """Échappe pour le HTML, puis surligne ce qui reste à remplir à la main."""
    t = html.escape(t)
    return A_REMPLIR.sub(lambda m: '<mark>[%s]</mark>' % m.group(1), t)


GABARIT = """<title>Kit WhatsApp — trente ans d'Elise</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bodoni+Moda:ital,opsz,wght@0,6..96,400..700&family=Schibsted+Grotesk:wght@400..800&display=swap" rel="stylesheet">
<style>
/* ═══════════════════════════════════════════════════════════════
   Un établi, pas un document : on l'ouvre à côté de WhatsApp Web
   et on descend en copiant. Mêmes couleurs que l'invitation.
   ═══════════════════════════════════════════════════════════════ */
:root{
  --roche:#d9a441; --pin:#4f6b4a; --pin-fonce:#39503a;
  --terre:#b4562f; --terre-fonce:#8c3d1f;
  --craie:#ede6d8; --craie-2:#e3d9c6; --craie-3:#d3c6ad;
  --encre:#1f2833; --encre-doux:#43505e; --encre-pale:#7c8794; --blanc:#faf7f0;
  --display:'Bodoni Moda',Didot,serif;
  --texte:'Schibsted Grotesk',-apple-system,'Segoe UI',sans-serif;
  --mono:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  --col:760px; --pad:1.15rem;
}
*{box-sizing:border-box}
body{margin:0;background:var(--craie);color:var(--encre);font-family:var(--texte);
  font-size:16px;line-height:1.6;-webkit-font-smoothing:antialiased}
.col{max-width:var(--col);margin-inline:auto;padding-inline:var(--pad)}
h1,h2{font-family:var(--display);font-weight:600;line-height:1.14;margin:0;text-wrap:balance}

.tete{background:var(--encre);color:var(--craie);padding-block:2.2rem 1.9rem}
.tete .oeil{font-size:.64rem;font-weight:700;letter-spacing:.22em;text-transform:uppercase;
  color:var(--roche);margin:0 0 .5rem}
.tete h1{font-size:clamp(1.9rem,7vw,2.7rem);color:var(--blanc)}
.tete>.col>p{color:#9fb0c0;font-size:.94rem;margin:.9rem 0 0;max-width:36em}

/* ══ LES DEUX VALEURS QUI NE SONT PAS DANS LE DÉPÔT ══ */
.reglages{background:var(--craie-2);border-bottom:1px solid var(--craie-3);
  padding-block:1.2rem}
.reglages .grille{display:grid;grid-template-columns:1fr 1fr;gap:.9rem}
@media (max-width:620px){.reglages .grille{grid-template-columns:1fr}}
.reglages label{display:block;font-size:.64rem;font-weight:700;letter-spacing:.15em;
  text-transform:uppercase;color:var(--encre-doux);margin-bottom:.3rem}
.reglages input{width:100%;font-family:var(--texte);font-size:.98rem;padding:.75rem .85rem;
  border:1px solid var(--craie-3);background:var(--blanc);color:var(--encre);min-height:46px}
.reglages input:focus{border-color:var(--terre);outline:none}
.reglages .avis{font-size:.82rem;color:var(--encre-doux);margin:.8rem 0 0}
.reglages .avis b{color:var(--encre)}

main{padding-block:2rem 4rem}
.marche{display:grid;grid-template-columns:auto 1fr;gap:.9rem;margin-bottom:.75rem;
  align-items:baseline}
.marche span{font-family:var(--display);font-size:1.5rem;color:var(--craie-3);line-height:1}
.marche p{margin:0;font-size:.95rem;color:var(--encre-doux)}
.marche b{color:var(--encre)}
.plan{background:var(--blanc);border:1px solid var(--craie-3);padding:1.1rem 1.2rem;
  margin-bottom:2.4rem}
.plan h2{font-size:1.2rem;margin-bottom:.8rem}

.bloc{background:var(--blanc);border:1px solid var(--craie-3);margin-bottom:1.6rem}
.bloc>header{display:flex;flex-wrap:wrap;gap:.6rem;align-items:baseline;
  justify-content:space-between;padding:.9rem 1rem;border-bottom:1px solid var(--craie-3);
  background:var(--craie-2)}
.bloc h2{font-size:1.12rem}
.bloc .ou{font-size:.72rem;color:var(--encre-doux)}
.bloc .quand{font-size:.6rem;font-weight:700;letter-spacing:.14em;text-transform:uppercase;
  color:var(--blanc);background:var(--pin);padding:.25rem .5rem}
.bloc pre{margin:0;padding:1rem 1.1rem;font-family:var(--mono);font-size:.83rem;
  line-height:1.62;white-space:pre-wrap;overflow-wrap:anywhere;color:var(--encre)}
.bloc pre mark{background:#fbe6c8;color:var(--terre-fonce);font-weight:700;padding:0 .15em}
.bloc pre .vide{background:#f9ded4;color:var(--terre-fonce);font-weight:700;padding:0 .2em}
.bloc pre .ok{background:#e4ecdf;color:var(--pin-fonce);font-weight:600;padding:0 .2em}
.bloc footer{padding:.75rem 1rem;border-top:1px solid var(--craie-3);display:flex;gap:.6rem;
  align-items:center;flex-wrap:wrap}
.copier{background:var(--encre);color:var(--craie);border:none;padding:.7rem 1.1rem;
  font-family:var(--texte);font-weight:700;font-size:.72rem;letter-spacing:.12em;
  text-transform:uppercase;cursor:pointer;min-height:44px;transition:background .18s}
.copier:hover{background:var(--terre)}
.copier.fait{background:var(--pin)}
.compte{font-size:.75rem;color:var(--encre-pale);font-variant-numeric:tabular-nums}

.note{border-left:3px solid var(--roche);background:#f7f2e6;padding:.8rem .95rem;
  margin-top:.9rem;font-size:.87rem;color:var(--encre-doux)}
.note b{color:var(--encre)}
.pied{background:var(--encre);color:var(--encre-pale);padding-block:1.8rem;font-size:.84rem}
.pied b{color:var(--craie)}
#mot{position:fixed;left:50%;bottom:1.3rem;transform:translate(-50%,150%);
  background:var(--encre);color:var(--craie);padding:.75rem 1.2rem;font-weight:600;
  font-size:.86rem;z-index:99;transition:transform .3s cubic-bezier(.22,.8,.3,1);
  pointer-events:none;border-left:3px solid var(--pin)}
#mot.vu{transform:translate(-50%,0)}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<header class="tete"><div class="col">
  <p class="oeil">WhatsApp Web · à coller dans l'ordre</p>
  <h1>Kit du groupe</h1>
  <p>Tout est écrit. Tu crées le groupe vide, tu colles, tu testes, et tu
    n'ouvres aux numéros qu'une fois satisfait.</p>
</div></header>

<div class="reglages"><div class="col">
  <div class="grille">
    <div>
      <label for="url">Lien du site</label>
      <input type="url" id="url" value="__URL_DEFAUT__" placeholder="https://…"
             autocomplete="off" spellcheck="false">
    </div>
    <div>
      <label for="adresse">Adresse de la maison</label>
      <input type="text" id="adresse" placeholder="Numéro, rue, commune" autocomplete="off">
    </div>
  </div>
  <p class="avis"><b>Ces deux valeurs restent dans ton navigateur.</b> Elles ne sont pas
    écrites dans cette page, et rien n'est transmis nulle part — c'est pour ça qu'elles
    te sont demandées ici plutôt qu'inscrites dans le dépôt, qui est public.</p>
</div></div>

<main><div class="col">

  <div class="plan">
    <h2>Dans WhatsApp Web, dans cet ordre</h2>
    <div class="marche"><span>1</span><p><b>Teste d'abord tout seul.</b> Ouvre ta propre
      conversation — « Moi-même » en haut de ta liste — et colle-y le message A. Tu vois
      les sauts de ligne, les emoji et l'aperçu du lien avant que quiconque les voie.</p></div>
    <div class="marche"><span>2</span><p><b>Crée le groupe.</b> Menu ⋮ → <b>Nouveau
      groupe</b>. Si ta version exige au moins un participant, ajoute une personne de
      confiance&nbsp;; tu retireras ou garderas, à toi de voir.</p></div>
    <div class="marche"><span>3</span><p><b>Colle le nom et la description</b>, puis le
      message A dans la conversation. Clic droit dessus → <b>Épingler</b>.</p></div>
    <div class="marche"><span>4</span><p><b>Relis dans le groupe</b>, corrige ce qui te
      gêne, et seulement là ajoute les huit autres numéros.</p></div>
    <div class="note"><b>Un saut de ligne dans WhatsApp Web&nbsp;:</b> <kbd>Maj</kbd> +
      <kbd>Entrée</kbd>. Un simple <kbd>Entrée</kbd> envoie le message — un collage garde
      ses retours à la ligne, mais si tu retouches à la main, souviens-t'en.</div>
  </div>

__BLOCS__

</div></main>

<footer class="pied"><div class="col">
  <p><b>Trente ans d'Elise</b> — les textes viennent de
    <code>anniversaire-elise/whatsapp/05_post_aix.md</code>. Modifie-les là-bas, puis
    relance <code>build_kit.py</code>&nbsp;: cette page suit.</p>
</div></footer>

<div id="mot" role="status" aria-live="polite"></div>

<script>
(function(){
  "use strict";
  var $ = function(id){ return document.getElementById(id); };
  var CLE = "elise-kit-whatsapp";

  function lu(){ try { return JSON.parse(localStorage.getItem(CLE) || "{}"); } catch(e){ return {}; } }
  function ecrit(o){ try { localStorage.setItem(CLE, JSON.stringify(o)); } catch(e){} }

  var mot = $("mot"), minuteur;
  function dire(t){
    mot.textContent = t; mot.classList.add("vu");
    clearTimeout(minuteur); minuteur = setTimeout(function(){ mot.classList.remove("vu"); }, 2400);
  }

  /* Les deux valeurs absentes du dépôt, remplacées à la volée dans chaque
     bloc. Tant qu'elles manquent, le marqueur reste visible et rouge : on ne
     colle pas un message troué sans le voir. */
  var blocs = Array.prototype.slice.call(document.querySelectorAll(".bloc"));
  blocs.forEach(function(b){ b.dataset.brut = b.querySelector("pre").innerHTML; });

  function rendre(){
    var url = $("url").value.trim();
    var adr = $("adresse").value.trim();
    ecrit({ url: url, adresse: adr });

    blocs.forEach(function(b){
      var t = b.dataset.brut;
      t = t.split("VOTRE-URL-ICI").join(url
            ? '<span class="ok">' + url.replace(/[&<>]/g, "") + '</span>'
            : '<span class="vide">[LIEN DU SITE]</span>');
      t = t.split("[ADRESSE]").join(adr
            ? '<span class="ok">' + adr.replace(/[&<>]/g, "") + '</span>'
            : '<span class="vide">[ADRESSE]</span>');
      var pre = b.querySelector("pre");
      pre.innerHTML = t;
      b.querySelector(".compte").textContent = pre.textContent.trim().length + " caractères";
    });
  }

  var memoire = lu();
  if (memoire.url) $("url").value = memoire.url;   /* un choix passé prime sur le défaut */
  if (memoire.adresse) $("adresse").value = memoire.adresse;
  $("url").addEventListener("input", rendre);
  $("adresse").addEventListener("input", rendre);
  rendre();

  /* Copie, avec repli hors contexte sécurisé. */
  blocs.forEach(function(b){
    var bouton = b.querySelector(".copier");
    bouton.addEventListener("click", function(){
      var texte = b.querySelector("pre").textContent.replace(/\\n$/, "");
      if (texte.indexOf("[LIEN DU SITE]") !== -1 || texte.indexOf("[ADRESSE]") !== -1){
        dire("Renseigne d'abord le lien et l'adresse, en haut");
        return;
      }
      var ok = function(){
        bouton.textContent = "Copié"; bouton.classList.add("fait");
        setTimeout(function(){ bouton.textContent = "Copier"; bouton.classList.remove("fait"); }, 2000);
      };
      var ko = function(){ dire("Copie refusée — sélectionne le texte à la main"); };
      if (navigator.clipboard && window.isSecureContext){
        navigator.clipboard.writeText(texte).then(ok).catch(ko); return;
      }
      var z = document.createElement("textarea");
      z.value = texte; z.setAttribute("readonly", "");
      z.style.cssText = "position:fixed;top:-9999px;opacity:0";
      document.body.appendChild(z); z.select(); z.setSelectionRange(0, texte.length);
      var fait = false;
      try { fait = document.execCommand("copy"); } catch(e){ fait = false; }
      document.body.removeChild(z);
      fait ? ok() : ko();
    });
  });
})();
</script>
"""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-o", "--sortie", default=str(HERE / "kit.html"))
    ap.add_argument("--url", default="",
                    help="lien de l'invitation, pré-rempli dans le champ")
    args = ap.parse_args()

    md = SOURCE.read_text(encoding="utf-8")
    morceaux = []
    for titre, quand, ou, contenu in blocs(md):
        morceaux.append(
            '  <section class="bloc">\n'
            '    <header>\n'
            '      <div><h2>%s</h2><p class="ou">%s</p></div>\n'
            '      <span class="quand">%s</span>\n'
            '    </header>\n'
            '    <pre>%s</pre>\n'
            '    <footer><button type="button" class="copier">Copier</button>'
            '<span class="compte"></span></footer>\n'
            '  </section>' % (html.escape(titre), html.escape(ou), html.escape(quand),
                              echappe(contenu))
        )

    page = (GABARIT.replace("__BLOCS__", "\n\n".join(morceaux))
                   .replace("__URL_DEFAUT__", html.escape(args.url, quote=True)))
    pathlib.Path(args.sortie).write_text(page, encoding="utf-8")
    print("%s — %d blocs, %.0f Ko" % (args.sortie, len(morceaux), len(page.encode()) / 1024))


if __name__ == "__main__":
    main()
