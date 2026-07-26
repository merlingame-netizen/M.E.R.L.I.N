# Run joué dans le moteur — transcript intégral

> Produit par l'instrumentation de `scripts/board_narration/board_narration.gd` (`MERLIN_TRANSCRIPT=<chemin>`) pendant un run réel en autoplay (`MERLIN_AUTOPLAY=1`), puis rendu par `tools/render_run_transcript.py`. Aucun élément n'est reconstitué à la main.

## ᚛ La Dette de Tourbe ᚜

*Tu viens payer ta dette à un noyé, et le noyé respire encore.*

Graine de variation : **entite centrale** un vivant qu'on croit mort · **lieu** tourbiere · **mecanisme du twist** identite (qui est vraiment la) · **pression** une dette a honorer · **registre sensoriel** odeur

> Il y a un an, Maël Kerlan s'est enfoncé dans la tourbière du Yeun et n'en est pas ressorti. Tu lui devais trois pièces et une promesse, et on ne laisse pas une dette à un mort. Sa veuve vit encore au bord du marais, dans une maison qui sent la fumée froide. Tu marches depuis l'aube avec les pièces cousues dans ta manche. L'odeur te prévient avant le paysage : la tourbe ne sent pas la vase, elle sent le pain brûlé et le fer. On dit que le Yeun garde ce qu'il prend et ne le rend jamais entier. Tu vas apprendre que ce n'est pas tout à fait vrai.

**Biome** : marais_korrigans · **Séquence d'actes** : Standard → Standard → Événement → Marchand → Standard → Climax → Standard → Standard → Standard → Standard → Climax · **Issue** : live · **Cartes jouées** : 11 · **Anam gagné** : 0

Chaque carte est présentée en deux plans : **à l'écran** (ce que le joueur lit) et **en coulisses** (ce que le moteur applique sans le dire).

## Départ

- Vie **100/100** · Anam affiché **0**
- Scénario sélectionné dans le catalogue : **la_forge_du_korrigan**
- Réputations de départ (jamais affichées) : {'anciens': 63.0, 'ankou': 100.0, 'druides': 100.0, 'korrigans': 22.0, 'niamh': 81.0}

## Carte 1 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 1 / 11 |
| Vie | 100/100 |
| Anam | 0 |

Texte de la carte :

> La maison de la veuve fume sans feu. Sur le seuil, une paire de bottes d'homme, seches, tournees vers la porte comme si quelqu'un venait de rentrer.

Les trois options, telles qu'elles s'affichent :

1. **Frapper et attendre** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Examiner les bottes** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Entrer sans annoncer** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.43 → **réussite**

Ce qui se produit ensuite :

> Le cuir est sec et la semelle propre. La tourbe ne pardonne pas : personne n'a marche dans le marais avec ces bottes. Elles ont ete posees la pour etre vues.

### En coulisses

- Carte tirée : `c1`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6
  2. réputation druides +8 · ajoute le marqueur « bottes_seches »
  3. réputation korrigans +10
- Choix retenu par l'autoplay : option 2 — « Examiner les bottes »
- Vie après résolution : 100/100 (avant : 100)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 2 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 2 / 11 |
| Vie | 100/100 |
| Anam | 0 |

Texte de la carte :

> La veuve pose les trois pieces sur la table sans les compter et les repousse vers toi. « Ce n'est pas ca qu'il attend », dit-elle en regardant la fenetre.

Les trois options, telles qu'elles s'affichent :

1. **Demander ce qu'il attend** — *prudente* · épreuve empathie/blanche · échec −3 PV
2. **Reposer les pieces sur la table** — *equilibree* · épreuve volonte/blanche · échec −4 PV
3. **Suivre son regard** — *audacieuse* · épreuve logic/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.71 → **échec**, −5 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu regardes par la fenetre et tu ne vois que du brouillard bas. Le temps que tes yeux s'y fassent, elle a tire le volet et la conversation est finie.

### En coulisses

