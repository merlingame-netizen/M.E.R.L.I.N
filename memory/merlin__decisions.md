
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
