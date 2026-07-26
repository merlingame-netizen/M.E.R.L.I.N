# Run joué dans le moteur — transcript intégral

> Produit par l'instrumentation de `scripts/board_narration/board_narration.gd` (`MERLIN_TRANSCRIPT=<chemin>`) pendant un run réel en autoplay (`MERLIN_AUTOPLAY=1`), puis rendu par `tools/render_run_transcript.py`. Aucun élément n'est reconstitué à la main.

**Biome** : foret_broceliande · **Séquence d'actes** : Standard → Marchand → Standard → Événement → Climax · **Issue** : live · **Cartes jouées** : 5 · **Anam gagné** : 0

Chaque carte est présentée en deux plans : **à l'écran** (ce que le joueur lit) et **en coulisses** (ce que le moteur applique sans le dire).

## Départ

- Vie **100/100** · Anam affiché **0**
- Scénario sélectionné dans le catalogue : **la_fille_perdue**
- Réputations de départ (jamais affichées) : {'anciens': 20, 'ankou': 20, 'druides': 20, 'korrigans': 20, 'niamh': 20}

## Carte 1 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 1 / 5 |
| Vie | 100/100 |
| Anam | 0 |

Texte de la carte :

> Un sentier se divise en trois devant un chene noueux. Des murmures viennent de chaque direction.

Les trois options, telles qu'elles s'affichent :

1. **Observer les traces au sol**
2. **Ecouter les murmures**
3. **Avancer au hasard**

### En coulisses

- Carte tirée : `fr_broceliande_001`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +5
  2. réputation anciens +5
  3. vie +3
- Choix retenu par l'autoplay : option 1 — « Observer les traces au sol »
- Vie après résolution : 100/100 (avant : 100)
- Réputations après le choix : druides +5 (→ 25)
- Dé du destin (lancé après chaque carte hors climax) : korrigans -1 (→ 19)

## Carte 2 — acte « Marchand »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 2 / 5 |
| Vie | 100/100 |
| Anam | 0 |

Texte de la carte :

> Une biche argentee te fixe a travers les fougeres. Elle semble attendre quelque chose.

Les trois options, telles qu'elles s'affichent :

1. **S'approcher doucement**
2. **Suivre la biche**
3. **Rester immobile**

### En coulisses

- ⚠ L'acte demandé était « shop » mais la carte servie est de type « standard » — le pool ne contient aucune carte pour cet acte.
- Carte tirée : `fr_broceliande_002`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +8
  2. réputation niamh +5 · vie +3
  3. vie +5
- Choix retenu par l'autoplay : option 1 — « S'approcher doucement »
- Vie après résolution : 100/100 (avant : 100)
- Réputations après le choix : druides +8 (→ 33)
- Dé du destin (lancé après chaque carte hors climax) : druides -1 (→ 32)

## Carte 3 — acte « Standard »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 3 / 5 |
| Vie | 100/100 |
| Anam | 0 |

Texte de la carte :

> Un cercle de champignons luminescents pulse doucement au pied d'un if centenaire. L'air vibre d'une energie ancienne.

Les trois options, telles qu'elles s'affichent :

1. **Entrer dans le cercle**
2. **Cueillir un champignon**
3. **Dechiffrer les runes sur l'if**

### En coulisses

- Carte tirée : `fr_broceliande_003`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +10 · vie −3
  2. vie +8
  3. réputation anciens +7
- Choix retenu par l'autoplay : option 1 — « Entrer dans le cercle »
- Vie après résolution : 97/100 (avant : 100)
- Réputations après le choix : druides +10 (→ 42)
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 19)

## Carte 4 — acte « Événement »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 4 / 5 |
| Vie | 97/100 |
| Anam | 0 |

Texte de la carte :

> Un loup solitaire hurle a la lune depuis une colline proche. Ses yeux brillent d'une intelligence surnaturelle.

Les trois options, telles qu'elles s'affichent :

1. **Affronter le loup**
2. **Chanter pour l'apaiser**
3. **Observer a distance**

### En coulisses

- ⚠ L'acte demandé était « event » mais la carte servie est de type « standard » — le pool ne contient aucune carte pour cet acte.
- Carte tirée : `fr_broceliande_004`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation ankou +8 · vie −5
  2. réputation niamh +8
  3. réputation druides +5
