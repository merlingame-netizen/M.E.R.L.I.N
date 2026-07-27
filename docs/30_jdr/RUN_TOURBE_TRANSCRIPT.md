# Run joué dans le moteur — transcript intégral

> Produit par l'instrumentation de `scripts/board_narration/board_narration.gd` (`MERLIN_TRANSCRIPT=<chemin>`) pendant un run réel en autoplay (`MERLIN_AUTOPLAY=1`), puis rendu par `tools/render_run_transcript.py`. Aucun élément n'est reconstitué à la main.

## ᚛ Deux Assiettes ᚜

*Tu demandes un toit pour une nuit, et l'on met deux assiettes.*

Graine de variation : **entite centrale** un vivant qu'on croit mort · **lieu** tourbiere · **mecanisme du twist** identite (qui est vraiment la) · **pression** une dette a honorer · **registre sensoriel** odeur

> Le jour tombe et la tourbière du Yeun ne rend pas le pied ferme. Tu marches depuis l'aube sur un chemin de planches que personne n'a l'air d'emprunter, et pourtant on l'entretient. L'odeur te prévient avant le paysage : ici la tourbe ne sent pas la vase, elle sent le pain brûlé et le fer. Il te faut un toit avant la nuit, et l'hospitalité ne se refuse pas à un voyageur, même dans le Yeun. Une fenêtre s'allume au bout des planches. Tu ne sais rien de cette maison ni de qui l'habite. Tu vas l'apprendre.

**Biome** : marais_korrigans · **Séquence d'actes** : Standard → Standard → Standard → Événement → Standard → Standard → Standard → Marchand → Standard → Climax → Événement → Standard → Standard → Standard → Standard → Standard → Standard → Événement → Standard → Standard → Marchand → Standard → Standard → Standard → Climax · **Issue** : live · **Cartes jouées** : 25 · **Anam gagné** : 0

Chaque carte est présentée en deux plans : **à l'écran** (ce que le joueur lit) et **en coulisses** (ce que le moteur applique sans le dire).

## Départ

- Vie **100/100** · Anam affiché **0**
- Scénario sélectionné dans le catalogue : **la_forge_du_korrigan**
- Réputations de départ (jamais affichées) : {'anciens': 94.0, 'ankou': 96.0, 'druides': 100.0, 'korrigans': 35.0, 'niamh': 85.0}

## Carte 1 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 1 / 25 |
| Vie | 100/100 |
| Anam | 0 |

Texte de la carte :

> Le chemin de planches s'enfonce dans la tourbiere au crepuscule. L'odeur qui monte n'est pas celle de la vase : ca sent le pain brule et le fer.

Les trois options, telles qu'elles s'affichent :

1. **Presser le pas** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Lire les traces** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Remonter l'odeur** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.83 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> La tourbe garde mal les traces et le jour tombe plus vite que tu ne lis. Tu releves la tete sans savoir depuis combien de temps tu es accroupi.

### En coulisses

- Carte tirée : `c1`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6
  2. réputation druides +8
  3. réputation korrigans +10
- Choix retenu par l'autoplay : option 2 — « Lire les traces »
- Vie après résolution : 96/100 (avant : 100)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 93)

## Carte 2 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 2 / 25 |
| Vie | 96/100 |
| Anam | 0 |

Texte de la carte :

> Au bout des planches, une maison basse. Une fenetre eclairee, et pas un fil de fumee a la cheminee alors que la nuit tombe et qu'il gele deja.

Les trois options, telles qu'elles s'affichent :

1. **Observer depuis la bruyere** — *prudente* · épreuve logic/blanche · échec −3 PV
2. **Approcher franchement** — *equilibree* · épreuve volonte/blanche · échec −4 PV
3. **Faire le tour** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **instinct** niveau 1 — 60 % de réussite, jet 0.41 → **réussite**

Ce qui se produit ensuite :

> Tu contournes par l'arriere. Pas de tas de tourbe, pas de bois coupe, pas de fumier : personne ne prepare l'hiver ici. Mais le seuil de la porte de derriere est use, et recemment.

