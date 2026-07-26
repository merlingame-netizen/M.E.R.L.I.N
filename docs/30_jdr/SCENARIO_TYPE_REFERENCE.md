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

> **Réussite.** Tu frappes trois coups et le silence dure assez pour que tu comptes tes battements. La porte s'ouvre sur une femme qui n'a pas l'air surprise. « Tu es en retard d'un an », dit-elle sans reproche.

> **Échec.** Tu frappes trop fort, trois fois, et la porte reste close si longtemps que tu finis par crier son nom au bois. Quand elle ouvre, son regard s'est ferme avant sa bouche.

*Effets — désormais visibles au HUD :* anciens +6

**Examiner les bottes** — *equilibree* · druides · épreuve logic/white · échec −4 PV · EV +0.32

> **Réussite.** Le cuir est sec et la semelle propre. La tourbe ne pardonne pas : personne n'a marche dans le marais avec ces bottes. Elles ont ete posees la pour etre vues.

> **Échec.** Tu retournes une botte et la semelle te tombe dans la main, gorgee de tourbe noire. Tu n'apprends rien, sinon que la porte s'est ouverte pendant que tu etais accroupi.

*Effets — désormais visibles au HUD :* druides +8 · marqueur « bottes_seches »

**Entrer sans annoncer** — *audacieuse* · korrigans · épreuve instinct/white · échec −5 PV · EV +0.40

> **Réussite.** Tu pousses la porte. La piece est tiede, la table mise pour deux, et une main referme derriere toi. « Il vaut mieux que personne ne t'ait vu entrer », dit la veuve.

> **Échec.** Tu pousses la porte du pied et le seuil cede : la premiere marche manque depuis longtemps. Tu t'etales dans la piece sombre, et la femme qui te releve ne dit rien.

*Effets — désormais visibles au HUD :* korrigans +10


### Carte 2 — acte 1 · NARRATIVE · COMMUNE · *fascination*

**Situation.** La veuve pose les trois pieces sur la table sans les compter et les repousse vers toi. « Ce n'est pas ca qu'il attend », dit-elle en regardant la fenetre.

**Demander ce qu'il attend** — *prudente* · niamh · épreuve empathie/white · échec −3 PV · EV +0.24

> **Réussite.** Elle met longtemps a repondre. « Qu'on le sorte », finit-elle par dire, et elle ne precise pas d'ou. Tu comprends que la question etait la bonne et que la reponse ne t'aidera pas.

> **Échec.** Tu poses la question trop vite, comme un percepteur. Elle se ferme, ramasse les pieces, et te fait comprendre que la table n'est plus la tienne.

*Effets — désormais visibles au HUD :* niamh +6

**Reposer les pieces sur la table** — *equilibree* · anciens · épreuve volonte/white · échec −4 PV · EV +0.32

> **Réussite.** Tu remets les pieces au milieu de la table. Elle ne les touche pas, mais quelque chose se detend dans ses epaules : la dette existe encore, et tant qu'elle existe, il y a une raison de te garder.

> **Échec.** Tu repousses les pieces d'un geste qu'elle prend pour de l'aumone. Elle les balaie au sol et te laisse les ramasser une par une sous son regard.

*Effets — désormais visibles au HUD :* anciens +8

**Suivre son regard** — *audacieuse* · druides · épreuve logic/white · échec −5 PV · EV +0.40

> **Réussite.** Par la fenetre, la tourbiere fume au ras du sol. A deux cents pas, une planche a ete jetee en travers d'une fosse — recemment, le bois est encore clair. Quelqu'un traverse regulierement.

> **Échec.** Tu regardes par la fenetre et tu ne vois que du brouillard bas. Le temps que tes yeux s'y fassent, elle a tire le volet et la conversation est finie.

*Effets — désormais visibles au HUD :* druides +10 · marqueur « vu_la_fenetre »


### Carte 3 — acte 1 · EVENT · COMMUNE · *tension*

**Situation.** Dehors, l'odeur de pain brule s'epaissit d'un coup. Trois oiseaux partent ensemble de la meme touffe de bruyere, sans qu'aucun bruit ne les ait leves.

**Rester immobile** — *prudente* · anciens · épreuve volonte/white · échec −3 PV · EV +1.44

> **Réussite.** Tu ne bouges pas. Au bout d'un moment, la bruyere se referme et l'odeur reflue. Ce qui passait est passe sans te voir, et tu respires mieux d'avoir su ne rien faire.

> **Échec.** Tu tiens en place trop longtemps. Le froid de la tourbe monte par les semelles, tes jambes se raidissent, et quand tu bouges enfin, quelque chose s'est deja eloigne.

