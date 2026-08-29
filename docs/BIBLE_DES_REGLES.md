# BIBLE DES RÈGLES — comment on joue à M.E.R.L.I.N.

> **v1.1 — 2026-08-29.** Ce document dit comment une partie se joue. Il ne dit pas ce que le monde
> contient (`docs/BIBLE.md`, canon R1 à R191) ni à quoi ressemblent les écrans
> (`docs/70_graphic/UI_UX_BIBLE.md`).
>
> Chaque règle ci-dessous est soit **appliquée par le code** — la source fait foi et elle est citée —
> soit **décidée et pas encore construite**, et c'est écrit en toutes lettres. Aucune règle n'est
> inventée pour faire joli : ce qui n'a pas de source ou de décision datée n'est pas ici.
>
> Les scénarios de référence (`data/scenarios/`, rendus dans `docs/scenarios/`) sont l'application
> de ce document. Ils sont générés par `tools/scenarios/rendre.py`, qui **recalcule** chaque chiffre
> depuis ces règles : une page ne peut pas afficher un résultat que les règles ne produisent pas.

---

## 1. La boucle

Une **quête** est une suite de **beats**. Le jeu tire sa longueur au hasard entre 8 et 25
(`QUETE_BEATS_MIN` / `QUETE_BEATS_MAX`, `scripts/llm/merlin_scenario.gd`). La variable
d'environnement `MERLIN_BEATS` force cette longueur, **pour le diagnostic uniquement** : elle exige
au moins 3, sinon le tirage est conservé.

Un beat est **ordinaire** ou **spécial**. Un beat ordinaire se joue avec une tuile et une rune, et
se résout au dé. Un beat spécial a sa propre mécanique et ne touche ni aux tuiles ni aux runes.

Chaque beat a un **type** narratif — Exploration, Rencontre, Épreuve, Dilemme, Climax — qui oriente
l'écriture sans changer les règles.

---

## 2. Le beat ordinaire

### 2.1 Les cinq tuiles, le socle

| Tuile | Ce qu'elle veut dire |
|---|---|
| `OBSERVER` | lire une scène avant d'y toucher |
| `AGIR` | faire de ses mains, avec adresse |
| `COMBATTRE` | y mettre le corps et tenir |
| `RÉVÉLER` | faire venir au jour ce qui se cache |
| `PARLER` | s'adresser à quelqu'un |

Elles ne changent jamais et sont toujours toutes disponibles. **Une quête qui n'en emploie jamais
une a un défaut de conception** — `tools/scenarios/rendre.py` le signale à chaque rendu.

### 2.2 Les runes, la main

Le Voyageur tient **quatre runes**. Une rune est une *posture*, pas une statistique : la Patience,
la Méfiance, la Franchise, l'Élan pour la main de départ ; la Pitié, l'Entêtement, le Silence, la
Ruse, l'Aplomb, le Deuil s'y ajoutent en cours de partie.

**La rune posée quitte la main, et on en repioche une.** La main de la fin n'est donc pas celle du
début : elle est le produit de ce qui a été joué.

**La main persiste d'une quête à l'autre.** Elle n'est pas remise à zéro : *La Course des Korrigans*
s'ouvre avec La Ruse, La Méfiance, La Franchise et La Patience — l'Élan est parti dans une partie
antérieure, La Ruse y est arrivée, et c'est elle qui ouvre la quête.

> **Décidé, non construit.** La pioche est aujourd'hui *dirigée* dans les scénarios de référence :
> la quête donne les runes dont ses beats auront besoin. Le tirage réellement aléatoire reste à
> trancher.

### 2.3 Le geste

Le joueur pose **une tuile et une rune**. La tuile dit *ce qu'il fait*, la rune dit *avec quoi*.

C'est le modèle qui lit la paire et écrit ce qui arrive. **Les tags ne sont jamais affichés** : le
joueur voit deux mots, pas une table de correspondances. `COMBATTRE avec La Patience` n'est pas un
bras de fer, c'est une essorée lente à deux ; `PARLER avec Le Silence` est une prise de parole qui
consiste à ne rien dire. Aucune table n'aurait produit ces scènes.

### 2.4 La résolution

Sous le capot — invisible au joueur — chaque beat demande deux **tags**, et la paire jouée en
couvre zéro, un ou deux.

| Élément | Valeur | Source |
|---|---|---|
| Par tag requis couvert | **+3** | `COVER_PER_TAG`, `scripts/game/merlin_resolution.gd` |
| Le jet | **2d6** | R158 |
| Marge | `total − difficulté` | — |
| Éclatante | marge **≥ 8** | `ECLAT_MARGIN` |
| Réussite | marge **≥ 0** | — |
| Partiel | marge **−1 à −5** | `PARTIEL_LOW` |
| Échec | marge **< −5** | — |

