# ᚛ Le Rite des Neuf Souffles ᚜

> **Scénario type de référence** — archétype `forgotten_ritual` (Le Rite Oublié) · pôle Ordre · twist `ritual_completion` · biome foret_broceliande.
>
> Généré par `tools/build_golden_scenario.py` : la couche mécanique est calculée depuis `data/ai/scenario_templates.json`, la prose est écrite par-dessus. Ce document est régénéré, pas édité à la main.

**25 cartes par route · 53 cartes au total · 3 voies isométriques.**

*Une cérémonie druidique laissée ouverte en plein milieu dort sous la mousse de Brocéliande, et attend qu'on lui rende son dernier souffle.*

## Accroche

> Dans cette forêt pas une feuille ne tourne : depuis des siècles, Brocéliande n'a pas expiré.

## Intro (parchemin d'ouverture)

Tu marches en Brocéliande depuis trois jours et la forêt ne t'a rien demandé. Ce matin ton pied glisse sur une bosse de mousse qui sonne creux, et sous la mousse il y a de la pierre taillée. Les entailles sont des oghams, plus vieux que les chemins, plus vieux que les noms qu'on donne ici aux clairières. Un peu plus loin, une autre bosse. Puis une autre, alignée. Neuf pierres dorment sous le tapis vert, neuf stations d'une cérémonie que personne n'a portée jusqu'au bout. Depuis ce jour-là la forêt n'expire plus : pas un souffle d'air entre les fûts, pas une feuille qui tourne. Quelqu'un a commencé le Rite des Neuf Souffles et l'a laissé ouvert au milieu — et te voilà, la paume sur la première pierre, à comprendre qu'il attendait quelqu'un.

## Les trois voies

- **Voie de l'Ordre** — Accomplir le rite mot pour mot, dans la patience des Anciens, sans discuter une seule entaille de l'ogham.
- **Voie du Chaos** — Réécrire le rite, chercher avec les korrigans la faille du texte, et faire dire à la formule autre chose que ce qu'elle exige.
- **Voie Liminale** — Ne rien clore ni rien rouvrir : tenir le rite sur le seuil, dans la brume de Niamh, à la lisière du souffle.

## Structure

| Acte | Rôle | Cartes | Contenu | Danger |
|---|---|---|---|---|
| 1 | Ouverture | 1–5 | tronc commun — 4×NARRATIVE, 1×EVENT | ×0.6 |
| 2 | Pacte | 6–10 | branche 1 (×3 voies) — 3×NARRATIVE, 1×SHOP, 1×PROMISE | ×0.8 |
| 3 | Épreuve | 11–15 | twist + branche 2 — 3×NARRATIVE, 1×MERLIN_DIRECT, 1×EVENT | ×1.0 |
| 4 | Bascule | 16–20 | branche 2 (×3 voies) — 2×NARRATIVE, 1×SHOP, 1×EVENT, 1×RUNE_UNLOCK | ×1.3 |
| 5 | Climax | 21–25 | convergence commune — 3×NARRATIVE, 2×MERLIN_DIRECT | ×1.6 |

## Déroulé de la voie de l'Ordre

*(les voies du Chaos et Liminale suivent la même ossature ; seules les cartes de branche diffèrent)*

