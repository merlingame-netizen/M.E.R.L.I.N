
## 2026-08-08: Pluie = harpe (musique de menu)
- Quand la meteo est "pluie", le role corde revient a LA HARPE (pas l'oud).
- Decision utilisateur explicite lors de la recomposition du theme de menu ;
  l'oud etait un choix d'implementation, corrige.
- Egalement : le socle doit rester clairseme (harmonie seule, ~160 notes) —
  le reproche "trop d'instruments ensemble" visait un socle a 534 notes avec
  harpe en arpeges continus, contre-chants et cloches. Le mouvement appartient
  aux roles remplacables, pas au socle.
- Les nappes de bruitage (tambour d'ocean...) doivent se CHEVAUCHER : une
  nappe par mesure plus courte que la mesure = "bruitage qui se coupe".

## 2026-08-07: Axes musique menu v2 — meteo=melodie, heure=vitesse, saison supprimee
- La meteo change l'INSTRUMENT DE LA MELODIE principale (valide par l'utilisateur).
  La regle « pluie = harpe » porte desormais sur la melodie elle-meme.
- L'heure de la journee devient un axe a 6 valeurs (aube/matinee/midi/apres-midi/
  soiree/nuit) qui pilote la VITESSE de la musique, ajoute parfois quelques
  instruments, et SUBSTITUE des instruments la nuit.
- L'axe saison est SUPPRIME.
- La musique doit comporter MOINS D'ELEMENTS (fond allege : halo seulement a
  certaines heures, substitution nocturne du fond).

## 2026-08-07: Table melodie v3 — REMPLACE « pluie = harpe »
- L'instrument de la melodie depend de (meteo, heure). Exemples donnes :
  nuit = BOITE A MUSIQUE lente (toutes meteos) ; apres-midi clair = OUD ;
  apres-midi couvert = HARPE ; FLUTE s'il pleut.
- La regle anterieure « pluie = harpe » est CADUQUE : la harpe appartient au
  ciel couvert, la pluie est a la flute.
- Moins d'instruments au global ; la musique se CENTRE SUR LE MOTIF
  (Tri Martolod), l'accompagnement s'efface.
- Le changement de vitesse ne doit JAMAIS s'entendre comme une coupure :
  un seul saut de playbackRate (pas de rampe continue, pas de pilotage
  micro-ajuste — chaque changement reinitialise l'etireur du navigateur).

## 2026-08-07: MAX 3 INSTRUMENTS A LA FOIS (menu)
- Regle absolue : jamais plus de 3 instruments simultanes.
- Assemblage : 1 socle (UN pupitre de cordes, basse+quinte) + 1 accompagnement
  (guitare le jour, cloches tubulaires la nuit) + 1 melodie (table meteo/heure).
- Consequence : pouls (bodhran/timbales) et extras (guirlande/veilleuse)
  RETIRES du fond — l'heure ne fait plus que la vitesse (+ substitution nuit).

## 2026-08-07: Fond v6 — drone lourd, percussions, PAS de guitare celte
- Le fond = DRONE grave et lourd (bourdon statique en re, cordes graves qui
  respirent) + quelques percussions sourdes. La guitare celtique SORT du fond.
- Le lecteur doit avoir une INTRODUCTION avant la boucle, et un mode boucle
  controlable.
- Tressaut permanent en vitesse modifiee : l'etireur temporel (preservesPitch)
  est mauvais EN CONTINU. Passage en VARISPEED (preservesPitch=false, hauteur
  liee a la vitesse comme une bande) : lecture parfaitement lisse, la piece
  entiere se transpose avec l'heure (nuit plus grave, midi plus brillant) —
  toutes les couches au meme taux, donc toujours accordees entre elles.

## 2026-08-07: Musique menu v7 — nuit hauteur normale, motif intangible
- La nuit, la boite a musique garde sa HAUTEUR NORMALE : rendu REEL au tempo
  x0,80 (MERLIN_TEMPO_SCALE, boucle 10 800 000 ech. = 2^4*3^3*5^5), lecture a
  1,0 — aucun traitement. Les heures de jour restent en varispeed DOUX
  (0,94-1,05, moins d'un demi-ton de derive).
- Le drone doit avoir de la VARIETE et SUIVRE la melodie : il porte la
  fondamentale de l'harmonie (grave, lourd, legato), plus une octave au coeur.
- Les percussions doivent etre AUDIBLES (entree mesure 5, pas 13) et de TYPES
  DIFFERENTS selon l'heure : calme (matinee/apres-midi), danse (midi),
  sourd (aube/soiree), tambour de nuit (nuit, integre au rendu lent).
- Tri Martolod : partition FIDELE, motif garde a 100 % — les garde-fous
  harmoniques ne deplacent JAMAIS une note du chant (purge_harsh exempte,
  lint R3 exempte) ; ornementation reduite a quelques twists sur les reprises.

## 2026-08-07: Musique menu v8 — mix et transitions
- Intro COURTE et SIMPLE : 1 mesure, drone seul qui se leve (4,9 s).
- Percussions +6 dB dans les mixes mobiles (noyees sous le drone sinon).
- Le fond (drone) a -4 dB sous la melodie : le motif domine, le fond porte.
- En VARISPEED pur, la rampe de vitesse est propre (c'est l'etireur temporel
  qui detestait les rampes) : glisse de bande ~350 ms, creux de gain retire.

## 2026-08-07: Musique menu v9 — tout en rendu reel, fond melodique, guitare
- TOUT en RENDU REEL, vitesses PRONONCEES : 4 jeux complets rendus aux
  echelles 3/4 (nuit), 5/6 (aube, soiree), 1 (matinee, apres-midi),
  9/8 (midi). Plus AUCUN varispeed. Echelles en fractions exactes pour des
  boucles 5-lisses (base 4 320 000 ech).
- Piece resserree a 20 MESURES (98 s) — la boucle d'un menu — pour que les
  4 jeux tiennent dans l'artefact. Forme : ouverture / air nu / refrain /
  air orne / coda. Le motif reste integral.
- FOND : drone ADOUCI et MELODIQUE (basse qui marche vers l'accord suivant)
  + ARPEGES DE GUITARE ACOUSTIQUE (celtic guitar reelle) + percussions
  RENFORCEES qui accompagnent la melodie (des la mesure 3). La regle
  « max 3 » est remplacee : drone + guitare + percussion + melodie.
- Palette bretonne/medievale/fantastique : neige = PSALTERION a archet
  (medieval, glace) au lieu de l'ocarina.
