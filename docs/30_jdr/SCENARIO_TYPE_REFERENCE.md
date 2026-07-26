# ᚛ La Dette de Tourbe ᚜

> **Scénario type de référence — canon bible v4.0.** Archétype `mist_wanderer` · pôle Liminal · twist `lost_then_found` · **11 cartes** · branchement narratif.
>
> Écrit à la main : c'est la **cible** que la génération LLM doit atteindre, pas un échantillon de ce qu'elle produit. Jamais injecté comme modèle de contenu.

## La graine qui l'a produit

Ce sont les cinq contraintes tirées avant génération. Elles seules garantissent qu'aucun scénario ne ressemble au précédent.

- **lieu** — tourbiere
- **entite centrale** — un vivant qu'on croit mort
- **pression** — une dette a honorer
- **registre sensoriel** — odeur
- **mecanisme du twist** — identite (qui est vraiment la)

*Tu viens payer ta dette à un noyé, et le noyé respire encore.*

## Accroche

> La tourbe ne sent pas la vase : elle sent le pain brûlé, et cette odeur te suit depuis l'aube.

## Intro (parchemin d'ouverture)

Il y a un an, Maël Kerlan s'est enfoncé dans la tourbière du Yeun et n'en est pas ressorti. Tu lui devais trois pièces et une promesse, et on ne laisse pas une dette à un mort. Sa veuve vit encore au bord du marais, dans une maison qui sent la fumée froide. Tu marches depuis l'aube avec les pièces cousues dans ta manche. L'odeur te prévient avant le paysage : la tourbe ne sent pas la vase, elle sent le pain brûlé et le fer. On dit que le Yeun garde ce qu'il prend et ne le rend jamais entier. Tu vas apprendre que ce n'est pas tout à fait vrai.

## Structure

| Acte | Cartes | Types | Émotions |
|---|---|---|---|
| 1 | 1–3 | 2×NARRATIVE, 1×EVENT | curiosite, fascination, tension |
| 2 | 4–5 | 1×SHOP, 1×NARRATIVE | fascination, tension |
| 3 | 6–7 | 1×MERLIN_DIRECT, 1×NARRATIVE | peur, tension |
| 4 | 8–9 | 1×PROMISE, 1×NARRATIVE | fascination, peur |
| 5 | 10–11 | 1×NARRATIVE, 1×MERLIN_DIRECT | tension, sagesse |

## Lecture d'équilibrage

Chaque effet est converti en **PV-équivalent** (vie 1.0 · essence 0.8 · réputation 0.4/pt · Anam 2.0), puis pondéré par la chance de réussite du premier run — 60 % à stat 1. L'écart entre les trois options doit rester **sous 2.0 PV-eq** : c'est ce qui empêche une ligne de jeu d'être mécaniquement supérieure aux deux autres.

| Carte | Acte | Épreuve de la carte | EV prudente | EV équilibrée | EV audacieuse | Écart |
|---|:---:|---|---:|---:|---:|---:|
| 1. NARRATIVE | 1 | blanche | +0.24 | +0.32 | +0.40 | 0.16 |
| 2. NARRATIVE | 1 | blanche | +0.24 | +0.32 | +0.40 | 0.16 |
| 3. EVENT | 1 | blanche | +1.44 | +0.32 | +0.40 | 1.12 |
| 4. SHOP | 2 | blanche | +1.68 | +2.24 | +0.88 | 1.36 |
| 5. NARRATIVE | 2 | blanche | +0.24 | +0.32 | +0.40 | 0.16 |
| 6. MERLIN_DIRECT | 3 | **contextuelle** | +0.32 | -0.56 | -0.48 | 0.88 |
| 7. NARRATIVE | 3 | **ROUGE** (télégraphiée) | +0.80 | -0.32 | +0.56 | 1.12 |
| 8. PROMISE | 4 | blanche | +0.32 | +0.80 | +0.88 | 0.56 |
| 9. NARRATIVE | 4 | blanche | -0.16 | +0.32 | +0.40 | 0.56 |
| 10. NARRATIVE | 5 | **contextuelle** | +0.32 | -0.32 | -0.24 | 0.64 |
| 11. MERLIN_DIRECT | 5 | blanche | +6.08 | +7.12 | +7.60 | 1.52 |