- Choix retenu par l'autoplay : option 1 — « Affronter le loup »
- Vie après résolution : 92/100 (avant : 97)
- Réputations après le choix : ankou +8 (→ 27)
- Dé du destin (lancé après chaque carte hors climax) : ankou -1 (→ 26)

## Carte 5 — acte « Climax »

### À l'écran

| HUD | valeur |
|---|---|
| Compteur | Carte 5 / 5 |
| Vie | 92/100 |
| Anam | 0 |

Texte de la carte :

> Des champignons luminescents forment un cercle parfait au pied d'un vieux hetre. L'air vibre d'une energie ancienne.

Les trois options, telles qu'elles s'affichent :

1. **Entrer dans le cercle**
2. **Cueillir un champignon**
3. **Dessiner les runes au sol**

### En coulisses

- ⚠ L'acte demandé était « boss » mais la carte servie est de type « standard » — le pool ne contient aucune carte pour cet acte.
- Carte tirée : `fr_broceliande_005`
- Effets attachés à chaque option, **invisibles pour le joueur** :
  1. réputation druides +10 · vie −3
  2. vie +8
  3. réputation anciens +8
- Choix retenu par l'autoplay : option 1 — « Entrer dans le cercle »
- Vie après résolution : 94/100 (avant : 92)
- Réputations après le choix : druides +10 (→ 52)
- Dé du destin (lancé après chaque carte hors climax) : aucun changement

## Fin de run

- Issue : **live**
- Vie finale : **94/100**
- Anam gagné sur ce run : **0**
- Réputations finales (jamais montrées au joueur) : {'anciens': 20, 'ankou': 26, 'druides': 52, 'korrigans': 19, 'niamh': 20}

## Ce que le joueur ne voit jamais

Relevé directement sur le HUD instrumenté : seuls **trois** éléments sont affichés — le compteur de cartes, la vie et l'Anam. Ne sont montrés à aucun moment :

- les réputations des cinq factions (`_refresh_hud` : « aucun affichage HUD »), alors que presque chaque option en modifie une ;
- les effets attachés aux options, y compris les dégâts et les soins ;
- le dé du destin, qui modifie une faction au hasard après chaque carte ;
- le scénario sélectionné dans le catalogue, ses ancres et ses drapeaux ;
- les marqueurs, promesses et modificateurs de marchand actifs.

## Notes de moteur — deux anomalies élucidées

Deux écarts entre ce que la carte annonce et ce que le moteur applique ont été
tracés jusqu'à leur origine.

**Carte 5 : la vie monte alors que l'option inflige des dégâts.** L'option
retenue déclare `DAMAGE_LIFE 3`, et la vie passe pourtant de 92 à 94. Le calcul
est : 92 − 3 (dégâts de la carte) + 5 (passif de biome) = 94. Brocéliande
déclare `{"every_n": 5, "direction": "up"}` (`data/balance/tuning.json`), et
`merlin_biome_system.gd:226` traduit `direction: "up"` en `HEAL_LIFE 5` toutes
les 5 cartes. Le passif se déclenche donc exactement sur la dernière carte du
run. Rien n'en informe le joueur : il voit sa vie remonter après avoir choisi
une option qui devait le blesser.

*Effet de bord* : la clé `"faction": "korrigans"` de ce passif n'est jamais lue —
`get_passive_effect` ne regarde que `direction` et renvoie un soin ou des dégâts
fixes de 5. Le passif de biome n'a aucun rapport avec la faction qu'il déclare.

**Anam gagné : 0.** Ce n'est pas un arrondi. `calculate_run_rewards` n'est
appelé que depuis `store_run.gd:334`, à l'intérieur de `handle_run_end`, lui-même
déclenché par `check_run_end` — c'est-à-dire uniquement sur une victoire ou une
mort. À 5 cartes sans mort, aucune des deux conditions n'est atteinte : la boucle
sort du `for`, appelle `_finish()`, et **aucun calcul de récompense n'a lieu**.
Le joueur ne reçoit donc rien du tout, pas même la base de 10 Anam réduite par
le facteur d'échec. La condition de victoire elle-même exige
`cards_played >= 25` (`merlin_constants.gd:103`) pour une boucle qui en joue 5 :
elle est inatteignable par construction.
