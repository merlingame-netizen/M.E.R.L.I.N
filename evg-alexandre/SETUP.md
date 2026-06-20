# ⚙️ SETUP — Site cagnotte autonome + montant synchronisé

Ce dossier est **100 % autonome** (HTML/CSS/JS + polices locales). Il est destiné à
vivre dans **son propre dépôt GitHub**, sur le **compte de ton choix** — séparé du
projet M.E.R.L.I.N.

## 1. Sortir le dossier vers ton dépôt (autre compte GitHub)

Depuis ce dossier (`evg-alexandre/`), un script prépare un dépôt git propre dont la
**racine = les fichiers du site** (indispensable pour GitHub Pages) :

```bash
bash extract-standalone.sh   # crée ../cagnotte-evg-standalone/ (repo git initialisé)
```

Puis, avec **TON** auth (gh ou SSH — au choix) :

```bash
cd ../cagnotte-evg-standalone

# Option A — GitHub CLI
gh auth login                      # connecte TON compte
gh repo create cagnotte-evg --public --source=. --remote=origin --push

# Option B — SSH (repo créé d'abord sur github.com)
git remote add origin git@github.com:<TON_COMPTE>/cagnotte-evg.git
git push -u origin main
```

Active ensuite **Settings → Pages → Deploy from a branch → `main` / `/root`**.
URL : `https://<TON_COMPTE>.github.io/cagnotte-evg/`

> La page marche **immédiatement** même sans l'étape 2 : le montant vient alors de
> `config.js` (secours). L'étape 2 ajoute la synchro temps réel.

## 2. Montant synchronisé — Cloudflare Worker (gratuit)

OnParticipe n'ayant pas d'API publique, on héberge un mini-compteur sur Cloudflare.
Lecture publique, écriture protégée par **mot de passe**.

```bash
npm install -g wrangler
cd worker
wrangler login                                  # ton compte Cloudflare (gratuit)
wrangler kv namespace create CAGNOTTE_KV        # → copie l'id affiché…
#   …et colle-le dans wrangler.toml (champ id = "...")
wrangler secret put ADMIN_SECRET                # tape TON mot de passe admin
wrangler deploy                                 # → affiche l'URL du Worker
```

Récupère l'**URL du Worker** (ex. `https://cagnotte-evg.<toi>.workers.dev`) et
colle-la dans **`config.js`** :

```js
sync: { worker_url: "https://cagnotte-evg.xxxx.workers.dev" },
```

Commit + push → la page lit désormais le montant en direct.

## 3. Mettre à jour le montant (depuis n'importe où)

Va sur **`/admin.html`** (ex. `https://<TON_COMPTE>.github.io/cagnotte-evg/admin.html`),
entre le **montant**, l'objectif (option) et ton **mot de passe** → « Mettre à jour ».
La page publique se synchronise au prochain chargement.

- Le mot de passe n'est **jamais** stocké dans le repo (tu le tapes à chaque fois).
- Free tier Cloudflare : 100 000 lectures/jour, 1 000 écritures/jour — large.

## Récap des fichiers

| Fichier | Rôle |
|---|---|
| `index.html` | Page Cagnotte publique (montant + objectif + RIB + OnParticipe + partage) |
| `admin.html` | Page admin protégée par mot de passe (mise à jour du montant) |
| `config.js` | Montant/objectif de secours, description, `sync.worker_url`, RIB, OnParticipe |
| `worker/worker.js` + `wrangler.toml` | Le Worker Cloudflare (compteur) |
| `programme.html` | Le détail du week-end (logement + activités) |
| `fonts/` | Polices auto-hébergées |
| `rib-maxime-babonneau.pdf` | RIB téléchargeable |