**Mix d'épreuves** — white 8/11 (73%) · contextuel 2/11 (18%) · red 1/11 (9%). Cible bible §26.2 : 75 / 15 / 8 / 2 %.

Les `effects` listés sous chaque option sont le **gain en cas de réussite**. Le coût du risque vit uniquement dans les dégâts d'échec — aucune option ne facture l'audace deux fois.

## Le déroulé complet

### Carte 1 — acte 1 · NARRATIVE · COMMUNE · *curiosite*

**Situation.** La maison de la veuve fume sans feu. Sur le seuil, une paire de bottes d'homme, seches, tournees vers la porte comme si quelqu'un venait de rentrer.

**Frapper et attendre** — *prudente* · anciens · épreuve volonte/white · échec −3 PV · EV +0.24

> Tu frappes trois coups et le silence dure assez pour que tu comptes tes battements. La porte s'ouvre sur une femme qui n'a pas l'air surprise. « Tu es en retard d'un an », dit-elle sans reproche.

*Effets — désormais visibles au HUD :* anciens +6

**Examiner les bottes** — *equilibree* · druides · épreuve logic/white · échec −4 PV · EV +0.32

> Le cuir est sec et la semelle propre. La tourbe ne pardonne pas : personne n'a marche dans le marais avec ces bottes. Elles ont ete posees la pour etre vues.

*Effets — désormais visibles au HUD :* druides +8 · marqueur « bottes_seches »

**Entrer sans annoncer** — *audacieuse* · korrigans · épreuve instinct/white · échec −5 PV · EV +0.40

> Tu pousses la porte. La piece est tiede, la table mise pour deux, et une main referme derriere toi. « Il vaut mieux que personne ne t'ait vu entrer », dit la veuve.

*Effets — désormais visibles au HUD :* korrigans +10


### Carte 2 — acte 1 · NARRATIVE · COMMUNE · *fascination*

**Situation.** La veuve pose les trois pieces sur la table sans les compter et les repousse vers toi. « Ce n'est pas ca qu'il attend », dit-elle en regardant la fenetre.

**Demander ce qu'il attend** — *prudente* · niamh · épreuve empathie/white · échec −3 PV · EV +0.24

> Elle met longtemps a repondre. « Qu'on le sorte », finit-elle par dire, et elle ne precise pas d'ou. Tu comprends que la question etait la bonne et que la reponse ne t'aidera pas.

*Effets — désormais visibles au HUD :* niamh +6

**Reposer les pieces sur la table** — *equilibree* · anciens · épreuve volonte/white · échec −4 PV · EV +0.32

> Tu remets les pieces au milieu de la table. Elle ne les touche pas, mais quelque chose se detend dans ses epaules : la dette existe encore, et tant qu'elle existe, il y a une raison de te garder.

*Effets — désormais visibles au HUD :* anciens +8

**Suivre son regard** — *audacieuse* · druides · épreuve logic/white · échec −5 PV · EV +0.40

> Par la fenetre, la tourbiere fume au ras du sol. A deux cents pas, une planche a ete jetee en travers d'une fosse — recemment, le bois est encore clair. Quelqu'un traverse regulierement.

*Effets — désormais visibles au HUD :* druides +10 · marqueur « vu_la_fenetre »


### Carte 3 — acte 1 · EVENT · COMMUNE · *tension*

**Situation.** Dehors, l'odeur de pain brule s'epaissit d'un coup. Trois oiseaux partent ensemble de la meme touffe de bruyere, sans qu'aucun bruit ne les ait leves.

**Rester immobile** — *prudente* · anciens · épreuve volonte/white · échec −3 PV · EV +1.44

> Tu ne bouges pas. Au bout d'un moment, la bruyere se referme et l'odeur reflue. Ce qui passait est passe sans te voir, et tu respires mieux d'avoir su ne rien faire.

*Effets — désormais visibles au HUD :* anciens +6 · vie +2

**Chercher l'origine de l'odeur** — *equilibree* · korrigans · épreuve instinct/white · échec −4 PV · EV +0.32

> Tu remontes l'odeur a contre-vent. Elle vient d'un trou dans la tourbe ou quelque chose a brule lentement, longtemps, et sous les cendres il y a du tissu qui n'a pas fini de se consumer.

