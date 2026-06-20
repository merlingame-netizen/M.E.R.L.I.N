# ⚙️ SETUP — Cagnotte autonome + montant auto-synchronisé

Site **100 % autonome** (HTML/CSS/JS + polices locales). À héberger sur **ton propre
dépôt GitHub** (compte de ton choix) + un **Cloudflare Worker** gratuit qui lit le
total **automatiquement sur OnParticipe**.

> La page fonctionne **dès l'étape A** (montant de secours dans `config.js`).
> L'étape B ajoute la **synchro auto** du montant + la page admin.

---

## A. Mettre le site en ligne — depuis le Git de ton PC

### A1. Récupérer le dossier
Télécharge le bundle `cagnotte-evg.zip` (fourni dans le chat) et dézippe-le. Tout est
à la **racine** (important pour GitHub Pages).

### A2. Créer le dépôt (ton autre compte)
1. Connecte-toi au **bon compte** sur GitHub, puis crée un dépôt **vide** :
   👉 https://github.com/new — nom : `cagnotte-evg`, **Public**, sans README.

### A3. Pousser depuis ton terminal (Git du PC)
```bash
cd cagnotte-evg            # le dossier dézippé
git init -b main
git add -A
git commit -m "site cagnotte EVG Alexandre"
```
Puis, au choix :

**HTTPS + token** (le plus simple)
- Crée un token : 👉 https://github.com/settings/tokens?type=beta
  (Fine-grained → *Only select repositories* = `cagnotte-evg` → Permissions *Contents: Read and write*).
```bash
git remote add origin https://github.com/<TON_COMPTE>/cagnotte-evg.git
git push -u origin main        # login = ton compte, password = le token
```

**SSH** (si tu as déjà une clé)
- Aide clé SSH : 👉 https://docs.github.com/authentication/connecting-to-github-with-ssh
```bash
git remote add origin git@github.com:<TON_COMPTE>/cagnotte-evg.git
git push -u origin main
```

### A4. Activer GitHub Pages
Repo → **Settings → Pages** → *Source* : **Deploy from a branch** → `main` / `/ (root)` → **Save**.
👉 Doc : https://docs.github.com/pages/getting-started-with-github-pages
URL finale : `https://<TON_COMPTE>.github.io/cagnotte-evg/`

---

## B. Montant auto-synchronisé — Cloudflare Worker (gratuit)

Le Worker lit le total affiché sur ta page OnParticipe (lecture server-side, mise en
cache ~2 min) et le sert à ton site. Une page **admin** permet de **forcer** une valeur
(utile si des virements RIB s'ajoutent) ou de **repasser en auto**.

### B1. Prérequis
- Compte Cloudflare (gratuit) : 👉 https://dash.cloudflare.com/sign-up
- Node.js : 👉 https://nodejs.org (LTS), puis :
```bash
npm install -g wrangler        # 👉 https://developers.cloudflare.com/workers/wrangler/
```

### B2. Déployer
```bash
cd cagnotte-evg/worker
wrangler login                                   # ouvre le navigateur, autorise
wrangler kv namespace create CAGNOTTE_KV         # → copie l'id "xxxxxxxx"
#   colle cet id dans wrangler.toml  (id = "xxxxxxxx")
wrangler secret put ADMIN_SECRET                 # tape TON mot de passe admin
wrangler deploy                                  # → affiche l'URL du Worker
```
👉 Doc KV : https://developers.cloudflare.com/kv/

### B3. Brancher le site sur le Worker
Dans **`config.js`**, renseigne l'URL du Worker :
```js
sync: { worker_url: "https://cagnotte-evg.<toi>.workers.dev" },
```
`git commit -am "branche worker" && git push` → le site lit le montant en direct.

---

## C. Mettre à jour / forcer le montant

- **Auto** : rien à faire, le Worker suit OnParticipe (rafraîchi ~2 min).
- **Forcer une valeur** : va sur **`/admin.html`**
  (`https://<TON_COMPTE>.github.io/cagnotte-evg/admin.html`), entre le montant + ton
  mot de passe → « Forcer ce montant ». Bouton **« Repasser en auto »** pour revenir
  au suivi OnParticipe. Le mot de passe n'est **jamais** stocké dans le repo.
- Free tier Cloudflare : 100 000 lectures/jour — large.

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `index.html` | Page Cagnotte publique (montant auto + objectif + RIB + OnParticipe + partage) |
| `admin.html` | Page admin (forcer le montant / repasser en auto) — protégée par mot de passe |
| `config.js` | Secours montant/objectif, description, `sync.worker_url`, RIB, lien OnParticipe |
| `worker/worker.js` + `wrangler.toml` | Worker Cloudflare (lecture auto OnParticipe + override) |
| `programme.html` | Détail du week-end (logement + activités) |
| `fonts/` · `rib-…pdf` | Polices auto-hébergées · RIB téléchargeable |
