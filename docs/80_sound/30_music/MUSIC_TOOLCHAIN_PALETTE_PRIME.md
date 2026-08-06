# Toolchain « Palette d'instruments » — extraire & recomposer
## Inspiration : Metroid Prime 1 → 4 (Kenji Yamamoto / Retro Studios)

> **Objectif** : disposer d'une **banque d'instruments fermée** (« fonts musicaux ») et
> recomposer des morceaux **complets** en n'utilisant **que** ces sons.
> Ce document liste les projets open source qui couvrent chaque maillon de la chaîne.

---

## 0. TL;DR — la chaîne en 3 maillons

```
[A] SOURCE                    [B] BANQUE                   [C] RECOMPOSITION
Extraire les éléments    →    Construire ta palette   →    Générer des morceaux
(samples ou stems)            (SF2 / SFZ / modèle)         complets, palette-only

MP1/2 : musyx-extract         Polyphone (SF2)              MIDI-GPT / MMM  → FluidSynth
MP3/Rmst/MP4 : Switch-        sfizz / SFZ                  ou RAVE (timbre transfer)
Toolbox + vgmstream           ou modèle RAVE               ou MusicGen-Stem (stems)
OST seul : Demucs/UVR5
```

Le point clé : **Metroid Prime 1 et 2 ne sont pas du streaming audio**. Ils utilisent le
moteur **MusyX** (Factor 5) → la musique est **séquencée** (MIDI-like) + une **banque de
samples** séparée. C'est exactement ce que tu cherches : les instruments existent
**déjà isolés** dans le jeu, pas besoin de séparation de sources.

---

## 1. Étape A — Récupérer les éléments source

### A.1 — Metroid Prime 1 & 2 (GameCube) — **le cas idéal**

Format : `AGSC` = 4 chunks MusyX (`.pool` / `.proj` / `.samp` / `.sdir`), plus `.csng`/`.son`
pour les séquences. Les samples sont en ADPCM GameCube (`.dsp`).

