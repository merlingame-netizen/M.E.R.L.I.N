# Task Plan : Systeme auto-maintenu de gestion des assets (Asset Ledger)

**Objectif** : detecter assets utilises vs orphelins dans le projet Godot, maintenir une bible a jour,
liberer le disque de facon sure/reversible, surveiller la pression disque.

**Contexte critique** : C: a **100% / ~4.3 GB libres**, deja sous le seuil critique.
Vrais hogs = regenerables (addons 3.3G, node_modules x19, .godot, .git, tools, build, tmp, junk root),
PAS les game assets (scenes 11K, scripts 1.1M, assets 143M, data 20M).

## Phases
- [x] P0 Recon (structure, tailles, disque, vault Obsidian)
- [x] P1 Scanner tools/asset_ledger/scan.py (graphe ref + disk pressure + BIBLE.md)
- [ ] P2 Run scan v0 : graph.json + BIBLE.md avec chiffres reels
- [ ] P3 (parallele) cleanup.py + watchdog.py + .asset-keep  [sub-agent]
- [ ] P3 (parallele) README.md + fiches Obsidian (asset-librarian-godot Active, promote godot-devops) [sub-agent]
- [ ] P4 AskUserQuestion (scheduling A/B/C/D, seuils disque, whitelist) AVANT tout delete
- [ ] P5 Code review (scan/cleanup/watchdog) + recap 30 lignes max

## Schema contrat graph.json (v3), fige pour tous les sous-agents
nodes[]: {path, rel, type, ext, size_bytes, mtime, hash, git_tracked, referenced_by[],
          reference_confidence: none|static|dynamic, reachable, status}
status dans {root, whitelisted, used, orphan_static, orphan_lore, dynamic_uncertain}
summary: {total_files, total_bytes, status_counts, orphan_static_bytes, disk_pressure_bytes}
disk_pressure[]: {path, size_bytes, size_complete, regenerable, note}
dynamic_patterns[]

## Regle de surete
Rien supprime sans .trash/ git-tracke + branche chore/asset-cleanup-YYYY-MM-DD + AskUserQuestion.
cleanup ne cible QUE status==orphan_static (jamais dynamic_uncertain/orphan_lore/whitelisted/addons).