### En coulisses

- Carte tirée : `c2`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +6
  2. réputation anciens +8
  3. réputation korrigans +10
- Choix retenu par l'autoplay : option 3 — « Faire le tour »
- Vie après résolution : 96/100 (avant : 96)
- Réputations après le choix : korrigans +10 (→ 45)
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 99)

## Carte 3 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 3 / 25 |
| Vie | 96/100 |
| Anam | 0 |

Texte de la carte :

> Devant la porte, sur le seuil de pierre, une paire de bottes d'homme. Tournees vers l'interieur, comme si quelqu'un venait de rentrer. Elles sont seches.

Les trois options, telles qu'elles s'affichent :

1. **Frapper** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Examiner les bottes** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Appeler** — *audacieuse* · épreuve empathie/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.30 → **réussite**

Ce qui se produit ensuite :

> Le cuir est sec jusqu'a la couture et la semelle propre. La tourbe ne pardonne pas : personne n'a marche dans le marais avec ces bottes. On les a posees la pour qu'on les voie.

### En coulisses

- Carte tirée : `c3`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6
  2. réputation druides +8 · ajoute le marqueur « bottes_seches »
  3. réputation niamh +10
- Choix retenu par l'autoplay : option 2 — « Examiner les bottes »
- Vie après résolution : 96/100 (avant : 96)
- Réputations après le choix : druides +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 92)
- Marqueurs actifs : ['bottes_seches']

## Carte 4 — acte « Événement »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 4 / 25 |
| Vie | 96/100 |
| Anam | 0 |

Texte de la carte :

> Rien ne repond. Un pas, un seul, de l'autre cote du bois — puis plus rien. Le vent tombe d'un coup et le froid s'installe sur le seuil avec toi.

Les trois options, telles qu'elles s'affichent :

1. **Attendre sans bouger** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Annoncer que tu es un voyageur** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Pousser la porte** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.02 → **réussite**

Ce qui se produit ensuite :

> Tu restes immobile, les mains visibles. Au bout d'un long moment le pas revient vers la porte, plus lentement, mais il revient. Tu respires mieux d'avoir su ne rien forcer.

### En coulisses

- Carte tirée : `c4`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6 · vie +3
  2. réputation niamh +8
  3. réputation korrigans +10
- Choix retenu par l'autoplay : option 1 — « Attendre sans bouger »
- Vie après résolution : 99/100 (avant : 96)
- Réputations après le choix : anciens +6 (→ 98)
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 97)
- Marqueurs actifs : ['bottes_seches']

## Carte 5 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 5 / 25 |
| Vie | 99/100 |
| Anam | 0 |

Texte de la carte :

> La porte s'ouvre de la largeur d'une main. Une lampe d'abord, puis une femme derriere, qui ne dit rien et te regarde des pieds a la tete.

Les trois options, telles qu'elles s'affichent :

1. **Demander le gite** — *prudente* · épreuve empathie/blanche · échec −3 PV
2. **Dire d'ou tu viens** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Attendre qu'elle parle** — *audacieuse* · épreuve volonte/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.09 → **réussite**

Ce qui se produit ensuite :

> Tu nommes le chemin, les planches neuves, l'odeur. A « planches neuves » son visage change une seconde, et elle ouvre la porte un peu plus.

### En coulisses

- Carte tirée : `c5`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation niamh +6
  2. réputation druides +8
  3. réputation anciens +10
- Choix retenu par l'autoplay : option 2 — « Dire d'ou tu viens »
- Vie après résolution : 94/100 (avant : 99)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 96)
- Marqueurs actifs : ['bottes_seches']

## Carte 6 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 6 / 25 |
| Vie | 94/100 |
| Anam | 0 |

Texte de la carte :

> Elle regarde par-dessus ton epaule, longuement, la tourbiere ou la nuit finit de tomber. Puis elle s'efface contre le mur pour te laisser le passage.

Les trois options, telles qu'elles s'affichent :