| Projet | Rôle | Lien |
|---|---|---|
| **Prime World Editor (PWE)** | Ouvrir les `.pak` de MP1/2/3, en sortir les `AGSC`/`ATBL`/`CSNG` | github.com/AxioDL/PWE |
| **Nisto/musyx-extract** | Extraire les samples `.sdir`+`.samp` → `.dsp` (et **repack** dans l'autre sens) | github.com/Nisto/musyx-extract |
| **AxioDL/amuse** | **Le plus important** : séquenceur/éditeur MusyX complet. `File > Import Groups` sur le `.proj` → tu vois les instruments, les macros, les layers, les courbes ADSR. Convertit `SNG ↔ MIDI` (`amuseconv`), rend l'audio en CLI (`amuserender`) | github.com/AxioDL/amuse |
| **vgmstream** | Décoder `.dsp` / `.adp` / `.bfstm` → WAV | github.com/vgmstream/vgmstream |

**Ce que ça te donne** : le sample brut de chaque instrument **+ sa configuration**
(key ranges, tuning, enveloppes, LFO). C'est littéralement le soundfont du jeu.

> Sortie recommandée : `amuse` pour lire la structure, `musyx-extract` pour sortir les WAV,
> puis on reconstruit en SF2/SFZ (étape B).

### A.2 — Metroid Prime 3 / Trilogy (Wii)

Même moteur MusyX, conteneurs Wii (`.pak` + `AGSC` variantes). PWE gère MP3.
La musique y est **partiellement streamée** (`.dsp` stéréo) → mix de cas A.1 et A.4.

### A.3 — Prime Remastered & **Metroid Prime 4: Beyond** (Switch / Switch 2)

Ici c'est de l'**audio streamé**, pas du séquencé. Formats Nintendo modernes :
`BARS` (conteneur) → `BWAV` / `BFSTM` / `BFWAV`, et `BFSAR`/`BFGRP` pour les banques SFX.

| Projet | Rôle | Lien |
|---|---|---|
| **Switch Toolbox** (KillzXGaming) | GUI : ouvre `BFSTM`/`BFWAV`/`BFSAR`, écoute, convertit (utilise VGAudio) | github.com/KillzXGaming/Switch-Toolbox |
| **bars-to-bwav** | Extrait les `BWAV` d'un conteneur `BARS` | github.com/jackz314/bars-to-bwav |
| **VGAudio** | Conversions loss-less entre `B_STM` (endianness arbitraire, gère le LE Switch) | github.com/Thealexbarney/VGAudio |
| **vgmstream** | Décodage universel + points de loop | github.com/vgmstream/vgmstream |

→ Comme c'est du mix rendu, il faut ensuite passer par la **séparation de sources** (A.4).
Pour l'écoute légale de référence, MP4: Beyond est dispo sur l'app **Nintendo Music**.

### A.4 — Tu n'as que le mix (OST rip, Remastered, MP4)

| Projet | Rôle | Note |
|---|---|---|
| **Demucs v4 / HTDemucs FT** | Séparation 4 ou 6 stems (`htdemucs_6s` ajoute piano + guitare) | Le standard open source |
| **python-audio-separator** | Wrapper CLI/pip propre autour des modèles MDX/Demucs/RoFormer → **scriptable**, parfait pour un pipeline | pip install audio-separator |
| **UVR5 (Ultimate Vocal Remover)** | GUI + zoo de modèles (MDX23C, Mel-RoFormer, BS-RoFormer), modes ensemble | Meilleure qualité en 2026 |
| **Music-Source-Separation-Training** (ZFTurbo) | Entraînement/inférence des modèles RoFormer récents | Si tu veux un modèle spécialisé |
| **basic-pitch** (Spotify) | Audio → MIDI polyphonique | Récupérer les **notes**, pas le son |

**Limite honnête** : sur une nappe atmosphérique Prime (réverb longue, couches fusionnées),
la séparation donne des stems « corrects mais colorés », jamais des samples propres.
Pour un instrument isolé et réutilisable, A.1 (MusyX) est **très supérieur**.

---

## 2. Étape B — Construire ta banque (« font musicale »)

C'est le maillon qui transforme un tas de WAV en **instrument jouable**.

| Projet | Rôle | Lien |
|---|---|---|
| **Polyphone** | Éditeur SF2/SF3 de référence : import WAV en masse, key mapping auto, loop points, enveloppes, export SF2 | polyphone-soundfonts.com |
| **SFZ + sfizz** | Format texte ouvert (donc **générable par script**), moteur LV2/VST open source. Idéal pour piloter la palette en Python | sfz.tools / github.com/sfztools/sfizz |
| **FluidSynth** | Rendu CLI `MIDI + SF2 → WAV`. Le bout de chaîne de tout pipeline automatisé | fluidsynth.org |
| **PyMusicLooper** | *(déjà utilisé sur MERLIN)* détection auto des points de loop seamless | pip install pymusiclooper |
| **Decent Sampler** | Format sampler gratuit, XML, si tu veux du multi-vélocité propre | decentsamples.com |

**Règle d'or** : ta palette = un fichier `palette_prime.sfz` versionné, avec ~8–12 instruments
max. La contrainte est le but — c'est ce qui donne l'identité sonore cohérente.

---

## 3. Étape C — Recomposer des morceaux **complets**, palette-only

Trois voies, par ordre de contrôle décroissant / magie croissante.

### C.1 — Voie symbolique : MIDI généré → rendu par TA banque ✅ **recommandée**

Le seul chemin qui **garantit** que seuls tes instruments choisis sonnent, parce que la
génération produit des **notes**, pas de l'audio.

| Projet | Rôle |
|---|---|
| **MIDI-GPT** (Metacreation Lab) | GPT-2 multipiste, **infill à la barre**, génération conditionnée par attributs. Tu figes les pistes = tes instruments |
| **MMM (Multi-Track Music Machine)** | Ancêtre de MIDI-GPT, infill piste/barre, très contrôlable |
| **Anticipatory Music Transformer** (Stanford) | Génération contrôlée par événements/accompagnement |
| **MusPy** | Boîte à outils Python (datasets, I/O, évaluation) pour bricoler ton propre modèle |
| **MidiTok** | Tokenisation MIDI, si tu fine-tunes sur un corpus « style Prime » |

Pipeline complet, 100 % scriptable :
```bash
# 1. génère la structure symbolique (N pistes = N instruments de ta palette)
python generate.py --model midi-gpt --tracks pad,bells,taiko,bass --bars 32 -o track.mid
# 2. rends avec TA banque uniquement
fluidsynth -ni palette_prime.sf2 track.mid -F track.wav -r 48000
# 3. stems séparés : un rendu par piste → base/rhythm/melody/climax
```
→ Ça sort **directement les 4 stems** attendus par `stems_music_manager.gd`. C'est le fit
parfait avec l'architecture MERLIN existante.

### C.2 — Voie neuronale timbre : rejouer n'importe quoi **avec** les instruments Prime

| Projet | Rôle |
|---|---|
| **RAVE** (ACIDS-IRCAM) | Auto-encodeur temps réel. Entraîne-le sur ~2–3 h de matière sonore cohérente → il **re-synthétise** n'importe quelle entrée dans ce timbre |
| **nn~** | External Max/MSP & PureData pour jouer les modèles RAVE en live |
| **DDSP** (Magenta) | Timbre transfer monophonique, ~10–15 min d'audio suffisent |
| **AFTER** (ACIDS-IRCAM) | Transfert timbre/structure plus récent |

C'est la réponse littérale à « recomposer avec les mêmes éléments musicaux » : tu joues une
mélodie celtique, elle ressort avec la texture Prime. Coût : entraînement GPU, et le
résultat est *inspiré de*, pas *identique à*.

### C.3 — Voie générative audio par stems

| Projet | Rôle |
|---|---|
| **MusicGen-Stem** (Meta/IRCAM, ICASSP 2025) | Premier modèle autorégressif **multi-stems** open source (bass / drums / other). Sait **éditer un stem** sur un morceau existant et composer itérativement (générer la basse par-dessus les drums existants) |
| **Stable Audio Open 1.0** | Génératif audio, **fine-tunable sur ton propre corpus de samples** → un modèle qui ne sait produire que ta matière sonore |
| **JASCO** (Meta) | Génération conditionnée accords / drums / mélodie |

Puissant pour l'idéation, mais **pas de garantie palette-only** : c'est de l'audio, pas des
notes. À utiliser en amont (maquette) puis re-faire en C.1.

---

## 4. Étape D — Intégration MERLIN

L'infra est **déjà là** :
- `scripts/audio/stems_music_manager.gd` — 4 stems (`base`/`rhythm`/`melody`/`climax`),
  crossfade 2.5 s, seuils de tension 0.0 / 0.2 / 0.4 / 0.6, `res://audio/music/<biome>/<stem>.ogg`
- `docs/80_sound/30_music/MERLIN_MUSIC_TEMPO_MAP.md` — mapping tempo stable
- `docs/80_sound/30_music/README.md` — Merlin pilote tempo & arrangement (60–140 BPM)

⇒ Le pipeline C.1 produit **exactement** ce format : un rendu FluidSynth par groupe de
pistes, même BPM, même durée, export OGG. Zéro changement de code côté Godot.

Contrainte à respecter : tous les stems d'un biome doivent être **rendus depuis le même
fichier MIDI** pour rester phase-alignés.

---

## 5. ⚠️ Note juridique (importante)

Les samples extraits de Metroid Prime sont la propriété de **Nintendo / Retro Studios**.
Les utiliser tels quels dans un jeu distribué (même gratuit) = contrefaçon, quel que soit
le degré de recomposition. Les outils ci-dessus sont légitimes pour l'**étude** et le
**modding personnel**.

**Chemin propre et recommandé** : utiliser l'extraction MusyX comme **analyse** — tu vois
exactement de quoi est faite la palette (quel type de sample, quelle enveloppe, quel
tuning) — puis **reconstruire** la même palette avec des sources libres/licenciées :

| Besoin | Source libre |
|---|---|
| Nappes / pads atmosphériques | Vital, Surge XT, Dexed (FM — cœur du son Yamamoto) |
| Percussions ethniques / taiko | Freesound (CC0), Spitfire LABS (gratuit) |
| Chœurs, cloches, textures | Sonatina Symphonic Orchestra, VSCO-2 CE (CC0) |
| Design sonore original | Stable Audio Open fine-tuné sur ta propre matière |

La signature Prime est surtout **une méthode** : FM/synthèse pour les pads froids, percussions
tribales sèches en contrepoint, nappes de chœur très réverbérées, arpèges de cloches
métalliques, basses sub lentes. Ça se **remonte** avec des instruments libres.

---

## 6. Implémentation en place — thème de menu

La chaîne décrite plus haut est **déjà appliquée** pour le menu principal, par la voie
« reconstruction légale » du §5 : palette entièrement synthétisée, zéro sample emprunté.

| Élément | Emplacement |
|---|---|
| Extracteur MusyX (ISO → PAK → AGSC → WAV) | `tools/audio/musyx_extract.py` |
| Lecteur d'échantillons (transposition, boucle, enveloppes) | `tools/audio/sample_bank.py` |
| **Lutherie** — 36 modèles d'instruments | `tools/audio/orchestra.py` |
| **Partition** — 32 mesures, conduite des voix, arc dynamique | `tools/audio/score_menu.py` |
| **Orchestration** — répartition pupitres/stems | `tools/audio/arrange_menu.py` |
| Rendu, salle, mastering, attestation | `tools/audio/synth_palette.py` |
| Contrôle d'équilibre du pupitre | `tools/audio/balance_check.py` |
| Thème de menu + 4 stems | `audio/music/menu/{menu_theme,base,rhythm,melody,climax}.ogg` |
| Page de présentation jouable | `tools/audio/build_web_page.py` + `page_template.html` |

### 6.1 — Deux modes de rendu

Le compositeur est **indépendant de la matière sonore**. La composition, les stems, le
timing et le mastering sont identiques dans les deux cas ; seuls les sons changent.

```bash
# mode SYNTHÉTISÉ (défaut) — palette reconstruite, aucun sample externe
python3 tools/audio/synth_palette.py --out audio/music/menu

# mode ÉCHANTILLONNÉ — samples originaux, pour test local
python3 tools/audio/musyx_extract.py iso --input <VOTRE_COPIE.iso> --out extract/
$EDITOR extract/palette_map.json          # choisir quel sample sert à quel rôle
python3 tools/audio/synth_palette.py --bank extract/ --out audio/music/menu

python3 tools/audio/build_web_page.py --out /tmp/palette.html   # page autonome
```

`palette_map.json` est **le fichier de sélection** : il décide quel sample extrait joue
quel rôle. C'est là qu'on ne garde que les fonts voulus. S'il n'existe pas, une
proposition est générée par heuristique (grave + court → taiko, bouclé + long → nappe,
etc.) et écrite sur disque comme point de départ.

### 6.2 — L'extracteur

Trois couches, implémentées d'après la spec du Retro Modding Wiki :

| Couche | Ce qui est lu |
|---|---|
| **GCM / ISO** | FST à `0x424`, entrées de 12 octets, table de chaînes |
| **PAK** | Table de ressources (20 o/entrée), payload zlib préfixé de la taille décompressée |
| **AGSC** | 4 chunks. Ordre `pool/proj/samp/sdir` en MP1, `pool/proj/sdir/samp` en MP2 |
| **SDIR** | Table A (0x20 o) : note de base, fréquence, format, nombre d'échantillons, boucle. Table B (0x28 o) : contexte + 16 coefficients ADPCM |
| **SAMP** | DSP-ADPCM GameCube : trames de 8 octets → 14 échantillons |

**L'outil ne fournit et ne télécharge aucune donnée de jeu.** Il travaille sur la copie
que vous lui donnez.

Comme il n'existe aucun moyen de tester le parseur sans données de jeu, chaque module
porte un autotest qui fabrique des fixtures **au format documenté** et les relit :

```bash
python3 tools/audio/musyx_extract.py selftest   # conteneur AGSC + codec ADPCM
python3 tools/audio/sample_bank.py              # boucle, one-shot, transposition
```

Résultats attendus : aller-retour ADPCM > 20 dB de SNR (obtenu : 52,8), PCM16 bit-exact,
transposition d'octave à un rapport de 2,00, one-shot silencieux après extinction,
nappe bouclée encore sonore à 9 s.

> Ces autotests valident l'implémentation **contre la spec**, pas contre les fichiers de
> Nintendo. Une particularité non documentée d'un groupe audio réel peut encore surprendre :
> au premier passage sur vos données, vérifiez les valeurs du `manifest.json` (fréquences
> plausibles, notes de base entre 20 et 100, durées non nulles) avant de composer.

### 6.3 — Attestation de provenance

Chaque rendu écrit `provenance.json` + `PROVENANCE.md` à côté des fichiers audio. C'est
la pièce qui permet de **certifier** ce qui est réellement entré dans un morceau.

| Champ | Mode synthétisé | Mode échantillonné |
|---|---|---|
| `mode` | `synthesized` | `sampled` |
| `external_samples` | `false` | `true` |
| Fichier source | — | nom, taille, **SHA-256** |
| Par font | — | ID du sample, groupe AGSC, offset SAMP, note de base, fréquence |
| Fichiers produits | SHA-256 de chaque `.ogg` | idem |

Le SHA-256 de la source est ce qui rend l'attestation vérifiable : il identifie
**exactement** la copie du jeu qui a fourni les échantillons. Deux rendus depuis la même
copie portent le même hash ; un rendu depuis une autre copie ne peut pas le falsifier.

`build_web_page.py` lit ce rapport et l'affiche en tête de la page. Une page bâtie sur un
rendu synthétisé porte donc, en toutes lettres, « synthèse — aucune source externe » ;
elle ne peut pas afficher une provenance qu'elle n'a pas.

> Une attestation **absente** est signalée comme telle, jamais rendue comme une
> attestation vide.

**Le morceau** : **Tri Martolod**, air traditionnel breton, arrangement original.
Ré dorien, 76 BPM, 40 mesures, boucle de 126,316 s. **36 pupitres**, 1549 événements.

### 6.1 bis — L'air et sa provenance

*Tri Martolod* (« trois marins ») est une chanson de Basse-Bretagne remontant au
XVIII<sup>e</sup> siècle. Alan Stivell l'a popularisée en 1971 — **son arrangement** lui
appartient, l'air est traditionnel. C'est l'air qui est repris, dans un arrangement écrit
pour ce projet.

Mélodie recoupée entre deux relevés : thesession.org (paroles bretonnes alignées note à
note — « tri / mar-to-lod / yao-uank ») et le *Nine-Note Tunebook* de Jack Campin. Les
deux concordent : la phrase chantée descend par degrés depuis la quinte.

> **Le fait qui a rendu la greffe naturelle** : transposé en ré, Tri Martolod porte un
> **si naturel** (la descente `ré do si la` de sa deuxième mesure). En ré mineur la sixte
> serait si bémol. Ce si signe le **mode dorien** — celui dans lequel la pièce était déjà
> écrite. L'air traditionnel et l'harmonisation froide partagent le même mode.

**Le couple biniou-bombarde** a été ajouté parce qu'il manquait : jouer Tri Martolod sans
lui, c'est jouer une gwerz sans son instrument. La bombarde mène, le biniou répond une
octave au-dessus, le bourdon ne bouge jamais — une cornemuse est à pression constante,
d'où une enveloppe plate là où tous les autres pupitres respirent. Mesures 13 à 16,
l'orchestre se tait entièrement : ils occupent alors 94 % du médium.

**La revisite**, en trois gestes : l'air est joué **lent** (76 BPM là où on le danse vers
120), harmonisé **modalement** plutôt qu'en mineur classique, et posé sur la **nappe FM
froide** et les cloches métalliques de la palette d'origine.