*Effets — désormais visibles au HUD :* korrigans +8 · marqueur « trace_fumee »

**Appeler le nom du mort** — *audacieuse* · ankou · épreuve volonte/white · échec −5 PV · EV +0.40

> Tu cries « Mael ». La tourbiere avale le son sans echo, puis te le rend — une seule fois, de beaucoup plus loin, et ce n'est pas ta voix. Quelque chose dans le marais vient d'apprendre le tien.

*Effets — désormais visibles au HUD :* ankou +10


### Carte 4 — acte 2 · SHOP · RARE · *fascination*

**Situation.** Un tourbier charge sa brouette au bord du chemin. Il vend ce qu'il trouve dans le marais : de la corde grasse, une lampe a huile, un couteau a lame courte.

**Acheter la corde** — *prudente* · anciens · épreuve volonte/white · échec −3 PV · EV +1.68

> Il te tend une corde epaisse de graisse de mouton. « Elle ne pourrit pas dans la tourbe », dit-il. « Et si tu tombes, elle ne te lachera pas — c'est toi qui la lacheras. »

*Effets — désormais visibles au HUD :* essence +6 · marqueur « corde »

**Acheter la lampe** — *equilibree* · druides · épreuve logic/white · échec −4 PV · EV +2.24

> La lampe est cabossee et son verre fume. Il la remplit devant toi et te previent : « Dans le Yeun, elle ne t'eclaire pas, elle te signale. A toi de savoir a qui. »

*Effets — désormais visibles au HUD :* essence +8 · marqueur « lampe »

**Lui demander qui traverse** — *audacieuse* · korrigans · épreuve instinct/white · échec −5 PV · EV +0.88

> Il arrete de charger. « Personne ne traverse », dit-il trop vite, puis il reprend sa brouette et ajoute sans se retourner : « Et si quelqu'un traversait, il vaudrait mieux ne pas l'avoir vu. »

*Effets — désormais visibles au HUD :* korrigans +12 · marqueur « tourbier_parle »


### Carte 5 — acte 2 · NARRATIVE · COMMUNE · *tension*

**Situation.** La planche jetee en travers de la fosse tient a peine. Dessous, l'eau noire ne bouge pas, et l'odeur de pain brule monte de la, pas du reste du marais.

**Sonder avant de passer** — *prudente* · druides · épreuve logic/white · échec −3 PV · EV +0.24

> Tu enfonces ton baton. Il descend d'une brasse, puis butte sur quelque chose qui n'est ni pierre ni racine — quelque chose qui cede un peu, puis resiste. Tu ne recommences pas.

*Effets — désormais visibles au HUD :* druides +6

**Traverser en courant** — *equilibree* · korrigans · épreuve instinct/white · échec −4 PV · EV +0.32

> Tu passes en trois enjambees. La planche plie au milieu et te lache juste apres ; tu t'etales de l'autre cote, les mains dans la tourbe tiede, et quelque chose sous la surface te rend ta poussee.

*Effets — désormais visibles au HUD :* korrigans +8

**Retirer la planche** — *audacieuse* · ankou · épreuve volonte/white · échec −5 PV · EV +0.40

> Tu tires la planche et la jettes dans la bruyere. Celui qui traverse ne traversera plus — mais toi non plus, et il te faudra contourner par le nord, ou la tourbe est plus molle et te prend jusqu'aux genoux.

*Effets — désormais visibles au HUD :* ankou +10


### Carte 6 — acte 3 · MERLIN_DIRECT · EPIQUE · *peur*

**Situation.** Merlin parle sans que tu l'aies appele. « Regarde mieux la fosse, voyageur. On n'y a rien jete. On y a amenage une place, et elle est occupee. »

**Demander qui est en bas** — *prudente* · druides · épreuve logic/white · échec −4 PV · EV +0.32

> « Celui a qui tu dois trois pieces », repond Merlin. « Il n'est pas mort dans le Yeun. Il s'y cache depuis un an, et quelqu'un le nourrit. »

> **Variante** — si marqueur « bottes_seches » : « Tu as deja la reponse », dit Merlin. « Des bottes seches devant une maison au bord d'un marais. Tu savais avant moi que Mael Kerlan marche encore ; tu attendais seulement qu'on te le dise. »