1. **Demander si tu deranges** — *prudente* · épreuve empathie/blanche · échec −3 PV
2. **Entrer** — *equilibree* · épreuve volonte/blanche · échec −4 PV
3. **Regarder ce qu'elle regarde** — *audacieuse* · épreuve logic/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.48 → **réussite**

Ce qui se produit ensuite :

> Tu entres en te baissant sous le linteau. Derriere toi elle referme, met la barre, et verifie la barre une seconde fois.

### En coulisses

- Carte tirée : `c6`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation niamh +6
  2. réputation anciens +8
  3. réputation druides +10 · ajoute le marqueur « la_lueur »
- Choix retenu par l'autoplay : option 2 — « Entrer »
- Vie après résolution : 94/100 (avant : 94)
- Réputations après le choix : anciens +4 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : korrigans -1 (→ 44)
- Marqueurs actifs : ['bottes_seches']

## Carte 7 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 7 / 25 |
| Vie | 94/100 |
| Anam | 0 |

Texte de la carte :

> Une piece basse, un feu eteint sous la cheminee froide, et la table mise pour deux. Une des assiettes est pleine et n'a pas ete touchee.

Les trois options, telles qu'elles s'affichent :

1. **T'asseoir ou elle t'indique** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Rester debout** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Regarder l'assiette intacte** — *audacieuse* · épreuve logic/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.83 → **échec**, −5 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu regardes l'assiette une seconde de trop. Elle la retire, la vide dans le seau, et repose l'assiette vide exactement au meme endroit.

### En coulisses

- Carte tirée : `c7`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6
  2. réputation niamh +8 · vie +3
  3. réputation druides +10 · ajoute le marqueur « deux_assiettes »
- Choix retenu par l'autoplay : option 3 — « Regarder l'assiette intacte »
- Vie après résolution : 89/100 (avant : 94)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 95)
- Marqueurs actifs : ['bottes_seches']

## Carte 8 — acte « Marchand »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 8 / 25 |
| Vie | 89/100 |
| Anam | 0 |

Texte de la carte :

> Elle pose devant toi ce qu'elle a : du pain dur, de la tourbe seche pour le feu. Puis, d'un coffre, des affaires d'homme. « Prenez ce qu'il vous faut. »

Les trois options, telles qu'elles s'affichent :

1. **Prendre la corde** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Prendre la lampe** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Ne rien prendre** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.66 → **échec**, −3 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu tires la corde et le coffre entier bascule. Tu ramasses tout et remets tout, et elle range derriere toi sans un mot, dans un ordre qui n'est pas le tien.

### En coulisses

- Carte tirée : `c8`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. essence +6 · ajoute le marqueur « corde »
  2. essence +8 · ajoute le marqueur « lampe »
  3. réputation korrigans +12
- Choix retenu par l'autoplay : option 1 — « Prendre la corde »
- Vie après résolution : 86/100 (avant : 89)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 9 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 9 / 25 |
| Vie | 86/100 |
| Anam | 0 |

Texte de la carte :

> Elle ne mange pas. Elle s'est assise de biais, face a la porte, et chaque fois que la tourbe soupire dehors sa cuiller s'arrete a mi-chemin.

Les trois options, telles qu'elles s'affichent :

1. **Manger en silence** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Demander qui est attendu** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Parler des planches neuves** — *audacieuse* · épreuve logic/blanche · échec −5 PV

Épreuve **empathie** niveau 1 — 60 % de réussite, jet 0.78 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu demandes qui est attendu et la question tombe mal. Elle se leve, va tisonner un feu eteint depuis longtemps, et te tourne le dos.

### En coulisses

- Carte tirée : `c9`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6 · vie +5
  2. réputation niamh +14
  3. réputation druides +16
- Choix retenu par l'autoplay : option 2 — « Demander qui est attendu »
- Vie après résolution : 82/100 (avant : 86)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 10 — acte « Climax »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 10 / 25 |
| Vie | 82/100 |
| Anam | 0 |