**Plan** : intro (1-4) · air nu au hautbois (5-8) · air doublé (9-12) · refrain
instrumental (13-16) · air harmonisé (17-20) · développement et crescendo (21-28, vers le
**la majeur**, seule note hors mode) · tutti (29-36) · coda (37-40).

Quatre choses le distinguent d'un empilement de nappes :

1. **Conduite des voix** — chaque voix rejoint la note la plus proche de l'accord suivant
   (4 à 5 demi-tons par changement). Une recherche gloutonne naïve sortait un sol majeur
   *sans tierce* : elle abandonnait le si naturel, qui est à la fois la signature dorienne
   et une note de la mélodie traditionnelle.
2. **Vélocité timbrale** — jouer fort n'augmente pas que le volume, ça ouvre le spectre.
3. **Ensemble** — 6 à 8 instrumentistes désaccordés par pupitre, chacun son vibrato et son
   attaque décalée.
4. **Placement sur scène** — panoramique *et* distance : réverbe, aigus mangés, pré-délai.

### 6.2 — L'extracteur

Trois couches, implémentées d'après la spec du Retro Modding Wiki :

| Couche | Ce qui est lu |
|---|---|
| **GCM / ISO** | FST à `0x424`, entrées de 12 octets, table de chaînes |
| **PAK** | Table de ressources (20 o/entrée), payload zlib préfixé de la taille décompressée |
| **AGSC** | 4 chunks. Ordre `pool/proj/samp/sdir` en MP1, `pool/proj/sdir/samp` en MP2 |
| **SDIR** | Table A (0x20 o) : note de base, fréquence, format, nombre d'échantillons, boucle. Table B (0x28 o) : contexte + 16 coefficients ADPCM |
| **SAMP** | DSP-ADPCM GameCube : trames de 8 octets → 14 échantillons |

