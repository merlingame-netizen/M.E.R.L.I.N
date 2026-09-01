# Les 30 ans d'Elise — 3 & 4 octobre 2026, Luberon

Kit complet : groupe WhatsApp, programme, budget, et le site à déployer sur la
VM Oracle.

**Paramètres retenus** — surprise totale · Luberon · 80-120 €/pers · 12 personnes
· samedi 3 (17h00) → dimanche 4 octobre 2026.

---

## Par où commencer

| Ordre | Fichier | Ce que tu y fais |
|-------|---------|------------------|
| 1 | `whatsapp/01_creation_groupe.md` | Créer le groupe. **10 minutes, et ça bloque tout le reste** |
| 2 | `whatsapp/02_messages_prets.md` | Copier-coller le message d'accueil (A) |
| 3 | `whatsapp/03_sondages.md` | Poster les sondages 1 et 2 |
| 4 | `docs/locations-pistes.md` | Chercher le gîte, contacter 5-6 propriétaires |
| 5 | `deploy/deploy-anniv.sh` | Déployer le site **et le kit de copie** sur la VM |
| 6 | `site/kit.html` | Depuis ton téléphone : envoyer chaque message en 2 gestes |
| 7 | `whatsapp/04_retroplanning.md` | Suivre le calendrier jusqu'au 3 octobre |

**Aujourd'hui (dim. 30 août), il reste 34 jours.** La seule chose vraiment
urgente : le gîte. Tout le reste peut attendre une semaine sans dommage.

---

## Le contenu

```
anniversaire-elise/
├── whatsapp/
│   ├── 01_creation_groupe.md   nom du groupe, réglages, pièges de la surprise
│   ├── 02_messages_prets.md    7 messages à copier-coller (A → G)
│   ├── 03_sondages.md          8 sondages, questions et options rédigées
│   ├── 04_retroplanning.md     qui poste quoi, quel jour, jusqu'au 3 octobre
│   ├── contacts.md             les 9 invités + les rôles à distribuer
│   ├── build_contacts.py       normalise les numéros → contacts.vcf
│   └── build_kit.py            génère site/kit.html depuis les 2 md ci-dessus
├── docs/
│   ├── programme.md            samedi/dimanche heure par heure, les 2 trajectoires
│   ├── activites.md            catalogue vérifié : tarifs, horaires, téléphones
│   ├── budget.md               1 432 € / 120 € par personne, détaillé
│   └── locations-pistes.md     où chercher le gîte, critères, message type
├── site/
│   ├── index.html              le site des invités
│   └── kit.html                page-outil : copier/envoyer sur WhatsApp (généré)
└── deploy/
    ├── deploy-anniv.sh         déploiement complet sur la VM Oracle
    ├── Caddyfile               Caddy + basic auth sur 127.0.0.1:8791
    └── rib.env.example         gabarit des coordonnées bancaires
```

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