*Effets — désormais visibles au HUD :* druides +8

**Refuser d'ecouter** — *equilibree* · anciens · épreuve volonte/contextuel · échec −8 PV · EV -0.56

> Tu lui dis de se taire. Il se tait — et le silence qu'il laisse est pire que ce qu'il allait dire, parce qu'il te laisse le remplir tout seul.

*Effets — désormais visibles au HUD :* anciens +11

**Descendre voir** — *audacieuse* · ankou · épreuve instinct/contextuel · échec −9 PV · EV -0.48

> Tu te laisses glisser dans la fosse. L'eau t'arrive a la taille et sent le pain brule de tres pres. Une main sort de la tourbe et se referme sur ton poignet — pas pour te noyer : pour te retenir.

*Effets — désormais visibles au HUD :* ankou +13


### Carte 7 — acte 3 · NARRATIVE · COMMUNE · *tension*

**Situation.** L'homme dans la fosse est vivant, maigre, et il te reconnait. « Ne le dis pas a elle », souffle Mael Kerlan. « Tant qu'elle me croit noye, elle est en vie. »

**Ecouter son histoire** — *prudente* · niamh · épreuve empathie/white · échec −4 PV · EV +0.80

> Il parle bas et vite. Ce n'est pas le marais qui l'a pris, c'est un homme du bourg a qui il devait plus que trois pieces — et cet homme a promis de prendre la veuve si le mari reparaissait.

*Effets — désormais visibles au HUD :* niamh +10

**Le sortir de la** — *equilibree* · anciens · épreuve volonte/contextuel · échec −8 PV · EV -0.32

> Tu le hisses par les aisselles. Il pese le poids d'un an de tourbe et ses jambes ne le portent plus. Une fois dehors, il regarde la maison qui fume au loin et se met a trembler — de froid, ou d'autre chose.

*Effets — désormais visibles au HUD :* anciens +12

**Le laisser et partir** — *audacieuse* · ankou · épreuve instinct/red · échec −13 PV · EV +0.56 · **télégraphiée**

> Tu remontes seul. Derriere toi, il ne crie pas, ne supplie pas, ne dit rien du tout — et c'est ce rien que tu emportes, plus lourd que trois pieces, et qui te suivra jusqu'au bout du marais.

*Effets — désormais visibles au HUD :* ankou +16 · essence +4


### Carte 8 — acte 4 · PROMISE · RARE · *fascination*

**Situation.** Il te demande de jurer. « Trois jours », dit-il. « Donne-moi trois jours pour partir loin, et ensuite dis-lui ce que tu voudras. »

**Jurer les trois jours** — *prudente* · anciens · épreuve volonte/white · échec −4 PV · EV +0.32

> Tu jures, et il te fait repeter le serment avec ses mots a lui. Le marais n'a pas d'oreilles, mais les Anciens en ont, et un serment prononce sur la tourbe ne s'efface pas.

*Effets — désormais visibles au HUD :* promesse « trois_jours » sous 3 cartes · anciens +8

**Promettre de revenir** — *equilibree* · niamh · épreuve empathie/white · échec −4 PV · EV +0.80

> Tu ne promets pas le silence, tu promets le retour — ce qui n'est pas la meme chose et il le sait. Il accepte quand meme, parce qu'un homme dans une fosse accepte ce qu'on lui donne.

*Effets — désormais visibles au HUD :* promesse « revenir » sous 4 cartes · niamh +10

**Ne rien jurer** — *audacieuse* · korrigans · épreuve instinct/white · échec −5 PV · EV +0.88

> Tu refuses de jurer quoi que ce soit. Il hoche la tete lentement : « Alors tu es honnete, ou tu es dangereux. » Il ne te tourne pas le dos en remontant vers la bruyere.

*Effets — désormais visibles au HUD :* korrigans +12


### Carte 9 — acte 4 · NARRATIVE · COMMUNE · *peur*

**Situation.** Sur le chemin du retour, un homme du bourg vient a ta rencontre. Il sourit, et il sent le pain brule alors qu'il n'a pas mis un pied dans la tourbe.

**Le saluer sans t'arreter** — *prudente* · druides · épreuve logic/white · échec −4 PV · EV -0.16