**L'outil ne fournit et ne télécharge aucune donnée de jeu.** Il travaille sur la copie
que vous lui donnez.

Comme il n'existe aucun moyen de tester le parseur sans données de jeu, chaque module
porte un autotest qui fabrique des fixtures **au format documenté** et les relit :

```bash
python3 tools/audio/musyx_extract.py selftest   # conteneur AGSC + codec ADPCM
python3 tools/audio/sample_bank.py              # boucle, one-shot, transposition
```

Résultats attendus : aller-retour ADPCM > 20 dB de SNR (obtenu : 52,8), PCM16 bit-exact,
transposition d'octave à un rapport de 2,00, one-shot silencieux après extinction,
nappe bouclée encore sonore à 9 s.

> Ces autotests valident l'implémentation **contre la spec**, pas contre les fichiers de
> Nintendo. Une particularité non documentée d'un groupe audio réel peut encore surprendre :
> au premier passage sur vos données, vérifiez les valeurs du `manifest.json` (fréquences
> plausibles, notes de base entre 20 et 100, durées non nulles) avant de composer.

### 6.3 — Attestation de provenance

Chaque rendu écrit `provenance.json` + `PROVENANCE.md` à côté des fichiers audio. C'est
la pièce qui permet de **certifier** ce qui est réellement entré dans un morceau.