*Effets — désormais visibles au HUD :* anciens +6 · vie +2

**Chercher l'origine de l'odeur** — *equilibree* · korrigans · épreuve instinct/white · échec −4 PV · EV +0.32

> **Réussite.** Tu remontes l'odeur a contre-vent. Elle vient d'un trou dans la tourbe ou quelque chose a brule lentement, longtemps, et sous les cendres il y a du tissu qui n'a pas fini de se consumer.

> **Échec.** Tu remontes le vent du mauvais cote. L'odeur t'echappe, la bruyere se referme, et tu ressors du fourre avec des mains ouvertes de coupures fines.

*Effets — désormais visibles au HUD :* korrigans +8 · marqueur « trace_fumee »

**Appeler le nom du mort** — *audacieuse* · ankou · épreuve volonte/white · échec −5 PV · EV +0.40

> **Réussite.** Tu cries « Mael ». La tourbiere avale le son sans echo, puis te le rend — une seule fois, de beaucoup plus loin, et ce n'est pas ta voix. Quelque chose dans le marais vient d'apprendre le tien.

> **Échec.** Ta voix se casse au milieu du nom. Le marais ne te rend rien, mais quelque chose cesse de bouger, tres loin, et le silence qui suit dure jusqu'a ce que tu recules.

*Effets — désormais visibles au HUD :* ankou +10


### Carte 4 — acte 2 · SHOP · RARE · *fascination*

**Situation.** Un tourbier charge sa brouette au bord du chemin. Il vend ce qu'il trouve dans le marais : de la corde grasse, une lampe a huile, un couteau a lame courte.

**Acheter la corde** — *prudente* · anciens · épreuve volonte/white · échec −3 PV · EV +1.68

> **Réussite.** Il te tend une corde epaisse de graisse de mouton. « Elle ne pourrit pas dans la tourbe », dit-il. « Et si tu tombes, elle ne te lachera pas — c'est toi qui la lacheras. »

> **Échec.** Tu marchandes mal. Le tourbier te laisse la corde et te reprend la moitie de ce que tu portes, en te souhaitant bonne chance d'un ton qui ne le pense pas.

*Effets — désormais visibles au HUD :* essence +6 · marqueur « corde »

**Acheter la lampe** — *equilibree* · druides · épreuve logic/white · échec −4 PV · EV +2.24

> **Réussite.** La lampe est cabossee et son verre fume. Il la remplit devant toi et te previent : « Dans le Yeun, elle ne t'eclaire pas, elle te signale. A toi de savoir a qui. »

> **Échec.** Tu prends la lampe sans verifier la meche. Elle s'eteint au premier souffle du marais, et il est deja trop loin pour t'entendre le rappeler.

*Effets — désormais visibles au HUD :* essence +8 · marqueur « lampe »

**Lui demander qui traverse** — *audacieuse* · korrigans · épreuve instinct/white · échec −5 PV · EV +0.88

> **Réussite.** Il arrete de charger. « Personne ne traverse », dit-il trop vite, puis il reprend sa brouette et ajoute sans se retourner : « Et si quelqu'un traversait, il vaudrait mieux ne pas l'avoir vu. »

> **Échec.** Tu poses la question trop droit. Il charge sa brouette, crache dans la tourbe, et s'en va sans rien dire — et le bourg saura ce soir que tu poses des questions.

*Effets — désormais visibles au HUD :* korrigans +12 · marqueur « tourbier_parle »


### Carte 5 — acte 2 · NARRATIVE · COMMUNE · *tension*

**Situation.** La planche jetee en travers de la fosse tient a peine. Dessous, l'eau noire ne bouge pas, et l'odeur de pain brule monte de la, pas du reste du marais.

**Sonder avant de passer** — *prudente* · druides · épreuve logic/white · échec −3 PV · EV +0.24

> **Réussite.** Tu enfonces ton baton. Il descend d'une brasse, puis butte sur quelque chose qui n'est ni pierre ni racine — quelque chose qui cede un peu, puis resiste. Tu ne recommences pas.

> **Échec.** Ton baton s'enfonce et ne remonte pas : la tourbe le garde. Tu restes au bord, sans rien savoir de plus, et avec une main de moins pour te retenir.

*Effets — désormais visibles au HUD :* druides +6

**Traverser en courant** — *equilibree* · korrigans · épreuve instinct/white · échec −4 PV · EV +0.32

> **Réussite.** Tu passes en trois enjambees. La planche plie au milieu et te lache juste apres ; tu t'etales de l'autre cote, les mains dans la tourbe tiede, et quelque chose sous la surface te rend ta poussee.

