# Flight Tracker — Marseille/Paris → La Réunion

Traceur de prix de billets d'avion **aller-retour** vers **Saint-Denis de La Réunion (RUN)**,
depuis **Marseille (MRS)**, **Paris-CDG** et **Paris-Orly (ORY)**.

- **Fenêtre de départ** : 20 décembre 2026 → 15 janvier 2027 (tous les jours).
- **Séjour** : 3 semaines exactes (retour = départ + 21 jours).
- **Sortie** : le **meilleur combo** (origine + dates les moins chères), un top 10,
  le meilleur prix par aéroport, et une **tendance** historique des prix.

Source de prix par défaut : **KEYLESS** — scraping de **Google Flights** via la
lib [`fast-flights`](https://pypi.org/project/fast-flights/). **Aucune clé, aucun
compte.** Source alternative optionnelle : **API Amadeus Self-Service** (si tu
renseignes des clés, le tracker bascule automatiquement dessus, voir §2).

| Source | Clé requise | Fiabilité | Sélection |
|--------|-------------|-----------|-----------|
| **Google Flights** (défaut) | ❌ aucune | scraping (best-effort) | auto si pas de clé |
| **Amadeus** | ✅ id+secret | API contractuelle | auto si clés présentes, ou `FT_PROVIDER=amadeus` |
| **Mock** | ❌ | prix simulés | `--mock` ou `FT_PROVIDER=mock` |

---

## 1. Utilisation rapide

```bash
# Depuis la racine du repo

# Installer la dépendance keyless (une fois)
pip install -r tools/flight_tracker/requirements.txt

# Scan réel SANS clé (prix réels Google Flights) — c'est le défaut
python -m tools.flight_tracker

# Test du pipeline sans réseau (prix simulés, déterministes)
python -m tools.flight_tracker --mock

# Voir les itinéraires interrogés sans rien appeler
python -m tools.flight_tracker --dry-run

# Forcer la source Amadeus (nécessite les clés, voir §2)
export AMADEUS_CLIENT_ID=xxxx
export AMADEUS_CLIENT_SECRET=yyyy
export AMADEUS_ENV=production        # ou "test" (données synthétiques)
python -m tools.flight_tracker
```

> **Note keyless** : Google ne détaille pas toujours compagnies/escales dans sa vue
> aller-retour combinée — ces champs sont best-effort (`?` / `n/a`), mais **le prix
> est fiable**. Le scraping peut être throttlé si on enchaîne beaucoup de requêtes
> depuis une même IP (cf. `FT_FETCH_MODE`, `--sleep`, `FT_DEPART_STEP`).

Résultats écrits dans `tools/flight_tracker/data/` :

| Fichier | Contenu |
|---------|---------|
| `latest_report.md` | Rapport lisible : meilleur combo, top 10, tendance |
| `best_combo.json` | Dernier meilleur combo (machine-readable) |
| `price_history.jsonl` | 1 ligne par relevé (historique des prix) |

---

## 2. Optionnel — passer sur Amadeus (plus robuste pour un watch quotidien)

Le scraping Google est parfait pour démarrer sans rien, mais une API contractuelle
est plus stable pour un relevé automatique quotidien. Pour basculer :

### Obtenir une clé Amadeus (gratuit)

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

**Aucune configuration n'est nécessaire** : sans secret, le workflow scrape Google
Flights (source keyless). Il installe `fast-flights` puis lance le tracker.

Réglages optionnels dans **Settings → Secrets and variables → Actions** du repo :

**Secrets** (seulement si tu veux la source Amadeus) :
- `AMADEUS_CLIENT_ID`
- `AMADEUS_CLIENT_SECRET`

**Variables** (optionnelles) :
- `AMADEUS_ENV` = `production` (recommandé) ou `test` *(défaut workflow : production)*
- `FT_FETCH_MODE` = `common` | `fallback` *(défaut)* | `local` — stratégie de scraping keyless
- `FT_DEPART_STEP` *(défaut workflow : `2`, pour limiter le throttling)*
- `FT_DEPART_START`, `FT_DEPART_END`, `FT_TRIP_DAYS`, `FT_RETURN_FLEX`, `FT_ORIGINS`, `FT_DESTINATION`

### Alerte email quotidienne (Gmail)

Le workflow envoie chaque jour un **email HTML** : meilleur combo, bandeau de
statistiques (min/médian/max, nb d'offres sous seuil), **classement compétitif de
toutes les offres** (rang + écart vs meilleur prix + médailles 🥇🥈🥉), meilleur
prix par aéroport, et tendance.

**Configuration (Gmail App Password) :**

1. Active la **validation en 2 étapes** sur le compte Google.
2. Crée un **App Password** : <https://myaccount.google.com/apppasswords> (16 caractères).
3. Ajoute 2 **secrets** repo :
   - `MAIL_USERNAME` = ton adresse Gmail (ex. `maxbab38@gmail.com`)
   - `MAIL_PASSWORD` = l'App Password (les espaces sont ignorés)
4. *(optionnel)* variables : `SMTP_HOST` (défaut `smtp.gmail.com`), `SMTP_PORT`
   (défaut `465`), `MAIL_TO` (défaut : les 2 adresses), `FT_EMAIL_TOP`
   (`0` = toutes les offres, défaut ; ou un nombre pour limiter le classement).

Sans `MAIL_USERNAME`/`MAIL_PASSWORD`, l'envoi est **ignoré** (le relevé des prix continue).

Test local :

```bash
export MAIL_USERNAME="maxbab38@gmail.com"
export MAIL_PASSWORD="xxxx xxxx xxxx xxxx"
export MAIL_TO="maxime.babonneau@orange.com,eliserobert05@gmail.com"
python -m tools.flight_tracker --email
```

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
| `FT_PROVIDER` | *(auto)* | Force la source : `google`, `amadeus` ou `mock` |
| `FT_FETCH_MODE` | `common` | Scraping keyless : `common`, `fallback` ou `local` |

Exemple — élargir à ±3 jours de séjour et n'interroger qu'un jour sur deux :

```bash
FT_RETURN_FLEX=3 FT_DEPART_STEP=2 python -m tools.flight_tracker
```

---

## 5. Architecture

```
tools/flight_tracker/
├── __main__.py               # CLI (python -m tools.flight_tracker)
├── config.py                 # Fenêtre de recherche + génération des itinéraires
├── google_flights_client.py  # Source KEYLESS (fast-flights / Google Flights) — défaut
├── amadeus_client.py         # Source Amadeus : OAuth2 + Flight Offers Search (+ MockClient)
├── emailer.py                # Alerte email HTML quotidienne (API Resend)
├── tracker.py                # Scan, sélection provider, historique JSONL, rapport Markdown
├── requirements.txt          # Dépendance keyless (fast-flights)
├── data/                     # Sorties (générées par les runs)
└── README.md
```

Prix indicatifs — toujours **confirmer le prix final sur le site de la compagnie**
avant de réserver.
