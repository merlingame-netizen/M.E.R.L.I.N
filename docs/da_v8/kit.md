# KIT DE CONTENU PARTAGÉ : DA v3, 3 pattes (P1 Gravure · P2 Enluminure · P3 Aplats)

Les 3 prototypes utilisent ce kit à l'identique : mêmes textes, mêmes positions, mêmes données, mêmes interactions et mêmes durées. Seul le traitement graphique change d'une patte à l'autre. Canvas de référence : 1920×1080, mis à l'échelle avec letterbox.

Sources : `docs/BIBLE.md` v2.0 (R33, R47, R86, R97, R102, R103, R135, R147, R166, §20, §21, §23, §25) et le code à HEAD (`merlin_menu.gd`, `merlin_selection.gd`, `merlin_card.gd`, `merlin_run.gd`, `merlin_visual.gd`, `merlin_scene_art.gd`, `merlin_prompt_builder.gd`). Quand la bible et le code divergent sur un point visuel, le code fait foi (§20).

Conventions de voix, à respecter partout :
- **Merlin tutoie** et appelle le joueur « Voyageur » ou « mon ami ». Ses phrases sont brèves et imagées, il pose des questions. Il donne des indices, jamais la vérité, et ne nomme jamais la simulation, le jeu, une carte ni un joueur.
- **Le récit vouvoie** (« Vous », au présent, d'après `SYSTEM_PREFIX`). Une situation se termine sur un instant suspendu, jamais sur « que faire ? ».
- **Les évocations de cartes tutoient** (R102).
- Aucun tiret cadratin dans le texte affiché (R157). Les textes génériques ne nomment aucun biome (R155) ; seuls le seuil et les répliques de biome le peuvent.

---

## A) ROSTER DES BIOMES (le seuil)

L'ordre suit la progression vers le Graal : plus on avance dans la liste, plus le glitch est fort (R97). La teinte ne colore que la vignette vue dans la porte et la pierre survolée, jamais l'interface. Aucun biome n'utilise VIOLET, qui est réservé à la Corruption.

**Constantes à créer :** les couleurs `BIOME_*` sont nouvelles. Il faut les ajouter à `MerlinVisual` au portage (§20 : aucun hex en dur).

**Statuts de démo :**
- débloqué : 1 biome ;
- entrouvert (« prochain ») : 1 biome ;
- scellé : 6 biomes.

**Conditions de déblocage :** ce sont des propositions (R80/R166). Le joueur de démo possède 2 éclats sur 12.

| # | id | Nom affiché | Statut | Motif iconique (3 à 6 formes simples) | Teinte dominante / accent | Réplique de Merlin au survol |
|---|---|---|---|---|---|---|
| 1 | `foret` | Brocéliande | **débloqué** | arbre-monde (tronc trapèze + couronne de 3 lobes), menhir en ogive, croissant de lune, 3 lucioles (points) | `BIOME_FORET` #4F6B3E (= GREEN_DARK) / lucioles GOLD #C9A24B | « Brocéliande rêve encore. Tu entends ? Elle a gardé ta place sous les chênes. » |
| 2 | `falaises` | Les Falaises du Bout-du-Monde | **entrouvert** (« Bientôt » : achever un récit à Brocéliande) | 2 caps (triangles), phare (fût effilé), lanterne (losange), 1 vague (arc), goéland (V) | `BIOME_FALAISES` #4E6A78 (près de RARE_BLUE, sans être égal) / lanterne GOLD | « Les Falaises du Bout-du-Monde... La porte bâille déjà. Tu sens le sel ? » |
| 3 | `arree` | Les Monts d'Arrée | scellé (3 éclats) | crête à 3 dents, chapelle au sommet (carré + triangle), marais (ellipse sombre), 2 bandes de brume | `BIOME_ARREE` #5E5140 (tourbe et schiste) / brume MIST | « Là-haut, le marais a une porte. Qui la garde, à ton avis ? » |
| 4 | `iroise` | La Mer d'Iroise | scellé (5 éclats) | ligne d'eau, clocher englouti sous la ligne (rectangle + triangle), 2 cloches (demi-cercles), île basse (dôme) | `BIOME_IROISE` #3E5C5A (vert d'eau profond) / cloches CREAM | « Sous l'Iroise, des cloches sonnent encore. Pour qui, je me le demande. » |
| 5 | `alignements` | Les Alignements | scellé (7 éclats) | 5 menhirs en file de taille décroissante, ligne de sol, soleil bas (demi-disque) | `BIOME_ALIGNEMENTS` #8C8472 (granit à lichen) / soleil GOLD_DARK | « Des pierres en rang, comme une armée qui attend un ordre. Lequel ? Pas encore. » |
| 6 | `tintagel` | Tintagel | scellé (9 éclats) | à-pic (polygone), tour brisée aux créneaux cassés, pont étroit (arche), comète (point + traîne) | `BIOME_TINTAGEL` #6A5A48 (pierre) / GOLD_DARK #8A6A2E | « Un roi y est né, dit-on. Un autre y est tombé. Ou le même ? » |
| 7 | `avalon` | Avalon | scellé (11 éclats) | île ronde, pommier (tronc + couronne ronde), 3 pommes (disques), barque (croissant), 2 bandes de brume nacrée | `BIOME_AVALON` #CFC6B0 (nacre, près de CREAM) / pommes GOLD | « Les pommes y mûrissent sans hiver. C'est ça qui devrait t'inquiéter. » |
| 8 | `corbenic` | Corbénic | scellé (12 éclats) | tour carrée, coupe sur pied (graal), 4 rayons, une fissure brisée (ligne en zigzag) | `BIOME_CORBENIC` = GOLD #C9A24B + glitch maximal | « Celle-là, ne la regarde pas trop longtemps. Elle, elle te regarde déjà. » |

**Clic sur un biome scellé.** Il n'y a pas de navigation. Le sceau pulse et Merlin prend l'expression taquin, puis dit : « Scellée. Pas par moi... enfin, pas seulement. Rapporte-moi des éclats. »

**Clic sur le biome entrouvert.** Il n'y a pas de navigation. Merlin prend l'expression intrigué et dit : « Pas encore. Finis ce que tu as commencé sous les arbres, et elle s'ouvrira. »

**Rendu des 3 statuts :**
- **Débloqué** : motif complet et coloré, animé dans la porte.
- **Entrouvert** : motif visible à moitié derrière un voile qui se lève sur 40 %, avec un filet de lumière GOLD qui fuit.
- **Scellé** : silhouette seule en SILHOUETTE #0E0B07 sur la brume, un **sceau** par-dessus (cercle, 2 liens croisés, point central), et le nom en DIM_WARM suivi de « Scellé ».
- Le glitch des silhouettes scellées augmente de #3 à #8 : décalage de 0 à 4 px et tremblement de 0 à 1,5 px.

---

## B) MENU = LE SEUIL ENTRE LES MONDES

**Libellés exacts** (code HEAD `merlin_menu.gd`). Chaque glyphe est à redessiner dans la patte.

| Ordre | Libellé | Glyphe (clé MerlinGlyph) | État démo |
|---|---|---|---|
| 1 | CONTINUER | `spark` | actif (une traversée est en cours) ; variante grisée à prévoir |
| 2 | NOUVELLE PARTIE | `burst` | actif |
| 3 | CHRONIQUES | `book` | actif |
| 4 | OPTIONS | `target` | actif |
| 5 | QUITTER | `cross` | actif |
| bas | À PROPOS | `crown` | actif, petit format |

- Titre : `M·E·R·L·I·N`.
- Indicateur de chargement du LLM : « Merlin s'éveille ».
- Constellation des éclats au survol : « deux éclats déjà arrachés ». La formulation vient du code : chiffres écrits en lettres, avec un singulier « éclat déjà arraché ».

**Réplique de Merlin au survol de chaque bouton :**
- CONTINUER : « Ton sentier t'attend là où tu l'as laissé. Il n'a pas bougé... presque pas. »
- CONTINUER grisé : « Rien à reprendre. Tout reste à commencer, et c'est tant mieux, non ? »
- NOUVELLE PARTIE : « Une page blanche ! Choisis une porte, je m'occupe du reste. »
- CHRONIQUES : « Tout ce que tu as vécu, et deux ou trois choses que tu as oubliées. »
- OPTIONS : « Régler la lumière, la voix, le rythme... Pas le destin, hélas. »
- QUITTER : « Déjà ? Va. Je garde la lune allumée. »
- À PROPOS : « Ceux qui ont gravé le seuil. Salue-les en passant. »

**Répliques d'arrivée :**
- Premier lancement : « Ah, un Voyageur. Approche, n'aie pas peur des pierres, elles ne mordent qu'en hiver. »
- Retour, quand une sauvegarde existe : « Te revoilà. Le seuil gardait ta place, tu sais ? »

**6 répliques d'attente.** Elles ne nomment aucun biome et font entre 12 et 22 mots, conformément au format de `merlin_menu_voice`. Le jeu les tire au hasard toutes les 14 à 20 s d'inactivité, sans jamais répéter deux fois la même d'affilée.
1. « Les pierres comptent les pas de ceux qui passent. Les tiens, elles les connaissent déjà par cœur. »
2. « Tu cherches le chemin, ou tu attends qu'il te cherche ? Moi, j'ai tout mon temps. Enfin... presque. »
3. « Une porte se ferme, une autre bâille. Laquelle t'a regardé en premier ? Réfléchis bien, mon ami. »
4. « Pourquoi tout recommence ? Bonne question. Garde-la précieusement, elle te servira plus tard, là-bas. »
5. « Je connais la fin... enfin, je crois. Non, je ne dirai rien. Même si tu insistes. »
6. « La lune cligne. Ce n'est pas elle, c'est moi. Tu ne l'avais pas remarqué, Voyageur ? »

**Parcours NOUVELLE PARTIE :**
1. Un clic sur NOUVELLE PARTIE fait passer le focus aux pierres des biomes. Merlin dit alors : « Choisis une porte. Celle qui brille, de préférence. »
2. Un clic sur Brocéliande déclenche la réplique de validation, puis la transition vers la Sélection.

Cela fait 2 gestes. Cliquer directement la pierre de Brocéliande fait la même chose en 1 geste.

**Réplique de validation**, reprise de la réplique canon n°12 : « Va. Je marche derrière toi, un peu à gauche, comme toujours. »

**Composition** (canvas 1920×1080, positions identiques pour les 3 pattes) :

*Colonne gauche :*
- Titre `M·E·R·L·I·N` en haut à gauche en (96, 64), hauteur 64 px, GOLD, avec une respiration or-crème sur 6 s.
- Filet avec triskèle à y 150. Le triskèle mesure 22 px et fait un tour en 24 s.
- 5 rangées de menu de 520×66 px en x 96, aux y 300, 380, 460, 540 et 620 :
  - chaque rangée comporte un disque de 52 px avec son glyphe, un libellé de 26 px, puis un filet et un diamant ;
  - au focus, le disque devient or plein et s'entoure d'un halo.
- « À PROPOS » en (96, 990).
- Indicateur « Merlin s'éveille » en (96, 1030), 18 px, DIM_WARM.

*Centre :*
- **La lune, œil du seuil**, centrée en (1010, 170), rayon 60, avec son anneau runique de 6 arcs. Elle cligne au même rythme que Merlin.
- **Constellation des 12 éclats du Graal** (R166) sur un arc de (760, 260) à (1260, 260), en passant au-dessus de la lune. 2 étoiles sont allumées en GOLD, les 10 autres sont éteintes en RING_BG.
- **La porte (trilithe) :**
  - montants en x 840 à 900 et 1120 à 1180, de y 330 à 700 ;
  - linteau de x 810 à 1210, de y 290 à 340 ;
  - **ouverture** de x 900 à 1120, de y 340 à 700. La vignette du biome au focus s'y affiche.
- **8 pierres dressées** en arc devant la porte, une par biome. Chacune porte son glyphe gravé et offre une zone cliquable d'au moins 64×120.

  | # | Biome | Centre de la base (x, y) |
  |---|---|---|
  | 1 | Brocéliande | (690, 760) |
  | 2 | Falaises | (760, 820) |
  | 3 | Arrée | (850, 860) |
  | 4 | Iroise | (950, 880) |
  | 5 | Alignements | (1070, 880) |
  | 6 | Tintagel | (1170, 860) |
  | 7 | Avalon | (1260, 820) |
  | 8 | Corbénic | (1330, 760) |

  Les pierres mesurent de 56 à 64 px de large et de 110 à 130 px de haut.
- **Nom du biome au focus**, centré en (1010, 950) : 40 px en CREAM. Dessous, le statut en 20 px (« Débloqué », « Bientôt » ou « Scellé ») et la condition de déblocage en DIM_WARM.
- Une brume basse et neutre (MIST/CREAM) court au pied des pierres. Il n'y a **ni sol de biome, ni arbre, ni mer** hors de l'ouverture de la porte.

*Colonne droite :*
- **Portrait de Merlin** dans un cadre en arche de x 1420 à 1825, de y 170 à 710 (405×540, format 3:4). La main gauche et l'orbe débordent du cadre (voir C).
- **Bulle de Merlin** de x 1380 à 1850, de y 760 à 940 : en-tête « yeux + MERLIN », texte en MERLIN_BLUE qui s'écrit.

**Animations ambiantes du menu** (inventaire commun, légères pour le CPU) :
- Défilement automatique de la porte : les biomes passent l'un après l'autre, 4 s chacun, avec un fondu de 0,6 s. Il s'arrête au survol et reprend après 3 s d'inactivité.
- Scintillement des étoiles : 14 étoiles, déphasées.
- Une étoile filante toutes les 18 à 30 s.
- Motes or : 12 particules au plus.
- La brume glisse sur 20 s.
- Les pierres des biomes débloqués respirent lentement : lueur de 0,6 à 1, sur 3 s.
- Le sceau des biomes scellés frémit toutes les 6 à 9 s.
- Le triskèle tourne et le titre respire.
- Merlin : cycle au repos décrit en C.

---

## C) MERLIN, PORTRAIT VIVANT (buste, jamais en pied)

**Règle absolue.** Merlin est toujours un **buste cadré à mi-poitrine** (visage + mains + orbe). Jamais de corps entier, jamais de jambes, jamais de pied. Il apparaît au même endroit sur chaque écran (colonne droite). Sa taille varie, mais le dessin reste le même.

**Description**, en coordonnées normalisées du cadre (x et y de 0 à 1, origine en haut à gauche) :
- **Visage** : ovale long et étroit, menton en pointe qui se prolonge dans la barbe. Centre de la tête en (0,50, 0,36) ; largeur 0,34, hauteur 0,44 du cadre. Teint gris ardoise d'âge indéfinissable. Nez long et légèrement busqué, tracé d'un seul trait. 3 rides frontales et 2 pattes d'oie.
- **Crâne** : **nu**, haut et légèrement bombé. Il n'a **ni chapeau ni capuche** (R132, code HEAD). Des mèches grises longues partent de derrière les oreilles et tombent sur les épaules : 3 mèches de chaque côté.
- **Col** : un col haut et raide monte jusqu'aux oreilles et s'ouvre en 2 pans pointus. Il évoque la silhouette d'une capuche sans en être une. Le manteau se ferme par un disque d'or uni, sans triskèle, car le triskèle est réservé à l'interface.
- **Barbe** : courte et **fourchue**, ses 2 pointes descendent jusqu'à y 0,66. Une **perle d'or** de diamètre 0,025 est posée à la fourche, en (0,50, 0,62), et fait écho à l'orbe. La moustache couvre les commissures.
- **Sourcils** : épais, broussailleux, anguleux, chacun en 3 mèches. C'est l'organe principal de l'expression.
- **Yeux (signature)** : **2 barres verticales lumineuses**, sans pupille.
  - Couleur au neutre : EYE_NEUTRAL #5FB8E8.
  - Taille : largeur 0,018, hauteur 0,06 du cadre.
  - Entraxe : 0,10. Centre du regard à y 0,33.
  - Elles sont logées dans des orbites sombres (SILHOUETTE) et prolongées d'un léger halo de la même couleur.
- **Bouche** : un trait fin sous la moustache. Les commissures sont mobiles.
- **Mains** : longues, osseuses, jointures marquées. 4 doigts et un pouce sont lisibles. L'index gauche porte une **bague runique** (anneau et 3 traits d'ogham).
  - Main gauche, libre, pour les gestes : repos en (0,20, 0,82). Elle peut déborder du bord gauche.
  - Main droite, posée à plat sur l'orbe.
