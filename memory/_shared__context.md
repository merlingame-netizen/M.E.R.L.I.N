# _shared — Context (environnement machine utilisateur)

> Contraintes durables de la/les machine(s) de travail. À respecter sur TOUS les projets.

## Contraintes machine

| Date | Contrainte | Conséquence |
|------|-----------|-------------|
| 2026-06-07 | **Sur ce PC, impossible de lancer des fichiers `.bat`** (probablement politique d'entreprise / blocage exécution). | NE JAMAIS proposer de `.bat` comme moyen de lancement ici. Privilégier : commande Python directe en terminal, `.ps1` seulement si autorisé, ou tâche VS Code. Pour les outils maison (ex. serveur TTS VoxCPM/Piper), fournir un lanceur **pur Python** (`py tools/voxcpm/serve.py`). |
| 2026-06-07 | **`python` n'est PAS dans le PATH** (PowerShell : "le terme python n'est pas reconnu"). | Utiliser le lanceur Windows **`py`** (ex. `py --version`, `py tools/voxcpm/serve.py`). Donner des commandes avec `py`, pas `python`. |

## Notes
- L'utilisateur a Python 3.10–3.12 installé, **mais via le lanceur `py`** (pas `python` sur le PATH).
- Terminal utilisé : **PowerShell** (Windows).
- Penser à rappeler de se placer DANS le dépôt (`cd`) ou à donner le **chemin absolu** du script (l'utilisateur se retrouve souvent dans `C:\Users\PGNK2128`).
- Machine principale = Windows (cf. tooling `.ps1`, win32com Outlook, PBI Desktop).