| # | Type | Rareté | Émotion | Situation | Épreuves |
|---|---|---|---|---|---|
| 1 | NARRATIVE | COMMUNE | curiosite | Sous la mousse d'un talus, une pierre dressée porte des entailles que la forêt n'a pas faites. | log/whit · vol/whit · ins/whit |
| 2 | NARRATIVE | COMMUNE | fascination | L'air ne bouge plus entre les fûts : la brume tient debout comme si elle attendait un signe. | vol/whit · emp/whit · log/whit |
| 3 | EVENT | COMMUNE | tension | Les fougères s'ouvrent d'un coup sur ton passage et quelque chose file vers la pierre suivante. | ins/whit · log/whit · vol/whit |
| 4 | NARRATIVE | COMMUNE | fascination | Sur la troisième pierre, une main plus tardive a griffé les traits de l'ogham pour en changer le sens. | log/whit · emp/whit · vol/whit |
| 5 | NARRATIVE | COMMUNE | curiosite | La pierre attend un souffle, et la mousse se fend en trois sentes qui ne se rejoignent plus. | vol/whit · ins/whit · emp/whit |
| 6 | SHOP | COMMUNE | emerveillement | Sous le dolmen, le gui et la corde du rite dorment intacts, et la gardienne des Anciens attend. | log/whit · ins/whit · vol/whit |
| 7 | NARRATIVE | COMMUNE | tension | La deuxième pierre exige une veille immobile jusqu'à la brume, et tes genoux saignent déjà sur la mousse. | emp/whit · vol/whit · vol/whit |
| 8 | NARRATIVE | COMMUNE | fascination | À la troisième station, une entaille manque au texte, et le rite tait le mot qu'il faudrait dire. | log/whit · vol/whit · ins/whit |
| 9 | PROMISE | RARE | tension | Devant la pierre des serments, la mousse s'écarte seule : ici, une parole donnée tient jusqu'à la neuvième station. | vol/whit · log/whit · emp/cont |
| 10 | NARRATIVE | COMMUNE | emerveillement | Tu as tenu la lettre du rite, et pour la première fois une feuille tourne : la forêt expire un peu. | ins/whit · emp/whit · log/whit |
| 11 | MERLIN_DIRECT | EPIQUE | fascination | Merlin te dit enfin pourquoi le rite dort : le neuvième souffle se prend sur celui qui le clôt. | log/whit · vol/whit · vol/whit |
| 12 | NARRATIVE | COMMUNE | tension | La quatrième pierre attend la suite exacte de la formule, et ta main tremble sur la mousse froide. | emp/whit · ins/whit · vol/whit |
| 13 | EVENT | RARE | emerveillement | À la cinquième pierre, un souffle tiède monte de la mousse et dessine la place des officiants disparus. | vol/whit · vol/whit · log/red |
| 14 | NARRATIVE | COMMUNE | tension | L'if tombé couvre la sixième pierre, et le rite interdit autant de la découvrir que de l'abandonner. | log/whit · emp/whit · ins/cont |
| 15 | NARRATIVE | COMMUNE | fascination | À la septième station, les noms des officiants montent le long des fûts et le dernier reste inachevé. | ins/whit · vol/whit · emp/whit |
| 16 | NARRATIVE | COMMUNE | emerveillement | Le vent revenu ne passe plus entre les futs : il entre dans ta poitrine et s'y arrêté. | emp/whit · log/whit · vol/whit |
| 17 | SHOP | RARE | tension | Au pied de l'if creux, une gardienne des Anciens pese ce qui manque a ta formule contre ce que tu portes. | vol/whit · ins/whit · log/cont |
| 18 | NARRATIVE | COMMUNE | fascination | Sur la huitième pierre, une seconde main a retaillé la dernière ligne d'une entaille plus douce. | log/whit · log/whit · emp/whit |
| 19 | EVENT | RARE | tension | La brume s'ouvre d'un coup : l'officiant arrêté est encore agenouillé devant la neuvième pierre. | log/whit · log/whit · log/red |
| 20 | RUNE_UNLOCK | RARE | emerveillement | L'ogham de l'if s'allume sous ta paume, chaud comme une braise que personne n'a soufflée. | emp/whit · log/whit · log/whit |
| 21 | NARRATIVE | COMMUNE | tension | La huitième pierre s'éteint derrière toi et la dernière se lève, seule, au fond du nemeton. | log/whit · emp/whit · log/whit |
| 22 | NARRATIVE | COMMUNE | fascination | Entre les deux dernières pierres se tient un homme de brume, la bouche ouverte sur un souffle jamais rendu. | log/whit · log/whit · log/cont |
| 23 | MERLIN_DIRECT | EPIQUE | emerveillement | Merlin ouvre la main et tu entends d'un seul coup les huit souffles rendus avant toi. | log/whit · log/whit · log/whit |
| 24 | NARRATIVE | COMMUNE | tension | Les korrigans s'assoient en cercle autour de la dernière pierre et parient tout bas sur qui paiera le souffle. | emp/whit · log/whit · log/whit |
| 25 | MERLIN_DIRECT | LEGENDAIRE | sagesse | La neuvième pierre attend, et il n'y a plus qu'un souffle à donner : reste à savoir de qui. | log/whit · log/whit · log/fata |

## Le twist

Carte 11 — **EPIQUE MERLIN_DIRECT** : Merlin te dit enfin pourquoi le rite dort : le neuvième souffle se prend sur celui qui le clôt.

- *prudente* — **Demander la formule mot à mot** (`demander`, druides, épreuve logic/white)
- *equilibree* — **Porter seul cette révélation** (`porter`, anciens, épreuve volonte/white)
- *audacieuse* — **Dire que tu clôras le rite** (`dire`, ankou, épreuve volonte/white)

## Équilibrage mesuré

| Dimension | Mesuré | Cible du contrat |
|---|---|---|
| Factions sur les options | druides 24%, anciens 22%, niamh 21%, korrigans 19%, ankou 14% | chacune ≥ 8 %, druides ≤ 30 % |
| Stats mises à l'épreuve | logic 40%, volonte 25%, empathie 20%, instinct 15% | logic 40%, empathie 20%, volonte 25%, instinct 15% |
| Épreuves par carte | white 72%, contextuel 16%, red 8%, fatal 4% | white 75 %, contextuel 15 %, red 8 %, fatal 2 % |

Conformité : `python tools/validate_scenario_balance.py --file data/ai/scenario_golden_broceliande.json --strict`
