# L'invitation hébergée, gratuitement

Cloudflare **Pages + Functions + D1**. Palier gratuit, **sans carte bancaire** :
100 000 requêtes par jour, 100 000 écritures par jour, 5 Go de base. Pour neuf
invités, c'est six ordres de grandeur au-dessus du besoin.

Ce que ça ajoute par rapport à la page publiée sur claude.ai : les réponses
vivent sur un serveur au lieu du navigateur de chacun, tout le monde voit les
compteurs, et **une même personne ne peut pas répondre deux fois**.

## Déployer

```bash
bash anniversaire-elise/cloudflare/deploy.sh
```

Il faut un compte Cloudflare — gratuit, deux minutes, une adresse e-mail. Le
script ouvre la page de connexion au premier lancement, crée la base, applique
le schéma, publie la page, pose le jeton d'administration et vérifie que l'API
répond avant d'afficher l'URL.

Relancer le script met la page à jour **sans toucher aux réponses déjà
données**.

> `deploy/rib.env` doit être présent : c'est de là que viennent l'IBAN et
> l'adresse, qui ne sont pas dans le dépôt. Sans lui, la page s'affiche avec
> « coordonnées à venir ».

## Comment la double réponse est empêchée

Deux garde-fous, l'un derrière l'autre :

1. **Un cookie** identifie le navigateur. Revenir sur la page recharge sa
   propre réponse, et l'enregistrer la met à jour.
2. **Le nom, normalisé**, porte un index unique en base. Accents, casse et
   espaces multiples sont ramenés à une forme commune, donc « Anne-Sophie »,
   « anne sophie » et « ANNE   SOPHIE » sont la même personne. Répondre depuis
   un autre téléphone met donc à jour la ligne existante au lieu d'en créer
   une seconde.

La normalisation s'arrête là volontairement : « Marine » et « Marine S. »
restent deux entrées. Mieux vaut un doublon visible qu'une réponse écrasée à
tort.

## Les routes

| Route | Ce qu'elle fait |
|-------|-----------------|
| `GET /api/etat` | Compteurs publics. Prénoms seulement — la page est publique |
| `POST /api/reponse` | Enregistre ou met à jour. Renvoie `deja: true` si la personne avait déjà répondu |
| `GET /api/admin?token=…` | Le détail complet, en JSON |
| `GET /api/admin?token=…&format=csv` | Le même, en CSV |

Le jeton est tiré au hasard au premier déploiement et gardé dans
`cloudflare/.admin-token`, gitignoré.

## Ce qui est vérifié, et ce qui ne l'est pas

Les réponses acceptées ne sont pas recopiées dans la fonction : `build.py` les
relève dans la page et les écrit dans `valeurs.json`, que la fonction importe.
Le formulaire et sa validation ne peuvent pas diverger. Toute valeur hors liste
est refusée en 400.

Le nombre de personnes est borné à 10, le nom à 60 caractères, les champs
libres tronqués. Les cellules du CSV commençant par `=` `+` `-` `@` sont
neutralisées : Excel les lirait comme des formules.

## Repasser le lien dans les messages

L'URL en `*.pages.dev` ne change pas d'un déploiement à l'autre. Une fois
obtenue :

```bash
python3 anniversaire-elise/whatsapp/build_messages.py --url "https://…pages.dev"
python3 anniversaire-elise/whatsapp/build_kit.py     --url "https://…pages.dev"
```

## Et la version VM ?

`vm/` fait la même chose sur ta machine, avec un tunnel Cloudflare. Les deux
partagent le script de synchronisation et la génération de `valeurs.json` —
elles parlent à la même API. Choisis l'une **ou** l'autre : héberger les deux
disperserait les réponses dans deux bases.

La version Pages a deux avantages : l'URL est stable, et il n'y a rien à
laisser allumé chez toi.
