# Courrier reçu — l'archive de ce que la VM raconte

Un fichier par jour (`AAAA-MM-JJ.md`, heure de **Paris**), écrit automatiquement par le
workflow `courrier-recu` toutes les 10 minutes.

**Pourquoi ce dossier existe.** La VM parle déjà : le Courrier poste ses verdicts sur ntfy.
Mais deux trous rendaient ce canal fragile :

1. **ntfy.sh efface tout au bout de ~12 h.** Un verdict tombé la nuit était perdu au matin —
   vécu le 2026-08-25 : les résultats de p63, p64 et p65 avaient disparu quand je les ai
   cherchés.
2. **Rien n'était archivé.** Le poste de pilotage ne lisait ntfy que sur sollicitation, et il
   fallait souvent que Maxime recolle une sortie à la main.

Désormais : ntfy reste le canal *rapide* (notification téléphone), et ce dossier est la
*mémoire* — lisible à tout moment par l'API GitHub, indéfiniment, sans que personne ait à
coller quoi que ce soit.

## Ce qu'on y trouve

```
<!-- id: <identifiant ntfy, sert a la deduplication> -->
## 22:39 — p65 depart

```
20:39:05Z sha=6326ca22
```
```

Les **pièces jointes** (journaux de partie, chroniques) sont référencées par leur URL ntfy.
Attention : **ces URL expirent avec ntfy** — elles servent dans les heures qui suivent, pas
après. Seul le texte est conservé durablement.

## Limites, dites franchement

- La planification GitHub n'est pas à la seconde : un créneau `*/10` peut glisser de quelques
  minutes sous charge. Ce n'est pas un canal temps réel, c'est une archive.
- Le relais **n'éveille pas** la session de pilotage. Il rend la lecture instantanée et
  complète quand on la demande ; il ne remplace pas un « alors ? ».