La **mise** est annoncée *avant* le dé et jamais l'issue : « Difficulté 9 · vos atouts +6 ». Elle
dit l'enjeu. Certains gestes passent **sans jet** — « le geste est acquis », « maîtrise du geste » —
et l'éclatante leur est alors interdite : dispenser le dé ne peut jamais produire un éclat.

La difficulté vaut 9 dans le cas courant et monte au climax.

---

## 3. Le beat spécial

Un beat spécial **n'a ni tuile, ni rune, ni dé**, et la main ne bouge pas : rien n'est posé, rien
n'est repioché. Il a sa propre mécanique.

> **Décidé, non construit.** Aucune de ces mécaniques n'existe dans le code aujourd'hui. Les neuf
> sont spécifiées ici et **toutes jouées au moins une fois** dans les six scénarios de référence —
> `tools/scenarios/rendre.py` le vérifie et nomme celles qui manqueraient.

### 3.1 Le choix

**2 à 4 propositions**, chacune avec ce qu'elle entraîne. On en sélectionne une, sans retour en
arrière, et aucun dé n'intervient. Une proposition qui ne coûte rien n'a pas sa place : si l'une
d'elles est manifestement la bonne, il n'y a pas de choix.

### 3.2 Le marchand

Un étal de trois à cinq articles avec leur prix. On achète, on refuse, on repart ; ce qu'on laisse
reste sur l'étal. **Un troc ne s'annule pas.**

### 3.3 Le boss

Une créature qui **rejoue** : trois ou quatre gestes, toujours dans le même ordre. On la regarde
boucler, et à chaque tour on peut agir ou attendre. **Il existe un tour où elle est découverte** ;
agir au mauvais moment coûte de la santé et relance le cycle.

Un boss ne se bat pas, il s'observe. C'est la loi du monde retournée en mécanique : tout rejoue
sans fin dans ces bois, donc tout est prévisible à qui accepte de regarder deux fois.

### 3.4 L'énigme écrite

Une question, un champ où écrire, **trois essais**. Le modèle juge le **sens** et non l'orthographe :
plusieurs formulations passent, une bonne intuition mal dite passe aussi. Un essai raté fait avancer
la nuit ; trois ratés ferment le passage et il faut contourner.

**L'indice doit avoir été posé dans un beat antérieur.** Une énigme dont la réponse n'était nulle
part n'est pas une énigme, c'est une devinette.

### 3.5 La veille

Un compteur qui descend, et une décision répétée : rester ou partir. Rester encore coûte un peu plus
à chaque tour, et rien ne dit combien de tours il faudra. Dans *Le Prix du Passeur*, il arrive au
tour juste après celui où partir devient impossible — et le joueur ne pouvait pas le savoir.

### 3.6 Le partage

Moins de choses que de mains tendues. Chaque attribution est définitive et aucun dé n'intervient.
**Ça ne punit pas sur le moment** : chacun se souvient de ce qu'il n'a pas reçu, et on repasse.
C'est la mécanique qui convient aux campagnes longues, où l'on a le temps de revenir.

### 3.7 La poursuite

Trois embranchements qui défilent sans temps mort. On tranche vite, chaque virage coûte, bon ou
mauvais. Bien trancher ne suffit pas : dans *La Course des Korrigans*, Fañch avait prévenu qu'il
connaît le marché et que le Voyageur non — l'avertissement était la solution, et il n'a pas servi.

### 3.8 Le rituel

Refaire des gestes dans un ordre vu plus tôt dans la quête, **sans aucun rappel à l'écran**. Ni
chance ni adresse : de l'attention payée avant. C'est un contrat entre deux beats éloignés — dans
*Trois Pains à Kerlan*, la frise est au beat 5 et le rite au beat 9, et rien ne signale le beat 5
comme important.

---

## 4. L'état

Trois compteurs, et **rien ne s'accumule parce qu'on a réussi**.

| Compteur | Ce qui le fait bouger |
|---|---|
| **Santé** | les partiels, les échecs, les mauvais tours de boss |
| **Corruption** | les décisions qui coûtent quelque chose au Voyageur |
| **Gwenneg** | **uniquement** un événement qui en donne : une transaction, un trésor, une bête dépouillée, une situation d'argent |

Une quête peut ne contenir **aucun** événement d'argent, et n'avoir **aucun marchand**. Cela dépend
du contexte. Dans *Le Linceul de Kado*, la bourse ne bouge qu'une fois en dix-huit beats — et c'est
ce qui rend les neuf gwenneg lourds.

> **Défaut mesuré, à corriger — voir la tâche ouverte.** Le jeu verse aujourd'hui +2 à +6 gwenneg à
> **chaque beat** sans raison narrative : sur la partie témoin p74, la bourse passe de 2 à 65 toute
> seule et les onze étals du colporteur enregistrent **zéro achat**. L'argent n'est ni gagné ni
> dépensé, c'est un compteur qui monte.

---

## 5. Ce qu'une quête doit respecter

