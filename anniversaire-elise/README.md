# Les 30 ans d'Elise — 10 & 11 octobre 2026, à Aix

**Chez Max et Elise, à Aix-en-Provence.** Les invités ne paient rien et dorment
sur place. La seule participation est la cagnotte cadeau.

> **Le dossier a beaucoup bougé.** Il a commencé en week-end surprise dans le
> Luberon, est passé par le Beaujolais quand le train est devenu le critère, et
> a fini chez vous. Les fichiers ci-dessous reflètent l'état final — les
> versions intermédiaires sont dans l'historique Git.

---

## Par où commencer

| Ordre | Fichier | Ce que tu y fais |
|-------|---------|------------------|
| 1 | `whatsapp/05_post_aix.md` | Créer le groupe, coller le message d'annonce |
| 2 | *(le lien du site)* | Le partager dans le groupe |
| 3 | `docs/aix-10-octobre.md` | Appeler le traiteur, commander le gâteau |
| 4 | — | Compter les couchages dès que les réponses arrivent |

**Deux appels suffisent** : un traiteur, un pâtissier. C'est tout ce que la
simplification a laissé.

---

## Le site

`site/public.html` — une page, trois onglets, un parcours en entonnoir.

- **Ma réponse** : trois étapes. 1. dispo, nom, effectif. 2. couchage, arrivée,
  activités. 3. récapitulatif, cagnotte cadeau et envoi WhatsApp.
- **Programme** : samedi et dimanche.
- **Venir à Aix** : les deux gares, avec les temps de trajet réels.

Qui répond « je ne peux pas » saute l'étape 2 : il n'a pas à dire où il dort.
Le champ « d'où arrives-tu » n'apparaît que si on a coché le train.

Tout est retenu dans le navigateur du visiteur. Publié en artifact : le lien
marche immédiatement, sans compte ni mot de passe.

## Le couchage est le seul chiffre qui compte

Plus de gîte à réserver, donc plus de date butoir de réservation. Mais la
maison a une capacité, elle. La page demande explicitement à chacun s'il lui
faut un lit, et le serveur de vote (`vm/`) en fait un compteur direct :
**« N lits à sortir »**.

C'est le seul point sur lequel on ne peut pas improviser la veille.

## L'IBAN

Il est **sur la page publiée, mais pas dans le dépôt**. `site/public.html`
garde les placeholders `__RIB_*__` ; l'injection ne se fait qu'à la publication,
depuis `deploy/rib.env` qui est gitignoré. Ton IBAN ne part pas sur GitHub.

Il est en revanche visible par toute personne ayant le lien — c'est voulu, la
cagnotte est centralisée sur ton compte.

## L'adresse

Elle n'est **pas** sur le site, et la FAQ le dit explicitement : la page circule,
votre adresse non. Elle vit dans le message épinglé du groupe WhatsApp.

---

## Tout coller dans WhatsApp d'un coup

C'est ce que fait `site/kit.html`, publié à côté du site des invités mais
**non listé dans leur menu**. Ouvre-le sur ton téléphone :

- **« Envoyer sur WhatsApp »** ouvre l'application avec le message déjà écrit
  via un lien `wa.me` : tu choisis le groupe, tu relis, tu envoies. Deux gestes.
- **« Copier »** met le texte dans le presse-papiers si tu préfères coller
  toi-même, ou si le lien direct bute sur un message très long.
- **Les sondages ne peuvent pas s'envoyer par lien** — WhatsApp ne le permet
  pas. Fais `＋ → Sondage`, puis copie la question et chaque option d'un tap.
  Le mode (choix unique ou multiple) est affiché sur chaque sondage.

La page est **générée** depuis `02_messages_prets.md` et `03_sondages.md`, donc
elle ne peut pas diverger de la documentation. Après toute modification de ces
deux fichiers :

```bash
python3 anniversaire-elise/whatsapp/build_kit.py
```

> Relis toujours le message dans WhatsApp avant d'envoyer : les `[CROCHETS]`
> non remplis partent tels quels.

---

## Le RIB

Les coordonnées bancaires sont dans `deploy/rib.env`, **gitignoré** comme les
numéros de téléphone. `deploy-anniv.sh` les injecte dans la page au moment de
la publication, en remplaçant les placeholders `__RIB_IBAN__` &co, puis
**refuse de continuer s'il en reste un seul** dans le fichier publié.

Sur une machine neuve :

```bash
cp anniversaire-elise/deploy/rib.env.example anniversaire-elise/deploy/rib.env
$EDITOR anniversaire-elise/deploy/rib.env
```

Sans ce fichier, le déploiement se poursuit et la page affiche « RIB à venir ».

La page porte un bouton **Copier l'IBAN** — un tap, et le virement se fait sans
recopier 27 caractères à la main, qui est la première cause de virement raté.

---

## Le site

Une page unique, sans dépendance ni build : compte à rebours, les deux
trajectoires du samedi, le programme, la checklist de sac (cochée et retenue par
le navigateur), le budget et la FAQ. Responsive, imprimable, `noindex`.

### Déployer sur la VM