| Champ | Mode synthétisé | Mode échantillonné |
|---|---|---|
| `mode` | `synthesized` | `sampled` |
| `external_samples` | `false` | `true` |
| Fichier source | — | nom, taille, **SHA-256** |
| Par font | — | ID du sample, groupe AGSC, offset SAMP, note de base, fréquence |
| Fichiers produits | SHA-256 de chaque `.ogg` | idem |

Le SHA-256 de la source est ce qui rend l'attestation vérifiable : il identifie
**exactement** la copie du jeu qui a fourni les échantillons. Deux rendus depuis la même
copie portent le même hash ; un rendu depuis une autre copie ne peut pas le falsifier.

`build_web_page.py` lit ce rapport et l'affiche en tête de la page. Une page bâtie sur un
rendu synthétisé porte donc, en toutes lettres, « synthèse — aucune source externe » ;
elle ne peut pas afficher une provenance qu'elle n'a pas.

> Une attestation **absente** est signalée comme telle, jamais rendue comme une
> attestation vide.

**Le morceau** : ré dorien, 66 BPM, **32 mesures**, forme A A' B A'', boucle de 116,364 s.
19 instruments, 657 événements de note.

Quatre choses le distinguent d'un empilement de nappes :

1. **Conduite des voix** — chaque voix rejoint la note la plus proche de l'accord suivant
   (4 à 5 demi-tons de mouvement par changement). Une recherche gloutonne naïve sortait un
   sol majeur *sans tierce* : elle prenait le plus proche et abandonnait le si naturel, qui
   est précisément la signature dorienne. L'algorithme énumère donc les affectations
   complètes, avec pénalité forte si la tierce manque.
