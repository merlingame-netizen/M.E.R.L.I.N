# Tutorial-free UX — show, don't tell

> Ref: Vampire Survivors, Slay the Spire, Hades. Le joueur apprend en JOUANT,
> pas en lisant des tooltips. Chaque mecanique se decouvre par l'experience.

---

## Principe

Si on doit ECRIRE comment ca marche, c'est que ca marche pas. Le seul tutoriel
acceptable est celui qui fait jouer le joueur SANS qu'il s'en rende compte.

---

## Ce qu'on supprime ou cache

### ❌ A proscrire absolument

- **Tooltips au survol** : "Cliquez pour..." → le bouton se suffit a lui-meme
- **Pop-ups d'introduction** : "Voici votre barre de vie" → la barre vit, c'est tout
- **Hints en bas d'ecran** : "[ESPACE] pour..." → si l'action est evidente, l'icone suffit
- **Tutoriels modaux** : 5 ecrans qui expliquent → faits via le 1er run guide
- **Texte instructif dans les dialogues** : "Vous devez faire X parce que Y" → le LLM raconte, n'explique pas

### ✅ Ce qui reste

- Le 1er run lui-meme (Brocéliande tuto) qui montre les mécaniques
- Quelques retours visuels CRITIQUES (couleur d'une stat qui change, son sur clic)
- L'iconographie cohérente (un X rouge = combat, une rune = ogham)

---

## Mapping mécanique → comment elle se découvre

| Mécanique | Découverte | Cycle qui l'introduit |
|-----------|------------|----------------------|
| **3 axes Souffle/Esprit/Coeur** | Implicite via choix : "Toucher (vif)" / "Dechiffrer (lent)" / "Saluer (ouvert)". Le joueur sent les 3 voies sans les nommer. | 1er run tuto, dès la 1ère carte |
| **Stats 0-10** | Jamais affichees brut. Visible via la qualité narrative ("tes mains tremblent encore" = stat basse). Apres 5 runs, le joueur a la sensation d'evoluer. | Cumulé sur 3-5 runs |
| **DC croissant** | Carte 5 plus difficile que carte 1 → joueur sent que la fin du run pèse. Pas de "DC 12" affiché. | Au 2e run, le joueur compare |
| **Ogham modifier** | Equiper un Ogham change SUBTILEMENT la narration ("la pierre te reconnait"). Le joueur teste, voit la difference. | 3e run, pendant la sélection Ogham |
| **Faction reputation** | Affiche post-run sous forme RP : "Les Druides te connaissent maintenant". Pas de score. | A la fin du 1er run |
| **Trait débloqué** | Annoncé par Merlin en RP entre runs ("Tu sais lire les pierres maintenant"). Pas d'icone trophy. | Au 4-5e run |
| **Memory log LLM** | Le LLM fait des callbacks ("La pierre que tu as déchiffrée resonne avec celle-ci"). Pas de "+5 souvenir". | Run 2+ |
| **Run modifiers (Gifts)** | 3 cartes proposées au joueur, il choisit, l'effet se voit dans la narration suivante. Pas de tooltip "stack +5%". | Run 1 |

---

## UI minimaliste — règles d'écriture

### Tons et longueur

- **Risk_hint** : 6-10 mots, allusif. ❌ "DC 11, vous avez 60% de chance" ✅ "L'orgueil les froisse souvent."
- **Choice label** : 2-5 mots, verbe d'abord. ❌ "Vous décidez de toucher la pierre maitresse avec précaution" ✅ "Toucher la pierre"
- **Resolution narrative** : 2-3 phrases max. Pas de "vous avez réussi" sec. Le résultat se DEVINE du ton.
- **Trait announce** : 1 phrase métaphore. ❌ "Vous avez gagné +1 Esprit" ✅ "Les vieilles pierres te reconnaissent maintenant."

### Iconographie cohérente

| Concept | Icône | Couleur |
|---------|-------|---------|
| Ogham | rune (caractère unicode) | gold (#E6BD52) |
| Vie / essence | ♥ ou ❀ | crimson (#A6221A) |
| Anam | ✦ ou ⟡ | violet (#8B6BC8) |
| Faction Druides | ❀ | green |
| Faction Korrigans | ✦ | yellow |
| Faction Niamh | ⟡ | blue |
| Faction Ankou | † | grey |
| Faction Anciens | ◊ | bronze |

Mêmes icones partout — apprentissage par répétition visuelle.

---

## Discoverability checklist (pre-merge)

Avant tout merge qui ajoute une mécanique, vérifier :

- [ ] Aucun pop-up modal d'explication
- [ ] Aucun tooltip au survol qui dit "ceci est un X"
- [ ] La mécanique est visible dans une narration LLM (au moins une carte)
- [ ] Le retour visuel/sonore au déclenchement est <100ms
- [ ] Le joueur peut ignorer la mécanique au 1er run et le run reste jouable
- [ ] La mécanique APPROFONDIT après 3 runs (sinon = noise)

---

## Anti-patterns observés

- ❌ "Cliquez ici pour continuer" sur l'écran de fin → close auto suffit
- ❌ Stat label "Souffle: 6" affiché en HUD → invisible, ressenti
- ❌ Tutorial obligatoire avant le 1er run → on saute et on apprend par jeu
- ❌ Onglet "Aide" dans le menu → si besoin d'aide, c'est qu'on s'est planté
- ❌ Sound sur chaque mouvement → seulement sur événements significatifs
- ❌ Animation > 0.6s entre la décision et le retour → le joueur perd le fil

---

## Test pratique : "le test du joueur muet"

Donner la build à un joueur sans aucune explication. Il doit pouvoir :
1. Lancer un run
2. Faire 5 choix sans hésiter > 15s
3. Comprendre s'il a réussi ou pas
4. Avoir envie de relancer

Si une de ces 4 étapes coince → ré-écrire le concerné, pas ajouter de tooltip.

---

*Doc canonique : 2026-04-26 — Version 1*
