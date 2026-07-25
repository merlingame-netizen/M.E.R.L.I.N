# Asset Ledger

Systeme d'inventaire et d'hygiene disque du projet Godot M.E.R.L.I.N. : cataloguer chaque asset `res://`, reperer les orphelins recuperables, et liberer l'espace disque de facon sure et reversible.

## Vue d'ensemble

Le systeme repose sur trois outils, une bible lisible et un graphe machine.

- **`scan.py`** : scanne l'ensemble du projet Godot, construit un graphe de references des assets `res://`, puis ecrit deux sorties dans `docs/asset-ledger/` :
  - `graph.json` : representation machine (noeuds, statuts, references) pour l'outillage.
  - `BIBLE.md` : bible humaine, regeneree a chaque scan avec un changelog delta (ce qui a change depuis le scan precedent).
  Le scan reporte aussi la **pression disque** ("disk_pressure") : les gros repertoires regenerables ou historiques exclus du graphe de jeu (node_modules, `.godot`, `.git`, caches de build). Ce sont eux les vrais gouffres a disque.
- **`cleanup.py`** : met en quarantaine les fichiers `status == orphan_static` dans un dossier `.trash/YYYY-MM-DD/` suivi par git, sur une branche `chore/asset-cleanup-YYYY-MM-DD`. Tout est reversible via git. Ne touche JAMAIS aux fichiers `used`, `root`, `whitelisted`, `dynamic_uncertain` ni `orphan_lore`.
- **`watchdog.py`** : surveille l'espace libre du disque C: et declenche des actions par paliers.

Principe de surete central : **rien n'est supprime sans passer par un `.trash` git-tracke reversible**. Une suppression accidentelle se rattrape avec un simple `git revert` ou `git checkout`.

## Utilisation

Runner Python complet (le `python` nu est un stub casse sur ce poste) :

```bash
# 1. Scanner le projet : construit graph.json + BIBLE.md
C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe tools/asset_ledger/scan.py
```

```bash
# 2. Nettoyer les orphelins (DRY-RUN par defaut : n'ecrit rien, montre le plan)
C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe tools/asset_ledger/cleanup.py
```

```bash
# 3. Surveiller le disque (DRY-RUN par defaut)
C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe tools/asset_ledger/watchdog.py
```

### Modes de `cleanup.py`

| Mode | Effet |
|------|-------|
| (defaut) | DRY-RUN : affiche ce qui serait mis en quarantaine, n'ecrit rien. |
| `--apply` | Deplace reellement les orphelins vers `.trash/YYYY-MM-DD/` sur la branche de cleanup. |
| `--auto` | Enchaine scan + quarantaine sans interaction (pour tache planifiee). |
| `--purge-trash` | Supprime definitivement les `.trash` de plus de 30 jours. |
| `--max-bytes N` | Plafonne la quantite de donnees mises en quarantaine a N octets. |

### Modes de `watchdog.py`

Paliers de declenchement sur l'espace libre du disque C: :

| Palier | Seuil | Action |
|--------|-------|--------|
| warn | < 20 Go libres | Journalise dans `docs/asset-ledger/ALERTS.md`. |
| critical | < 5 Go libres | Lance scan + `cleanup --auto` + purge des `.trash` + purge de `.godot/imported`. |
| imported | `.godot/imported` > 2 Go | Purge ce cache (regenere par Godot au prochain import). |

Par defaut `watchdog.py` tourne en DRY-RUN. Ajouter `--enforce` pour appliquer reellement les actions.

## Taxonomie des statuts

| Statut | Signification | Supprimable ? |
|--------|---------------|---------------|
| `root` | Point d'entree du projet (scenes/scripts racine, `project.godot`). | Non |
| `whitelisted` | Protege explicitement par `.asset-keep`. | Non |
| `used` | Reference par au moins un autre asset du graphe. | Non |
| `orphan_static` | Aucun referent statique trouve : candidat sur a la suppression. | Oui (via quarantaine) |
| `orphan_lore` | Contenu narratif orphelin : marque, jamais supprime automatiquement. | Non (auto) |
| `dynamic_uncertain` | Reference par chemin calcule ou nom logique : a verifier manuellement. | Non (auto) |

