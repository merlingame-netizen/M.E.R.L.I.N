# _shared — Context (environnement machine utilisateur)

> Contraintes durables de la/les machine(s) de travail. À respecter sur TOUS les projets.

## Contraintes machine

| Date | Contrainte | Conséquence |
|------|-----------|-------------|
| 2026-06-07 | **Sur ce PC, impossible de lancer des fichiers `.bat`** (probablement politique d'entreprise / blocage exécution). | NE JAMAIS proposer de `.bat` comme moyen de lancement ici. Privilégier : commande Python directe en terminal (`python script.py`), `.ps1` seulement si autorisé, ou tâche VS Code. Pour les outils maison (ex. serveur TTS VoxCPM/Piper), fournir un lanceur **pur Python** (`python tools/voxcpm/serve.py`). |

## Notes
- L'utilisateur a Python 3.10–3.12 installé et peut exécuter `python ...` dans un terminal.
- Machine principale = Windows (cf. tooling `.ps1`, win32com Outlook, PBI Desktop).