Texte de la carte :

> Elle se leve de table sans avoir vide sa cuiller. L'assiette pleine reste ou elle est. Dans le feu eteint, une voix que tu es seul a entendre : « Deux assiettes, voyageur. Compte-les encore. »

Les trois options, telles qu'elles s'affichent :

1. **Lui demander ce qu'il sait** — *prudente* · épreuve logic/blanche · échec −4 PV
2. **Lui dire de se taire** — *equilibree* · épreuve volonte/contextuelle · échec −8 PV
3. **Demander qui est mort ici** — *audacieuse* · épreuve instinct/contextuelle · échec −9 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.55 → **réussite**

Ce qui se produit ensuite :

> « Ce que tu sais deja », repond Merlin. « Une table mise pour deux dans une maison ou l'on vient de te dire qu'il n'y a personne d'autre. Je ne t'apprends rien. Je t'empeche de l'oublier. »

### En coulisses

- Carte tirée : `c10`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +9
  2. réputation anciens +11
  3. réputation ankou +13
- Choix retenu par l'autoplay : option 1 — « Lui demander ce qu'il sait »
- Vie après résolution : 77/100 (avant : 82)
- Réputations après le choix : druides +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : aucun changement
- Marqueurs actifs : ['bottes_seches']

## Carte 11 — acte « Événement »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 11 / 25 |
| Vie | 77/100 |
| Anam | 0 |

Texte de la carte :

> La voix s'est tue avec les cendres. Tu dors mal sur le banc. Vers le milieu de la nuit, trois oiseaux se levent de la meme touffe de bruyere, sans qu'aucun bruit ne les ait leves.

Les trois options, telles qu'elles s'affichent :

1. **Ne pas bouger** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Ecouter a la porte** — *equilibree* · épreuve instinct/blanche · échec −4 PV
3. **Regarder par la fenetre** — *audacieuse* · épreuve logic/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.31 → **réussite**

Ce qui se produit ensuite :

> Par la vitre, la tourbe est noire jusqu'a l'horizon. Sauf a un endroit, ou une lueur basse avance a hauteur d'homme, du meme pas qu'un homme.

### En coulisses

- Carte tirée : `c11`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6 · vie +2
  2. réputation korrigans +8
  3. réputation druides +10
- Choix retenu par l'autoplay : option 3 — « Regarder par la fenetre »
- Vie après résolution : 77/100 (avant : 77)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : korrigans -1 (→ 43)
- Marqueurs actifs : ['bottes_seches']

## Carte 12 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 12 / 25 |
| Vie | 77/100 |
| Anam | 0 |

Texte de la carte :

> La lueur ne va pas droit. Elle suit les planches, s'arrete ou elles s'arretent, repart. Ce qui la porte connait le chemin par coeur.

Les trois options, telles qu'elles s'affichent :

1. **Compter les arrets** — *prudente* · épreuve logic/blanche · échec −3 PV
2. **Reveiller la femme** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Sortir sur le seuil** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **empathie** niveau 1 — 60 % de réussite, jet 0.30 → **réussite**

Ce qui se produit ensuite :

> Tu la touches a l'epaule. Elle est deja reveillee, assise dans le noir, et elle regardait la meme chose que toi depuis un moment.

### En coulisses

- Carte tirée : `c12`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +6
  2. réputation niamh +8
  3. réputation korrigans +10
- Choix retenu par l'autoplay : option 2 — « Reveiller la femme »
- Vie après résolution : 77/100 (avant : 77)
- Réputations après le choix : niamh +8 (→ 93)
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 13 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 13 / 25 |
| Vie | 77/100 |
| Anam | 0 |

Texte de la carte :

> Elle est derriere toi, pieds nus sur le plancher. Elle souffle la lampe sans un mot, te prend le poignet, et te fait signe de ne plus bouger tant que la lueur est dehors.

Les trois options, telles qu'elles s'affichent :