> **Échec.** La planche tourne sous ton pied au premier pas. Tu te rattrapes a plat ventre, les jambes dans l'eau noire, et il te faut longtemps pour ressortir.

*Effets — désormais visibles au HUD :* korrigans +8

**Retirer la planche** — *audacieuse* · ankou · épreuve volonte/white · échec −5 PV · EV +0.40

> **Réussite.** Tu tires la planche et la jettes dans la bruyere. Celui qui traverse ne traversera plus — mais toi non plus, et il te faudra contourner par le nord, ou la tourbe est plus molle et te prend jusqu'aux genoux.

> **Échec.** Le bois est plus lourd qu'il n'en a l'air et il t'echappe. La planche part dans la fosse, l'eau te gifle jusqu'au visage, et personne ne passera plus — toi non plus.

*Effets — désormais visibles au HUD :* ankou +10


### Carte 6 — acte 3 · MERLIN_DIRECT · EPIQUE · *peur*

**Situation.** Merlin parle sans que tu l'aies appele. « Regarde mieux la fosse, voyageur. On n'y a rien jete. On y a amenage une place, et elle est occupee. »

**Demander qui est en bas** — *prudente* · druides · épreuve logic/white · échec −4 PV · EV +0.32

> **Réussite.** « Celui a qui tu dois trois pieces », repond Merlin. « Il n'est pas mort dans le Yeun. Il s'y cache depuis un an, et quelqu'un le nourrit. »

> **Échec.** Tu poses mal ta question et Merlin te retourne le silence. « Tu demandes un nom », dit-il enfin. « Tu n'es pas encore pret a l'entendre. »

> **Variante** — si marqueur « bottes_seches » : « Tu as deja la reponse », dit Merlin. « Des bottes seches devant une maison au bord d'un marais. Tu savais avant moi que Mael Kerlan marche encore ; tu attendais seulement qu'on te le dise. »

*Effets — désormais visibles au HUD :* druides +8

**Refuser d'ecouter** — *equilibree* · anciens · épreuve volonte/contextuel · échec −8 PV · EV -0.56

> **Réussite.** Tu lui dis de se taire. Il se tait — et le silence qu'il laisse est pire que ce qu'il allait dire, parce qu'il te laisse le remplir tout seul.

> **Échec.** Tu lui dis de se taire et ta voix tremble a la fin. Il se tait, oui — mais il rit d'abord, et ce rire te suit jusqu'au bord de la fosse.

*Effets — désormais visibles au HUD :* anciens +11

**Descendre voir** — *audacieuse* · ankou · épreuve instinct/contextuel · échec −9 PV · EV -0.48

> **Réussite.** Tu te laisses glisser dans la fosse. L'eau t'arrive a la taille et sent le pain brule de tres pres. Une main sort de la tourbe et se referme sur ton poignet — pas pour te noyer : pour te retenir.

> **Échec.** Tu te laisses glisser trop vite. Le bord cede, tu tombes de tout ton long dans l'eau noire, et tu remontes en crachant sans avoir rien vu.

*Effets — désormais visibles au HUD :* ankou +13


### Carte 7 — acte 3 · NARRATIVE · COMMUNE · *tension*

**Situation.** L'homme dans la fosse est vivant, maigre, et il te reconnait. « Ne le dis pas a elle », souffle Mael Kerlan. « Tant qu'elle me croit noye, elle est en vie. »

**Ecouter son histoire** — *prudente* · niamh · épreuve empathie/white · échec −4 PV · EV +0.80

> **Réussite.** Il parle bas et vite. Ce n'est pas le marais qui l'a pris, c'est un homme du bourg a qui il devait plus que trois pieces — et cet homme a promis de prendre la veuve si le mari reparaissait.

> **Échec.** Tu ecoutes mal, tu coupes, tu veux des dates. Il se referme au milieu d'une phrase et ne reprend pas — tu emportes la moitie d'une histoire.

*Effets — désormais visibles au HUD :* niamh +10

**Le sortir de la** — *equilibree* · anciens · épreuve volonte/contextuel · échec −8 PV · EV -0.32

> **Réussite.** Tu le hisses par les aisselles. Il pese le poids d'un an de tourbe et ses jambes ne le portent plus. Une fois dehors, il regarde la maison qui fume au loin et se met a trembler — de froid, ou d'autre chose.

> **Échec.** Tu tires et il glisse. Vous retombez tous les deux, lui au fond, toi contre la paroi, et il te faut recommencer avec un bras qui ne repond plus bien.