Ces règles ne sont pas des préférences d'écriture : ce sont les conditions pour qu'une quête tienne.

1. **Le but tient en une phrase, et le Voyageur le connaît tôt.** On doit pouvoir le répéter à
   n'importe quel moment de la partie.
2. **Chaque figure a un nom, veut quelque chose, et le dit.** Pas « une femme au visage fatigué » :
   la Lavandière de Nuit, qui veut qu'on l'aide à tordre.
3. **Le mystère est dans l'ambiance, jamais dans le sens.** Une phrase qui sonne profonde et ne veut
   rien dire est un défaut, pas un style.
4. **Chaque beat coûte ou rapporte quelque chose qu'on peut nommer.** Si on peut le retirer sans
   rien changer, il ne devait pas exister.
5. **Ce qui apparaît revient.** Un objet qui traverse une scène et disparaît est du décor ; trois de
   suite, c'est du remplissage.
6. **L'issue ne redit pas la scène : elle la déplace.** Si la dernière phrase pouvait être la
   première, il ne s'est rien passé.
7. **Un compagnon gagné apparaît dans toutes les scènes qui suivent, ou n'est pas gagné.** Kado suit
   le Voyageur à partir du beat 7 : il ralentit la course, reconnaît sa corde sur l'étal, on parle
   de lui devant lui, et **le chevalier ne fait son offre que parce qu'il le voit debout**.
8. **La boucle est le moteur, pas le papier peint.** Les êtres rejouent sans fin, seul le Voyageur
   avance : c'est de là que sortent les dilemmes, et c'est aussi la faiblesse du boss.

### 5.1 Le rythme des décisions

Une décision **ne se pose pas au métronome**. Elle se pose quand le sol vient de bouger, et
seulement quand le Voyageur a de quoi décider.

On distingue les **bascules subies** — le monde décide — des **bascules choisies**. Elles alternent
à intervalles irréguliers, et l'irrégularité est de l'information. Dans *Le Linceul de Kado*, trois
bascules tombent en quatre beats au début, puis plus aucune décision pendant cinq beats : on vous
vole votre outil, on vous apprend qu'il faudra condamner quelqu'un, et **vous ne décidez rien parce
que vous n'avez encore personne à mettre à la place**. Ce creux est la pression du milieu, pas un
oubli.

---

## 6. Les défauts que le code produit aujourd'hui

Mesurés sur la partie témoin p74 (`docs/chroniques/p74/`), et à corriger.

| Défaut | Mesure | État |
|---|---|---|
| La bourse se remplit seule | 2 → 65 gwenneg en 20 beats, 0 achat sur 11 étals | ouvert |
| Le même geste partout | 17 beats sur 20 ouvrent par « Vous arrêtez votre regard… » | ouvert |
| La numérotation fuit dans la prose | « 0. », « 1. », « 6. » dans 7 beats | ouvert |
| Le climax recopie le milieu | 89 % des mots du beat 16 dans le beat 22 | ouvert |
| Le Lore ne s'imprime pas | 0 figure nommée sur 17 249 caractères | corrigé par v52 |
| Le timeout brique le moteur | beats 12-13 à 1741 et 1728 tokens relus | corrigé par v51 |
| Des beats joués hors journal | index 15 et 21 absents pour 22 beats joués | corrigé par v53 |

---

*Sources : `scripts/game/merlin_resolution.gd`, `scripts/llm/merlin_scenario.gd`,
`scripts/llm/merlin_prompt_builder.gd`, `tools/scenarios/rendre.py`, journal de p74.*

---

## 7. Le corpus de référence

Six quêtes, 67 beats, sous `data/scenarios/` et rendues dans `docs/scenarios/`. Elles servent à
deux choses : montrer le rendu qu'on vise, et donner au modèle des exemples de ce qu'on attend.

| Quête | Beats | Ce qu'elle exerce |
|---|---|---|
| Le Linceul de Kado | 18 | la référence Brocéliande — choix, marchand, compagnon qui pèse |
| La Cloche d'Ys | 10 | le **boss** : la boucle d'une figure est sa faiblesse |
| Les Neuf Corbeaux | 10 | l'**énigme écrite**, dont l'indice est posé sept beats avant |
| Le Prix du Passeur | 10 | la **veille**, et un prix qu'on ne connaît qu'au milieu |
| Trois Pains à Kerlan | 10 | le **partage** et le **rituel** |
| La Course des Korrigans | 9 | la **poursuite**, et le seul **échec** du corpus |

`tools/scenarios/rendre.py` rend les pages et publie un **rapport de corpus** : mécaniques
couvertes, tuiles jouées, degrés obtenus, runes jamais posées. Ce rapport a déjà attrapé quatre
défauts réels — une quête qui ne jouait jamais `AGIR`, une autre `COMBATTRE`, la rune `La Ruse`
jamais posée, et **43 réussites pour zéro échec** : un corpus qui ne rate jamais apprendrait au
modèle que tout réussit.