1. **Obeir** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Chercher son regard** — *equilibree* · épreuve empathie/contextuelle · échec −8 PV
3. **Degager ton poignet** — *audacieuse* · épreuve instinct/contextuelle · échec −9 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.87 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu obeis mais ton pied glisse sur la pierre et racle. Dehors, la lueur s'arrete net et reste arretee tres longtemps.

### En coulisses

- Carte tirée : `c13`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +8
  2. réputation niamh +11
  3. réputation korrigans +13
- Choix retenu par l'autoplay : option 1 — « Obeir »
- Vie après résolution : 73/100 (avant : 77)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : korrigans -1 (→ 42)
- Marqueurs actifs : ['bottes_seches']

## Carte 14 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 14 / 25 |
| Vie | 73/100 |
| Anam | 0 |

Texte de la carte :

> La lueur s'est perdue vers le marais. Elle rallume la lampe, les mains lentes. « Un feu follet », dit-elle. « Il y en a beaucoup, ici. »

Les trois options, telles qu'elles s'affichent :

1. **Accepter l'explication** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Dire qu'un feu follet ne sonde pas** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Proposer de rester un jour** — *audacieuse* · épreuve empathie/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.75 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu la contredis trop vite et trop bien. Elle se ferme d'un coup : « Vous etes savant, pour un homme qui dort sur mon banc. »

### En coulisses

- Carte tirée : `c14`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6
  2. réputation druides +8
  3. réputation niamh +10 · vie +3
- Choix retenu par l'autoplay : option 2 — « Dire qu'un feu follet ne sonde pas »
- Vie après résolution : 69/100 (avant : 73)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 94)
- Marqueurs actifs : ['bottes_seches']

## Carte 15 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 15 / 25 |
| Vie | 69/100 |
| Anam | 0 |

Texte de la carte :

> Au petit jour elle dort assise, la lampe encore allumee contre elle. La barre de la porte est retiree. Dehors, les planches neuves partent vers le marais.

Les trois options, telles qu'elles s'affichent :

1. **Remettre la barre et attendre** — *prudente* · épreuve empathie/blanche · échec −3 PV
2. **Suivre les planches neuves** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Emporter l'assiette pleine** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.76 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu sors et la porte grince sur toute sa longueur. Tu t'engages quand meme sur les planches, en sachant qu'elle t'a entendu partir.

### En coulisses

- Carte tirée : `c15`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation niamh +6
  2. réputation druides +8
  3. réputation ankou +10 · vie +3
- Choix retenu par l'autoplay : option 2 — « Suivre les planches neuves »
- Vie après résolution : 60/100 (avant : 69)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : niamh -1 (→ 92)
- Marqueurs actifs : ['bottes_seches']

## Carte 16 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 16 / 25 |
| Vie | 60/100 |
| Anam | 0 |

Texte de la carte :

> A deux cents pas de la maison, les planches se divisent. Une branche va vers le bourg, grise et usee. L'autre est neuve, et elle entre dans le marais.

Les trois options, telles qu'elles s'affichent :

1. **Prendre la branche du bourg** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Sonder la branche neuve** — *equilibree* · épreuve logic/contextuelle · échec −8 PV
3. **Prendre la branche neuve** — *audacieuse* · épreuve instinct/contextuelle · échec −9 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.18 → **réussite**

Ce qui se produit ensuite :

> Tu enfonces ton baton entre deux planches neuves. Il descend d'une brasse et butte sur du bois : on a double le fond. Ce chemin a ete construit pour porter quelqu'un tous les jours.

### En coulisses

- Carte tirée : `c16`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +8
  2. réputation druides +16
  3. réputation korrigans +17
- Choix retenu par l'autoplay : option 2 — « Sonder la branche neuve »
- Vie après résolution : 60/100 (avant : 60)
- Réputations après le choix : druides +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 17 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 17 / 25 |
| Vie | 60/100 |
| Anam | 0 |

Texte de la carte :

> La branche neuve s'arrete net sur une fosse. Une planche unique est jetee en travers, et sous elle l'eau noire ne bouge pas du tout.

