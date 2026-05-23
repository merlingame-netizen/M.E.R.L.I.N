"""Style-tag system for MERLIN scenarios (LORE_BIBLE v1.0 §8).

33 style tags in 4 families. Each carries a one-sentence ``voice`` prompt
fragment the LLM follows to colour the prose. A scenario draws 1 dominant
tag (deterministically by seed, biome-weighted) ; the voice is injected into
the intro / bridge / outro / per-card generation prompts.

Single source of truth — imported by simulate_human_run_v731.py (runtime
draw) and dedup_and_expand_pool.py (offline enrichment).

Usage :
    from style_tags import pick_style_tag, voice_for, STYLE_TAGS
    tag = pick_style_tag(seed=1234, biome="foret_broceliande")
    voice = voice_for(tag)   # -> "Registre contemplatif : ..."
"""

from __future__ import annotations

import random

# tag_id -> (family, voice instruction)
STYLE_TAGS: dict[str, dict[str, str]] = {
    # --- Narratifs classiques (11) ---
    "folkloric": {"family": "classique", "voice": "Raconte comme un conte populaire transmis au coin du feu : phrases simples, images concrètes, sagesse paysanne."},
    "mythique": {"family": "classique", "voice": "Adopte le registre du mythe fondateur : grandeur, forces primordiales, destin, vocabulaire élevé."},
    "tragique": {"family": "classique", "voice": "Registre tragique : l'inéluctable approche, dignité dans la chute, gravité retenue."},
    "comique": {"family": "classique", "voice": "Touche légère et drôle : ironie douce, situations cocasses, sans casser l'ambiance druidique."},
    "pastoral": {"family": "classique", "voice": "Registre pastoral : nature paisible, lumière, rythme lent, harmonie entre l'être et la forêt."},
    "gothique": {"family": "classique", "voice": "Atmosphère gothique : ombres, ruines, malaise sourd, beauté inquiétante."},
    "onirique": {"family": "classique", "voice": "Logique de rêve : associations libres, images flottantes, frontières floues entre réel et vision."},
    "legendaire": {"family": "classique", "voice": "Ton de la légende ancienne : 'on raconte que...', hauts faits, oralité noble."},
    "mystique": {"family": "classique", "voice": "Registre mystique : seuils, silences, présences invisibles, vérités qui se dérobent."},
    "absurde": {"family": "classique", "voice": "Logique absurde maîtrisée : décalages, non-sens signifiants, humour sec à la Beckett."},
    "contemplative": {"family": "classique", "voice": "Registre contemplatif : peu d'action, attention au détail, intériorité, temps suspendu."},
    # --- Transmission orale celtique (8) ---
    "conte-initiatique": {"family": "orale", "voice": "Structure de conte initiatique : une épreuve, un passage, une transformation."},
    "conte-mise-en-garde": {"family": "orale", "voice": "Conte d'avertissement : montre les conséquences d'une faute, ton de sagesse prudente."},
    "prophetie": {"family": "orale", "voice": "Registre prophétique : annonce voilée, futur entrevu, formules sentencieuses."},
    "lamentation": {"family": "orale", "voice": "Registre de la lamentation : deuil, perte, beauté de ce qui n'est plus, plainte mesurée."},
    "song-of-praise": {"family": "orale", "voice": "Chant de louange : célébration d'un être, d'un lieu ou d'un acte, énumération admirative."},
    "dialogue-avec-esprit": {"family": "orale", "voice": "Dialogue ritualisé avec un esprit : il parle par énigmes, le druide répond avec respect."},
    "geste-de-heros": {"family": "orale", "voice": "Geste héroïque : action noble, courage, exploit raconté avec souffle épique."},
    "devinette": {"family": "orale", "voice": "Forme de la devinette : la rencontre pose une énigme, la réponse est dans le choix."},
    # --- Émotionnels atmosphère-first (9) ---
    "amer-doux": {"family": "emotion", "voice": "Ton doux-amer : la joie et la perte mêlées, un sourire triste."},
    "vertigineux": {"family": "emotion", "voice": "Sensation de vertige : l'immense, l'abîme, le sublime qui dépasse."},
    "paisible-tendu": {"family": "emotion", "voice": "Calme habité d'une tension sourde : la surface est sereine, le dessous frémit."},
    "ironique": {"family": "emotion", "voice": "Ironie fine : double sens, distance amusée, l'esprit qui observe."},
    "sublime": {"family": "emotion", "voice": "Registre du sublime : grandeur qui écrase et élève, beauté terrible."},
    "sourd": {"family": "emotion", "voice": "Ton sourd, étouffé : peu de couleurs, voix basse, ce qui n'est pas dit."},
    "brillant": {"family": "emotion", "voice": "Ton brillant : clarté, éclat, énergie, lumière franche."},
    "glace": {"family": "emotion", "voice": "Froideur : distance, gel émotionnel, beauté cristalline et coupante."},
    "chaleureux": {"family": "emotion", "voice": "Chaleur humaine : tendresse, accueil, lien, réconfort."},
    # --- Méta / fourth-wall (5) ---
    "meta-leger": {"family": "meta", "voice": "Le druide a un bref instant de conscience de quelque chose 'd'ailleurs', un regard qui dépasse la scène, sans rompre l'illusion."},
    "meta-cache": {"family": "meta", "voice": "Glisse un clin d'œil discret (formule à double sens) destiné à celui qui marche, jamais explicite."},
    "simulation-transparente": {"family": "meta", "voice": "Laisse transparaître subtilement la nature construite de la scène : un détail trop parfait, une répétition signifiante."},
    "echo-archetypal": {"family": "meta", "voice": "La scène nomme doucement le motif qu'elle incarne, comme consciente d'être un archétype."},
    "memoire-meta": {"family": "meta", "voice": "Évoque l'écho d'une marche passée, un déjà-vu que le druide ne s'explique pas."},
}

