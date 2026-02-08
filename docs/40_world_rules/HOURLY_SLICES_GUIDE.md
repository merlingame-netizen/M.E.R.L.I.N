# Hourly Slices Guide (24h Model)

Purpose
- Define the 24 time slices used by the game.
- Provide transition rules when the hour changes mid-event.
- Provide a JSON structure reference (aligned with hourly_facts.json).

24 slices table (source: hourly_facts.json)
| hour | label             | tags                 | focus (dominant boosts) |
| ---- | ----------------- | -------------------- | ----------------------- |
| 00   | minuit            | nuit, ombre          | spirit, mystery         |
| 01   | profonde_nuit     | nuit, silence        | spirit, mystery         |
| 02   | veillee_tardive   | nuit, veillee        | spirit, mystery         |
| 03   | silence_noir      | nuit                 | spirit, mystery         |
| 04   | pre_aube          | nuit, brume          | spirit, mystery         |
| 05   | aube_pale         | aube                 | ritual, fauna           |
| 06   | aube              | aube, source         | ritual, fauna, resource |
| 07   | matin             | jour, marche         | fauna, craft            |
| 08   | matin_clair       | jour                 | craft, resource         |
| 09   | jour              | jour                 | craft, resource         |
| 10   | jour_haut         | jour                 | craft, resource         |
| 11   | approche_midi     | jour                 | craft, resource         |
| 12   | midi              | jour, plein_lumiere  | resource, craft         |
| 13   | apres_midi        | jour                 | craft, resource         |
| 14   | apres_midi_long   | jour                 | craft                   |
| 15   | fin_jour          | jour                 | fauna, mystery          |
| 16   | pre_crepuscule    | crepuscule           | fauna, mystery          |
| 17   | crepuscule        | crepuscule, ritual   | ritual, mystery         |
| 18   | crepuscule_chaud  | crepuscule, ritual   | ritual, spirit, mystery |
| 19   | tombee_nuit       | nuit, ritual         | spirit, mystery         |
| 20   | nuit              | nuit, ombre          | spirit, mystery         |
| 21   | nuit_froide       | nuit                 | spirit, mystery         |
| 22   | nuit_noire        | nuit, ombre          | spirit, mystery         |
| 23   | veillee           | nuit, veillee        | spirit, mystery         |

Transition rules (hour change)
- Hour changes can happen at any time. The system must be stable.
- If an hour changes during a node:
  - Freeze the starting hour for that node.
  - Apply the new hour after the node resolves.
- If an hour changes during combat:
  - Freeze the starting hour for the combat.
  - Apply the new hour after combat ends.
- If an hour changes in hub or camp:
  - Apply immediately (bonuses, alignments, music).
- If the hour changes during a choice prompt:
  - Keep the old hour until the choice is resolved.
  - Show a short Merlin line after resolution to mark the shift.

Merlin hour-change remark (active pause)
- On hour change, trigger an "active pause":
  - Screen darkens (not full black), gameplay freezes.
  - Merlin delivers a short LLM line (one line).
  - Resume immediately after the line.
- The line must blend:
  - what just happened (last node outcome),
  - the hour transition,
  - a mystical implication for what may follow.
- Remark length: 6-14 words, no exposition.
- Tone follows current merlin_mood + hour tags (nuit, crepuscule, aube).
- Do not repeat the same remark within 3 hour changes.
- Audio: music tempo dips while the screen darkens, then returns after resume.

LLM prompt (hour-change remark)
SYSTEM
You are Merlin. Speak in French. One line only, 6-14 words. Mystical tone, subtle.
Blend: (1) what just happened, (2) the hour change, (3) a hint of what it implies.
Do not reveal the simulation or meta systems. No lists, no questions.

INPUT VARIABLES
- last_event_summary: short sentence of the last node outcome.
- hour_label: current hour label (from hourly_facts.json).
- hour_tags: list of tags (nuit, crepuscule, aube, etc).
- merlin_mood: calm|wary|stern|amused|wounded|wrath

OUTPUT FORMAT
- Single line of text, no quotes.

EXAMPLE INPUT
last_event_summary: "La bestiole a repousse l'essaim, mais perdue d'energie."
hour_label: "crepuscule"
hour_tags: ["crepuscule", "ritual"]
merlin_mood: "wary"

EXAMPLE OUTPUT
Le crepuscule boit la fatigue, et les ombres repondent.

JSON structure (aligned with hourly_facts.json)
{
  "notes": "Hours never block spawns; multipliers only increase or decrease chance.",
  "hourly_facts": [
    {
      "hour": 17,
      "label": "crepuscule",
      "tags": ["crepuscule", "ritual"],
      "boosts": { "global": 1.10, "ritual": 1.20, "mystery": 1.15 }
    }
  ]
}

Rules reminder
- Hours never block spawns; they only modify probabilities.
- The current hour slice is the only active bonus set.