2. **Vélocité timbrale** — jouer fort n'augmente pas que le volume, ça ouvre le spectre.
   Sans ce lien, les nuances sonnent comme un bouton de volume.
3. **Ensemble** — un pupitre de cordes, c'est 6 à 8 instrumentistes désaccordés, chacun
   avec son vibrato et son attaque décalée. C'est cette décorrélation qui épaissit.
4. **Placement sur scène** — panoramique *et* distance : plus de réverbe, aigus mangés,
   léger pré-délai. C'est la profondeur.

**L'événement dramatique** : mesure 24, un **la majeur**. Son do dièse est la seule note
étrangère au mode de toute la pièce, et il sert de dominante pour ramener le thème.

**Contrôles qualité mesurés** (à re-vérifier après toute modification) :

| Contrôle | Valeur | Seuil |
|---|---|---|
| Crête après encodage Vorbis | 0,563 | < 0,90 — Vorbis dépasse le PCM source de 1 à 2 dB |
| Niveau moyen | −19,2 dB RMS | −18 à −20 dB pour un menu |
| Corrélation L/R | +0,89 | > 0,5 (compatibilité mono) |
| Somme des 4 stems vs mix | −18,6 / −19,0 dB | écart nul |
| Discontinuité au point de boucle | 0,0001 | ≈ 0 |
| Amplitude de l'arc dynamique | 15,1 dB | > 8 dB, sinon la pièce est plate |
| Part du chant dans le médium | 36 % | le thème doit dominer ses accompagnements |
| … au tutti | 41 % | l'air doit rester audible sous 36 pupitres |
| … pendant l'énoncé nu | 84 % | le cor anglais est seul, il doit l'être vraiment |
| … pendant le couple breton | 94 % | l'orchestre se tait pour eux |
| Énergie sous 300 Hz | 34,8 % | 20 à 35 % — au-delà, le médium disparaît |