Les trois options, telles qu'elles s'affichent :

1. **Sonder la fosse** — *prudente* · épreuve logic/blanche · échec −4 PV
2. **Traverser sur la planche** — *equilibree* · épreuve volonte/contextuelle · échec −8 PV
3. **Retirer la planche** — *audacieuse* · épreuve instinct/contextuelle · échec −9 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.53 → **réussite**

Ce qui se produit ensuite :

> Tu passes en trois enjambees. La planche plie au milieu et tient. De l'autre cote, la berge a ete creusee de main d'homme, en marches.

### En coulisses

- Carte tirée : `c17`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +9
  2. réputation anciens +12
  3. réputation ankou +13
- Choix retenu par l'autoplay : option 2 — « Traverser sur la planche »
- Vie après résolution : 60/100 (avant : 60)
- Réputations après le choix : anciens +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : niamh -1 (→ 91)
- Marqueurs actifs : ['bottes_seches']

## Carte 18 — acte « Événement »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 18 / 25 |
| Vie | 60/100 |
| Anam | 0 |

Texte de la carte :

> De l'autre cote, sous la berge creusee, l'odeur monte d'un coup. Ce n'est plus le pain brule de la tourbe : c'est de la fumee, et elle est recente.

Les trois options, telles qu'elles s'affichent :

1. **Reculer et regarder** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Chercher le trou de fumee** — *equilibree* · épreuve logic/contextuelle · échec −8 PV
3. **Ouvrir l'abri** — *audacieuse* · épreuve instinct/**ROUGE** · échec −13 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.15 → **réussite**

Ce qui se produit ensuite :

> Tu recules de trois pas et tu regardes au lieu d'avancer. Sous la berge, la tourbe a ete creusee en abri, et un filet de fumee sort d'un trou d'aeration bouche de mousse.

### En coulisses

- Carte tirée : `c18`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +10
  2. réputation druides +12
  3. réputation ankou +16 · essence +4
- Choix retenu par l'autoplay : option 1 — « Reculer et regarder »
- Vie après résolution : 60/100 (avant : 60)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 99)
- Marqueurs actifs : ['bottes_seches']

## Carte 19 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 19 / 25 |
| Vie | 60/100 |
| Anam | 0 |

Texte de la carte :

> Une place a ete amenagee sous la berge : de la paille seche, un quart de fer, une couverture pliee. Quelqu'un vit ici depuis longtemps, et pas si mal.

Les trois options, telles qu'elles s'affichent :

1. **Annoncer ta presence** — *prudente* · épreuve empathie/blanche · échec −3 PV
2. **Regarder ce qu'il y a** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Entrer dans l'abri** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.13 → **réussite**

Ce qui se produit ensuite :

> Un quart de fer grave d'une marque, une couverture reprisee au meme fil que celle du banc ou tu as dormi. On ne survit pas ici : on est nourri ici.

### En coulisses

- Carte tirée : `c19`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation niamh +6
  2. réputation druides +8
  3. réputation korrigans +10 · vie +3
- Choix retenu par l'autoplay : option 2 — « Regarder ce qu'il y a »
- Vie après résolution : 60/100 (avant : 60)
- Réputations après le choix : druides +1 (→ 100)
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 93)
- Marqueurs actifs : ['bottes_seches']

## Carte 20 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 20 / 25 |
| Vie | 60/100 |
| Anam | 0 |

Texte de la carte :

> L'homme est vivant, maigre, et il ne te connait pas plus que tu ne le connais. « Ne dites pas que vous m'avez vu », souffle-t-il. « Trois jours. »

Les trois options, telles qu'elles s'affichent :

1. **Jurer les trois jours** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Promettre de revenir** — *equilibree* · épreuve empathie/blanche · échec −4 PV
3. **Ne rien jurer** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.95 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu jures d'une voix plate, sans ses mots. Il te fait recommencer trois fois et n'y croit toujours pas : le serment tient, mais mal.

### En coulisses