*Effets — désormais visibles au HUD :* anciens +12

**Le laisser et partir** — *audacieuse* · ankou · épreuve instinct/red · échec −13 PV · EV +0.56 · **télégraphiée**

> **Réussite.** Tu remontes seul. Derriere toi, il ne crie pas, ne supplie pas, ne dit rien du tout — et c'est ce rien que tu emportes, plus lourd que trois pieces, et qui te suivra jusqu'au bout du marais.

> **Échec.** Tu remontes trop vite et la tourbe cede sous toi. Tu retombes a cote de lui, face contre l'eau, et il te regarde te debattre sans tendre la main.

*Effets — désormais visibles au HUD :* ankou +16 · essence +4


### Carte 8 — acte 4 · PROMISE · RARE · *fascination*

**Situation.** Il te demande de jurer. « Trois jours », dit-il. « Donne-moi trois jours pour partir loin, et ensuite dis-lui ce que tu voudras. »

**Jurer les trois jours** — *prudente* · anciens · épreuve volonte/white · échec −4 PV · EV +0.32

> **Réussite.** Tu jures, et il te fait repeter le serment avec ses mots a lui. Le marais n'a pas d'oreilles, mais les Anciens en ont, et un serment prononce sur la tourbe ne s'efface pas.

> **Échec.** Tu jures d'une voix plate, sans ses mots a lui. Il te fait recommencer trois fois et n'y croit toujours pas — le serment tient, mais mal.

*Effets — désormais visibles au HUD :* promesse « trois_jours » sous 3 cartes · anciens +8

**Promettre de revenir** — *equilibree* · niamh · épreuve empathie/white · échec −4 PV · EV +0.80

> **Réussite.** Tu ne promets pas le silence, tu promets le retour — ce qui n'est pas la meme chose et il le sait. Il accepte quand meme, parce qu'un homme dans une fosse accepte ce qu'on lui donne.

> **Échec.** Tu promets le retour et tu entends toi-meme que ca sonne faux. Il detourne les yeux, accepte quand meme, et vous savez tous les deux ce que ca vaut.

*Effets — désormais visibles au HUD :* promesse « revenir » sous 4 cartes · niamh +10

**Ne rien jurer** — *audacieuse* · korrigans · épreuve instinct/white · échec −5 PV · EV +0.88

> **Réussite.** Tu refuses de jurer quoi que ce soit. Il hoche la tete lentement : « Alors tu es honnete, ou tu es dangereux. » Il ne te tourne pas le dos en remontant vers la bruyere.

> **Échec.** Tu refuses trop sechement. Il recule d'un pas dans la tourbe, met une main derriere lui, et le reste de la conversation se fait a distance.

*Effets — désormais visibles au HUD :* korrigans +12


### Carte 9 — acte 4 · NARRATIVE · COMMUNE · *peur*

**Situation.** Sur le chemin du retour, un homme du bourg vient a ta rencontre. Il sourit, et il sent le pain brule alors qu'il n'a pas mis un pied dans la tourbe.

**Le saluer sans t'arreter** — *prudente* · druides · épreuve logic/white · échec −4 PV · EV -0.16

> **Réussite.** Tu le depasses en inclinant la tete. Il se retourne pour te regarder partir — tu ne le vois pas, tu l'entends : ses pas s'arretent quand les tiens continuent.

> **Échec.** Tu acceleres et il accelere avec toi. Vous marchez cote a cote un long moment, en silence, et c'est lui qui decide ou ca s'arrete.

*Effets — désormais visibles au HUD :* druides +6

**Lui demander son nom** — *equilibree* · niamh · épreuve empathie/white · échec −4 PV · EV +0.32

> **Réussite.** « Kerlan », repond-il. « Comme le noye. C'etait mon frere. » Il dit « etait » avec beaucoup de soin, comme un mot qu'on a beaucoup repete pour s'y habituer.

> **Échec.** Il te donne un nom qui n'existe pas et te demande le tien. Tu le donnes avant d'avoir reflechi, et son sourire change.

*Effets — désormais visibles au HUD :* niamh +8

**Lui barrer le chemin** — *audacieuse* · ankou · épreuve volonte/white · échec −5 PV · EV +0.40

> **Réussite.** Tu te mets en travers. Il ne recule pas et ne contourne pas : il attend, tres calme, que tu comprennes que tu n'as aucune raison de le retenir — aucune que tu puisses dire a voix haute.

> **Échec.** Tu te mets en travers et il te contourne comme on contourne une pierre. Tu te retournes trop tard : il a pris le chemin de la maison qui fume.