- **Objet tenu** : un bâton court dont on ne voit que le haut. Son **orbe GOLD** mesure 0,14 de la largeur du cadre et se trouve en **bas à droite**, en (0,84, 0,90). Il déborde du cadre d'environ 0,05. 3 étincelles runiques tournent autour.
- **Cadre** : une arche de pierre neutre, sans aucune marque de biome, doublée d'un filet or. Format 3:4, cadrage à mi-poitrine.
  - Fond : brume neutre (MIST), avec derrière la tête une **lune-nimbe** en CREAM à 20 % d'opacité, qui rappelle l'œil-lune de R126.
  - Le biome ne colore rien d'autre qu'un liseré d'accent de 2 px, au plus.
- **Couleurs réservées à Merlin** (à créer dans `MerlinVisual`) :

  | Constante | Hex | Usage |
  |---|---|---|
  | `MERLIN_SLATE` | #6E7477 | teint |
  | `MERLIN_SLATE_DARK` | #3C4144 | ombre |
  | `MERLIN_ASH` | #B9BDB6 | mèches, barbe, sourcils |

  Les yeux utilisent EYE_NEUTRAL, EYE_SURPRISE et EYE_ANGRY. La voix garde MERLIN_BLUE #A6CFF0 sur la cartouche MERLIN_SPEECH_BG, avec le liseré #5F8FBE.

