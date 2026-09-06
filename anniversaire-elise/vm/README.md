# Le vote en direct — serveur sur la VM

Ce que l'artifact claude.ai ne peut pas faire : **un vote réellement partagé
sur une URL publique**. Les réponses vivent ici dans un SQLite sur ta VM, et
chaque visiteur voit les compteurs des autres.

---

## Pourquoi ce dossier existe

| | Artifact claude.ai | Ce serveur |
|---|---|---|
| URL publique, sans compte | ✅ | ✅ |
| Réponses gardées par visiteur | ✅ (son navigateur) | ✅ (son navigateur **et** le serveur) |
| **Compteurs partagés entre invités** | ❌ impossible | ✅ |
| Dépouillement | 9 messages WhatsApp à lire | Tableau + export CSV |
| Mise en route | déjà en ligne | un script à lancer sur la VM |

L'artifact reste utile — il marche tout de suite. Ce serveur est la version
qui compte les voix pour de vrai.

**La limite de la plateforme, pour mémoire :** la capacité `db` d'un artifact
est réservée aux membres de ton organisation, et l'auto-republication rejette
`capability_disabled` dès que l'artifact est partagé publiquement. Public et
vote partagé sont incompatibles là-bas. Pas ici.

---

## Déployer

```bash
ssh merlin-vm
cd ~/workspace/M.E.R.L.I.N && git pull
bash anniversaire-elise/vm/deploy-vote.sh
```

Le script installe l'environnement Python, monte le service, **vérifie que la
page répond et que `/admin` renvoie bien 403 sans jeton**, ouvre le tunnel
Cloudflare et affiche l'URL publique plus ton lien d'administration.

Il est idempotent : relance-le après toute modification de la page.

## Architecture

```
[invité] --HTTPS--> Cloudflare --tunnel sortant--> cloudflared (VM)
                                                       |
                                         gunicorn 127.0.0.1:8792
                                                       |
                                   SQLite /var/lib/anniv-vote/reponses.db
```

Aucun port entrant ouvert : ni `ufw`, ni security list OCI, ni Terraform à
toucher. Le tunnel part **de** la VM **vers** Cloudflare.

Contrairement au site statique protégé par mot de passe (`deploy/`), **cette
page est publique et sans authentification** — c'est le but : les invités
votent sans compte ni mot de passe.

## Ce que fait le serveur

| Route | Rôle |
|-------|------|
| `GET /` | La page, avec les compteurs déjà rendus |
| `POST /api/reponse` | Enregistre ou met à jour une réponse |
| `GET /api/etat` | Les compteurs en JSON |
| `GET /admin?token=…` | Le détail nominatif des réponses |
| `GET /admin?token=…&format=csv` | Export CSV |
| `GET /healthz` | Sonde de santé |

Chaque visiteur reçoit un cookie `anniv_id` : il peut revenir modifier sa
réponse autant qu'il veut, sans jamais créer de doublon.

## Une seule source pour la page

`templates/index.html` est **généré** depuis `../site/public.html` par
`build_template.py`, qui y greffe trois choses sans toucher au reste :

1. le squelette HTML complet ;
2. la section « Les votes en direct » ;
3. le script qui envoie la réponse au serveur.

Le JS d'origine — localStorage, budget vivant, timeline personnalisée —
continue de tourner tel quel. Modifie `site/public.html`, relance le script,
et les deux versions restent alignées.

## Sécurité

La page est publique : les protections ne sont donc pas décoratives.

| Risque | Traitement |
|--------|-----------|
| Injection HTML dans un nom | Jinja2 échappe au rendu, `textContent` côté JS |
| Valeurs fantaisistes | Présence, gîte et activités validés contre une liste fermée ; nom ≤ 60 caractères ; effectif entre 1 et 10 |
| Flood | 20 requêtes par minute et par IP, puis HTTP 429 |
| Formule dans le CSV | Un nom commençant par `= + - @` est préfixé d'une apostrophe |
| Accès au détail nominatif | `/admin` exige un jeton de 40 caractères, généré une fois |
| Vie privée | La page publique n'affiche que les **prénoms**. Les noms complets restent dans `/admin` |

Le service tourne avec `NoNewPrivileges`, `ProtectSystem=full` et
`ProtectHome=read-only` : il n'écrit que dans son dossier de données.

## Les réponses

Elles sont dans `/var/lib/anniv-vote/reponses.db`. **Sauvegarde-le avant tout
redéploiement** — le script ne l'écrase pas, mais un `rm -rf` malheureux, si.

```bash
sudo sqlite3 /var/lib/anniv-vote/reponses.db \
  "SELECT nom, nb, vient, json_extract(donnees,'$.escape') FROM reponses ORDER BY maj;"

# Le detail complet d'une reponse, lisible :
sudo sqlite3 /var/lib/anniv-vote/reponses.db \
  "SELECT json_pretty(donnees) FROM reponses ORDER BY maj DESC LIMIT 1;"
```

### Pourquoi une colonne `donnees` en JSON

La page a été refondue une demi-douzaine de fois, et chaque refonte ajoutait
ou retirait une question. Un schéma à une colonne par question aurait demandé
une migration à chaque fois. Ici seules les colonnes sur lesquelles on compte
ou on trie sont sorties du JSON — `nom`, `nb`, `vient`, `maj` — et le reste
suit la page sans migration.

La contrepartie serait de laisser entrer n'importe quoi : c'est pourquoi
`build_template.py` relève dans la page toutes les paires `name`/`value` des
boutons radio et des cases à cocher, les écrit dans `valeurs.json`, et le
serveur refuse toute réponse hors de ces listes. Le formulaire et sa
validation ne peuvent plus diverger.

## URL stable

Une URL `*.trycloudflare.com` **change à chaque redémarrage du tunnel**. Tant
que tu ne redémarres pas le service, elle tient. Pour une URL fixe jusqu'au
15 septembre, avec un domaine sur Cloudflare :

```bash
cloudflared tunnel login
cloudflared tunnel create anniv-elise
cloudflared tunnel route dns anniv-elise anniv.tondomaine.fr
```

puis remplace la ligne `ExecStart` de `/etc/systemd/system/anniv-vote-tunnel.service`
par `cloudflared tunnel run anniv-elise`, et
`sudo systemctl daemon-reload && sudo systemctl restart anniv-vote-tunnel`.

## Après la fête

```bash
sudo systemctl disable --now anniv-vote anniv-vote-tunnel
sudo cp /var/lib/anniv-vote/reponses.db ~/reponses-anniv-elise.db   # au cas où
sudo rm -rf /opt/anniv-vote /var/lib/anniv-vote /etc/anniv-vote.env
```
