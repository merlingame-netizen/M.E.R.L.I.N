# 1 — Créer le groupe WhatsApp (10 minutes, à faire en premier)

Mode retenu : **surprise totale**. Elise n'est pas dans ce groupe et ne doit
jamais en soupçonner l'existence.

---

## Étape 0 — Importer les contacts

Les 9 invités doivent être dans le répertoire du téléphone, sinon WhatsApp
refuse de les ajouter au groupe.

```bash
python3 whatsapp/build_contacts.py     # génère contacts.vcf
```

Envoie-toi `contacts.vcf` par mail, ouvre-le sur le téléphone → « Importer tous
les contacts ». Ils arrivent taggés `Anniv Elise 30`, faciles à retrouver et à
supprimer après.

---

## Étape 1 — Nom du groupe

**⚠️ Le piège n°1 de la surprise.** WhatsApp affiche le nom du groupe dans
la notification, dans l'aperçu de l'écran verrouillé et dans le partage
d'écran. Si Elise jette un œil au téléphone d'une invitée pendant un café, un
groupe nommé « 🎉 SURPRISE 30 ANS ELISE 🎉 » fait tout tomber.

**Nom à utiliser :**

```
Rando Luberon — 3/4 oct
```

Ennuyeux, plausible, illisible pour un œil extérieur. C'est exactement le but.

**Alternatives aussi neutres** si celle-ci ne colle pas à votre cercle :
`Week-end Vaucluse`, `Covoit' 3 octobre`, `Sortie Apt`.

**À ne surtout pas utiliser :** tout ce qui contient *Elise*, *30 ans*,
*anniv*, *surprise*, ou un emoji festif.

## Étape 2 — Photo du groupe

Un paysage du Luberon. **Pas** de photo d'Elise, pas de ballons, pas de gâteau.
La photo apparaît elle aussi dans les notifications.

## Étape 3 — Description du groupe

Menu ⋮ → Infos du groupe → Description. À copier tel quel :

```
Samedi 3 → dimanche 4 octobre 2026, Luberon.
Les 30 ans d'Elise. Elle ne sait rien. On tient jusqu'au bout.

H = samedi 17h00 précises, au gîte. Sois là à 14h30.

Tout le programme, l'adresse et la checklist :
https://VOTRE-URL-ICI
(identifiants dans le message épinglé)

Aucun post public, aucune story, aucun tag jusqu'à dimanche soir.
Question ? Écris ici, jamais à Elise.
```

## Étape 4 — Réglages (le point qu'on oublie)

Infos du groupe → **Autorisations de groupe** :

| Réglage | Valeur | Pourquoi |
|---------|--------|----------|
| Envoyer des messages | **Tous les participants** | Il faut que ça vive, sinon personne ne répond aux sondages |
| Modifier les infos du groupe | **Admins uniquement** | Empêche un renommage enthousiaste en « ANNIV ELISE 🎂 » |
| Ajouter d'autres participants | **Admins uniquement** | Empêche l'ajout accidentel d'Elise — c'est arrivé à d'autres |
| Approuver les nouveaux participants | **Activé** | Deuxième filet sous le premier |

Puis **désigne un co-admin tout de suite** : le samedi tu seras avec Elise,
téléphone sous surveillance, incapable de piloter quoi que ce soit.

## Étape 5 — Ajouter les 9 invités

Ajoute-les **tous en une fois**, pas au fil de l'eau : chaque ajout génère une
notification système, et neuf vagues d'ajouts sur trois jours donnent une
conversation illisible où les premiers arrivés ont déjà tout dit.

## Étape 6 — Épingler le message d'accueil

Poste le message d'accueil (`02_messages_prets.md`, message A), puis
appui long → **Épingler** → **30 jours**. C'est ce que verra chaque invité en
ouvrant le groupe, sans avoir à remonter la conversation.

---

## Règle de sécurité à rappeler le jour de la création

> Un anniversaire surprise ne se fait pas trahir par un bavard. Il se fait
> trahir par une story Instagram, un « à samedi ! » envoyé dans la mauvaise
> fenêtre, et une notification lue par-dessus l'épaule.

Trois consignes, dans le message d'accueil, en toutes lettres :

1. **Rien en ligne** avant dimanche soir : pas de story, pas de post, pas de tag.
2. **Ne jamais répondre à Elise depuis ce fil.** Vérifier le nom du destinataire
   avant chaque envoi — c'est la fuite la plus fréquente.
3. **Notifications en sourdine** pour qui voit Elise d'ici le 3 octobre.
