# DA v8 : spécification d'application aux 6 scènes

Validée par Maxime le 2026-09-24 (« Super, partons là-dessus pour le dev cloud ! Applique à toutes les scènes »).
Référence visuelle et interactive : `docs/da_v8/merlin_v8.html` (ouvrir dans un navigateur, tout est animé et cliquable).
Grammaire de gravure : `docs/da_v8/charte_p1.md`. Contenus partagés (biomes, répliques, récits, cartes) : `docs/da_v8/kit.md`.

## 1. Les trois décisions qui font la v8

1. **Le monde est une gravure sur bois (patte P1).** Nuit = taille blanche creusée dans le noir (traits clairs `GRAV_TAILLE #C8B894` sur bois sombre), cerne d'encre `#0E0B07` épais (3,5 u sur 1600), hachures à 45° (h6 / h4 / x4) côté ombre, liseré de lune en haut à gauche, or réservé à « ce qui est à toi ». Page = encre sur crème (cartes, parchemins). Aucun dégradé, aucun flou. Détails chiffrés : `charte_p1.md` §2 à §5.
2. **Merlin est une sphère robot en 3D low poly, et c'est le SEUL élément 3D du jeu.** Il doit trancher avec le monde gravé (voulu : la machine au milieu de la légende). Pas de corps, pas de portrait, pas de mains : une sphère flottante hyper animée (voir §3).
3. **Les menus et panneaux suivent l'UX de Claude.** Panneaux sombres arrondis, listes sobres, survol en fond discret, raccourcis clavier visibles au survol, bouton primaire clair, voix de Merlin en serif qui s'écrit mot à mot avec un indicateur qui tourne, suggestions cliquables sous chaque réplique, statut « Gemma 4 · local · prêt ». Le chrome d'interface est en sans-serif (DM Sans), la voix et les titres restent en serif (EB Garamond, IM Fell English SC).

Et partout : **tout est ultra animé**, mais sans jamais bloquer la décision du joueur (§21 BIBLE) ni voler du CPU à Gemma pendant la génération (R58).

## 2. Monde gravé (toutes scènes)