Seul `orphan_static` est deplace par `cleanup.py`. Tout le reste est preserve.

## Fichier `.asset-keep`

Place a la racine du projet, il protege des fichiers du nettoyage meme s'ils apparaissent comme orphelins.

Format :
- une ligne = un motif glob (fnmatch applique sur le chemin relatif) ;
- les lignes commencant par `#` sont des commentaires ;
- prefixe optionnel `KEEP:` toleré devant un motif.

Exemple :

```
# Garder tous les stems audio de reference
assets/audio/stems/**

# Proteger un artwork precis
KEEP: assets/art/broceliande_concept_v3.png

# Garder les GGUF du LLM natif
addons/merlin_llm/models/*.gguf
```

Tout fichier dont le chemin relatif matche un de ces motifs recoit le statut `whitelisted` et ne sera jamais mis en quarantaine.

## Interpreter la BIBLE.md

`docs/asset-ledger/BIBLE.md` est regeneree a chaque scan. Points a regarder :

- **Resume** : total des fichiers de jeu suivis, volume total, et repartition par statut. Vue d'ensemble rapide de la sante de l'inventaire.
- **Pression disque** : les gros repertoires regenerables ou historiques (hors graphe de jeu). C'est ici qu'on voit ou part reellement l'espace disque.
- **Top orphelins** : les plus gros `orphan_static` par volume : le gisement recuperable, tries pour prioriser.
- **References dynamiques a verifier** : les `dynamic_uncertain`, a inspecter a la main avant toute action (chemins calcules, noms logiques).
- **Changelog** : le delta depuis le scan precedent (assets ajoutes, passes orphelins, disparus). Permet de suivre l'evolution entre deux scans.

## Pression disque vs orphelins

Deux problemes distincts, deux traitements :

- **Pression disque** : `node_modules`, `.godot`, `.git`, caches de build. Ce sont les vrais gouffres a disque, mais ils sont **regenerables** et **hors du graphe de jeu**. On ne les catalogue pas comme des assets : ils sont geres par `watchdog.py` (purge de `.godot/imported`, purge des `.trash`). Les supprimer est sans risque, le projet les reconstruit.
- **Orphelins** : des assets de jeu **historiques** (sorties Demucs de stems musicaux, dumps 3D-gen `Assets/trellis`, etc.) qui ne sont plus references. Ils vivent dans le graphe de jeu, sont recuperables via `cleanup.py`, et passent toujours par la quarantaine `.trash` reversible.

En clair : pour recuperer de l'espace vite, regarder d'abord la pression disque (watchdog) ; pour degraisser durablement l'inventaire de jeu, traiter les orphelins (cleanup).

## Scheduling

`scan.py` et `watchdog.py` se pretent a une execution en tache planifiee (Planificateur de taches Windows) pour maintenir l'inventaire et l'hygiene disque sans intervention. La configuration reste a la main de Maxime (frequence, `--enforce` pour le watchdog, `--auto` pour le cleanup). Recommandation : scan quotidien en lecture, watchdog frequent en `--enforce` une fois le comportement valide en dry-run.

## Securite / reversibilite

- `cleanup.py` travaille sur une branche dediee `chore/asset-cleanup-YYYY-MM-DD` : le nettoyage n'atterrit jamais directement sur la branche de travail.
- Les fichiers ne sont pas supprimes : ils sont deplaces dans `.trash/YYYY-MM-DD/`, suivi par git.
- Pour annuler un nettoyage : `git revert` du commit de quarantaine, ou `git checkout <commit> -- <chemin>` pour restaurer un fichier precis.
- La suppression definitive n'arrive qu'au `--purge-trash` (ou palier critical du watchdog), et seulement pour les `.trash` de plus de 30 jours.
