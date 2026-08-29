# Penn ar Bed, paquet v1

Architecture complète du monde et de la quête principale de M.E.R.L.I.N., prête à être déposée
sur la VM. **Rien n'a été appliqué au dépôt** : ce paquet est du contenu à intégrer, pas un patch
à exécuter.

---

## 1. Ce qu'il y a dedans

```
PENN_AR_BED.html                  la page, deux onglets, autoportante (aucun réseau requis)
canon/BIBLE_S26_PENN_AR_BED.md    18 règles canon, R173 à R190, à concaténer dans docs/BIBLE.md
data/biomes/<id>.json             12 lieux
data/quete/chapitres.json         les 12 chapitres de la quête principale
data/quete/paliers.json           les 5 paliers, les souvenirs de Merlin, le run final
data/quete/reliques.json          les 5 reliques
data/quete/traversees.json        la dorsale (11 traversées) et les sentiers secondaires (9)
data/figures/<id>.json            16 fiches de personnage
data/_index.json                  manifeste et table de rebind des ambiances
```

La page HTML s'ouvre par double-clic, sans serveur. Onglet **I La carte** : les douze lieux, la
dorsale numérotée, un curseur de progression de 0 à 12 éclats, trois couches (Lieux, Forces,
Cosmologie). Onglet **II Le roster** : les seize fiches, filtrables par force, par nature, par lieu
et par chapitre, avec liens croisés vers la carte.

Le contour du territoire est le contour réel du Finistère (données ouvertes, douze masses de terre
dont Ouessant, Molène, Sein et les Glénan), mais le lieu ne s'appelle jamais ainsi devant le joueur.

---

## 2. Quoi en faire sur la VM

1. **Le canon.** Concaténer `canon/BIBLE_S26_PENN_AR_BED.md` à la fin de `docs/BIBLE.md`.
   La section s'insère après §25 et ne réécrit rien : les deux endroits où elle amende le canon
   antérieur sont signalés en toutes lettres (R175 amende R97, R179 amende le comportement de
   `record_end`).

2. **Les données.** Copier `data/` par-dessus le `data/` du dépôt. `data/biomes/` est vide dans le
   dépôt actuel, `data/quete/` et `data/figures/` n'existent pas encore : aucune collision de fichier.

3. **La page.** À garder comme référence de design. Elle n'est lue par aucun code.

Aucun script à lancer, aucune dépendance à installer.

---

## 3. Trois hypothèses que j'ai prises, et qui restent à valider

Ces points ont été décidés faute de réponse, pas par préférence. Chacun est réversible.

### 3.1 Le rebind des ambiances sonores

Le dépôt contient déjà douze fichiers `audio/sfx/amb_*.wav`, câblés à douze airs bretons et douze
instruments lead par `tools/breton_tunes.py`. Ils portent l'ancienne nomenclature (Brocéliande plus
cinq factions, plus six biomes legacy), qui ne correspond pas aux douze lieux de cette architecture.

**J'ai rebindé les douze ambiances existantes sur les douze lieux, un pour un.** Aucun fichier créé,
aucun supprimé, aucun air rejeté. Le binding air et instrument suit l'ambiance, donc il n'est pas
affecté.

| Lieu | Ambiance reprise |
|---|---|
| Ar C'hoad Kozh | `amb_broceliande` |
| Ar Vevenn | `amb_cotes` |
| Menez Du | `amb_landes` |
| Kerlan | `amb_villages` |
| Ar C'hairn | `amb_cercles` |
| Yeun Elez | `amb_marais` |
| Menez Hom | `amb_collines` |
| Marc'had an Deur | `amb_broc_korrigans` |
| Ys | `amb_broc_niamh` |
| Kastell Skeud | `amb_broc_anciens` |
| Enez Glenn | `amb_broc_ankou` |
| Enez Gouel | `amb_broc_druides` |

Si l'arbitrage inverse est préféré (la carte prend les noms de l'audio), seuls les libellés changent :
les clés `amb_*`, les airs et les leads restent identiques dans les deux cas.

### 3.2 Le second onglet est en lecture, pas en édition

L'onglet Roster se **contrôle** par filtres, tri et fiches dépliables. Il ne permet pas d'éditer les
fiches dans la page avec sauvegarde. La version éditable est faisable, c'est une autre mécanique.

### 3.3 Le roster est limité aux seize figures canon

Merlin, Arthur, les quatre piliers et les dix du roster nommé R166. Aucune figure inventée pour
l'occasion : tout le texte des fiches dérive de `docs/BIBLE.md` §6.

---

## 4. Le seul vrai changement de code que l'architecture exige

`MerlinChronicle.record_end` incrémente aujourd'hui `graal_fragments` sur **toute** fin
d'accomplissement :

```gdscript
if end_type == "accomplissement":
    cfg.set_value(SECTION, "graal_fragments", int(cfg.get_value(SECTION, "graal_fragments", 0)) + 1)
```

R179 exige que l'éclat vienne du **chapitre**, pas de la victoire. Sans ce changement, douze
traversées libres réussies suffisent à finir la quête principale et toute l'architecture des verrous
devient décorative. C'est le premier ticket à ouvrir.

Deux autres manques bloquants avant implémentation, listés en §26.6 du canon : le **registre des
hauts faits** cross-run (sans lui, aucune condition de chapitre n'est vérifiable) et la **migration
de la nomenclature legacy** (`data/ai/scenarios/faction_encounters/` et `BIOMES_SYSTEM.md` portent
encore `foret_broceliande`, `landes_bruyere`, `marais_korrigans`).

---

## 5. Ce qui a été vérifié, et ce qui ne l'a pas été

**Vérifié dans le navigateur, sur la page livrée :**
- Les douze lieux tombent sur la terre ferme, sauf Ys, volontairement au large.
- Aucune étiquette ne se chevauche ni ne sort du cadre.
- La progression est cohérente éclat par éclat : à N éclats, exactement les lieux attendus sont
  ouverts, exactement N-1 traversées sont faites, et le chapitre courant est le N+1.
- Chaque verrou de chapitre est franchissable pile au moment où le chapitre arrive, sans trou.
- Les filtres du roster se croisent correctement (Falaises plus chapitre 9 ne laisse qu'Erwan Veilleur).
- Les trois couches et les bascules d'onglet fonctionnent.
- Les trois polices se chargent.

**Non vérifié, et il faut le savoir :**
- Aucune capture d'écran ni test à taille mobile : le volet navigateur de la session était masqué,
  ce qui rend la mesure de largeur inexploitable. Le responsive repose sur des media queries écrites
  mais non exécutées à 375 px.
- Aucune validation Godot (`validate_step0`, smoke, soak) : aucun fichier du jeu n'a été modifié,
  il n'y avait rien à valider.

---

*Paquet produit le 2026-08-29. Canon de référence : `docs/BIBLE.md` v2.0, R1 à R172.*