- Carte tirée : `c20`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. promesse « trois_jours » · réputation anciens +8
  2. promesse « revenir » · réputation niamh +10
  3. réputation korrigans +12
- Choix retenu par l'autoplay : option 1 — « Jurer les trois jours »
- Vie après résolution : 51/100 (avant : 60)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : korrigans -1 (→ 41)
- Marqueurs actifs : ['bottes_seches']

## Carte 21 — acte « Marchand »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 21 / 25 |
| Vie | 51/100 |
| Anam | 0 |

Texte de la carte :

> Sur le chemin gris du retour, un homme du bourg vient a ta rencontre. Il sourit. Il sent le pain brule alors qu'il n'a pas mis un pied dans la tourbe.

Les trois options, telles qu'elles s'affichent :

1. **Accepter les piecettes** — *prudente* · épreuve logic/blanche · échec −3 PV
2. **Refuser les pieces** — *equilibree* · épreuve volonte/blanche · échec −4 PV
3. **Lui demander son nom** — *audacieuse* · épreuve empathie/blanche · échec −5 PV

Épreuve **volonte** niveau 1 — 60 % de réussite, jet 0.92 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu refuses d'un geste trop large et l'une des pieces tombe entre les planches. Il ne se baisse pas. « Elle est a vous maintenant », dit-il.

### En coulisses

- Carte tirée : `c21`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. essence +4
  2. réputation anciens +10
  3. réputation niamh +12 · ajoute le marqueur « le_frere »
- Choix retenu par l'autoplay : option 2 — « Refuser les pieces »
- Vie après résolution : 47/100 (avant : 51)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 98)
- Marqueurs actifs : ['bottes_seches']

## Carte 22 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 22 / 25 |
| Vie | 47/100 |
| Anam | 0 |

Texte de la carte :

> Il s'arrete au milieu du chemin et ne s'ecarte pas. « Vous venez du marais », dit-il, toujours poliment. « Qu'est-ce qu'on y trouve, en cette saison ? »

Les trois options, telles qu'elles s'affichent :

