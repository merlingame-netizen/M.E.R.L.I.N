# SUNO Prompts Guide - DRU Project

## Table of Contents
1. [Best Practices Summary](#best-practices-summary)
2. [Prompt Engineering Fundamentals](#prompt-engineering-fundamentals)
3. [Common Mistakes to Avoid](#common-mistakes-to-avoid)
4. [SUNO Versions (v4.5 vs v5)](#suno-versions)
5. [DRU-Specific Prompts](#dru-specific-prompts)
6. [Sources & References](#sources)

---

## Best Practices Summary

### The Golden Rules

| Rule | Description |
|------|-------------|
| **4-7 descriptors** | Sweet spot. Fewer = generic, more = confused |
| **Describe, don't command** | "Slow Celtic ambient" not "Make a slow Celtic song" |
| **3-6 instruments max** | Over-instrumenting blurs the arrangement |
| **Generate 6+ takes** | It often takes many iterations to find the vibe |
| **Off-peak hours** | 3:00 AM - 4:30 AM yields higher quality (community finding) |

### Effective Prompt Formula

```
[Genre] + [Mood] + [Tempo/BPM] + [Instruments] + [Texture/Mix] + [Special Tags]
```

**Example:**
```
Celtic folk ambient, mystical, 70 BPM, tin whistle, harp, warm analog pads, ethereal, seamless loop
```

---

## Prompt Engineering Fundamentals

### Prompt Components

#### 1. Genre & Style
- Be specific: "Celtic folk" > "folk"
- Combine wisely: max 2-3 genres
- Use regional tags: "Irish traditional", "Scottish folk", "Breton"

#### 2. Mood & Emotion
Essential mood words for DRU:
- `mystical`, `ethereal`, `haunting`, `ancient`
- `melancholic`, `nostalgic`, `contemplative`
- `serene`, `peaceful`, `calming`
- `ominous`, `foreboding`, `mysterious`

#### 3. Tempo & Rhythm
- **Slow atmospheric**: 50-70 BPM
- **Meditative**: 60-80 BPM
- **Calm folk**: 80-100 BPM
- Use descriptive terms: "very slow", "breathing tempo", "unhurried"

#### 4. Instrumentation (Celtic Palette)
Primary:
- `tin whistle`, `low whistle`, `Irish flute`
- `Celtic harp`, `wire-strung harp`
- `fiddle`, `violin`
- `bodhrán` (drum)
- `uilleann pipes`

Atmospheric additions:
- `warm analog pads`, `ambient drones`
- `soft strings`, `ethereal choir`
- `nature sounds`, `wind`, `rain`

#### 5. Texture & Mix Tags
- `warm`, `airy`, `icy`, `granular`, `shimmering`
- `lo-fi`, `vintage`, `analog warmth`
- `wide mix`, `intimate`, `spacious`
- `no reverb tails` (for loops)

### Metatags for Structure

Use these in the lyrics field for Custom Mode:

| Tag | Purpose |
|-----|---------|
| `[Intro]` | Opening section (sometimes unreliable) |
| `[Verse]` | Main melodic section |
| `[Chorus]` | Hook/recurring theme |
| `[Bridge]` | Contrasting transition |
| `[Break]` | Pause in rhythm |
| `[Interlude]` | Transition passage |
| `[Outro]` | Ending section |

**Tip:** For instrumentals, use section tags without lyrics.

### Instrumental-Only Tags

To ensure no vocals:
- Enable **Instrumental Mode** in SUNO
- Add: `instrumental only`, `no vocals`, `no voice`
- For v5: Negative prompting works reliably

---

## Common Mistakes to Avoid

### 1. Vague Descriptions
**Bad:** "Make some nice background music"
**Good:** "Celtic ambient, mystical, 65 BPM, tin whistle, harp, warm pads, ethereal"

### 2. Descriptor Overload (10+)
**Bad:** "Celtic folk mystical ancient haunting melancholic nostalgic contemplative serene peaceful ambient atmospheric dreamy slow meditative"
**Good:** "Celtic folk, mystical, melancholic, slow, ambient"

### 3. Contradictory Terms
**Bad:** "Slow and high-energy Celtic dance"
**Good:** "Slow Celtic ballad with building intensity"

### 4. Too Many Genres
**Bad:** "Celtic + EDM + jazz + classical + rock"
**Good:** "Celtic ambient with subtle electronic textures"

### 5. Artist Name References
**Bad:** "Make it sound like Enya"
**Good:** "Ethereal Celtic new age, female vocal layers, reverb-heavy"

### 6. Over-Instrumenting
**Bad:** "Harp, fiddle, flute, pipes, guitar, mandolin, bodhrán, piano, strings, choir, synth pads"
**Good:** "Harp, tin whistle, soft strings, ambient pads"

### 7. Expecting Perfection First Try
- Generate 6+ variations
- Cherry-pick best elements
- Use Extend/Remix features

---

## SUNO Versions

### v4.5 (July 2025)
- Track length up to 8 minutes
- Better vocal performance
- Add Vocals / Add Instrumental features
- Improved Covers/Personas

### v5 (September 2025)
- **Higher fidelity**: Clearer instrument separation
- **Better vocals**: More natural pronunciation
- **Reliable negative prompting**: Exclusions work consistently
- **Hybrid Diffusion Transformer**: Better long-range coherence
- **Recurring motifs**: Can maintain themes across 5+ minutes

### Recommendation for DRU
Use **v5** for final production tracks. Key advantages:
- Better instrument separation (critical for Celtic instruments)
- Seamless loops more reliable
- Consistent no-vocal execution

---

## DRU-Specific Prompts

### Style Direction
DRU requires: **Retro video game + Celtic covers + Atmospheric ambient**

Core concept: Celtic traditional melodies reimagined as slow, atmospheric, 8-bit inspired game music.

---

### Main Theme Variants

#### 1. Menu / Title Screen
```
Celtic chiptune ambient, mystical, 65 BPM, 8-bit harp arpeggios,
pulse wave tin whistle, warm analog pads, lo-fi, nostalgic,
retro video game, seamless loop, no vocals
```

#### 2. Exploration (Low Tension)
```
Celtic folk ambient, serene, 70 BPM, soft harp, gentle fiddle,
nature ambience, warm pads, airy, contemplative, forest atmosphere,
video game soundtrack, seamless loop, instrumental
```

#### 3. Exploration (Medium Tension)
```
Celtic ambient, mysterious, 75 BPM, low whistle, modal harp,
subtle drone, foreboding undertones, misty, ancient,
retro game music, seamless loop, no vocals
```

#### 4. Danger / High Tension
```
Dark Celtic ambient, ominous, 96 BPM, minor key fiddle,
deep bodhrán pulse, eerie drone, tense atmosphere,
haunting whistle, video game boss, seamless loop, instrumental
```

#### 4.5. Combat Scene
```
Celtic battle ambient, urgent, 100 BPM, driving bodhrán,
intense fiddle, war pipes hint, primal energy, stakes raised,
video game combat, seamless loop, no vocals
```

#### 4.6. Taniere / Den (Hub Scene)
```
Celtic intimate ambient, cozy, 60 BPM, soft harp, crackling warmth,
cave reverb, safe haven, gentle breathing space,
companion comfort, seamless loop, no drums, instrumental
```

#### 5. Season: Samhain (Winter/Death)
```
Celtic dark ambient, haunting, 55 BPM, ghostly tin whistle,
sparse harp, wind sounds, chilling atmosphere,
spectral choir whispers, ancient ritual, seamless loop, no vocals
```

#### 6. Season: Imbolc (Spring/Rebirth)
```
Celtic pastoral ambient, hopeful, 75 BPM, bright harp,
cheerful tin whistle, birdsong ambience, warm morning light feel,
gentle fiddle, renewal theme, seamless loop, instrumental
```

#### 7. Season: Beltane (Summer/Fire)
```
Celtic festive ambient, mystical, 85 BPM, lively fiddle,
dancing harp, subtle bodhrán, warm golden atmosphere,
celebration energy but calm, seamless loop, no vocals
```

#### 8. Season: Lughnasadh (Autumn/Harvest)
```
Celtic melancholic ambient, nostalgic, 65 BPM, wistful fiddle,
falling leaves atmosphere, warm but fading light, bittersweet harp,
harvest moon feeling, seamless loop, instrumental
```

---

### Special Moments

#### Merlin's Wisdom (Narrative Pause)
```
Celtic mystical ambient, sage-like, 50 BPM, ancient harp,
ethereal drone, wisdom atmosphere, old magic feeling,
deep contemplation, spacious reverb, no drums, instrumental
```

#### Card Decision (Tension Build)
```
Celtic suspense ambient, anticipation, 60 BPM, held note drone,
sparse harp plucks, time suspended feeling, choice moment,
fate hangs in balance, minimal, atmospheric, no vocals
```

#### Game Over (Tragic Ending)
```
Celtic lament ambient, sorrowful, 45 BPM, mournful fiddle,
weeping harp, fading life theme, ancient grief,
elegiac, fade to silence ending, instrumental
```

#### Victory / Good Ending
```
Celtic triumphant ambient, bittersweet hope, 70 BPM,
soaring fiddle, bright harp resolution, dawn breaking feel,
earned peace, warm resolution, gentle fade, no vocals
```

#### Bestiole Bond Theme
```
Celtic whimsical ambient, playful, 80 BPM, light tin whistle,
dancing harp, sprite-like magic, companion affection,
warm friendship, gentle 8-bit textures, seamless loop, no vocals
```

---

### Ogham Activation Stingers

Short 2-4 second cues for skill activation. Generate with shorter duration settings.

#### REVEAL Skills (beith, coll, ailm)
```
Celtic revelation stinger, bright, 90 BPM, ascending harp arpeggio,
clarity chime, veil lifting, sudden insight, 3 seconds, instrumental
```

#### PROTECTION Skills (luis, gort, eadhadh)
```
Celtic barrier stinger, sturdy, 80 BPM, deep harp chord,
protective drone, shield forming, grounded, 2 seconds, instrumental
```

#### BOOST Skills (duir, tinne, onn)
```
Celtic power stinger, triumphant, 100 BPM, ascending whistle,
rising energy, strength surge, heroic, 2 seconds, instrumental
```

#### NARRATIVE Skills (nuin, huath, straif)
```
Celtic mystery stinger, otherworldly, 70 BPM, swirling harp,
reality bending, fate threads, enigmatic, 3 seconds, instrumental
```

#### RECOVERY Skills (quert, ruis, saille)
```
Celtic restoration stinger, soothing, 65 BPM, gentle harp waves,
healing warmth, energy return, comfort, 3 seconds, instrumental
```

#### SPECIAL Skills (muin, ioho, ur)
```
Celtic ancient magic stinger, profound, 60 BPM, deep drone rising,
primordial power, old ways awakening, momentous, 4 seconds, instrumental
```

---

### Retro/Chiptune Hybrid Variations

For more pronounced retro game feel:

#### NES-Style Celtic
```
Chiptune Celtic fusion, retro, 70 BPM, 8-bit lead melody,
pulse wave harp simulation, square wave whistle,
NES-style, mono output, no reverb, vintage game feel, seamless loop
```

#### Lo-Fi Celtic Ambient
```
Lo-fi Celtic ambient, dreamy, 65 BPM, warm vinyl crackle,
soft harp, muffled tin whistle, cozy atmosphere,
tape saturation, vintage warmth, bedroom producer aesthetic,
seamless loop, instrumental
```

#### Synthwave Celtic

> **WARNING**: This variant uses electronic elements that contradict DRU's
> core medieval aesthetic. Use only for experimental purposes, not production.

```
Synthwave Celtic fusion, ethereal, 75 BPM, analog synth pads,
retro arpeggios, Celtic harp samples, neon mysticism,
80s nostalgia meets ancient magic, seamless loop, no vocals
```

---

### Technical Tags Reference

#### Loop-Specific
- `seamless loop` - Creates loopable tracks
- `no fade in/out` - Clean loop points
- `no reverb tails` - Prevents bleed at loop points
- `consistent energy` - Stable throughout

#### Video Game Specific
- `video game soundtrack`
- `background music`
- `gameplay ambience`
- `menu music`
- `exploration theme`

#### Atmosphere
- `wide mix` / `intimate mix`
- `spacious reverb` / `tight room`
- `warm analog` / `cold digital`
- `natural ambience` / `studio clean`

---

## Sources

### Core Documentation
- [Complete List of Prompts & Styles for Suno AI Music (2026)](https://travisnicholson.medium.com/complete-list-of-prompts-styles-for-suno-ai-music-2024-33ecee85f180)
- [How To Write Suno AI Prompts (With Examples)](https://travisnicholson.medium.com/how-to-write-suno-ai-prompts-with-examples-46700d2c3003)
- [Suno AI Music Prompt Guide: Complete Tutorial](https://howtopromptsuno.com/a-complete-guide-to-prompting-suno)
- [How to Write Effective Prompts for Suno Music (2026)](https://www.soundverse.ai/blog/article/how-to-write-effective-prompts-for-suno-music-1128)

### Advanced Techniques
- [Suno AI Meta Tags & Song Structure Command Guide](https://jackrighteous.com/en-us/pages/suno-ai-meta-tags-guide)
- [World-Inspired Ambient Suno V5 Prompt Guide](https://jackrighteous.com/en-us/blogs/guides-using-suno-ai-music-creation/world-inspired-ambient-instrumental-prompts-suno-v5)
- [Suno v5 vs v4.5: Full Feature & Audio Upgrade Guide](https://jackrighteous.com/en-us/blogs/guides-using-suno-ai-music-creation/suno-v5-vs-v4-5-upgrade-guide)
- [7 Beginner Mistakes to Avoid with Suno AI](https://jackrighteous.com/en-us/blogs/guides-using-suno-ai-music-creation/beginner-mistakes-with-suno-ai)

### Celtic & Folk Specific
- [Suno Prompts for Folk Music (HookGenius)](https://hookgenius.app/learn/suno-folk-prompts/)
- [Folk Music for AI Creation: Ultimate Guide & 235+ Genre Prompts](https://sunoprompt.com/music-style-genre/folk-music-genre)

### Chiptune & Retro
- [Ultimate Guide - Best AI 8-Bit Music Generator 2025](https://www.wondera.ai/tools/en/the-best-ai-8-bit-music-generator)
- [8-Bit Head Chiptune Playlist (Suno)](https://suno.com/playlist/5156a8a0-2a8f-44d3-83fe-117242905b4d)

### Tools
- [Suno Prompt Generator](https://howtopromptsuno.com/)
- [Suno Meta Tags Creator](https://sunometatagcreator.com/metatags-guide)
- [Suno AI Prompt Generator](https://sunoprompt.com/)

---

*Document created: 2026-02-08*
*For DRU: Le Jeu des Oghams*
