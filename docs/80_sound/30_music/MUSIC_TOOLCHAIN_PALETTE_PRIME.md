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
| Synthétiseur de palette (6 fonts) | `tools/audio/synth_palette.py` |
| Thème de menu + 4 stems | `audio/music/menu/{menu_theme,base,rhythm,melody,climax}.ogg` |
| Page de présentation jouable | `tools/audio/build_web_page.py` + `page_template.html` |

```bash
python3 tools/audio/synth_palette.py --out audio/music/menu     # rend le morceau
python3 tools/audio/build_web_page.py --out /tmp/palette.html   # page autonome
```

**Le morceau** : ré dorien, 66 BPM, 16 mesures, boucle de 58,182 s.
Progression `Dm · C · Dm · G · Dm · C · Bb · Am` — le sol majeur porte un si naturel
(signature dorienne), le si bémol de la mesure 13 est un emprunt éolien qui ouvre juste
avant la retombée.

**Contrôles qualité mesurés** (à re-vérifier après toute modification) :

| Contrôle | Valeur | Seuil |
|---|---|---|
| Crête après encodage Vorbis | 0,472 | < 0,90 — Vorbis dépasse le PCM source de 1 à 2 dB |
| Niveau moyen | −19,0 dB RMS | −18 à −20 dB pour un menu |
| Corrélation L/R | +0,79 | > 0,5 (compatibilité mono) |
| Somme des 4 stems vs mix | −18,9 / −19,0 dB | écart nul |
| Discontinuité au point de boucle | 0,0037 | ≈ 0 |

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