```bash
ssh merlin-vm
cd ~/workspace/M.E.R.L.I.N && git pull
bash anniversaire-elise/deploy/deploy-anniv.sh
```

Le script installe Caddy et cloudflared, publie le site sur `127.0.0.1:8791`
derrière un mot de passe, monte un tunnel Cloudflare, **vérifie que la page
renvoie bien 401 sans identifiants**, et affiche l'URL publique et le mot de
passe à coller dans le groupe.

Il est idempotent : relance-le après chaque modification du HTML, le mot de
passe ne change pas.

### Pourquoi ce montage

La stack MERLIN lie tout à `127.0.0.1` et ne s'atteint que par tunnel SSH — ce
qui est parfait pour toi, et inutilisable par dix invités sur leur téléphone.
Le tunnel Cloudflare résout ça sans rien ouvrir : la connexion part **de** la VM
**vers** Cloudflare. Aucune modification du Terraform, aucune règle d'ingress,
aucun port exposé, et HTTPS de bout en bout.

### Le mot de passe n'est pas décoratif

L'URL du tunnel est aléatoire, mais une URL aléatoire n'est pas un secret : elle
transite dans un groupe WhatsApp de douze personnes, elle sera copiée-collée,
elle finira peut-être dans un presse-papier partagé. Le `basic_auth` de Caddy est
la vraie barrière — et le script refuse de terminer si la page répond autre
chose que 401 sans identifiants.

### URL stable

Une URL `*.trycloudflare.com` **change à chaque redémarrage du tunnel**. Tant
que tu ne redémarres pas le service, elle tient. Pour une URL qui ne bouge pas
jusqu'au 3 octobre, et si tu as un domaine sur Cloudflare :

```bash
cloudflared tunnel login
cloudflared tunnel create anniv-elise
cloudflared tunnel route dns anniv-elise anniv.tondomaine.fr
```

puis remplace la ligne `ExecStart` de `/etc/systemd/system/anniv-elise-tunnel.service`
par `cloudflared tunnel run anniv-elise` et `systemctl daemon-reload && systemctl restart anniv-elise-tunnel`.

### Après la fête

```bash
sudo systemctl disable --now anniv-elise-web anniv-elise-tunnel
sudo rm -rf /opt/anniv-elise /etc/anniv-elise.cred /etc/caddy/Caddyfile.anniv
```

---

## Les numéros de téléphone

Les 9 numéros de la capture sont dans `whatsapp/contacts_source.txt`,
**gitignoré** avec `contacts.csv` et `contacts.vcf`. Ce dépôt part sur GitHub ;
les numéros de tiers n'ont rien à y faire. `contacts.md`, lui, est commité et ne
contient que les noms.

Pour régénérer le fichier à importer dans le téléphone :

```bash
python3 anniversaire-elise/whatsapp/build_contacts.py
```

Les neuf numéros sont tous des mobiles français — les tirets de la capture
(`063-998-1234`) sont un artefact d'affichage, pas un indicatif étranger.

---

## Les placeholders à remplir

Le site et les messages contiennent des `[CROCHETS]` à compléter une fois le
gîte réservé :

```bash
grep -rn '\[[A-Z]' anniversaire-elise/site/index.html anniversaire-elise/whatsapp/
```

| Placeholder | Où le trouver |
|-------------|---------------|
| `[NOM DU GÎTE]`, `[ADRESSE COMPLÈTE]` | confirmation de réservation |
| `[LIEN GOOGLE MAPS]` | Maps → Partager → copier le lien |
| `[CO-ADMIN]`, `[TÉLÉPHONE]` | la personne que tu désignes |
| `[MOT DE PASSE]` | affiché par `deploy-anniv.sh` |
| Le RIB | déjà rempli via `deploy/rib.env` — rien à faire |
| `[PLAN B PARKING]` | à demander au propriétaire |

---

## Ce que ce kit ne fait pas

- **Rien n'est réservé.** Ni gîte, ni dégustation, ni gâteau. Les disponibilités
  d'un week-end précis ne se consultent qu'en direct auprès de chaque
  plateforme. `docs/locations-pistes.md` te donne les canaux, les critères et un
  message type — la réservation, c'est toi.
- **Le groupe WhatsApp n'est pas créé.** WhatsApp n'a pas d'API pour les comptes
  personnels : la création se fait à la main, en dix minutes, en suivant
  `whatsapp/01_creation_groupe.md`.
- **Le site n'est pas déployé.** La VM Oracle n'est pas joignable depuis cette
  session ; `deploy/deploy-anniv.sh` s'exécute depuis la VM.
- **Les horaires et tarifs sont à reconfirmer.** Sentier des Ocres, Colorado
  Provençal, caves, Sun-E-Bike : relevés pour la saison 2026 (voir
  `docs/activites.md`), mais un coup de fil au J-14 ne coûte rien — les
  horaires d'arrière-saison bougent.
- **Aucun sondage n'est créé.** WhatsApp ne permet pas de pré-remplir un
  sondage par lien ; `site/kit.html` réduit ça à un tap par ligne.
