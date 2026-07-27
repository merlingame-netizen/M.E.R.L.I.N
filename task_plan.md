# task_plan.md : bible visuelle vivante + forêt de Brocéliande variée, 2026-07-27

## Dispatch Plan (task_dispatcher.md : types « Assets Visuels / Animation », complexité MODEREE)
- Wave 1 (parallèle, conseil) : art_direction.md (silhouettes, plans de profondeur, garde-fous §20/§23)
  || motion_designer.md (easing du coup de vent, profil de flexion, propagation, §21/R121)
- Wave 2 (review) : ui_impl.md — intégration et lisibilité du texte narratif
- Wave 3 (auto) : debug_qa.md + optimizer.md — tout changement .gd
- Gates : validate_step0 0/0 · smoke MerlinGame + MerlinMenu · captures avant/après (§24 « code visuel pur »)

## Décisions utilisateur (ne pas rejouer)
1. Étape 1 = bible visuelle : la bible MONTRE la palette au lieu de la décrire.
2. Forêt : 100% PROCÉDURAL, DA gravure conservée. Pixel art IA écarté (conflit §20, non contrôlable, rejeté 4x).
3. Densité : 10-14 arbres sur 3 plans, CENTRE DÉGAGÉ (lune, Merlin, sentier).

## Phases
- [x] P0. Bible visuelle régénérée (133 Ko -> 171 Ko, 6 semaines de dérive rattrapées).
      Constat : generate_bible_site.py extrait DÉJÀ palette/FS_*/DUR_* et rend des .swatch.
      L'extracteur de tokens que j'avais prévu était REDONDANT. Le vrai manque = fraîcheur.
- [x] P1. Cause 1 de l'erratique : sway_trees() TRANS_ELASTIC -> TRANS_CUBIC (aligné sur thicken_mist).
- [ ] P2. Cause 2 : les appelants ajoutent _tree_sway à base.x -> l'arbre GLISSE. Le pied doit rester planté.
- [ ] P3. Cause 3 : silhouette identique (toujours 2 branches, 5 blobs). Variation par seed par arbre.
- [ ] P4. Densité : 3 plans de profondeur, 10-14 arbres, clairière centrale préservée.
- [ ] P5. Gates + captures avant/après + revue.
