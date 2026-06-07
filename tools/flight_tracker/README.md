# Flight Tracker — Marseille/Paris → La Réunion

Traceur de prix de billets d'avion **aller-retour** vers **Saint-Denis de La Réunion (RUN)**,
depuis **Marseille (MRS)**, **Paris-CDG** et **Paris-Orly (ORY)**.

- **Fenêtre de départ** : 20 décembre 2026 → 15 janvier 2027 (tous les jours).
- **Séjour** : 3 semaines exactes (retour = départ + 21 jours).
- **Sortie** : le **meilleur combo** (origine + dates les moins chères), un top 10,
  le meilleur prix par aéroport, et une **tendance** historique des prix.

Source de prix : **API Amadeus Self-Service** (palier gratuit). Le code n'utilise
que la bibliothèque standard Python (aucune dépendance à installer).

---

## 1. Utilisation rapide

```bash
# Depuis la racine du repo

# Test du pipeline sans clé API (prix simulés, déterministes)
python -m tools.flight_tracker --mock

# Voir les itinéraires interrogés sans appeler l'API
python -m tools.flight_tracker --dry-run

# Scan réel (nécessite les clés Amadeus, voir §2)
export AMADEUS_CLIENT_ID=xxxx
export AMADEUS_CLIENT_SECRET=yyyy
export AMADEUS_ENV=production        # ou "test" (données synthétiques)
python -m tools.flight_tracker
```

Résultats écrits dans `tools/flight_tracker/data/` :

| Fichier | Contenu |
|---------|---------|
| `latest_report.md` | Rapport lisible : meilleur combo, top 10, tendance |
| `best_combo.json` | Dernier meilleur combo (machine-readable) |
| `price_history.jsonl` | 1 ligne par relevé (historique des prix) |

---

## 2. Obtenir une clé Amadeus (gratuit)

1. Créer un compte sur <https://developers.amadeus.com>.
2. **My Self-Service Workspace → Create New App**.
3. Copier **API Key** (= `AMADEUS_CLIENT_ID`) et **API Secret** (= `AMADEUS_CLIENT_SECRET`).
4. Par défaut l'app est en environnement **test** : les données vol y sont
   limitées/synthétiques (les routes La Réunion peuvent manquer). Pour de **vrais
   prix**, cliquer sur **"Move to production"** dans le portail (toujours gratuit,
   même quota mensuel d'environ 2000 requêtes), puis utiliser `AMADEUS_ENV=production`.

> Un scan complet = 3 aéroports × 27 dates = **81 requêtes**. Largement dans le quota gratuit
> pour un relevé quotidien.

---

## 3. Le « Watch » automatique (GitHub Action)

Le workflow [`.github/workflows/flight-tracker.yml`](../../.github/workflows/flight-tracker.yml)
exécute le tracker **chaque jour à 06:00 UTC** et commite l'historique + le rapport
mis à jour dans le repo.

### Configuration

Dans **Settings → Secrets and variables → Actions** du repo :

**Secrets** (obligatoires pour les vrais prix) :
- `AMADEUS_CLIENT_ID`
- `AMADEUS_CLIENT_SECRET`

**Variables** (optionnelles — surchargent la fenêtre de recherche) :
- `AMADEUS_ENV` = `production` (recommandé) ou `test`
- `FT_DEPART_START`, `FT_DEPART_END`, `FT_TRIP_DAYS`, `FT_RETURN_FLEX`, `FT_ORIGINS`, `FT_DESTINATION`

### Déclenchement

- **Cron automatique** : GitHub n'exécute les workflows planifiés que depuis la
  **branche par défaut**. Pour activer le watch quotidien, il faut donc fusionner
  ce workflow dans la branche par défaut (`main`).
- **Manuel** : depuis l'onglet **Actions → Flight Tracker → Run workflow**, on peut
  le lancer sur n'importe quelle branche (option `mock` disponible pour un test).

---

## 4. Personnaliser la recherche

Tout se règle par variables d'environnement (voir `config.py`) :

| Variable | Défaut | Rôle |
|----------|--------|------|
| `FT_ORIGINS` | `MRS,CDG,ORY` | Aéroports de départ (codes IATA, séparés par `,`) |
| `FT_DESTINATION` | `RUN` | Destination |
| `FT_DEPART_START` | `2026-12-20` | Début fenêtre de départ |
| `FT_DEPART_END` | `2027-01-15` | Fin fenêtre de départ |
| `FT_TRIP_DAYS` | `21` | Durée du séjour (jours) |
| `FT_RETURN_FLEX` | `0` | Tolérance ± jours sur la durée (ex. `2` teste 19→23 j) |
| `FT_DEPART_STEP` | `1` | Pas en jours dans la fenêtre de départ |
| `FT_CURRENCY` | `EUR` | Devise |
| `FT_ADULTS` | `1` | Nombre d'adultes |
| `FT_NON_STOP` | `false` | `true` = vols directs uniquement |

Exemple — élargir à ±3 jours de séjour et n'interroger qu'un jour sur deux :

```bash
FT_RETURN_FLEX=3 FT_DEPART_STEP=2 python -m tools.flight_tracker
```

---

## 5. Architecture

```
tools/flight_tracker/
├── __main__.py        # CLI (python -m tools.flight_tracker)
├── config.py          # Fenêtre de recherche + génération des itinéraires
├── amadeus_client.py  # OAuth2 + Flight Offers Search (+ MockClient)
├── tracker.py         # Scan, historique JSONL, rapport Markdown
├── data/              # Sorties (générées par les runs)
└── README.md
```

Prix indicatifs Amadeus — toujours **confirmer le prix final sur le site de la compagnie**
avant de réserver.