> **Cinquième piège, et le plus embarrassant** : la table d'équilibre des pupitres
> (`orchestra.GAIN`), mesurée par `balance_check.py`, **n'était jamais appliquée au
> rendu**. Elle existait, elle était juste, et le moteur l'ignorait — tout l'équilibrage
> passait par les vélocités d'arrangement et les gains de stems, qui compensaient à
> l'aveugle. Une fois branchée, le mix a entièrement changé : le spectre s'est ouvert
> (haut-médium de −20 à −15 dB) mais le socle est tombé à 3 % du médium. Il a fallu
> recalculer les gains de stems dans la foulée. Leçon : un outil de mesure qui n'est pas
> câblé sur ce qu'il mesure donne des chiffres justes et un résultat faux.

> **Quatrième piège, propre à l'orchestration d'un air** : au premier rendu de Tri Martolod,
> la flûte ne pesait plus que **1 %** du médium pendant le tutti, contre 95 % pour les
> cuivres et le chœur. Le thème disparaissait exactement là où il devait triompher.
> Correction : deux bois à l'unisson au lieu d'une flûte seule, doublage aux violons
> reclassé dans le stem `melody` (doubler la mélodie, c'est de la mélodie), cuivres et
> chœur atténués. La part du chant au tutti est passée de 1 % à 27 %.

> **Troisième piège, propre à l'orchestration** : au premier rendu orchestral, le stem
> `base` fournissait **87 % du grave et 56 % du médium**, la mélodie 10 %. Le thème était
> enterré sous ses propres accompagnements, et le mix sonnait sourd. Le diagnostic n'a pas
> été fait à l'oreille mais en mesurant la contribution de chaque stem par bande de
> fréquence — c'est la seule façon de trancher sans écouter. Correction : allègement du
> socle (l'octave de basse confiée aux altos plutôt qu'aux violoncelles, coupe de 3,5 dB
> vers 260 Hz) et rééquilibrage des gains de stems.

> **Piège rencontré** : un master calé à 0,89 crête ressortait à **1,44** après encodage
> Vorbis — le décodeur reconstruit des pics inter-échantillons. Il faut viser le RMS et
> garder une vraie marge de crête, pas normaliser au plafond.

> **Second piège** : deux réponses impulsionnelles de bruit indépendantes donnent une
> réverbe très large mais qui **s'annule en mono** (corrélation ≈ 0). D'où `stereo_ir()`,
> qui garde un tronc commun majoritaire.

---

## 7. Recommandation concrète pour MERLIN

**Setup minimal (3 outils), dans cet ordre :**

1. **amuse** + **musyx-extract** — une session d'analyse sur MP1, pour comprendre et
   documenter la palette (→ écrire `PALETTE_PRIME_ANALYSIS.md`)
2. **Polyphone** ou un `.sfz` scripté — construire `palette_merlin.sfz` : 8–12 instruments,
   sources libres, texture Prime + couleur celtique (harpe, tin whistle, bodhrán)
3. **MIDI-GPT → FluidSynth** — génération symbolique multipiste puis rendu 4 stems par
   biome, directement consommables par `stems_music_manager.gd`

Bonus si GPU dispo : **RAVE** entraîné sur ta propre palette → « moteur de timbre MERLIN »
utilisable pour re-colorer n'importe quelle maquette (y compris les sorties Suno actuelles).

---

*Créé 2026-08-04 — recherche outillage musical, projet M.E.R.L.I.N.*