> Tu le depasses en inclinant la tete. Il se retourne pour te regarder partir — tu ne le vois pas, tu l'entends : ses pas s'arretent quand les tiens continuent.

*Effets — désormais visibles au HUD :* druides +6

**Lui demander son nom** — *equilibree* · niamh · épreuve empathie/white · échec −4 PV · EV +0.32

> « Kerlan », repond-il. « Comme le noye. C'etait mon frere. » Il dit « etait » avec beaucoup de soin, comme un mot qu'on a beaucoup repete pour s'y habituer.

*Effets — désormais visibles au HUD :* niamh +8

**Lui barrer le chemin** — *audacieuse* · ankou · épreuve volonte/white · échec −5 PV · EV +0.40

> Tu te mets en travers. Il ne recule pas et ne contourne pas : il attend, tres calme, que tu comprennes que tu n'as aucune raison de le retenir — aucune que tu puisses dire a voix haute.

*Effets — désormais visibles au HUD :* ankou +10


### Carte 10 — acte 5 · NARRATIVE · COMMUNE · *tension*

**Situation.** La veuve t'attend sur le seuil, les trois pieces dans la main. Elle a vu d'ou tu reviens. « Alors ? » demande-t-elle, et sa voix ne tremble pas.

**Dire que la dette est payee** — *prudente* · korrigans · épreuve instinct/white · échec −4 PV · EV +0.32

> Tu dis que tu as porte les pieces au marais et que c'est fini. Elle te regarde longtemps, referme la main sur les pieces, et ne te demande pas pourquoi tes bottes sont propres.

*Effets — désormais visibles au HUD :* korrigans +8

**Lui parler de son beau-frere** — *equilibree* · druides · épreuve logic/contextuel · échec −8 PV · EV -0.32

> Tu ne parles pas du vivant, tu parles de celui qui sent le pain brule sans avoir marche dans la tourbe. Elle blemit — non pas de surprise, mais parce que quelqu'un d'autre le sait enfin.

*Effets — désormais visibles au HUD :* druides +12

**Tout lui dire** — *audacieuse* · niamh · épreuve empathie/contextuel · échec −9 PV · EV -0.24

> Tu dis tout, y compris le serment que tu viens de rompre. Elle s'assoit sur le seuil, les pieces toujours dans la main, et ne pleure pas : elle calcule combien d'annees elle a passees a porter un deuil qu'on lui avait vendu.

*Effets — désormais visibles au HUD :* niamh +14


### Carte 11 — acte 5 · MERLIN_DIRECT · LEGENDAIRE · *sagesse*

**Situation.** Merlin est assis sur la borne, au bout du chemin. « Trois pieces », dit-il. « Voila ce que tu croyais devoir. Dis-moi ce que tu dois maintenant. »

**Payer et partir** — *prudente* · anciens · épreuve volonte/white · échec −4 PV · EV +6.08

> Tu poses les pieces sur la borne et tu t'en vas. Merlin ne les ramasse pas. « Une dette payee au mauvais creancier reste une dette », dit-il dans ton dos, mais tu marches deja.

*Effets — désormais visibles au HUD :* anciens +12 · Anam +4

**Nommer ta vraie dette** — *equilibree* · druides · épreuve logic/white · échec −5 PV · EV +7.12

> Tu dis que tu dois la verite a une femme et trois jours a un homme, et que les deux ne tiennent pas ensemble. Merlin hoche la tete. « Voila. C'est la premiere chose juste que tu dis depuis l'aube. »

> **Variante** — si promesse rompue « trois_jours » : Tu dis ce que tu dois, et Merlin t'arrete a mi-phrase. « Tu as jure trois jours et tu n'en as pas tenu un. Ce que tu dois maintenant, ce n'est plus a eux — c'est a ta propre parole, et elle est plus chere. »

*Effets — désormais visibles au HUD :* druides +13 · Anam +5

**Retourner au marais** — *audacieuse* · ankou · épreuve instinct/white · échec −5 PV · EV +7.60

> Tu fais demi-tour sans repondre. Merlin ne te retient pas ; il te regarde reprendre le chemin de la tourbiere et murmure, pour lui seul : « Celui-la finira par comprendre ce qu'il est venu chercher. »

*Effets — désormais visibles au HUD :* ankou +15 · Anam +5

