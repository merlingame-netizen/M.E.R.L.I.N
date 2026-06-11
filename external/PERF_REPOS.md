# M.E.R.L.I.N. — External Performance Repos (Reference Only)

> Cloned 2026-05-15 part 18 per user request : "Déploie des projets git pour du godot qui pourraient aider notre projet sur l'angle performance".
>
> Ces repos sont **clones shallow read-only** servant de référence et de patterns. **Aucun import direct** dans le code MERLIN — on copie/adapte les patterns dans `scripts/board_narration/`.
>
> `.gdignore` à la racine de `external/` empêche Godot scanner ces dossiers.

---

## 1. `multi_mesh_manager/` (richardathome)

- **URL** : https://github.com/richardathome/multi_mesh_manager
- **Godot version** : 4.x

### À quoi ça sert
Plugin éditeur-friendly pour gérer des `MultiMeshInstance3D` à partir d'instances posées dans la scène. `ManagedMesh` scene template + instanciation X fois → auto-batched en MultiMesh, draw call unique.

### Quand l'utiliser dans MERLIN
- Foliage Brocéliande : 18 arbres (4 variants × ~4-5 instances) → MultiMesh par variant.
- Brocéliande Forêt 3D : centaines d'arbres/herbes → MultiMesh obligatoire.
- Dolmens cercles_pierres : 8-12 menhirs identiques → MultiMesh.

### Pattern à copier
1. Wrapper Node3D = container.
2. Children = `MeshInstance3D` "templates" (transforms libres).
3. Au `_ready()`, le container collecte les transforms, crée un MultiMesh, free les templates.
4. Édition possible : remettre temporairement les MeshInstance3D pour repositionner.

### À adapter pour MERLIN
- Ajouter le **second MultiMesh outline** (cull FRONT, scale 1.015) pour signature noir bible §20.
- Wrapping dans `scripts/board_narration/multimesh_outline_helper.gd` (phase future).

---

## 2. `MeshLodGenerator/` (vPumpking)

- **URL** : https://github.com/vPumpking/MeshLodGenerator
- **Godot version** : 4.x

### À quoi ça sert
Plugin éditeur Godot pour générer automatiquement des LODs sur les `MeshInstance3D`. Crée 2-3 versions simplifiées, LOD bias calculé selon distance caméra.

### Quand l'utiliser dans MERLIN
- Brocéliande Forêt 3D rail-walk : arbres à 20m+ → LOD2 (20%), à 8m+ → LOD1 (50%), à <8m → LOD0 full.
- BoardNarration : la plupart des assets restent en LOD0 (caméra à ~5m).
- Cas limite : 18 arbres backdrop → LOD activé si drop FPS sur frame profiler.

### Pattern à copier
1. Prend un mesh source.
2. Applique Decimate (Collapse) avec ratios 0.5 + 0.2.
3. Génère un nouveau mesh avec les 3 surfaces (LOD0/1/2).
4. Godot bascule automatiquement selon `lod_bias`.

### À adapter pour MERLIN
- Tous les meshes du bundle `<biome>.glb` passent par ce LOD generator AVANT export.
- Optionnel : générer les LODs depuis Blender (Decimate modifier × 2) + nommage `Tree_LP_LOD0/1/2`.

---

## 3. `godot-blender-exporter/` (godotengine)

- **URL** : https://github.com/godotengine/godot-blender-exporter
- **Godot version** : 4.x (officiel Godot Engine)

### À quoi ça sert
Repo officiel Godot pour le workflow Blender → Godot. Contient :
- Addon Blender pour customiser l'export (collisions, MultiMesh markers, scripts attachés, custom materials).
- Patterns de naming convention.
- Fix Blender 4.1+ pour les vertex colors (cf. `BLENDER_WORKFLOW.md` §2.6).

### Quand l'utiliser dans MERLIN
- **Setup initial** : installer l'addon Blender depuis ce repo.
- **Workflow standard** : suivre les conventions de naming pour que Godot pré-configure auto les nodes (`<asset>_col` → CollisionShape3D).
- **Référence vertex colors** : consulter `addons/godot_blender_exporter/scripts/vertex_colors.py` pour le fix Blender 4.1.

### Pattern à copier
- Naming convention `Tree_LP_001`, `Rock_LP_001` → reconnu par Godot auto-import.
- Custom properties (`godot_collision_shape: "convex"`, `godot_multimesh_source: true`) embarqués dans GLB extras.

### À adapter pour MERLIN
- Installer l'addon dans Blender 4.x local.
- Documenter dans `BLENDER_WORKFLOW.md` les naming conventions retenues.

---

## 4. Politique d'usage

- ✅ Lire le code, copier les patterns, adapter dans `scripts/board_narration/`.
- ✅ Citer le repo source dans le commentaire de tête du fichier MERLIN.
- ❌ Ne JAMAIS importer directement un fichier de `external/` dans le code MERLIN (`.gdignore` empêche déjà l'autoload).
- ❌ Ne pas modifier les repos clonés (sauf `git pull --rebase` pour update).

## 5. Mise à jour
```bash
cd external/<repo_name> && git pull --depth 1
```

## 6. Désinstallation
```bash
rm -rf external/<repo_name>
```
(Préserver `external/.gdignore`.)

---

*PERF_REPOS v1.0 — M.E.R.L.I.N. — 2026-05-15.*
*Réfs : `docs/BLENDER_WORKFLOW.md` §6+§7+§9, `docs/archive/GAME_DESIGN_BIBLE_legacy_v3.8.md` §20 (ARCHIVÉ — canon : `docs/BIBLE.md` §20/§24).*