- Carte tirée : `c2`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation niamh +6
  2. réputation anciens +8
  3. réputation druides +10 · ajoute le marqueur « vu_la_fenetre »
- Choix retenu par l'autoplay : option 3 — « Suivre son regard »
- Vie après résolution : 95/100 (avant : 100)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 3 — acte « Événement »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 3 / 11 |
| Vie | 95/100 |
| Anam | 0 |

Texte de la carte :

> Dehors, l'odeur de pain brule s'epaissit d'un coup. Trois oiseaux partent ensemble de la meme touffe de bruyere, sans qu'aucun bruit ne les ait leves.

Les trois options, telles qu'elles s'affichent :

1. **Rester immobile** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Chercher l'origine de l'odeur** — *equilibree* · épreuve instinct/blanche · échec −4 PV
3. **Appeler le nom du mort** — *audacieuse* · épreuve volonte/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.90 → **échec**, −3 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu tiens en place trop longtemps. Le froid de la tourbe monte par les semelles, tes jambes se raidissent, et quand tu bouges enfin, quelque chose s'est deja eloigne.

### En coulisses

- Carte tirée : `c3`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6 · vie +2
  2. réputation korrigans +8 · ajoute le marqueur « trace_fumee »
  3. réputation ankou +10
- Choix retenu par l'autoplay : option 1 — « Rester immobile »
- Vie après résolution : 92/100 (avant : 95)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : niamh -1 (→ 80)
- Marqueurs actifs : ['bottes_seches']

## Carte 4 — acte « Marchand »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 4 / 11 |
| Vie | 92/100 |
| Anam | 0 |

Texte de la carte :

> Un tourbier charge sa brouette au bord du chemin. Il vend ce qu'il trouve dans le marais : de la corde grasse, une lampe a huile, un couteau a lame courte.

Les trois options, telles qu'elles s'affichent :

1. **Acheter la corde** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Acheter la lampe** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Lui demander qui traverse** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.67 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu prends la lampe sans verifier la meche. Elle s'eteint au premier souffle du marais, et il est deja trop loin pour t'entendre le rappeler.

### En coulisses

- Carte tirée : `c4`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. essence +6 · ajoute le marqueur « corde »
  2. essence +8 · ajoute le marqueur « lampe »
  3. réputation korrigans +12 · ajoute le marqueur « tourbier_parle »
- Choix retenu par l'autoplay : option 2 — « Acheter la lampe »
- Vie après résolution : 88/100 (avant : 92)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 62)
- Marqueurs actifs : ['bottes_seches']

## Carte 5 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 5 / 11 |
| Vie | 88/100 |
| Anam | 0 |

Texte de la carte :

> La planche jetee en travers de la fosse tient a peine. Dessous, l'eau noire ne bouge pas, et l'odeur de pain brule monte de la, pas du reste du marais.

Les trois options, telles qu'elles s'affichent :

1. **Sonder avant de passer** — *prudente* · épreuve logic/blanche · échec −3 PV
2. **Traverser en courant** — *equilibree* · épreuve instinct/blanche · échec −4 PV
3. **Retirer la planche** — *audacieuse* · épreuve volonte/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.80 → **échec**, −5 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Le bois est plus lourd qu'il n'en a l'air et il t'echappe. La planche part dans la fosse, l'eau te gifle jusqu'au visage, et personne ne passera plus — toi non plus.

### En coulisses

- Carte tirée : `c5`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +6
  2. réputation korrigans +8
  3. réputation ankou +10
- Choix retenu par l'autoplay : option 3 — « Retirer la planche »
- Vie après résolution : 83/100 (avant : 88)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 61)
- Marqueurs actifs : ['bottes_seches']

## Carte 6 — acte « Climax »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 6 / 11 |
| Vie | 83/100 |
| Anam | 0 |

Texte de la carte :

> Merlin parle sans que tu l'aies appele. « Regarde mieux la fosse, voyageur. On n'y a rien jete. On y a amenage une place, et elle est occupee. »