*Effets — désormais visibles au HUD :* ankou +10


### Carte 10 — acte 5 · NARRATIVE · COMMUNE · *tension*

**Situation.** La veuve t'attend sur le seuil, les trois pieces dans la main. Elle a vu d'ou tu reviens. « Alors ? » demande-t-elle, et sa voix ne tremble pas.

**Dire que la dette est payee** — *prudente* · korrigans · épreuve instinct/white · échec −4 PV · EV +0.32

> **Réussite.** Tu dis que tu as porte les pieces au marais et que c'est fini. Elle te regarde longtemps, referme la main sur les pieces, et ne te demande pas pourquoi tes bottes sont propres.

> **Échec.** Tu mens et tes yeux vont vers le marais au mauvais moment. Elle suit ton regard, referme la porte, et tu restes sur le seuil avec les pieces dans la main.

*Effets — désormais visibles au HUD :* korrigans +8

**Lui parler de son beau-frere** — *equilibree* · druides · épreuve logic/contextuel · échec −8 PV · EV -0.32

> **Réussite.** Tu ne parles pas du vivant, tu parles de celui qui sent le pain brule sans avoir marche dans la tourbe. Elle blemit — non pas de surprise, mais parce que quelqu'un d'autre le sait enfin.

> **Échec.** Tu t'embrouilles dans ce que tu as vu et ce que tu as deduit. Elle entend une accusation contre un homme du bourg, sans preuve, et te demande de partir.

*Effets — désormais visibles au HUD :* druides +12

**Tout lui dire** — *audacieuse* · niamh · épreuve empathie/contextuel · échec −9 PV · EV -0.24

> **Réussite.** Tu dis tout, y compris le serment que tu viens de rompre. Elle s'assoit sur le seuil, les pieces toujours dans la main, et ne pleure pas : elle calcule combien d'annees elle a passees a porter un deuil qu'on lui avait vendu.

> **Échec.** Tu dis tout, dans le desordre, et le pire arrive avant le reste. Elle n'entend que le mensonge d'un an, s'assied, et ne te repond plus.

*Effets — désormais visibles au HUD :* niamh +14


### Carte 11 — acte 5 · MERLIN_DIRECT · LEGENDAIRE · *sagesse*

**Situation.** Merlin est assis sur la borne, au bout du chemin. « Trois pieces », dit-il. « Voila ce que tu croyais devoir. Dis-moi ce que tu dois maintenant. »

**Payer et partir** — *prudente* · anciens · épreuve volonte/white · échec −4 PV · EV +6.08

> **Réussite.** Tu poses les pieces sur la borne et tu t'en vas. Merlin ne les ramasse pas. « Une dette payee au mauvais creancier reste une dette », dit-il dans ton dos, mais tu marches deja.

> **Échec.** Tu poses les pieces et ta main tremble en les lachant. Merlin le voit. « Va », dit-il seulement, et le mot pese plus lourd que la dette.

*Effets — désormais visibles au HUD :* anciens +12 · Anam +4

**Nommer ta vraie dette** — *equilibree* · druides · épreuve logic/white · échec −5 PV · EV +7.12

> **Réussite.** Tu dis que tu dois la verite a une femme et trois jours a un homme, et que les deux ne tiennent pas ensemble. Merlin hoche la tete. « Voila. C'est la premiere chose juste que tu dis depuis l'aube. »

> **Échec.** Tu cherches tes mots et tu n'en trouves qu'un : « rien ». Merlin hoche la tete sans te contredire, et c'est pire que s'il l'avait fait.

> **Variante** — si promesse rompue « trois_jours » : Tu dis ce que tu dois, et Merlin t'arrete a mi-phrase. « Tu as jure trois jours et tu n'en as pas tenu un. Ce que tu dois maintenant, ce n'est plus a eux — c'est a ta propre parole, et elle est plus chere. »

*Effets — désormais visibles au HUD :* druides +13 · Anam +5

**Retourner au marais** — *audacieuse* · ankou · épreuve instinct/white · échec −5 PV · EV +7.60

> **Réussite.** Tu fais demi-tour sans repondre. Merlin ne te retient pas ; il te regarde reprendre le chemin de la tourbiere et murmure, pour lui seul : « Celui-la finira par comprendre ce qu'il est venu chercher. »

> **Échec.** Tu fais demi-tour et tes jambes ne suivent pas : la tourbe t'a pris quelque chose que tu n'avais pas compte. Tu t'assieds sur la borne, a cote de lui, en silence.

*Effets — désormais visibles au HUD :* ankou +15 · Anam +5