1. **Mentir simplement** — *prudente* · épreuve instinct/blanche · échec −4 PV
2. **Retourner la question** — *equilibree* · épreuve logic/contextuelle · échec −8 PV
3. **Lui dire que son frere respire** — *audacieuse* · épreuve volonte/**ROUGE** · échec −13 PV

Épreuve **instinct** niveau 1 — 60 % de réussite, jet 0.23 → **réussite**

Ce qui se produit ensuite :

> Tu dis que tu cherchais un raccourci et que tu as trouve de la tourbe. C'est court, c'est plat, et c'est exactement ce qu'un voyageur repondrait. Il te croit a moitie, ce qui suffit.

### En coulisses

- Carte tirée : `c22`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation korrigans +10
  2. réputation druides +12
  3. réputation ankou +16 · essence +4
- Choix retenu par l'autoplay : option 1 — « Mentir simplement »
- Vie après résolution : 47/100 (avant : 47)
- Réputations après le choix : korrigans +10 (→ 51)
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 92)
- Marqueurs actifs : ['bottes_seches']

## Carte 23 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 23 / 25 |
| Vie | 47/100 |
| Anam | 0 |

Texte de la carte :

> Tu le laisses sur le chemin gris. La maison basse est au bout des planches, et elle t'attend debout sur le seuil, la porte ouverte derriere elle. Elle a vu d'ou tu reviens.

Les trois options, telles qu'elles s'affichent :

1. **La saluer et rentrer** — *prudente* · épreuve volonte/blanche · échec −3 PV
2. **Regarder la table avant de parler** — *equilibree* · épreuve logic/blanche · échec −4 PV
3. **Dire tout de suite ou tu es alle** — *audacieuse* · épreuve empathie/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.72 → **échec**, −4 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu regardes la table trop ouvertement et elle te devance. Le temps que tu te retournes, l'assiette est dans le seau et la table est mise pour un.

### En coulisses

- Carte tirée : `c23`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +6
  2. réputation druides +8
  3. réputation niamh +10 · vie +3
- Choix retenu par l'autoplay : option 2 — « Regarder la table avant de parler »
- Vie après résolution : 43/100 (avant : 47)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 97)
- Marqueurs actifs : ['bottes_seches']

## Carte 24 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 24 / 25 |
| Vie | 43/100 |
| Anam | 0 |

Texte de la carte :

> Elle a pose les mains a plat sur la table, entre les deux assiettes, et elle attend. « Alors ? » demande-t-elle, et sa voix ne tremble pas.

Les trois options, telles qu'elles s'affichent :

1. **Ne rien dire** — *prudente* · épreuve instinct/blanche · échec −4 PV
2. **Parler de l'homme du bourg** — *equilibree* · épreuve logic/contextuelle · échec −8 PV
3. **Tout lui dire** — *audacieuse* · épreuve empathie/contextuelle · échec −9 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.97 → **échec**, −8 PV

Ce qui se produit ensuite (**l'épreuve a échoué**) :

> Tu t'embrouilles entre ce que tu as vu et ce que tu as deduit. Elle n'entend qu'une accusation sans preuve contre un homme du bourg, et se leve pour ouvrir la porte.

### En coulisses

- Carte tirée : `c24`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation ankou +9
  2. réputation druides +12
  3. réputation niamh +14
- Choix retenu par l'autoplay : option 2 — « Parler de l'homme du bourg »
- Vie après résolution : 35/100 (avant : 43)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : anciens -1 (→ 96)
- Marqueurs actifs : ['bottes_seches']

## Carte 25 — acte « Climax »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 25 / 25 |
| Vie | 35/100 |
| Anam | 0 |

Texte de la carte :

> Au bout des planches grises, la ou le marais rend enfin le pied ferme, une borne. Merlin est assis dessus. « Tu es entre dans cette maison pour une nuit », dit-il.

Les trois options, telles qu'elles s'affichent :

1. **Reprendre la route** — *prudente* · épreuve volonte/blanche · échec −4 PV
2. **Lui demander ce que tu dois** — *equilibree* · épreuve logic/blanche · échec −5 PV
3. **Faire demi-tour** — *audacieuse* · épreuve instinct/blanche · échec −5 PV

Épreuve **logic** niveau 1 — 60 % de réussite, jet 0.32 → **réussite**

Ce qui se produit ensuite :

> « Rien qu'on puisse payer », repond Merlin. « Tu as vu une chose que deux personnes voulaient garder, et chacune pour proteger l'autre. Tu ne dois pas d'argent. Tu dois de te taire ou de parler, et les deux coutent. »

### En coulisses

- Carte tirée : `c25`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation anciens +12 · Anam +4
  2. réputation druides +13 · Anam +5
  3. réputation ankou +15 · Anam +5
- Choix retenu par l'autoplay : option 2 — « Lui demander ce que tu dois »
- Vie après résolution : 30/100 (avant : 35)
- Réputations après le choix : aucun changement
- Dé du destin (lancé après chaque carte hors climax) : aucun changement
- Marqueurs actifs : ['bottes_seches']

## Fin de run

- Issue : **live**
- Vie finale : **30/100**
- Anam gagné sur ce run : **0**
- Réputations finales (jamais montrées au joueur) : {'anciens': 96, 'ankou': 92, 'druides': 100, 'korrigans': 51, 'niamh': 91}

## Ce que le joueur ne voit jamais

Relevé directement sur le HUD instrumenté : seuls **trois** éléments sont affichés — le compteur de cartes, la vie et l'Anam. Ne sont montrés à aucun moment :

- les réputations des cinq factions (`_refresh_hud` : « aucun affichage HUD »), alors que presque chaque option en modifie une ;
- les effets attachés aux options, y compris les dégâts et les soins ;
- le dé du destin, qui modifie une faction au hasard après chaque carte ;
- le scénario sélectionné dans le catalogue, ses ancres et ses drapeaux ;
- les marqueurs, promesses et modificateurs de marchand actifs.