Les trois options, telles qu'elles s'affichent :

1. **Demander qui est en bas** — *prudente* · épreuve logic/blanche · échec −4 PV
2. **Refuser d'ecouter** — *equilibree* · épreuve volonte/contextuelle · échec −8 PV
3. **Descendre voir** — *audacieuse* · épreuve instinct/contextuelle · échec −9 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.76 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu poses mal ta question et Merlin te retourne le silence. « Tu demandes un nom », dit-il enfin. « Tu n'es pas encore pret a l'entendre. »

### En coulisses

- Carte tirée : `c6`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +8
  2. réputation anciens +11
  3. réputation ankou +13
- Choix retenu par l'autoplay : option 1 — « Demander qui est en bas »
- Vie après résolution : 79/100 (avant : 83)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : aucun changement
- Marqueurs actifs : ['bottes_seches']

## Carte 7 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 7 / 11 |
| Vie | 79/100 |
| Anam | 0 |

Texte de la carte :

> L'homme dans la fosse est vivant, maigre, et il te reconnait. « Ne le dis pas a elle », souffle Mael Kerlan. « Tant qu'elle me croit noye, elle est en vie. »

Les trois options, telles qu'elles s'affichent :

1. **Ecouter son histoire** — *prudente* · épreuve empathie/blanche · échec −4 PV
2. **Le sortir de la** — *equilibree* · épreuve volonte/contextuelle · échec −8 PV
3. **Le laisser et partir** — *audacieuse* · épreuve instinct/**ROUGE** · échec −13 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.05 → **réussite**

Ce qui se produit ensuite :

> Tu le hisses par les aisselles. Il pese le poids d'un an de tourbe et ses jambes ne le portent plus. Une fois dehors, il regarde la maison qui fume au loin et se met a trembler — de froid, ou d'autre chose.

### En coulisses

- Carte tirée : `c7`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation niamh +10
  2. réputation anciens +12
  3. réputation ankou +16 · essence +4
- Choix retenu par l'autoplay : option 2 — « Le sortir de la »
- Vie après résolution : 79/100 (avant : 79)
- Réputations après le choix : anciens +12 (→ 73)
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 72)
- Marqueurs actifs : ['bottes_seches']

## Carte 8 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 8 / 11 |
| Vie | 79/100 |
| Anam | 0 |

Texte de la carte :

> Il te demande de jurer. « Trois jours », dit-il. « Donne-moi trois jours pour partir loin, et ensuite dis-lui ce que tu voudras. »

Les trois options, telles qu'elles s'affichent :

1. **Jurer les trois jours** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Promettre de revenir** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Ne rien jurer** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.20 → **réussite**

Ce qui se produit ensuite :

> Tu jures, et il te fait repeter le serment avec ses mots a lui. Le marais n'a pas d'oreilles, mais les Anciens en ont, et un serment prononce sur la tourbe ne s'efface pas.

### En coulisses

- Carte tirée : `c8`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. promesse « trois_jours » · réputation anciens +8
  2. promesse « revenir » · réputation niamh +10
  3. réputation korrigans +12
- Choix retenu par l'autoplay : option 1 — « Jurer les trois jours »
- Vie après résolution : 79/100 (avant : 79)
- Réputations après le choix : anciens +8 (→ 80)
- Dé du destin (lancé après chaque carte hors climax) : korrigans -1 (→ 21)
- Marqueurs actifs : ['bottes_seches']

## Carte 9 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 9 / 11 |
| Vie | 79/100 |
| Anam | 0 |

Texte de la carte :

> Sur le chemin du retour, un homme du bourg vient a ta rencontre. Il sourit, et il sent le pain brule alors qu'il n'a pas mis un pied dans la tourbe.

Les trois options, telles qu'elles s'affichent :

1. **Le saluer sans t'arreter** — *prudente* · épreuve logic/blanche · échec −4 PV
2. **Lui demander son nom** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Lui barrer le chemin** — *audacieuse* · épreuve volonte/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.86 → **échec**, −5 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu te mets en travers et il te contourne comme on contourne une pierre. Tu te retournes trop tard : il a pris le chemin de la maison qui fume.

### En coulisses

- Carte tirée : `c9`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +6
  2. réputation niamh +8
  3. réputation ankou +10
- Choix retenu par l'autoplay : option 3 — « Lui barrer le chemin »
- Vie après résolution : 74/100 (avant : 79)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 98)
- Marqueurs actifs : ['bottes_seches']

## Carte 10 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 10 / 11 |
| Vie | 74/100 |
| Anam | 0 |

Texte de la carte :

> La veuve t'attend sur le seuil, les trois pieces dans la main. Elle a vu d'ou tu reviens. « Alors ? » demande-t-elle, et sa voix ne tremble pas.

Les trois options, telles qu'elles s'affichent :

1. **Dire que la dette est payee** — *prudente* · épreuve instinct/blanche · échec −4 PV
2. **Lui parler de son beau-frere** — *equilibree* · épreuve logic/contextuelle · échec −8 PV
3. **Tout lui dire** — *audacieuse* · épreuve empathie/contextuelle · échec −9 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.38 → **réussite**

Ce qui se produit ensuite :

> Tu ne parles pas du vivant, tu parles de celui qui sent le pain brule sans avoir marche dans la tourbe. Elle blemit — non pas de surprise, mais parce que quelqu'un d'autre le sait enfin.

### En coulisses

- Carte tirée : `c10`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation korrigans +8
  2. réputation druides +12
  3. réputation niamh +14
- Choix retenu par l'autoplay : option 2 — « Lui parler de son beau-frere »
- Vie après résolution : 69/100 (avant : 74)
- Réputations après le choix : druides +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 11 — acte « Climax »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 11 / 11 |
| Vie | 69/100 |
| Anam | 0 |

Texte de la carte :

> Merlin est assis sur la borne, au bout du chemin. « Trois pieces », dit-il. « Voila ce que tu croyais devoir. Dis-moi ce que tu dois maintenant. »

Les trois options, telles qu'elles s'affichent :

1. **Payer et partir** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Nommer ta vraie dette** — *equilibree* · épreuve logic/blanche · échec −5 PV
3. **Retourner au marais** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.04 → **réussite**

Ce qui se produit ensuite (**variante d'état** : trois_jours) :

> Tu dis ce que tu dois, et Merlin t'arrete a mi-phrase. « Tu as jure trois jours et tu n'en as pas tenu un. Ce que tu dois maintenant, ce n'est plus a eux — c'est a ta propre parole, et elle est plus chere. »

### En coulisses

- Carte tirée : `c11`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +12 · Anam +4
  2. réputation druides +13 · Anam +5
  3. réputation ankou +15 · Anam +5
- Choix retenu par l'autoplay : option 2 — « Nommer ta vraie dette »
- Vie après résolution : 69/100 (avant : 69)
- Réputations après le choix : druides +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : aucun changement
- Marqueurs actifs : ['bottes_seches']

## Fin de run

- Issue : **live**
- Vie finale : **69/100**
- Anam gagné sur ce run : **0**
- Réputations finales (jamais montrées au joueur) : {'anciens': 80, 'ankou': 98, 'druides': 100, 'korrigans': 21, 'niamh': 80}

## Ce que le joueur ne voit jamais

Relevé directement sur le HUD instrumenté : seuls **trois** éléments sont affichés — le compteur de cartes, la vie et l'Anam. Ne sont montrés à aucun moment :

- les réputations des cinq factions (`_refresh_hud` : « aucun affichage HUD »), alors que presque chaque option en modifie une ;
- les effets attachés aux options, y compris les dégâts et les soins ;
- le dé du destin, qui modifie une faction au hasard après chaque carte ;
- le scénario sélectionné dans le catalogue, ses ancres et ses drapeaux ;
- les marqueurs, promesses et modificateurs de marchand actifs.
