# Tester « Deux Assiettes » depuis ton PC

Le scénario type de référence, 25 cartes, joué par toi — pas en autoplay.

---

## 1. Récupérer la version à jour

> ⚠ **Ton travail local est en avance sur le remote.** L'interface que tu m'as
> montrée (barre à 5 stats, main de runes, panneau narratif) n'existe dans aucun
> commit. Un `git pull` brut risque de la mettre en conflit avec le ménage.
> Mets-la à l'abri d'abord.

```powershell
cd C:\Users\PGNK2128\Godot-MCP

git status                    # qu'est-ce qui n'est pas commité ?
git branch --show-current

# Mets ton travail en cours à l'abri sur une branche
git switch -c wip/ui-locale
git add -A
git commit -m "wip: etat local avant synchro"
git push -u origin wip/ui-locale

# Puis récupère main
git switch main
git pull origin main
```

Si `git status` est déjà propre, un simple `git pull origin main` suffit.

**Après le pull, ouvre le projet dans l'éditeur Godot une fois.** Il doit
réimporter les assets — la musique est passée en `.ogg` et les `.import` ne sont
pas versionnés. Sans ça, Godot se plaindra de polices et de traductions
introuvables.

---

## 2. Jouer

Double-clic sur **`jouer_scenario.bat`** à la racine du projet.

Le script cherche Godot à
`C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64.exe`. Si ton exécutable est
ailleurs :

```powershell
$env:GODOT = "C:\chemin\vers\Godot.exe" ; .\jouer_scenario.bat
```

---

## 3. Ce que tu dois voir

Sept cartes pour franchir une porte — c'est le point de la règle « aucune
ellipse » (bible §33.2) :

| Carte | |
|---:|---|
| 1 | le chemin de planches dans la tourbière, l'odeur de pain brûlé |
| 2 | la maison basse — fenêtre allumée, cheminée froide |
| 3 | le seuil, les bottes d'homme sèches tournées vers l'intérieur |
| 4 | on frappe. Un pas de l'autre côté du bois, puis plus rien |
| 5 | la porte s'ouvre de la largeur d'une main. Une lampe, une femme |
| 6 | elle regarde la tourbière par-dessus ton épaule, puis s'efface |
| 7 | la pièce basse, le feu éteint, **la table mise pour deux** |

**Sur chaque carte :**

- les trois options portent leur épreuve **avant** le choix —
  `[Logic 60%] Lire les traces`. Une épreuve rouge s'annonce en toutes lettres :
  un risque doit se voir, sinon c'est un piège ;
- après ton choix, une **résolution** est narrée : ce qui se produit, et ce que
  ça t'apporte. Elle diffère selon que l'épreuve réussit ou échoue ;
- en haut au centre : **Acte N / 5** (le rythme). En haut à droite :
  **Carte N / 25** (la progression). Ce sont deux choses distinctes.

**Prends ton temps** — aucune limite. L'échéance de 60 s qui choisissait à ta
place a été retirée.

**Deux moments à guetter**, les résolutions qui changent selon ce que tu traînes
derrière toi :
- carte 6, si tu as examiné les bottes carte 3 → Merlin te répond autrement ;
- carte 25, si tu as juré les trois jours carte 20 sans les tenir → Merlin
  t'arrête à mi-phrase.

---

## 4. Relire la partie

Double-clic sur **`voir_le_run.bat`**. Il produit deux vues du même run :

- `docs/30_jdr/RUN_TOURBE_TRANSCRIPT.md` — le déroulé complet en texte ;
- `docs/30_jdr/RUN_TOURBE_DASHBOARD.html` — le tableau de contrôle, qui s'ouvre
  tout seul. Deux colonnes par carte : **à l'écran** ce que tu as vu,
  **moteur** ce qu'il a appliqué sans le dire. C'est cet écart qui se contrôle.

Le tableau signale de lui-même les anomalies : dégâts non annoncés, gains de
réputation absorbés par le plafond, cartes sans résolution.

---

## 5. Rejouer la même partie

Les épreuves sont tirées au sort. Pour rejouer exactement la même suite de
réussites et d'échecs — utile pour vérifier une correction :

```powershell
$env:MERLIN_SEED = "11" ; .\jouer_scenario.bat
```

---

## 6. Ce qui n'est pas encore là

Par honnêteté, ce que tu ne verras pas :

| | |
|---|---|
| Les 5 réputations en chiffres au HUD | pas encore câblé (décision du 2026-07-26) |
| Le modificateur de marchand | les cartes SHOP portent `ADD_ESSENCE`, le moteur attend `APPLY_MODIFIER` |
| L'Anam en fin de run | `calculate_run_rewards` n'est appelé que sur victoire ou mort |

Et quatre défauts d'affichage relevés sur les captures du 2026-07-27, non
corrigés : le texte déborde du parchemin, l'identifiant de carte (`c2`, `c9`)
s'affiche en grand au centre, une frame montre le parchemin retourné, et les
decks de pioche et de défausse n'apparaissent pas quand une carte est à l'écran.
