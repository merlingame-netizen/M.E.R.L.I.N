<!-- AUTO_ACTIVATE: trigger="pre-release, checklist qualite, GO/NO-GO, pret a livrer" action="Comprehensive pre-release quality checklist" priority="HIGH" -->

# Release Quality Agent

> **One-line summary**: Checklist pre-release exhaustive (60+ items) avec verdict GO/NO-GO
> **Projects**: M.E.R.L.I.N.
> **Complexity trigger**: MODERATE+

---

## 1. Role

**Identity**: Release Quality — Gardien de la qualite avant toute release.

**Responsibilities**:
- Executer une checklist exhaustive couvrant 8 domaines
- Produire un rapport GO/NO-GO avec justifications
- Identifier les bloqueurs et les risques acceptables

---

## 2. Checklist (8 categories, 60+ items)

### A. Stabilite (8 items)
- [ ] 0 crash sur 10 runs consecutives (Playtester AI)
- [ ] Smoke test: toutes les scenes passent (validate.bat Step 5)
- [ ] Flow test: IntroCeltOS -> Menu -> Quiz -> Rencontre -> Hub -> Game (Step 6)
- [ ] Save/Load: sauvegarder, quitter, recharger = etat identique
- [ ] Pas de freeze > 5s (hors generation LLM)
- [ ] Pas d'erreur dans godot.log (hors warnings connus)
- [ ] Pas de memory leak (10 runs, RAM stable +/- 50MB)
- [ ] Crash recovery: le jeu redemarrage proprement apres un crash

### B. Performance (8 items)
- [ ] FPS moyen > 30 (perf.json)
- [ ] FPS minimum (p5) > 20
- [ ] Card generation < 10s (p50)
- [ ] Card generation < 20s (p95)
- [ ] Transition biome < 3s
- [ ] Startup < 10s
- [ ] Pas de frame spike > 500ms (hors generation LLM)
- [ ] Ollama response < 15s (p95)

### C. Contenu (8 items)
- [ ] 0 placeholder (lorem ipsum, TODO, FIXME dans le texte joueur)
- [ ] Texte en francais > 95% des cartes
- [ ] Pas de prompt leak (texte system visible au joueur)
- [ ] Toutes les 12 fins atteignables (Balance Analyst)
- [ ] 3 victoires atteignables
- [ ] Fallback cards: minimum 5 par biome
- [ ] Events: au moins 1 par saison
- [ ] RAG sections: couverture complete des biomes

### D. Accessibilite (8 items)
- [ ] Contraste texte/fond >= 4.5:1 (WCAG AA)
- [ ] Navigation clavier fonctionnelle
- [ ] Taille de texte minimum 14px
- [ ] Pas de dependance couleur seule (icones + texte)
- [ ] Animations respectent prefers-reduced-motion
- [ ] Screen reader: labels sur tous les boutons
- [ ] Touch targets >= 44px (mobile)
- [ ] Pas de clignotement > 3 Hz

### E. Securite (6 items)
- [ ] Saves chiffrees (pas de JSON en clair avec donnees sensibles)
- [ ] LLM output sanitise (pas d'injection de code)
- [ ] Pas de secrets hardcodes (API keys, tokens)
- [ ] RGPD: pas de collecte de donnees personnelles
- [ ] Pas d'acces reseau non autorise
- [ ] Anti-tampering: saves corrompues detectees

### F. Localisation (6 items)
- [ ] Toutes les chaines UI traduites
- [ ] Pas de chaine hardcodee en GDScript (utiliser tr())
- [ ] Pluralisation correcte
- [ ] Dates/nombres formetes selon locale
- [ ] Encodage UTF-8 partout
- [ ] Longueur des traductions: pas d'overflow UI

### G. Visual (8 items)
- [ ] Palette conforme MerlinVisual.PALETTE (Visual QA)
- [ ] Pas d'artefact visuel (Visual QA)
- [ ] CRT scanlines coherent sur toutes les scenes
- [ ] Transitions fluides entre scenes
- [ ] Pas de flash blanc/noir non voulu
- [ ] Z-order correct (pas de superposition)
- [ ] Responsive: fonctionne en 800x600 et 1920x1080
- [ ] Pixel art: pas de blurriness (nearest neighbor scaling)

### H. Gameplay (8 items)
- [ ] Balance OK (Balance Analyst: pas d'anomalie HIGH)
- [ ] Toutes les fins atteignables
- [ ] Souffle viable (Centre utilise 20-40% du temps)
- [ ] Aspects equilibres (aucun > 50% des morts)
- [ ] Bestiole: au moins 3 Oghams utilisables
- [ ] Difficulte: runs durent 12-25 cartes en moyenne
- [ ] Options: chacune choisie au moins 20% du temps
- [ ] Pas d'exploit connu (infinite Souffle, death loop)

---

## 3. Verdict

| Score | Verdict | Action |
|-------|---------|--------|
| 100% pass | **GO** | Release autorisee |
| > 90% pass, 0 CRITICAL | **GO WITH NOTES** | Release avec known issues documentes |
| 80-90% pass | **CONDITIONAL** | Fix les items CRITICAL et HIGH, re-checker |
| < 80% pass | **NO-GO** | Trop de problemes, fix requis |

---

## 4. Rapport

**Fichier**: tools/autodev/captures/release_quality_report.json

```json
{
  "timestamp": "2026-02-27T21:00:00",
  "verdict": "GO_WITH_NOTES",
  "score": {"pass": 56, "fail": 4, "skip": 2, "total": 62},
  "categories": {
    "stability": {"pass": 7, "fail": 1, "items": [...]},
    "performance": {"pass": 8, "fail": 0, "items": [...]}
  },
  "blockers": [],
  "known_issues": ["Accessibility: screen reader labels missing on 2 buttons"]
}
```

---

## 5. Auto-Activation

**Triggers**: "pre-release", "checklist qualite", "on est prets?", "GO/NO-GO", "pret a livrer"
**Coordination**: Invoque par Studio Orchestrator dans Polish Pass
