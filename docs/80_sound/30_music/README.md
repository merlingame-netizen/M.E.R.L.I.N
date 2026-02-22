# Music (Dynamic, Merlin-Driven)

Purpose
- All music is governed by the supercomputer (Merlin).
- The system can accelerate, decelerate, or cut music based on mood, story state, and world conditions.

Core rules
- Merlin controls tempo and arrangement; the player never directly selects tracks.
- Tempo can accelerate or slow down smoothly with mood changes.
- Hard cut is allowed only on major events (oaths broken, revelations, critical failures).
- Transitions must be seamless (no gaps, no audible jumps).

State inputs (examples)
- merlin_mood: calm, wary, stern, amused, wounded, wrath
- trust_level: low/medium/high
- world_tension: low/medium/high
- time_of_day: dawn/day/dusk/night
- event_flags: oath_broken, oath_kept, anomaly, seasonal_event

Music behavior mapping (guidelines)
- calm: slow tempo, sparse arrangement, soft timbres.
- wary: moderate tempo, added pulse, subtle dissonance.
- stern: firm rhythm, mid-tempo, reduced melodic movement.
- amused: light rhythm, playful ornaments.
- wounded: low tempo, dark palette, minimal dynamics.
- wrath: fast tempo, percussive emphasis, higher intensity.

Tempo control
- Target tempo is derived from merlin_mood + world_tension.
- Allowed tempo range: 60-140 BPM (avoid extremes).
- Tempo changes ramp over 4-12 seconds unless hard cut is triggered.

Cuts and silences
- When Merlin cuts the music, keep a short (0.2-0.5s) tail fade.
- Silence can be used as tension but should not exceed 10 seconds unless scripted.

Implementation notes
- Music is layered: base + pulse + accent + danger layers.
- Layer activation is driven by merlin_mood and world_tension.
- One music bus controlled by Merlin; all other audio ducks under it when needed.

---

## Music Loop Workflow (PyMusicLooper)

### Outil
- **PyMusicLooper** v3.6.0 (Python, open source)
- Installation: `pip install pymusiclooper`
- Algorithme: analyse spectrale automatique des waveforms pour detecter les meilleurs points de loop seamless

### Structure du dossier `music/`
```
music/
  base/       <- Fichiers originaux (MP3/OGG/WAV source)
  loop/       <- Fichiers decoupes par PyMusicLooper
                 *-intro.wav   (debut avant le loop)
                 *-loop.wav    (section qui boucle)
                 *-outro.wav   (fin apres le loop)
```

### Workflow de creation d'un loop

1. **Analyser** le fichier audio et lister les loop points :
   ```bash
   pymusiclooper export-points --path music/base/fichier.mp3 --alt-export-top 5 --fmt time
   ```
   Sortie: `loop_start loop_end score1 score2 score_global` (score > 0.9 = excellent)

2. **Preecouter** en temps reel avec choix interactif :
   ```bash
   pymusiclooper play --path music/base/fichier.mp3 -i
   ```
   Naviguer entre les loop points, Ctrl+C pour arreter.

3. **Exporter** en intro/loop/outro :
   ```bash
   pymusiclooper split-audio --path music/base/fichier.mp3 -o music/loop/
   ```

4. **Importer dans Godot** :
   - Le fichier `*-loop.wav` : Import > Loop Mode = Forward (loop sans pop)
   - Le fichier `*-intro.wav` : joue une seule fois avant le loop
   - Alternative : garder l'OGG original et configurer Loop Offset via `export-points --fmt seconds`

### Options avancees
- `--brute-force` : analyse exhaustive (lent mais plus precis sur des morceaux complexes)
- `--min-loop-duration 30` : forcer une duree minimale de loop en secondes
- `--approx-loop-position 35 145` : cibler une zone de loop specifique
- `pymusiclooper extend --path fichier.mp3 -o extended.wav --minutes 5` : creer une version etendue

### Import Godot 4 — rappels
- **WAV** : supporte Loop Begin + Loop End + modes Forward/Ping-Pong/Backward
- **OGG/MP3** : Loop Offset uniquement (debut du loop, fin = fin du fichier)
- **Bouton "Advanced..."** dans l'inspecteur d'import pour visualiser la waveform
