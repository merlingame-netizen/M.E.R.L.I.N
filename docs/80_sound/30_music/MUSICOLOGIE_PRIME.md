# Profil musicologique — trilogie Metroid Prime, transposé à M.E.R.L.I.N.

> **Statut épistémique.** Ce document sépare strictement trois niveaux :
> **[DOC]** ce qui est documenté et sourcé · **[DED]** ce qui se déduit de
> contraintes techniques vérifiables · **[PROP]** ma proposition de design.
> Aucun relevé d'écoute n'entre ici : je n'ai pas de perception auditive et je
> n'ai pas l'OST. Ce profil est une **charpente de design argumentée**, pas une
> analyse spectrale. Il devient mesurable dès qu'on lui fournit une référence
> (voir §6).

---

## 1. Ce qui est établi

**[DOC]** Musique de *Metroid Prime* composée par Kenji Yamamoto avec Kōichi
Kyūma. Yamamoto compose depuis le Japon pendant que Retro Studios développe
le jeu au Texas.
([Metroid Wiki](https://www.metroidwiki.org/wiki/Kenji_Yamamoto),
[Metroid Recon](https://metroid.retropixel.net/games/mprime/music/))

**[DOC]** Yamamoto déclare avoir employé pour Metroid des techniques et des
instruments différents de ses autres projets, au service d'un univers
particulier. *Metroid Prime 3* embarque un système de musique interactive qui
modifie la partition selon l'état du joueur.
([Original Sound Version](https://www.originalsoundversion.com/a-blast-from-the-past-metroid-prime-3-corruption-with-kenji-yamamoto-and-retro-studios/),
[Destructoid](https://www.destructoid.com/interview-with-metroid-prime-3s-retro-studios-and-composer-kenji-yamamoto/))

**[DOC]** Pour Phendrana (zone glacée) : mélange de sons de synthèse et
d'instruments « fidèlement recréés », dont des sonorités de glace ; un piano
avec maillets, traité en écho, installe l'imagerie gelée.
([Wikitroid](https://metroid.fandom.com/wiki/Phendrana_Drifts_\(theme\)))

**[DOC]** Chaque zone possède une **famille** de morceaux et non un thème
unique : ambiance, thème principal, profondeurs, variante d'énigme, variante de
combat. Phendrana compte à elle seule ambiance / thème / profondeurs / énigme,
et son thème est écrit pour préparer sa reprise accélérée.
([Metroid Recon](https://metroid.retropixel.net/games/mprime/music/))

> **C'est le point le plus important pour nous**, et c'est du documenté :
> l'unité d'écriture n'est pas le morceau, c'est **la zone déclinée en états**.
> Exactement la structure « un socle, des titulaires qui changent » que
> M.E.R.L.I.N. utilise déjà.

**[DED]** Contraintes matérielles GameCube. La console lit du DSP-ADPCM ; le
codec impose environ 24 dB de rapport signal/bruit et comprime à ~29 % de la
taille PCM (mesuré sur notre propre banque, `musyx_extract.py`). La mémoire
force des fréquences d'échantillonnage basses, d'où un aigu naturellement
adouci. **Une part réelle de la signature « Prime » ne tient pas aux
instruments mais à ce que la machine leur faisait subir.**

**[DED]** Les banques MusyX (`.agsc`) stockent des notes isolées avec note de
base, fréquence et points de boucle : la musique est **séquencée**, pas
diffusée en flux. C'est ce qui rend possible une adaptation continue à l'état
du joueur — et c'est le même principe que notre table de distribution.

---

## 2. Ce qui n'est PAS documenté

Il n'existe pas, dans les sources accessibles, de relevé instrumental fin par
zone, ni d'analyse harmonique publiée. Les palettes du §3 sont donc **[PROP]**.
Elles s'appuient sur des principes d'orchestration généraux, pas sur un relevé
de l'OST. Elles sont faites pour être corrigées : par ton écoute, ou par mesure
(§6).

---

## 3. Archétypes d'environnement → palette

Le principe transposable est une **règle de correspondance** entre un milieu et
un traitement sonore. C'est de la méthode, pas du matériau : rien ici ne
reproduit une œuvre.

| Archétype | Registre | Attaque | Espace | Densité |
|---|---|---|---|---|
| **Gelé** | aigu clairsemé | percussive brève, métallique/vitreuse | très longue, sombre | très faible |
| **Volcanique** | grave soutenu | sourde, bruitée | courte, dense | forte |
| **Végétal** | médium | organique, bois et peaux | moyenne, diffuse | moyenne |
| **Ruines** | médium-grave | tenue, sans transitoire | très longue | faible |
| **Industriel** | large, dissonant | dure, inharmonique | métallique | irrégulière |

Trois invariants traversent les cinq, et ce sont eux qui font le style :

1. **La retenue.** Peu de notes, longues. Le silence porte autant que le son.
2. **L'espace comme instrument.** La réverbe n'est pas un effet, c'est un
   paramètre de composition : sa durée et son amortissement *disent* le lieu.
3. **Le mélange synthèse / acoustique.** Ni orchestre pur, ni synthé pur : des
   timbres reconnaissables placés dans un espace qui ne l'est pas.

---

## 4. Correspondance avec les contextes M.E.R.L.I.N.

Notre jeu n'a ni lave ni mines, mais ses axes (météo, saison, moment) sont des
milieux. La correspondance retenue **[PROP]** :

| Contexte | Archétype | Effet sur le mix |
|---|---|---|
| `neige` | Gelé | aigu ouvert, réverbe très longue et sombre, grave retiré |
| `brume` | Gelé atténué | aigu voilé, réverbe longue, très humide |
| `pluie` | Végétal | médium présent, réverbe moyenne |
| `couvert` | Ruines | réverbe longue, aigu légèrement retiré |
| `clair` | Végétal ouvert | peu de réverbe, spectre neutre |
| `hiver` | Gelé | comme `neige`, plus sobre |
| `nuit` | Ruines | réverbe la plus longue, grave soutenu |
| `aube` | Végétal | claire et proche |

**La référence à Prime est ici, et nulle part ailleurs** : quand il neige,
Tri Martolod prend le traitement d'un monde gelé — aigu clairsemé, longue queue
sombre, grave retiré. Aucune mélodie n'est empruntée. Ce qui est emprunté, c'est
la *règle* qui lie un milieu à un son.

---

## 5. Ce qui reste original

Tri Martolod est traditionnel — domaine public. L'arrangement, la forme en 40
mesures, le mode ré dorien, la distribution en trois rôles et les ornements sont
écrits pour ce projet. La trilogie Prime n'apporte que trois choses, toutes
méthodologiques :

- décliner une zone en états plutôt qu'écrire un morceau,
- traiter l'espace comme un paramètre d'écriture,
- accepter le grain de la machine plutôt que le masquer.

C'est ce qui distingue une **influence** d'un **emprunt**.

---

## 6. Rendre ce profil mesurable

Les valeurs du §4 sont des choix. Elles deviennent des cibles chiffrées dès
qu'on dispose d'une référence légalement détenue. La procédure n'extrait aucun
audio, uniquement des nombres :

| Mesure | Ce qu'elle règle |
|---|---|
| Pente spectrale (dB/octave) | les deux shelfs |
| RT60 par bande | durée et amortissement de réverbe |
| Rapport tonal / bruité | dosage synthèse vs acoustique |
| Densité d'attaques par minute | densité d'écriture |
| Écart-type des intervalles | ambitus mélodique |

Rien de tout cela n'est protégeable : ce sont des descripteurs, pas des œuvres.

---

*Sources : [Metroid Wiki](https://www.metroidwiki.org/wiki/Kenji_Yamamoto) ·
[Wikitroid](https://metroid.fandom.com/wiki/Kenji_Yamamoto) ·
[Metroid Recon](https://metroid.retropixel.net/games/mprime/music/) ·
[Original Sound Version](https://www.originalsoundversion.com/a-blast-from-the-past-metroid-prime-3-corruption-with-kenji-yamamoto-and-retro-studios/) ·
[Destructoid](https://www.destructoid.com/interview-with-metroid-prime-3s-retro-studios-and-composer-kenji-yamamoto/)*
