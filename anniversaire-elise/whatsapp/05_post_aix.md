# Le message à poster — Aix, 10-11 octobre

Le lien de l'invitation est écrit en clair dans les messages ci-dessous.
S'il change — nouvel hébergement, nouveau nom de domaine — une seule commande
le remplace partout, ici comme dans les deux générateurs&nbsp;:

```bash
python3 anniversaire-elise/whatsapp/set_url.py https://…
```

> ⚠️ **`[ADRESSE]` reste un placeholder ici, et c'est volontaire.**
> Le dépôt `merlingame-netizen/M.E.R.L.I.N` est **public** : l'adresse du
> domicile n'y a pas sa place, pas plus que l'IBAN. Elle est stockée dans
> `deploy/rib.env`, gitignoré.
>
> Pour obtenir ces messages tout remplis, sans rien recopier à la main :
> ```bash
> python3 anniversaire-elise/whatsapp/build_messages.py
> ```
> Le fichier produit (`messages_prets.md`) est lui aussi gitignoré.

---

## Créer le groupe depuis un iPhone

Trois étapes, dix minutes. Tout est déjà produit, il n'y a rien à recopier.

### 1. Importer les neuf contacts

`whatsapp/contacts.vcf` est une carte de visite multiple au format vCard 3.0,
avec les numéros normalisés en `+33` et le type `CELL` — c'est ce format que
WhatsApp utilise pour reconnaître un contact.

Régénère-la si besoin&nbsp;:

```bash
python3 anniversaire-elise/whatsapp/build_contacts.py
```

Puis, sur l'iPhone, au choix&nbsp;:

- **AirDrop** depuis le Mac → l'iPhone propose « Ajouter les 9 contacts ».
- **Fichiers** : dépose `contacts.vcf` dans iCloud Drive, ouvre-le depuis
  l'app Fichiers, puis *Ajouter tous les contacts*.
- **Mail** : envoie-toi le fichier, touche la pièce jointe, *Ajouter tous
  les contacts*.

Tous portent le libellé `Anniv Elise 30` : dans Contacts, un groupe
« Anniv Elise 30 » apparaît, ce qui évite de les chercher un par un.

> Si un contact existe déjà avec un autre format de numéro, iOS propose de
> fusionner. Accepte&nbsp;: WhatsApp se cale sur le numéro E.164.

### 2. Créer le groupe WhatsApp

WhatsApp → **Discussions** → ✏️ en haut à droite → **Nouveau groupe**.
Les neuf contacts remontent en tapant leur prénom. Nom du groupe et
description ci-dessous — les deux se collent tels quels.

### 3. Coller, puis épingler

Colle le **message A** dans le groupe, puis maintiens-le appuyé →
**Épingler**. Il est court : tout le détail vit sur la page, où il reste
à jour. L'adresse, elle, n'est que dans le message C et le message D.

> Les messages avec l'URL, l'adresse et l'IBAN déjà dedans sont dans
> `whatsapp/messages_prets.md`, produit par&nbsp;:
> ```bash
> python3 anniversaire-elise/whatsapp/build_messages.py
> ```
> Ce fichier-là est gitignoré : c'est le seul qui porte l'adresse en clair.

---

## Nom du groupe

```
Anniv Elise — 10/11 oct à Aix
```

## Description du groupe

```
Les 30 ans d'Elise — samedi 10 → dimanche 11 octobre 2026, chez nous à Aix.
Samedi à partir de 14h, dimanche jusqu'au milieu de l'après-midi.
Tout est sur la page : programme, itinéraire, votes et cagnotte.

Répondez ici : https://claude.ai/code/artifact/29f10c22-6058-494a-bd9a-15bbab495e66
Réponses avant le vendredi 25 septembre.

📍 L'adresse est sur la page, dans « Comment venir ».
```

---

## Message A — l'annonce ⏱ maintenant, **à épingler**

```
✨ ELISE A 30 ANS ✨

Et on fête ça chez nous, à Aix, le week-end du 10 octobre.
Vous êtes invités — tous les neuf.

📅  Samedi 10 octobre, 14h → dimanche 11, milieu d'après-midi
🏡  Chez nous, à Aix. L'adresse et l'itinéraire sont sur la page.

Au programme : mölkky au parc, escape game, apéro dînatoire,
gâteaux, jeux jusqu'à pas d'heure. Et le dimanche, ce que vous
voulez.

👉  TOUT EST LÀ, EN PHOTOS :
https://claude.ai/code/artifact/29f10c22-6058-494a-bd9a-15bbab495e66

Sur la page, en trois minutes :
· vous dites si vous venez, quand vous arrivez et quand vous repartez
· l'itinéraire s'affiche tout seul, vers le bon endroit selon votre heure
· vous votez ce qui vous tente — la salle d'escape, les parfums des
  deux gâteaux, la suite de la soirée
· vous signalez vos allergies

⏳  Réponse avant le VENDREDI 25 SEPTEMBRE.
Passé cette date je réserve, et c'est trop tard pour changer.

Des questions ? Ici, je réponds 🙂
```

## Message B — relance ⏱ J-7, **en privé**

```
Hey [PRÉNOM] ! Il me manque ta réponse pour les 30 ans d'Elise
(10-11 octobre, chez nous à Aix). Deux minutes : https://claude.ai/code/artifact/29f10c22-6058-494a-bd9a-15bbab495e66

Le programme est en photos sur la page. J'ai surtout besoin de savoir
si tu fais l'escape game, et quand tu arrives 🙏
```

## Message C — le récapitulatif ⏱ vers le 20 septembre

```
📋 ON SERA [N] !

🎯 Escape game : [X] participants, [X] salles réservées.

🚆 Les arrivées du samedi :
[HEURE] — [PRÉNOMS] — Aix TGV
[HEURE] — [PRÉNOMS] — Aix centre
Si votre train change, dites-le ici.

🥾 Activité du samedi : [ACTIVITÉ] — [X] voix

📍 L'adresse : [ADRESSE]

Le programme complet est toujours sur https://claude.ai/code/artifact/29f10c22-6058-494a-bd9a-15bbab495e66
```

## Message D — la veille ⏱ vendredi 9 octobre

```
🎒 DEMAIN !

📍 [ADRESSE] — on vous attend à partir de 14h.
🚌 L'itinéraire est sur la page, dans votre réponse. Pensez à la carte sans
   contact pour le bus.

Dans le sac : trousse de toilette, une serviette si vous en avez une facile
à emporter, des chaussures pour marcher si vous avez voté une balade dimanche,
et une petite laine — il fera 12 °C le soir.

Rien d'autre. Vraiment.

À demain 💛
```