# Per-biome affinity (LORE_BIBLE §5). The picker draws 70% from the biome's
# preferred list, 30% from the full 33-tag pool for variety.
BIOME_STYLE_AFFINITY: dict[str, list[str]] = {
    "foret_broceliande": ["contemplative", "folkloric", "amer-doux", "conte-initiatique", "mystique", "memoire-meta"],
    "cercle_pierres": ["legendaire", "prophetie", "mythique", "song-of-praise", "geste-de-heros"],
    "lac_avalon": ["mystique", "sublime", "conte-initiatique", "onirique", "vertigineux"],
    "souterrain_korrigan": ["comique", "absurde", "ironique", "devinette", "meta-cache"],
    "annwn": ["tragique", "lamentation", "gothique", "sourd", "conte-mise-en-garde"],
    "tourbiere": ["onirique", "sourd", "glace", "memoire-meta", "simulation-transparente"],
    "tir_na_nog": ["brillant", "sublime", "chaleureux", "mystique", "song-of-praise"],
    "cime_tilleul": ["mystique", "vertigineux", "prophetie", "simulation-transparente", "echo-archetypal"],
}

_ALL_TAGS: list[str] = list(STYLE_TAGS.keys())


def voice_for(tag_id: str) -> str:
    """Return the LLM voice instruction for a style tag (or '' if unknown)."""
    entry = STYLE_TAGS.get(tag_id)
    return entry["voice"] if entry else ""


def family_of(tag_id: str) -> str:
    entry = STYLE_TAGS.get(tag_id)
    return entry["family"] if entry else ""


def pick_style_tag(seed: int, biome: str = "foret_broceliande") -> str:
    """Deterministically pick a style tag for a run.

    70% chance to draw from the biome's affinity list, 30% from the full
    33-tag pool for variety. Deterministic on (seed, biome) so re-running
    the same seed yields the same style.
    """
    rng = random.Random(f"style::{seed}::{biome}")
    affinity = BIOME_STYLE_AFFINITY.get(biome, [])
    if affinity and rng.random() < 0.7:
        return rng.choice(affinity)
    return rng.choice(_ALL_TAGS)


def style_prompt_fragment(tag_id: str) -> str:
    """A ready-to-inject system-prompt fragment for the given tag."""
    voice = voice_for(tag_id)
    if not voice:
        return ""
    return f"\n\nSTYLE NARRATIF imposé pour cette marche [{tag_id}] : {voice}"