- Ciel : bandes de lignes horizontales en tirets (plus denses vers l'horizon) qui défilent lentement ; étoiles en petites croix qui scintillent ; nuages gravés (aplat + cerne + liseré) qui dérivent.
- Lune : disque crème cerné, croissant d'ombre en hachure encre, gloire de 16 rayons qui tourne, anneau de 24 graduations runiques qui tourne en sens inverse.
- Relief : collines facettées (segments de 8 à 14 u, jamais de Bézier lisse), bande hachurée h6 sous la crête, sol à entailles courtes, brume en lignes hachurées qui dérivent.
- **Bouillonnement** : les motifs de hachure sont re-décalés de 0 à 1,4 u et tournés de ±1° toutes les 125 ms (8 i/s) pour l'effet « gravure animée ». Coupé en mouvement réduit.
- Pierres : aplat RING_BG, cerne, face ombre en x4, liseré lumière, fissures INT encre, mousse en aplat vert sombre.
- Oghams et triskèles gravés qui s'allument en or l'un après l'autre (vague lente).
- Étincelles en croix qui montent des sources de lumière.
- Le biome n'apparaît QUE dans la porte au menu (neutralité multi-biomes, R97). En jeu, le décor est celui du biome du run, dans la même grammaire.

## 3. Merlin, la sphère (nœud partagé `MerlinOrb`, réutilisé dans les 6 scènes)

Construction (valeurs du prototype, rayon de coque 0,62) :
- coque = icosphère subdivision 1 (80 faces), flat shading, gris métal en 4 nuances alternées par face (seul élément en gris : le gris est réservé à Merlin) ;
- cœur = icosaèdre cyan `#9FD3E6` visible entre les plaques ;
- visière noire (bande de cylindre ouverte, ~130°) et 2 yeux-barres émissifs devant, avec halo additif ;
- antenne + pointe octaèdre qui clignote ;
- anneau runique or incliné avec 6 graduations, et 3 satellites octaèdres (or, cyan, crème) sur orbites inclinées.

Vie permanente : flottement (2 sinus), plaques qui « respirent » (chaque face poussée le long de sa normale, phase propre), cœur qui pulse, anneau qui tourne, satellites en orbite, clignement toutes les 2 à 5 s (double 1 fois sur 5), regard lissé vers la cible (curseur, bouton survolé, pierre survolée, carte survolée), pulsation à chaque mot prononcé.

Figures automatiques toutes les 3,5 à 6,5 s (au hasard) : pirouette 0,75 s, bond écrasé 0,5 s, vague qui parcourt la coque, faisceau de scan conique 1,3 s (les pierres balayées s'allument en cyan), satellites qui s'emballent. Réactions déclenchées : bond (choix validé), secousse (refus), glitch (plaques qui éclatent 0,7 s + saut d'écran).

7 humeurs (couleur + forme des yeux) : neutre cyan ; taquin = clin d'œil (un œil à 15 %) ; intrigué = or `#F4E0A8`, plus hauts, inclinés ; inquiet = pâle, courts, en accent circonflexe ; grave = bleu sombre, très courts ; émerveillé = or, très hauts ; désapprobateur = rouge `#D04848`, courts, en V. Seuls les yeux changent en mouvement réduit.

Au sol : ombre elliptique hachurée (dans la grammaire gravée) qui rétrécit quand la sphère monte, et anneaux de scan cyan concentriques. Ce pont 2D/3D fait tenir l'ensemble.

Implémentation Godot conseillée : `SubViewport` (transparent_bg, taille ~512², rendu 30 i/s) contenant la scène 3D, affiché par un `TextureRect`/`SubViewportContainer` dans la scène 2D ; `ArrayMesh` avec sommets dupliqués par face, mis à jour 30 fois par seconde (80 faces = coût négligeable) ; `StandardMaterial3D` `shading_mode = per_pixel` avec flat normals ou normales de face recalculées. Compatible GL Compatibility et export Web. API de script : `set_mood(name)`, `look_at_screen(pos)`, `trick(name)`, `speak_pulse()`, `set_generating(bool)` (ralentit tout pendant la génération LLM).

## 4. UI façon Claude (composants communs)

- Panneau : fond `#14100C` à 86-90 %, bord 1 px crème à 16 %, rayon ~16 px (1920), aucune ombre portée floue.
- Bouton primaire : fond crème, texte encre, rayon ~10 px, reflet qui passe toutes les 4,5 s.
- Ligne de liste : icône fine (trait 1,8), libellé + sous-titre gris, raccourci clavier (kbd) qui glisse à droite au survol ; survol = fond crème à 8 %, icône qui passe en or et tourne légèrement ; appui = échelle 0,985.
- Section « Récents » = historique des runs (point de couleur du biome, titre, biome · issue · date).
- Carte de réponse de Merlin : en-tête (2 petites barres-yeux cyan + « Merlin » + étoile à 4 branches qui tourne pendant l'écriture), texte en EB Garamond qui apparaît mot par mot (fondu + léger flou 0,18 s, ~24 mots/s), puis 1 à 3 suggestions en pilules qui « pop » en cascade. Clic sur la réponse = tout afficher.
- Pilule de sélection (biome, onglets) : fond sombre arrondi, flèches rondes, changement animé en glissement vertical 0,2 s, étiquette d'état colorée.
- Entrées : le panneau glisse depuis la gauche (0,45 s), les lignes arrivent en cascade (40-50 ms d'écart).
- Clavier partout (raccourcis, flèches, Entrée, Échap), cibles ≥ 44 px, focus visible (piliers UX §23).

## 5. Application scène par scène

### MerlinMenu : « Le seuil entre les mondes »
- Décor : trilithe gravé au centre, porte = vignette du biome au focus (Brocéliande ouverte ; Falaises entrouvertes ; les autres scellées avec chaînes + sceau), 8 menhirs = 8 biomes (glyphe gravé, gemme d'état verte / orange clignotante / éteinte, menhir courant levé avec gloire dorée).
- Survol d'un menhir = la porte montre le biome (flash) et Merlin le commente ; clic sur un biome débloqué = choix du biome (remplace l'overlay `BIOME_CARDS`) ; 3 clics sur un scellé = glitch de Merlin + « Tu n'as rien vu. ».
- Panneau latéral façon Claude : M·E·R·L·I·N (IM Fell, or, respiration crème), « Le seuil entre les mondes », bouton « Nouveau récit » (N), Reprendre (R, avec le run en cours), Chroniques (C), Cartes (K), Options (,), section Récents, pied « Gemma 4 · local · prêt » + Quitter.
- Carte de réponse de Merlin en bas à droite, sphère au-dessus, pilule de biome en bas au centre.

### MerlinSelection : les 3 récits
- Fond : le seuil assombri (lune, ciel, brume), jamais un biome entier.
- Les 3 récits = 3 cartes-parchemins en polarité page (encre sur crème, cerne, hachures encre), disposées comme des propositions de Claude (cartes arrondies survolables, sceau de faction dessiné).
- Survol = la carte se lève, Merlin la regarde et la commente dans sa carte de réponse ; clic = les deux autres se consument, le squelette des 5 beats se trace à la plume (nœuds qui « pop »), puis bouton primaire « Entrer dans le récit ».
- Merlin répond pendant la génération (étoile qui tourne) : l'attente est animée ET skippable (R110).

### MerlinGame : le plateau
- Décor gravé du biome du run (Brocéliande : forêt gravée avec lucioles ; Falaises : mer à lignes, phare qui balaie).
- Situation = message de Gemma façon Claude (carte de réponse large, texte serif qui s'écrit mot à mot), tags requis en empreintes gravées qui s'allument quand couverts.
- Main de cartes en polarité page (charte P1 §5 : bordure de rareté, rune, bande d'archétype), survol ×1,18 + évocation, vol en arc vers la zone combo.
- Jauges : anneaux gravés (charte P1 §5 : Intégrité verte, Corruption en 5 segments violets), chemin des beats en nœuds.
- Merlin : sphère en petit (coin haut droit) qui commente la carte survolée et réagit au degré (humeurs). Elle remplace l'œil-lune de R126 à l'écran de jeu (un seul Merlin visible).
- La cinématique de fusion et la logique de run ne changent PAS (seulement le rendu). Glitch de Corruption R75 par paliers conservé, traduit dans la grammaire (traits qui bavent en violet, décalages).

### MerlinEnd : l'épilogue
- Épilogue = fil de messages façon Claude (Merlin + narration), vignette gravée de la fin (fusion / refus / corruption), récapitulatif (éclats, cartes-souvenir) en liste sobre, boutons « Rejouer » (primaire) et « Retour au seuil ».
- Merlin réagit selon la fin (émerveillé, grave, désapprobateur).

### MerlinOptions
- Page de réglages façon Claude : sections (Affichage, Audio, Accessibilité, Gemma), interrupteurs et curseurs arrondis, description grise sous chaque réglage, fond = seuil gravé très assombri.
- Mouvement réduit (R74) : coupe le bouillonnement, les figures de Merlin et les glitchs ; l'information reste.

### GemmaConsole
- Console = interface de conversation façon Claude : fil de messages (utilisateur à droite, Gemma à gauche en serif, streaming mot à mot), champ de saisie arrondi en bas avec bouton d'envoi, métriques discrètes (tok/s, contexte) en gris. La sphère Merlin en petit réagit pendant la génération.

## 6. Contraintes non négociables

- **Couleurs** : tout vient de `MerlinVisual` (zéro hex en dur ailleurs). Ajouter les constantes nouvelles : `GRAV_TAILLE #C8B894`, `GRAV_PAPIER_FOULE #D6C8A6`, `GRAV_OR_REHAUT #E8CC7A`, `SILHOUETTE #0E0B07`, `MACHINE_CYAN #9FD3E6`, couleurs d'humeur des yeux, `BIOME_*` (8), `MERLIN_GRAYS` (4).
- **Polices** (OFL, à ajouter avec leur licence) : EB Garamond, IM Fell English SC, DM Sans.
- **Performance** : décor ≤ 15 écritures/s par calque animé (throttle §21 R121), bouillonnement 8 i/s, sphère 30 i/s, tout en pause fenêtre cachée ; pendant une génération LLM, `set_generating(true)` divise les animations par 2 et coupe les figures.
- **Flux** : ne pas modifier la logique de run, la save (R108), les prompts ni la résolution. Le menu change (choix du biome par les menhirs) : c'est un changement de flow, donc gate R109.
- **Gates avant chaque commit runtime** : parse check sans erreur, smoke des scènes touchées (`passed=true`, `script_errors=[]`), et en fin de chantier soak 200/200 + autoplay 3/3 (R109). Sur Linux, appeler Godot directement (`tools/cli.py` porte des chemins Windows).
- **Bible** : ajouter les règles **R192 et suivantes** (au canon de9d1385 le plus grand numéro est R191, §26 « Penn ar Bed » ; revérifier avant d’écrire) : Merlin-sphère (amende R16/R126/R129), Seuil entre les mondes (R97/R132), patte P1 + UI façon Claude (amende §20 et R70 : sans-serif autorisé pour le chrome d'interface, serif pour la voix et les titres).
- **Textes** : biome-agnostiques hors contexte de biome ; voix de Merlin taquine, brève, par questions, ne nomme jamais la simulation ; pas de tiret cadratin.

## 6bis. Repères techniques relevés dans le canon (2026-09-24)

- `scripts/game/merlin_game.gd` fait environ 4 255 lignes, `merlin_scene_art.gd` 1 686, `merlin_menu.gd` 1 310 : procéder par petits commits vérifiés.
- L'overlay de choix de biome `BIOME_CARDS` est dans `scripts/game/merlin_menu.gd` (vers les lignes 834 et 870).
- Polices présentes : MorrisRoman et VT323 seulement ; EB Garamond, IM Fell English SC et DM Sans sont à ajouter avec leur licence OFL.
- `tools/cli.py godot` et `tools/adapters/godot_adapter.py` portent des chemins Windows : appeler Godot directement avec `--path`.
- Import headless : sans dossier `.godot/`, poser des `.gdignore` dans Assets, external, native, docs, archive, web-demo et `import/blender/enabled=false` dans `project.godot`, SANS commiter ces réglages locaux.

## 7. Points ouverts (ne pas trancher sans Maxime)

- Couleur du degré ÉCHEC : violet (canon actuel) ou rouge `#D04848` (le violet ne signifierait plus que la Corruption).
- Le build servi sur la VM contient un commit d'animations `236ed7fb` (branche locale VM `vm/anim-juice`) qui n'est pas sur GitHub : le signaler dans la PR, ne pas l'inventer.
