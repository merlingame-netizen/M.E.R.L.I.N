# _shared — Business Rules : rédaction des mails (Maxime)

> **Statut : RÈGLE PERMANENTE, non négociable.** S'applique à TOUT mail rédigé ou
> proposé par l'agent (Outlook pro Orange, Gmail perso, relances, comptes rendus).
> Décrété 2026-09-10. Toute rédaction de mail commence par la lecture de ce fichier.

---

## 1. Interdits absolus (bannis DÉFINITIVEMENT)

| Interdit | Pourquoi | À la place |
|----------|----------|------------|
| **« Ce que j'attends de vous »** (+ variantes : « Ce que j'attends de toi », « Mes attentes », « Ce que j'attends de votre part », rubrique/titre « Attendus ») | Formule jamais employée par Maxime, marqueur immédiat de rédaction IA + ton descendant | Demande directe en une phrase : « Peux-tu me confirmer X avant vendredi ? » |
| Sections titrées en gras dans un mail court (**Contexte** / **Objectif** / **Actions** / **Prochaines étapes**) | Structure de rapport IA, pas d'un mail | Paragraphes courts ; puces uniquement s'il y a ≥ 3 points réellement distincts |
| « J'espère que ce message vous trouve bien », « En espérant que tout va bien » | Calque anglo-saxon, jamais utilisé | Aller droit au sujet |
| « Je me permets de revenir vers vous », « Je reviens vers vous concernant » | Formule ampoulée | « Je relance sur… », « Petit rappel sur… » |
| « N'hésitez pas à revenir vers moi pour toute question complémentaire » | Marqueur IA le plus courant | « Dis-moi si besoin. » / « Je reste dispo si besoin. » |
| Tirets cadratins (—), points-virgules décoratifs, emojis, gras à outrance | Typographie non naturelle en mail | Virgule, point, parenthèse |
| Triades rhétoriques (« rapide, fiable et scalable »), superlatifs (« crucial », « essentiel », « robuste ») | Style LLM | Vocabulaire plat et factuel |
| Reformuler la demande reçue avant d'y répondre | Remplissage | Répondre directement |
| Signature auto-générée type « Bien cordialement, [Prénom Nom] — [Fonction] » | Redondant avec la signature Outlook | Voir §4 |

**Contrôle avant envoi** : relire et supprimer toute phrase qui ne survivrait pas à
la question « est-ce que je dirais ça à l'oral à cette personne ? ».

## 2. Forme par défaut

- **Longueur** : 3 à 8 lignes. Au-delà de 12 lignes → soit une pièce jointe, soit un point de 15 min.
- **Objet** : nominal, sans verbe conjugué, sujet + périmètre. Ex. `Dataset Propension — refresh KO du 09/09`, `Point CRA septembre`, `RDV vendredi 14h ?`.
- **Une seule demande par mail.** Si deux sujets → deux mails.
- **Deadline explicite** quand il y en a une, jamais « dès que possible ».
- Puces courtes, sans point final, sans phrase d'introduction du type « Voici les éléments ci-dessous : ».
- Pas de PS, pas de citations, pas de mise en forme colorée.
- Tutoiement par défaut avec l'équipe et les interlocuteurs directs ; vouvoiement pour hiérarchie N+2, externes, premier contact.

## 3. Banque de formulations (registre habituel)

À piocher telles quelles. Ne pas inventer de variantes plus « écrites ».

**Ouverture**
- « Bonjour Prénom, »
- « Bonjour à tous, »
- « Bonjour Prénom, merci pour ton retour. »
- « Bonjour, suite à notre échange de ce matin, »

**Contexte / info (1 phrase max)**
- « Pour info, … »
- « Suite au point de ce matin, … »
- « Comme convenu, … »
- « J'ai regardé le sujet X, voilà où on en est : »
- « Petit point sur X. »

**Demande**
- « Peux-tu me confirmer … ? »
- « Est-ce que tu peux regarder … avant [date] ? »
- « J'aurais besoin de … pour pouvoir avancer. »
- « Il me manque … pour finaliser. »
- « Tu peux me dire si c'est OK de ton côté ? »
- « Qui est le bon interlocuteur pour … ? »

**Relance**
- « Je relance sur le sujet X. »
- « Petit rappel sur ma demande du [date]. »
- « Je me permets une relance, on est bloqués sur … »
- « Toujours en attente de … de votre côté. »

**Livraison / transmission**
- « Tu trouveras en pièce jointe … »
- « C'est en ligne, tu peux regarder. »
- « Le rapport est à jour, les chiffres sont dispos depuis ce matin. »
- « J'ai corrigé le point remonté, c'est rechargé. »

**Réserve / désaccord (jamais frontal, jamais mou)**
- « De mon côté je vois plutôt … »
- « Attention, ça implique … »
- « Sur ce point je ne suis pas sûr que ce soit faisable dans les délais. »
- « OK pour moi, sous réserve de … »

**Clôture**
- « Merci d'avance. »
- « Dis-moi si besoin. »
- « Je reste dispo si besoin. »
- « Bonne journée, »
- « Cordialement, » (vouvoiement / externe)
- « Bien à vous, » (formel, rare)

**Signature** : prénom seul en interne (« Maxime »), rien de plus — la signature
Outlook fait le reste.

## 4. Corpus réel (à alimenter)

Ce fichier reste la source de vérité. Le corpus est raffiné à partir des **mails
réellement envoyés** (Éléments envoyés Outlook, poste Windows uniquement) :

```bash
python tools/mail_style_mine.py --limit 200        # analyse + rapport
python tools/mail_style_mine.py --limit 200 --write # + met à jour §5 ci-dessous
```

La section §5 est générée automatiquement ; §1 à §3 sont écrites à la main et
priment en cas de conflit.

## 5. Formulations extraites du corpus

_(vide — lancer `tools/mail_style_mine.py --write` depuis le poste Windows avec Outlook ouvert)_
