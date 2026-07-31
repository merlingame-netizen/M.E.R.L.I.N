# MERLIN Studio — extension VS Code

Pilote depuis VS Code le studio de dev hébergé sur la **VM Oracle** : tester le jeu, générer du
contenu, interroger Gemma 4, suivre les jobs — sans terminal, sans SSH, **sans Python sur le PC**
(VS Code embarque déjà Node).

```
VS Code (ton PC)  ──HTTPS + Basic auth──►  Cloudflare Tunnel  ──►  VM Oracle : tools/merlin_studio (:8790)
                                                                     └─ Godot 4.6 · Ollama/Gemma 4 · dépôt du jeu
```

## Installation

```
Code → Extensions → “…” → Install from VSIX…  →  merlin-studio-1.0.0.vsix
```
(ou en ligne de commande : `code --install-extension merlin-studio-1.0.0.vsix`)

Puis **`Ctrl+Shift+P` → « MERLIN: Configurer la connexion »** : colle l'URL du tunnel et le token
affiché par `deploy-studio.sh`. Le token va dans le **coffre chiffré de VS Code** (SecretStorage),
jamais dans les settings ni dans le dépôt.

## Ce que ça donne

**Barre latérale** (icône MERLIN) — 3 arbres qui se rafraîchissent tout seuls :
- **Scènes du jeu** — les 8 scènes réelles, avec le dernier résultat (✅/❌ + nombre de
  `SCRIPT ERROR`). **Un clic sur une scène lance son smoke test.**
- **Jobs** — ce qui tourne / vient de tourner, clic = log complet.
- **VM & modèles** — cœurs/RAM, modèles Ollama installés, branche du dépôt, services systemd.

**Barre d'état** : `MERLIN 4c · 21Go · ⟳2` — santé de la VM en continu, clic = tableau de bord.

**Commandes** (`Ctrl+Shift+P`, préfixe `MERLIN:`) :

| Tester le jeu | Contenu & modèles | Divers |
|---|---|---|
| Tester une scène (smoke) | Générer des cartes | Mettre à jour le dépôt (pull ff-only) |
| Tester TOUTES les scènes | Valider le contenu | Voir le log d'un job |
| Suite de tests (headless) | Demander au modèle (Gemma 4) | Arrêter un job |
| Boot check | Télécharger un modèle Ollama | **Lancer une action (liste complète)** |
| | Démarrer les services voix | Ouvrir le tableau de bord |

La dernière — **« Lancer une action »** — lit l'`/api/launchers` de la VM : toute nouvelle action
ajoutée côté studio apparaît automatiquement, sans mettre à jour l'extension.

**Suivi live** : chaque job ouvre la sortie « MERLIN Studio » et **déverse le log au fil de l'eau**,
puis affiche `✅ terminé (exit 0) en 12s`.

## Réglages

| Réglage | Défaut | Rôle |
|---|---|---|
| `merlinStudio.url` | — | URL du studio (tunnel ou `http://127.0.0.1:8790`) |
| `merlinStudio.user` | `merlin` | utilisateur Basic-auth |
| `merlinStudio.refreshSeconds` | `15` | rafraîchissement auto (0 = off) |
| `merlinStudio.autoOpenLog` | `true` | ouvrir la sortie au lancement d'un job |

Le token n'est **pas** un réglage : il est dans le SecretStorage.

## Vérifié

Protocole testé de bout en bout contre un vrai studio : `/healthz`, découverte des 8 scènes,
`/api/overview`, 15 lanceurs, **lancement d'un vrai smoke Godot suivi jusqu'à la fin (exit 0) avec
récupération du log (5,5 Ko)**, et refus `401` sans token.

## Reconstruire le .vsix

```bash
cd tools/vscode-merlin-studio
npx @vscode/vsce package --allow-missing-repository --no-dependencies
```