**Tailles par écran.** On ne fait pas une simple mise à l'échelle : on redessine avec les épaisseurs de trait fixes de la patte.

| Écran | Taille | Niveau de détail |
|---|---|---|
| Menu | 405×540 | complet |
| Sélection | 270×360 | on retire les pattes d'oie |
| Plateau (médaillon) | 150×200 | on garde les yeux, les sourcils, la barbe et la perle, la main et l'orbe ; on retire les rides et les mèches fines |

**7 expressions.** Les valeurs sont relatives au neutre. « Barres » désigne la hauteur des yeux-barres.

| Expression | Sourcils | Barres (paupières) | Bouche | Mains | Tête / extra | Déclencheurs communs |
|---|---|---|---|---|---|---|
| **Neutre** | droits, 0° | 100 %, EYE_NEUTRAL | trait droit | gauche au repos sur le rebord du cadre ; droite posée sur l'orbe | 0° | par défaut ; retour au neutre après 4,5 s |
| **Taquin / amusé** | gauche levé de 8 px (+12°), droit neutre | gauche 100 %, droite 35 % (clin d'œil) | coin droit relevé en demi-sourire | gauche, paume ouverte vers le haut, index qui fait « viens » | +4° | survol des boutons, réaction partiel/réussite, clic sur scellé |
| **Intrigué** | asymétriques : l'un levé de 10 px, l'autre froncé | 110 %, EYE_SURPRISE #F2D24A | petite bouche pincée | gauche au menton (pouce + index) | -8° (inclinée) | survol de l'entrouvert, arrivée à la Sélection, lecture d'une situation |
| **Inquiet** | en accent circonflexe (bouts intérieurs +15°, levés de 6 px) | 60 %, bleu pâle (EYE_NEUTRAL mêlé à CREAM à 50 %) | commissures tombantes | gauche remontée contre la poitrine, doigts serrés | épaules +2 px | survol de L'Appel de l'Ombre, réaction échec |
| **Grave** | bas et droits (-6 px) | 40 %, fines, EYE_NEUTRAL assombri de 30 % | droite, serrée | **mains jointes en clocher** devant la poitrine (la droite quitte l'orbe) | lumière par en dessous (l'ombre monte) | palier de Corruption franchi, veille du climax, carte à coût jouée |
| **Émerveillé** | hauts, +12 px | 130 %, EYE_SURPRISE, écartées de +20 % | entrouverte | gauche, doigts écartés vers le haut | étincelles 2 fois plus rapides, orbe qui pulse plus fort | éclatante, validation d'un biome |
| **Désapprobateur** | froncés (bouts intérieurs -20°, bas) | 70 %, EYE_ANGRY #E0483A | V inversé | gauche, revers qui balaie (0,3 s) | regard détourné (barres décalées de -4 px), tête -6° | combinaison contradictoire, 3e clic d'affilée sur un scellé |

**Gestes additionnels**, combinables avec une expression :
- **Index levé** : indice. Joué avec chaque indice de situation.
- **Main devant la bouche** : loi du rêve, un mot retenu. Joué sur la réplique d'attente n°5 et sur « Je n'ai rien dit ».
- **Doigts qui tapotent l'orbe** : attente du LLM, pendant « Merlin s'éveille » et « Merlin rêve les trois sentiers ».

**Cycle au repos (idle), commun aux 3 pattes :**
- Respiration : épaules de ±2 px et tête de ±1 px, sur 4,2 s.
- Clignement toutes les 4 à 7 s, à intervalle aléatoire : les barres descendent à 10 % en 0,06 s puis reviennent en 0,09 s. Un double clignement survient 1 fois sur 5.
- Le regard suit le curseur ou l'élément au focus : barres décalées de ±4 px en x et ±2 px en y, tête de ±2°, lissage de 0,12 s.
- L'orbe pulse sur 2,4 s (échelle 1 à 1,06, lueur de 0,5 à 0,9). Les 3 étincelles font un tour d'orbite en 9 s.
- Les mèches et les pans du col dérivent de ±1,5° sur 7 s.
- Toutes les 9 à 14 s, un micro-geste aléatoire de 0,8 s : doigts qui pianotent sur l'orbe, pouce qui frotte la bague, ou main gauche qui se lève à peine.
- **Parole** : la bouche alterne 3 positions (fermée, mi-ouverte, ouverte) au rythme de l'écriture, environ toutes les 90 ms.
  - Écriture : 45 caractères par seconde. Un clic affiche tout le texte d'un coup.
  - Un blip de voix sonne tous les 2 caractères. Sa hauteur suit l'humeur :

    | Humeur | Hauteur du blip |
    |---|---|
    | neutre | 1,00 |
    | taquin | 1,12 |
    | intrigué | 1,08 |
    | inquiet | 0,94 |
    | grave | 0,85 |
    | émerveillé | 1,18 |
    | désapprobateur | 0,90 |

- **Mouvement réduit** : seuls les yeux changent (couleur, hauteur, clignement). Il n'y a plus de respiration, d'orbite ni d'animation de geste : la pose change d'un coup.
- **Une seule voix à la fois** (R124). L'ordre de priorité est : palier de Corruption, puis carte à coût, puis degré, puis survol.
- Au plateau, une réplique de survol ne se déclenche qu'après 600 ms de survol, puis ne peut pas revenir avant 4 s.

**Fiche « à faire / à éviter »** (cohérence de Merlin entre les pattes) :

| À faire | À éviter |
|---|---|
| Garder les barres bleues comme seul regard. Elles sont toujours lisibles et restent l'élément le plus lumineux du visage. | Des pupilles, des yeux ambrés en fente, une capuche pointue, un chapeau, des câbles « tech », une barbe longue de mage. |
| Faire porter l'expression d'abord par les sourcils et les barres, puis par la main gauche. | Animer tout le visage : on anime seulement les yeux, les sourcils, la bouche et la main gauche. |
| Garder la main droite toujours en contact avec l'orbe, sauf dans l'expression grave. | Mettre des signes de biome dans le cadre (feuille, vague...). |

---

## D) SÉLECTION (3 récits, tous à Brocéliande)

**Libellés du code :**
- Titre : « Choisis ton chemin ».
- Bouton sur chaque parchemin : « Suivre ce sentier ».
- Retour : « Retour », avec une flèche dessinée dans la patte.
- Pendant la génération : « Merlin rêve les trois sentiers ».
- Après le choix : « Merlin écrit » (R56).

**Réplique d'arrivée** (expression intrigué) : « Trois sentiers. Un seul te mènera quelque part ; les deux autres aussi, d'ailleurs. »

Les 3 récits couvrent les 3 envergures, une chacune (§25.3). Les pitchs sont narrés et donc vouvoyés. Ils adaptent R47 et R103, qui tutoyaient.

| # | Titre | Pitch (1 phrase) | Faction et symbole dessinable | Envergure | Figures | Réplique de Merlin (survol ou focus) |
|---|---|---|---|---|---|---|
| 1 | **Le Rite sans Fin** | « Au cœur de Brocéliande, des voix psalmodient sans relâche un rite que nul ne comprend plus, et quelque chose attend que vous l'écoutiez. » | Druides : **rameau de gui** (tige en Y, 2 feuilles en amande, 3 baies rondes) | périple | Le Chœur des Druides, Ordalc'h | « Des voix qui ne s'arrêtent jamais. Tu crois qu'elles ont oublié comment, ou pourquoi ? » |
| 2 | **Le Marché des Murmures** | « Une clairière s'éveille à la nuit, avec ses lanternes sans porteurs et ses marchands sans visage, et quelqu'un y connaît déjà votre nom. » | Créatures & Êtres : **lanterne sans porteur** (cage en losange, anneau, flamme en goutte) | brève | L'Être Indéfinissable, Fañch le Trotteur | « Là-bas, tout se vend. Même ce que tu ne savais pas posséder. Garde tes poches fermées. » |
| 3 | **Le Serment de Cendre** | « Un chevalier sans blason tourne depuis toujours autour d'une chapelle en ruine et vous supplie de l'aider à retrouver le serment qu'il a trahi. » | Chevalerie déchue : **épée brisée** (lame, garde en croix, éclat détaché) | odyssée | Le Chevalier Sans Nom | « Un chevalier sans nom... Il me rappelle quelqu'un. Non, laisse. Je n'ai rien dit. » (avec le geste de la main devant la bouche) |

**Couleurs des factions.** Elles sont reprises de `set_faction` et servent uniquement au ciel, à la lune et aux particules :

| Faction | Couleur |
|---|---|
| Druides | GREEN #7FA65C |
| Créatures & Êtres | RARE_BLUE #5A7A8C |
| Chevalerie déchue | or patiné #B59859 (GOLD mêlé à DIM_WARM à 45 %) |

Sur le parchemin, le symbole est tracé à l'encre (INK). La couleur de faction n'y apparaît qu'en petite touche (baies, flamme, éclat), pour ne pas se confondre avec la rareté Rare.

**Réplique au choix** (expression émerveillé, puis geste des doigts qui tapotent l'orbe) : « Ce sentier-là. Bien. Laisse-moi un instant, je le trace pour toi. »

**Squelette à 5 beats.** Il se trace au focus ou au survol du parchemin, et aussi au tap, pour que l'information ne soit jamais réservée au survol. Chaque nœud porte le glyphe de son type (voir G).

| Récit | 1 · Exploration | 2 · Rencontre | 3 · Épreuve | 4 · Dilemme | 5 · Climax |
|---|---|---|---|---|---|
| Le Rite sans Fin | L'orée du chant | Le Chœur méfiant | La pierre d'offrande | Rompre ou poursuivre | Le cœur du rite |
| Le Marché des Murmures | Les lanternes s'allument | Le troc du korrigan | La dette réclamée | Le pacte de l'Être | Payer le passeur |
| Le Serment de Cendre | La chapelle en ruine | Le chevalier sans blason | Le duel rejoué | Rendre ou garder le nom | Le serment de cendre |

Pour l'odyssée, les 5 beats affichés sont ceux de la première quête.

**Composition :**
- Titre centré à y 80, 40 px.
- 3 parchemins de 420×560, de y 190 à 750, en x 180, 650 et 1120. Chacun porte :
  - le symbole de faction (64 px) ;
  - le titre (36 px) ;
  - le pitch (24 px, à fer à gauche) ;
  - l'envergure et les figures (20 px, INK_DIM sur crème) ;
  - le bouton « Suivre ce sentier » (380×56).
- Merlin (270×360) de x 1590 à 1860, de y 190 à 550. Sa bulle va de x 1560 à 1880, de y 570 à 740.
- Squelette de x 180 à 1540, de y 800 à 960 : 5 nœuds de 56 px reliés par un tracé qui s'écrit en 0,6 s. Nom du beat sous chaque nœud, en 20 px.
- « Retour » en (60, 990).
- Animations ambiantes :
  - les parchemins ondulent de ±1° sur 6 s, déphasés ;
  - le parchemin au focus se soulève de 12 px en 0,22 s ;
  - la scène neutre du menu, assombrie, reste en fond (R125) ;
  - des motes couleur de faction se déplacent au focus.

---

## E) PLATEAU (récit « Le Rite sans Fin », Brocéliande)

**État de démo :**
- Intégrité **7/10** (anneau vert, glyphe cœur).
- Corruption **4**. L'anneau violet est gradué par 5, donc 4 segments sur 5 sont remplis ; le glyphe est une spirale voilée. On est au palier « sain ».
- Chemin à 5 nœuds, au beat courant.
- Libellés du code : bouton « Résoudre » ; marqueur de degré en pill avec « ÉCHEC », « PARTIEL », « RÉUSSITE » ou « ÉCLATANTE ».

**Degré, règle de prototype.** Elle est déterministe et sans dé, pour que les démos soient identiques d'une patte à l'autre :
- 0 tag requis couvert : **échec** ;
- 1 sur 2 : **partiel** ;
- 2 sur 2 : **réussite** ;
- 2 sur 2 avec 3 cartes posées, dont au moins un tag en plus des requis : **éclatante**.

**Variations de jauges :**
- Intégrité : échec -2, partiel -1, réussite 0, éclatante +1.
- Corruption : + la somme des coûts des cartes posées.
- Pour la démo, les touches 1 à 4 forcent le degré.

### 3 situations

Les tags requis restent des données. Ils s'affichent comme **2 empreintes** : des glyphes de concept dessinés, sans mot, qui s'allument quand une carte posée les couvre (voir le point à trancher n°3). Les cartes de la main qui couvrent un requis reçoivent le signal d'or à l'avance (R147/R150).

| # | Beat (type) | Locuteur | Texte (vouvoyé, suspendu) | Tags requis | Indice de Merlin (index levé) |
|---|---|---|---|---|---|
| S1 | 1 · L'orée du chant (Exploration) | le récit | « Un chant monte d'entre les menhirs, grave, sans un souffle entre les vers. À la troisième reprise, vous remarquez qu'il bute toujours sur le même mot, et que ce mot vous ressemble. » | Sens, Verbe | « Écoute où ça bute. Et si tu répondais, toi ? » |
| S2 | 3 · La pierre d'offrande (Épreuve) | le Chœur des Druides | « Au centre du cercle repose une pierre d'offrande trop lourde pour un seul homme, creusée d'une vasque vide. Les druides se taisent et vous regardent, attendant que vous la souleviez ou que vous y laissiez quelque chose de vous. » | Force, Sacrifice | « Ils ne veulent pas un cadeau. Ils veulent un prix. Tu as des épaules, non ? » |
| S3 | 4 · Rompre ou poursuivre (Dilemme) | Ordalc'h | « Ordalc'h, la sentinelle muette, pose sa main sur la vôtre et désigne la brèche du chant : l'arrêter libérerait le cercle, mais sous vos pieds les racines se tordent déjà vers l'ombre. Le chœur, lui, ne s'est jamais tu. » | Empathie, Nature | « Écoute les racines autant que les voix. Les deux ont peur, tu sais. » |

### 5 cartes de la main

Les tags suivent la bible R33, qui est la version couverte par les situations. Les tags v11 du code sont indiqués entre parenthèses.

| Carte (nom canon) | Nom en haut / rune en bas / motif ogham (R147) | Verbe | Tags | Archétype (bande basse) | Rareté | Coût, effet | Évocation canon | Réplique de Merlin au survol |
|---|---|---|---|---|---|---|---|---|
| **Le Regard Perçant** | Acuité / Sulwen / 0 | Observer | Sens (v11 : Vigilance, Sens) | Mystique, « MYSTÈRE » | Commune | aucun | « Tes yeux fendent l'ombre ; rien ne reste caché à qui sait vraiment voir. » (R102) | « Regarde mieux ce qui brille. Ce n'est pas toujours de l'or. » |
| **La Main de Fer** | Poigne / Dornek / 3 | Forcer | Force (v11 : Force, Endurance) | Offensif, « OFFENSE » | Commune | aucun | « Quand la douceur échoue, reste la poigne qui ne tremble pas. » (R102) | « La force ouvre les portes. Parfois aussi les mauvaises. » |
| **La Langue de Miel** | Charme / Melgan / 6 | Convaincre | Empathie, Verbe (v11 : Ruse, Empathie) | Social, « PAROLE » | Commune | aucun | « Tes mots coulent doux ; même les cœurs fermés s'entrouvrent. » (R102) | « Du miel, toujours du miel... Et si on te croyait vraiment ? » |
| **L'Appel de l'Ombre** | Ombre / Duvael / 11 | Invoquer | Instinct, Nature (v11 : Mystère, Nature) | Corrompu, « CORRUPTION » | Commune | **Corruption 1** (gemme violette) | « Tu appelles ce qui dort sous les racines. Il vient, mais il prélève son dû. » (R102, sans tiret depuis R157) | « Tu sens ce froid au bout des doigts ? Il ne vient pas de dehors. » (inquiet) |
| **Le Serment Tenu** | Serment / Ledoun / 21 | Jurer (verbe proposé, non canon) | Sacrifice, Franchise | Défensif, « DÉFENSE » | **Rare** | soin +1 (badge cœur) | « Tu as promis. Tu paies le prix. Et c'est précisément ce qui te donne du poids. » (pool enrichi du code, pas R102) | « Une promesse, ça pèse. Tu es sûr d'avoir les épaules ? » |

Les combinaisons de référence ci-dessous couvrent chaque situation et servent à vérifier les 4 degrés :

| Situation | Combinaison de référence | Tags couverts |
|---|---|---|
| S1 | Regard Perçant + Langue de Miel | Sens, Verbe |
| S2 | Main de Fer + Serment Tenu | Force, Sacrifice |
| S3 | Langue de Miel + Appel de l'Ombre | Empathie, Nature, **+1 Corruption** |

### Issues par degré

C'est le récit qui parle ici, pas Merlin. La 1re phrase, en italique, décrit le geste et fusionne les cartes jouées (R167). La suite dit la conséquence.

**S1** (Regard Perçant + Langue de Miel) :
- **Échec** : « *Vous tentez de reprendre le vers à l'endroit où il bute.* Votre voix se brise sur le mot, et le chant, offensé, repart plus fort et plus loin de vous. »
- **Partiel** : « *Vous fixez la bouche du plus vieux chanteur et murmurez le mot manquant.* Le chant hésite une mesure, puis vous engloutit ; un druide a vu votre audace, et il ne l'oubliera pas. »
- **Réussite** : « *Vous repérez l'instant exact où le chant trébuche et y glissez le mot, doucement.* Le vers se referme ; pour la première fois depuis longtemps les voix respirent, et le cercle s'ouvre d'un pas. »
- **Éclatante** : « *Vous lisez la faille du chant comme une ligne écrite et la chantez avec eux, juste.* Les voix se tournent vers vous, stupéfaites : l'une d'elles prononce votre nom avant que vous l'ayez dit. »

**S2** (Main de Fer + Serment Tenu) :
- **Échec** : « *Vous arc-boutez tout votre corps contre la pierre.* Elle ne bouge pas d'un doigt, votre épaule cède, et un murmure réprobateur court dans le cercle. »
- **Partiel** : « *Vous soulevez la pierre par un bord en jurant de ne pas la lâcher.* Elle retombe à mi-course et fend la vasque ; les druides acceptent, du bout des lèvres. »
- **Réussite** : « *Vous hissez la pierre en prononçant tout haut ce que vous laissez en gage.* La vasque se remplit d'une eau venue de nulle part, et le chœur, un instant, chante pour vous. »
- **Éclatante** : « *Vous portez la pierre comme on porte une promesse, sans un tremblement.* Le chant s'interrompt net ; le plus vieux druide s'incline et vous tend un rameau de gui. »

**S3** (Langue de Miel + Appel de l'Ombre) :
- **Échec** : « *Vous parlez aux racines comme on apaise une bête.* Elles se referment sur votre cheville ; Ordalc'h vous arrache à elles, et son silence devient reproche. »
- **Partiel** : « *Vous appelez ce qui dort sous le cercle en promettant qu'on ne lui fera pas de mal.* Les racines se calment, mais une traînée froide remonte le long de votre bras et n'en redescend pas. »
- **Réussite** : « *Vous tendez la main à Ordalc'h et, de l'autre, rassurez la terre qui gronde.* Le chant ralentit sans s'éteindre ; la sentinelle hoche la tête une seule fois, et c'est beaucoup. »
- **Éclatante** : « *Vous accordez votre voix aux racines et aux druides à la fois, un seul souffle pour deux peurs.* La brèche se referme d'elle-même ; sous vos pieds, une mousse neuve pousse en cercle. »

### Réactions de Merlin (une ligne, voix bleutée, après l'issue)

| Cas | Réplique | Expression |
|---|---|---|
| Échec | « Aïe. La pierre était plus têtue que toi. Relève-toi, on recommence. » | inquiet |
| Partiel | « À moitié. La moitié d'une porte, ça laisse quand même passer un pied. » | taquin |
| Réussite | « Joli. Tu vois ce qui arrive quand tu écoutes ? » | taquin |
| Éclatante | « Ça, c'était beau ! Ne prends pas la grosse tête, surtout. » (canon n°7) | émerveillé |
| **+ Corruption** (carte à coût jouée, quel que soit le degré ; remplace la réaction de degré) | « Tu as payé, et pas en or. Regarde un peu tes mains. » | grave |
| **+ Palier franchi** (4 vers 5, palier « trouble ») | « Le froid est entré. Ne le laisse pas s'asseoir près du feu. » | grave, avec le geste de la main devant la bouche |
| Série d'échecs (momentum ≤ -2) | « Trois chutes. Même les pierres roulent mieux. Allez, relève-toi. » (canon n°6) | taquin |

**Quand le palier est franchi (Corruption 4 vers 5) :**
- L'anneau pulse en 0,3 s (échelle 1, puis 1,3, puis 1).
- Une carte **Murmure Corrompu** part dans la défausse.
- Le voile passe en légère désaturation (palier « trouble », R75).
- Un indice statique reste affiché : un voile VIOLET à 6 % et une pastille près de l'anneau.

**Composition** (grille R136, identique pour les 3 pattes) :
- **HUD**, de y 36 à 96 :
  - à gauche, « Le Rite sans Fin » en 22 px, DIM_WARM ;
  - au centre, le chemin de 5 nœuds (x 660 à 1260, nœuds de 40 px, glyphe de type par nœud) ;
  - à droite, le bouton pause, un glyphe dessiné de 48×48.
- **Décor**, de y 96 à 296 : bandeau de Brocéliande.
  - Anneaux de 78 px à gauche : Intégrité en (48, 150), Corruption en (140, 150). La valeur est écrite dessous en 20 px.
  - **Médaillon de Merlin** (150×200) de x 1722 à 1872, de y 96 à 296.
- **Encart**, de y 296 à 644 :
  - la situation à gauche (x 96 à 1150) : locuteur en 22 px GOLD_DARK, texte en 36 px CREAM qui s'écrit (clic = tout afficher), et les 2 empreintes de 56 px sous le texte ;
  - la zone combo à droite (x 1200 à 1824) : **1 emplacement principal de 150×225** et **2 modificateurs de 120×180** ;
  - la bulle de Merlin s'ancre sous son médaillon (x 1380 à 1872, y 300 à 420) et recouvre le haut de la zone combo pendant 4 s au plus.
- **Ligne d'état**, de y 644 à 716 :
  - pill de degré de 170×48, en (96, 656) ;
  - aperçu de résolution en 20 px DIM_WARM (« Couvre 1 empreinte sur 2 ») ;
  - **« Résoudre »** de 264×56 en (1560, 652), GOLD quand au moins une carte est posée, grisé sinon.
- **Main**, de y 716 à 1044 (éventail et rangée « actions » fusionnés) :
  - 5 cartes de 180×270, en éventail de ±6°, centrées sur x 960, avec 8 px de recouvrement ;
  - survol : échelle 1,18 et soulèvement de 30 px (0,12 s) ;
  - l'évocation apparaît à l'agrandissement **et** à la sélection par tap.
- **Animations ambiantes du plateau** :
  - décor de Brocéliande : lucioles, brume, balancement des branches ;
  - les cartes qui couvrent un requis reçoivent une lueur GOLD en 3 crans (R150) ;
  - le nœud courant du chemin pulse ;
  - Merlin suit du regard la carte survolée.
- **Chorégraphie de résolution** (§21) :
  - fusion en 3 phases de 0,9 à 1,7 s selon le degré ;
  - pill de degré, avec une micro-secousse sur un échec ;
  - le typewriter écrit l'issue ;
  - les variations s'affichent sur les anneaux (flottant de 0,9 s) ;
  - puis vient la réaction de Merlin ;
  - enfin la nouvelle main est distribuée (0,24 à 0,28 s, retour élastique, décalage de 0,05 s).

---

## F) CARTES : planche des 5 états

La **ligne A**, obligatoire, présente la même carte dans les 5 états : **Le Regard Perçant** (Acuité / Sulwen / motif 0, évocation R102). Seul le traitement de rareté change.

La **ligne B** montre une carte canon réelle par état, pour vérifier l'effet en contexte :

| État | Carte |
|---|---|
| Commune | Le Regard Perçant |
| Rare | Le Serment Tenu |
| Épique | La Marche d'Équilibre (Constance / Kemwez / 25, effet PURGE 2, « Tu ne cherches pas la victoire : tu cherches la durée. Et tu dures. ») |
| Mythique | Le Verbe Primordial (Incantation / Gerwan / 27, effet PURGE 2, « Ce mot existait avant les hommes. Tu n'en connais qu'un. Il suffit. ») |
| Corrompue | Murmure Corrompu (Chuchotis / Morgrez / 46, tags Murmure et Vide, Corruption 1, « Une voix sans bouche s'invite dans ta main. Elle veut que tu l'écoutes. ») |

**Règles visuelles par état** (§20 et code HEAD, identiques pour les 3 pattes : la couleur, l'épaisseur et la forme sont fixes, la patte ne change que la matière) :

| État | Bordure | Signes distinctifs, jamais la couleur seule |
|---|---|---|
| **Commune** | BORDER_BRUN #4A3B28, 3 px, mate | filet simple, aucun ornement |
| **Rare** | RARE_BLUE #5A7A8C, 4 px | double filet fin, 4 coins marqués |
| **Épique** | RARITY_EPIC #B9BDB6 (argent, MAJ 2026-09-24 ; ancien #9A4FA8 violet, retiré car confondu avec la Corruption), 5 px, filet intérieur INK | double filet et **3 fleurons** argent (haut, bas, rune), strictement symétriques. |
| **Mythique** | GOLD #C9A24B, 7 px + **lueur or** qui pulse sur 2,4 s | fleurons aux 4 coins, rune dorée, un reflet qui balaie la carte toutes les 6 s |
| **Corrompue** | bordure **« glitch » hors rareté** : ARCHETYPE_CORRUPT #8B4FA3, cassée en segments décalés de 1 à 3 px | fissure qui traverse la carte, tremblement de 1 px toutes les 3 à 5 s, **gemme violette** avec le coût, bande « CORRUPTION » |

**Anatomie commune de la carte**, en portrait 2:3 et en compact 180×270 :
- Fond CREAM.
- **Nom français en haut** (Acuité), 22 px, INK.
- **Glyphe ogham** au centre, dessiné procéduralement dans le trait de la patte.
- **Nom de rune celte** sous le glyphe (Sulwen), 18 px en petites capitales, INK_DIM.
- **Bande d'archétype** en bas, 26 px de haut, avec son mot : MYSTÈRE #6B5A9C, OFFENSE #C0533A, PAROLE #B58A3A, DÉFENSE #4E7A6A, CORRUPTION #8B4FA3. MAJ 2026-09-24 (v4) : MYSTÈRE #44558C (indigo nuit, VIOLET réservé à la Corruption) ; aplats de bande assombris de 20 % vers BG_DEEP pour le contraste du mot : OFFENSE #9E4631, DÉFENSE #426557, CORRUPTION #734285.
- **Gemme de coût** de 28 px en haut à droite, seulement si la Corruption est supérieure à 0.
- **Badge d'effet** (à partir de Rare) en haut à gauche, pictogramme dessiné : cœur pour le soin, étoile pour la purge, croix pour la pioche.
- **Vue agrandie** (212×319 au survol, ou 320×480 au focus) : on y ajoute le nom canon en sous-titre italique (« Le Regard Perçant ») et l'**évocation** (20 px, INK).
- Pas de pastille de tag (R147).

---

## G) RÈGLES DE COHÉRENCE COMMUNES

### Ce qui est IDENTIQUE dans les 3 pattes (invariants)

**1. Contenu.** Tous les textes de ce kit sont repris mot pour mot, sans reformulation. Cela vaut aussi pour les données de démo : Intégrité 7, Corruption 4, 2 éclats sur 12, Brocéliande débloqué, Falaises entrouvert, 6 biomes scellés, CONTINUER actif.

**2. Positions.** Les coordonnées de B, D et E sont les mêmes sur le canvas 1920×1080. On change d'écran dans cet ordre : Menu-seuil, Sélection, Plateau, Planche de cartes. Une barre de navigation de démo discrète propose aussi le choix de la patte.

**3. Interactions** :
- Au plus 2 gestes par action.
- Cibles d'au moins 44×44 px.
- Retour visuel en 100 ms ou moins.
- Aucune information réservée au survol : tout ce qui apparaît au survol apparaît aussi au focus clavier et au tap.
- Clavier : flèches, Entrée et Échap.
- Démo : les touches 1 à 4 forcent le degré, la touche M bascule le mouvement réduit.

**4. Durées** (§21) :

| Nom | Durée |
|---|---|
| appui (tap) | 0,06 / 0,10 s, échelle 0,97 à 1 |
| rapide (fast) | 0,12 s |
| interface (ui) | 0,22 s |
| distribution (deal) | 0,24 à 0,28 s, retour élastique, décalage 0,05 s |
| défausse (discard) | 0,25 s |
| voile (veil) | 0,20 / 0,25 s |
| variation flottante (float_delta) | 0,9 s |
| pulsation (pulse) | 0,3 s |
| fusion | 0,9 à 1,7 s |
| décalage entre éléments d'un groupe | 0,04 à 0,06 s |

- Aucune animation d'interface ne dépasse 0,5 s, sauf la fusion et le voile.
- Aucune animation ne bloque une décision.

**5. Merlin.** Il a le même dessin structurel (C), les mêmes 7 expressions, les mêmes déclencheurs, le même cycle au repos, la même vitesse d'écriture et les mêmes blips. Une seule voix à la fois. Il n'apparaît jamais en pied.

**6. Couleurs sémantiques.** Elles sont fixes quelle que soit la patte :

| Couleur | Sens |
|---|---|
| GOLD | à toi, feedforward, CTA |
| VIOLET | Corruption, uniquement |
| EYE_* | yeux de Merlin |
| MERLIN_BLUE | voix de Merlin |
| degrés | échec VIOLET, partiel INK_DIM, réussite GOLD_DARK, éclatante GREEN_DARK |
| raretés | couleurs et épaisseurs de F |
| archétypes | couleurs de bande de F |

- Texte principal en CREAM sur fond sombre. Texte secondaire en DIM_WARM sur fond sombre, en INK_DIM sur crème.
- Contraste d'au moins 4,5:1.
- Un degré ou un danger se lit toujours par la couleur, la forme et le libellé ensemble. Pastilles de la pill : **losange fêlé** (échec), **demi-disque** (partiel), **disque plein** (réussite), **étoile à 8 branches** (éclatante).

**7. Typographie.**
- Le texte courant (récit, évocations, bulles, boutons) utilise une **même serif lisible** dans les 3 pattes, par exemple EB Garamond ou Crimson Pro via Google Fonts.
- Tailles FS : narration 36, titre 40, bouton 26, légende 22, indication 20. Minimum 16 px.
- Seule la **fonte d'affichage** (titre M·E·R·L·I·N, titres de récit, nom du biome) peut changer selon la patte.

**8. Inventaire d'animations ambiantes.** Les éléments animés sont les mêmes (listes de B, D et E) ; seul leur rendu change.
- Le glitch de Corruption garde les 4 paliers R75 dans les 3 pattes (sain, trouble, emprise, dissolution) et doit pouvoir monter comme redescendre.
- Il est plafonné à 0,1 en mouvement réduit.

**9. Budget CPU** (Gemma tourne en local) :
- Transformations et opacité uniquement, via CSS ou SVG, avec au plus un canvas par écran.
- Le décor ambiant tourne à environ 15 images par seconde : `requestAnimationFrame` limité, ou animations CSS à pas.
- Pas de `filter: blur` sur de grandes surfaces, pas d'animation de `box-shadow`, pas de particules en nœuds DOM au-delà de 24.
- Pause complète quand l'onglet est caché. `prefers-reduced-motion` est respecté.

**10. Pictogrammes.** Ils sont tous **dessinés dans la patte**, à la même épaisseur que le reste. Aucune icône générique (Tabler, emoji, caractère Unicode décoratif comme ◀, ✦ ou ♥). La liste complète :
- glyphes du menu : spark, burst, book, target, cross, crown ;
- triskèle ;
- cœur (Intégrité) et spirale voilée (Corruption) ;
- 5 glyphes de type de beat :

  | Type | Glyphe |
  |---|---|
  | Exploration | boussole |
  | Rencontre | deux profils face à face |
  | Épreuve | rocher trapu |
  | Dilemme | fourche en Y |
  | Climax | flamme |

- 3 symboles de faction (D) ;
- 8 glyphes de biome et le sceau (A) ;
- runes ogham 0, 3, 6, 11, 21, 25, 27, 46 ;
- badges d'effet : cœur, étoile, croix ;
- gemme de coût ;
- 4 pastilles de degré ;
- flèche Retour, bouton pause ;
- badge « Bénie », étoile dessinée ;
- 12 éclats de la constellation.

**11. Lumière.**
- Une seule source principale dans les 3 pattes : **la lune et la porte**, venant du **haut à gauche (10 h 30)** sur tous les écrans. Merlin est donc éclairé du côté de la porte.
- Seule exception : l'expression grave, éclairée par en dessous.
- Aucun autre éclairage directionnel.

### Ce qui VARIE (et doit rester cohérent à l'intérieur de chaque patte)

Chaque patte applique **une seule grammaire** au décor, à l'interface, aux cartes, à Merlin et aux pictogrammes :

- **Trait.** Un système d'épaisseurs unique par patte, dont le rapport entre contour et trait intérieur est fixé une fois pour toutes. Exemples :
  - P1 : contour de 4 px, hachures de 2 px, noir uniquement pour l'encre ;
  - P2 : contour de 3 px, trait intérieur de 1,5 px, encre qui peut être colorée ;
  - P3 : pas de contour, la forme tient par les aplats.
- **Valeurs et texture.** Le nombre d'aplats, le grain et le papier :
  - P1 : 3 ou 4 aplats, plus l'or ;
  - P2 : aplats vifs, feuille d'or, fond de vélin ;
  - P3 : moins de 8 couleurs, dégradé de fond seulement.
- **Rendu des ombres**, avec la même direction de lumière pour toutes :
  - P1 : hachures et noir plein ;
  - P2 : pas d'ombre portée, la profondeur vient de la brume et de la couleur ;
  - P3 : plans de silhouettes et couleur de brouillard.
- **Ornement des cadres** :
  - P1 : filets gravés ;
  - P2 : entrelacs, uniquement dans les marges et jamais sous le texte ;
  - P3 : découpes géométriques.
- **Fonte d'affichage** et **rendu des effets** (brume, motes, glitch, lueur d'affinité). Seule la matière change ; la durée, l'amplitude et la position restent celles du kit.

**Test de cohérence à passer avant livraison, pour chaque patte.** Mettre côte à côte une carte, le médaillon de Merlin, une pierre de biome et un bouton du menu : ils doivent sembler sortis de la même main, avec le même trait, la même lumière et le même grain. Si un élément « détonne », c'est un échec.

---

## Points à trancher (signalés, sans blocage pour le prototype)

1. **Couvre-chef de Merlin.**
   - Le code HEAD et R132 le montrent tête nue ; R129 parle d'une « capuche en pointe ».
   - Le kit retient tête nue avec un col haut qui évoque la capuche.
   - La barbe fourchue avec sa perle est une proposition, à valider.
2. **Présence de Merlin (R16/R50/§6).**
   - Le canon actuel dit « voix off, sans corps » ; il faut l'amender en « buste vivant cadré, jamais en pied ».
   - R126 (les yeux de Merlin dans la lune en jeu) ferait doublon avec le médaillon du plateau. Le kit ne garde qu'un seul Merlin à l'écran (§23, MINIMAL).
3. **Tags requis visibles.**
   - R147 a retiré les chips de requis ; le prototype précédent (validé sur le principe) les affichait.
   - Le kit les montre en 2 empreintes glyphiques, sans mot, en plus du signal d'or.
4. **Taille de la main.** Le code v11 utilise une main de 4 traits et 5 tuiles d'action (HAND_SIZE 4, R159). Le kit garde la main de 5 et la combinaison « 1 principale + 2 modificateurs » validées lors du prototype précédent. Le kit reprend les tags R33 et non les retags v11.
5. **Menu neutre (R132).** Le menu est « nu » d'après R132 : il faut amender la règle pour autoriser les vignettes de biome **uniquement dans l'ouverture de la porte** (choix de Maxime : « le seuil entre les mondes »). Le choix du biome se fait au seuil (R97).
6. **Statut des Falaises.** Elles sont jouables à HEAD, mais présentées ici comme « entrouvertes » pour la démo (R152/R153 : décision utilisateur en attente). La mer d'Iroise est différenciée des Falaises : cloches d'Ys englouties d'un côté, phare et à-pic de l'autre.
7. **Bulle de Merlin.** Un brief parle d'une « bulle crème bordée d'or ». Le code utilise une cartouche bleu-nuit avec texte MERLIN_BLUE et liseré #5F8FBE ; le kit suit le code.
8. **Évocation au survol (R71) contre §23 (pas d'information réservée au survol).** Le kit affiche l'évocation au survol **et** au focus ou au tap.
9. **Nouvelles constantes** à ajouter à `MerlinVisual` au portage : `BIOME_*` (8) et `MERLIN_SLATE`, `MERLIN_SLATE_DARK`, `MERLIN_ASH`.
