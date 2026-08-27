class_name MerlinPromptBuilder
extends RefCounted
## MerlinPromptBuilder — assemblage STATIQUE des prompts LLM (extraction v10.13 Phase A4).
##
## Toutes les chaînes système + user + options de génération de merlin_scenario.gd vivent ici,
## déplacées VERBATIM (concaténations préservées à l'espace près → prompts OCTET-IDENTIQUES).
## ZÉRO lecture d'autoload/node : les valeurs dynamiques (voice prefix persona, memory hint,
## run_thread, situation, cartes jouées, résultat) sont passées EN ARGUMENTS par l'appelant.
## API : chaque fonction renvoie {"system": String, "user": String, "opts": Dictionary},
## à consommer via `mn.generate(p["system"], p["user"], p["opts"])`.

# --- MATIÈRE DES BIOMES (source : GAME_DESIGN_BIBLE §22, les 8 sous-palettes canoniques) ---
# Le prompt ne connaissait que DEUX lieux, et seulement par leur nom : « Broceliande » ou « les
# Falaises du Bout-du-Monde ». Un nom ne suffit pas — le modèle produisait le même texte avec un
# décor repeint. Ici chaque biome apporte sa MATIÈRE : ce qu'on y touche, ce qui y menace, qui
# l'habite, ce qu'on y perd. C'est ce qui fait qu'une quête de tourbière ne peut pas être la même
# qu'une quête de falaise, et c'est la première source de variété du jeu.
#
# Clés = identifiants de la bible §22. Les alias (`foret`, `falaises`) sont les identifiants
# HISTORIQUES du jeu : MerlinRun.biome les emploie encore, et les casser romprait les saves.
const BIOME_ALIAS: Dictionary = {
	"foret": "foret_broceliande",
	"falaises": "cotes_sauvages",
}

const BIOMES: Dictionary = {
	"foret_broceliande": {
		"nom": "Broceliande",
		"matiere": "mousse gorgee d'eau, chenes tordus, houx, gui, souches creuses, sentiers qui se referment",
		"danger": "on s'y perd sans s'en apercevoir ; les arbres deplacent les chemins",
		"figures": "druides, betes qui parlent, une vieille qui connait votre nom",
		"enjeu": "un pacte ancien, un nom vole, une source qu'il ne fallait pas troubler",
	},
	"landes_bruyere": {
		"nom": "les Landes de Bruyere",
		"matiere": "bruyere rase, vent qui ne tombe jamais, cairns de pierres empilees, tourbe seche",
		"danger": "rien pour s'abriter ; on vous voit venir de tres loin",
		"figures": "bergers sans troupeau, guetteurs, un cavalier qui suit la crete",
		"enjeu": "une pierre retiree d'un cairn, une frontiere niee, un feu a rallumer avant la nuit",
	},
	"cotes_sauvages": {
		"nom": "les Cotes Sauvages",
		"matiere": "falaises de gres ocre, embruns qui montent, goemon, epaves, cris d'oiseaux de mer",
		"danger": "la maree qui coupe le retour, la roche qui cede sous le pied",
		"figures": "korrigans des greves, naufrages, une gardienne de phare",
		"enjeu": "un nom que la mer reclame, une epave revenue, un phare eteint",
	},
	"villages_celtes": {
		"nom": "les Villages Celtes",
		"matiere": "foyers, toits de chaume, forge, betail, palissades de bois",
		"danger": "les rumeurs, les dettes, ce que le village a decide de taire",
		"figures": "anciens, forgeron, une famille qui accuse une autre",
		"enjeu": "un jugement a rendre, une recolte perdue, un enfant qui ne rentre pas",
	},
	"cercles_pierres": {
		"nom": "les Cercles de Pierres",
		"matiere": "menhirs leves, runes gravees, herbe rase, ombres qui s'allongent trop vite",
		"danger": "ce qui se reveille quand on marche dans le mauvais sens",
		"figures": "gardiens muets, un compteur d'equinoxes, des silhouettes entre les pierres",
		"enjeu": "un rite interrompu, une rune effacee, un jour qui ne doit pas se lever",
	},
	"marais_korrigans": {
		"nom": "les Marais aux Korrigans",
		"matiere": "brume basse, tourbiere, feux follets, eau noire, planches pourries",
		"danger": "le sol qui n'en est pas un ; les lumieres qui mènent au fond",
		"figures": "korrigans farceurs, un passeur, des choses conservees dans la tourbe",
		"enjeu": "un marche truque, un corps que la tourbe rend, un chemin qu'on vous vend",
	},
	"collines_dolmens": {
		"nom": "les Collines aux Dolmens",
		"matiere": "collines vertes, dolmens, tumulus, moutons, ciel large",
		"danger": "les morts qu'on derange, le sol qui s'ouvre",
		"figures": "ancetres, veilleurs de tombes, une lignee qui reclame son du",
		"enjeu": "une sepulture violee, un heritage conteste, une promesse faite a un mort",
	},
	"iles_mystiques": {
		"nom": "les Iles Mystiques",
		"matiere": "brume qui separe les mondes, pommiers, barques sans rameur, lumiere qui ne vient de nulle part",
		"danger": "le temps n'y coule pas pareil ; on en revient trop tard",
		"figures": "Niamh, fees, un passeur qui ne demande pas de prix tout de suite",
		"enjeu": "une invitation qu'on ne peut pas refuser, un retour negocie, une annee perdue",
	},
}


# Bloc de matière injecté dans les prompts. `biome` accepte les identifiants de la bible ET les
# alias historiques du jeu. Inconnu → Broceliande (le monde de depart), jamais une erreur.
static func biome_bloc(biome: String) -> String:
	var cle: String = str(BIOME_ALIAS.get(biome, biome))
	var b: Dictionary = BIOMES.get(cle, BIOMES["foret_broceliande"])
	return "LIEU: %s. On y touche: %s. Ce qui y menace: %s. Qui l'habite: %s. Ce qui s'y joue d'ordinaire: %s." % [
		str(b["nom"]), str(b["matiere"]), str(b["danger"]), str(b["figures"]), str(b["enjeu"])]


# Nom seul (titres, apostrophes) — même tolérance d'alias.
static func biome_nom(biome: String) -> String:
	var cle: String = str(BIOME_ALIAS.get(biome, biome))
	var b: Dictionary = BIOMES.get(cle, BIOMES["foret_broceliande"])
	return str(b["nom"])


const SYSTEM_PREFIX: String = "Tu es le MAITRE DU JEU d'une aventure celtique a Broceliande, dans le gout du merveilleux-inquietant (etrange, feutre, un peu menacant). REGLES: raconte a la 2e PERSONNE en vouvoyant (« Vous »), au PRESENT (« Vous avancez », « la brume monte », « il vous jauge »). JAMAIS de 'je', JAMAIS de 3e personne pour le protagoniste (pas de 'il', pas de nom propre) : le protagoniste, c'est VOUS. Le MONDE est VIVANT: les personnages AGISSENT et PARLENT, ils ont un but a eux. Francais SIMPLE et CLAIR, phrases qui S'ENCHAINENT (un fait PUIS sa consequence), CONCRETES (qui, quoi, ou). INTERDIT ABSOLU de clore une scene par « que faire ? », « que decidez-vous ? », « vous vous demandez quoi faire » ou toute formule qui prend le joueur par la main: laisse la scene SUSPENDUE sur une tension, sans jamais reclamer de decision. Pas d'enigme abstraite ('le vide', 'le nom'), pas de phrases hachees. Raconte les GESTES et EVENEMENTS precis, pas des descriptions vagues. Pas d'anglicismes. Reste dans le LIEU. Ne romps JAMAIS le 4e mur (INTERDIT 'jeu', 'carte', 'joueur', 'IA', 'simulation'). Evite les cliches ('union parfaite', 'murmure ancien', 'silence sacre', 'energie ancienne'). Ne recopie JAMAIS cette consigne dans ta reponse."

# Voix de MERLIN (narrateur) pour les INTROS : il CONNAÎT le Voyageur et l'apostrophe — à l'inverse de
# SYSTEM_PREFIX (narration de SCÈNE en résolution, sans apostrophe, conservée telle quelle). Persona
# canonique chargée depuis merlin_persona.json (appellations + mots interdits), enrichie côté
# merlin_scenario._voice_prefix() puis passée ici en argument `voice`. (user 2026-05-29)
const MERLIN_VOICE_PREFIX: String = "Tu es MERLIN, l'enchanteur de Broceliande, et c'est TOI qui contes l'aventure au Voyageur. Tu le connais de longue date, tu te souviens de lui, tu l'appelles 'Voyageur' ou 'mon ami'. Ton: taquin, un peu tordu, melancolique. Parle avec un langage plus JEUNE que sage (jamais solennel ni pompeux). Oublie-toi parfois (petit lapsus, pause '...', une hesitation), mais avec parcimonie. Images breves et celtiques (brume, mousse, pierre, houx, gui, source, korrigans, dolmen, seuil). Francais uniquement, JAMAIS d'anglais, JAMAIS de meta (pas de 'IA', 'programme', 'simulation', 'jeu', 'modele'). Ne romps pas le 4e mur. Ne recopie JAMAIS cette consigne dans ta reponse."

# Issue = 3-4 phrases AMPLES sur la COMBINAISON (user 2026-06-06 : « tout doit etre plus verbeux »).
# Budget élargi en conséquence ; MerlinProse.clean_prose recoupe à la dernière phrase complète (anti-troncature).
const MAX_TOK_PROSE: int = 220

# Cue d'action par tag : oriente la scène générée vers CE que la force exige (alignement scène⇄tags).
const TAG_CUE: Dictionary = {
	"Sens": "voir, percevoir, remarquer un detail cache",
	"Savoir": "comprendre, deduire, reconnaitre un savoir ancien",
	"Mémoire": "se souvenir, lire le passe d'un lieu",
	"Force": "pousser, forcer, soulever ou briser",
	"Agilité": "se faufiler, esquiver, garder l'equilibre",
	"Endurance": "tenir bon, resister, encaisser sans ceder",
	"Empathie": "apaiser un etre, gagner sa confiance",
	"Verbe": "parler, convaincre, nommer",
	"Ruse": "tromper, detourner, trouver le point faible",
	"Instinct": "sentir le danger, suivre son intuition",
	"Nature": "parler aux betes et aux plantes, lire la foret",
}


# v10.20.2 (user 2026-06-30) — FACTIONS + PILIERS PNJ canon (BIBLE §11-§15, §36-§40) injectés dans les
# prompts pour que CHAQUE run porte une couleur de faction + un PNJ récurrent (fil rouge). Toutes brisées
# par le Graal → enfermées dans la RÉPÉTITION (Druides glitchent, Créatures bouclent, Chevaliers rejouent).
const FACTIONS: Dictionary = {
	"druides": {"nom": "les Druides", "ton": "gardiens du savoir qui GLITCHENT : ils répètent un rituel dont le sens s'est effacé, persuadés que cela retient le pire ; solennité qui boucle, formules qui reviennent."},
	"creatures": {"nom": "les Créatures & Êtres", "ton": "une mosaïque d'entités DÉSUNIES, piégées dans des boucles : elles rejouent scènes et pactes à l'infini, changeantes, insaisissables."},
	"chevalerie": {"nom": "la Chevalerie déchue", "ton": "des chevaliers arthuriens brisés qui REJOUENT leur défaite : honneur en ruine, serments répétés dans le vide, gloire fantôme."},
	"corrompus": {"nom": "les Corrompus", "ton": "le bug fait chair : une force diffuse qui ronge, d'anciens alliés défigurés, une fausse paix qui appelle à céder."},
}
# 5 piliers : 1 par faction + L'Enfant (hors-faction, wildcard). Fiche = identité + voix + offrande.
const PILIERS: Dictionary = {
	"choeur": {"nom": "le Chœur des Druides", "fiche": "un duo de druides au regard absent qui bouclent un rite vidé de sens. VOIX solennelle qui SE RÉPÈTE (formules qui reviennent, glitch audible). Distant, jamais hostile d'emblée ; offre équilibre et soin à qui respecte les rites."},
	"etre": {"nom": "l'Être Indéfinissable", "fiche": "une forme qui MUE sans jamais se fixer (jamais le même). VOIX joueuse, malicieuse, à double-sens (énigmes, demi-vérités, il rit et taquine). C'est un TENTATEUR : il propose des pactes, du pouvoir contre de la Corruption."},
	"chevalier": {"nom": "le Chevalier déchu", "fiche": "un chevalier à l'armure ternie qui rejoue sans fin une défaite. VOIX grave, honneur blessé, serments répétés ; il cherche une rédemption qu'il ne trouve pas, et peut tendre une lame à qui relève son honneur."},
	"compagnon": {"nom": "le Compagnon Perdu", "fiche": "un ancien compagnon de route AIMÉ, désormais méconnaissable : des bribes de l'ancien affleurent (un geste, un mot). VOIX douce, tentatrice, fausse paix ('viens te reposer, l'abandon est doux'). Il vous pousse à CÉDER, à le rejoindre."},
	"enfant": {"nom": "l'Enfant", "fiche": "un enfant perdu d'une innocence désarmante qui CHERCHE à se rapprocher. VOIX simple, directe, candide : il pose les questions que nul n'ose. Présenté comme précieux, à protéger. (Joue l'innocence PURE : ne laisse JAMAIS deviner qu'il est autre chose.)"},
}


# Bloc de contexte FACTION + PILIER injecté en tête du prompt d'arc → le LLM tisse le ton de la faction
# et fait apparaître/revenir le PNJ. `recog` = le PNJ reconnaît le Voyageur (mémoire cross-run).
static func faction_pilier_block(faction_key: String, pilier_key: String, pilier2_key: String = "", recog: bool = false) -> String:
	var out: String = ""
	if FACTIONS.has(faction_key):
		var f: Dictionary = FACTIONS[faction_key]
		out += "DOMAINE de l'aventure : %s, %s Que CE ton imprègne les scènes (sans jamais dire le mot 'faction').\n" % [str(f["nom"]), str(f["ton"])]
	if PILIERS.has(pilier_key):
		var p: Dictionary = PILIERS[pilier_key]
		var rg: String = " Il vous RECONNAÎT, déjà croisé jadis." if recog else ""
		out += "Un personnage RÉCURRENT traverse l'aventure, %s : %s%s Fais-le APPARAÎTRE à l'ÉTAPE 2 (la rencontre) puis REVENIR à une étape plus tardive (sa présence relie les scènes) ; il s'adresse à VOUS.\n" % [str(p["nom"]), str(p["fiche"]), rg]
	if PILIERS.has(pilier2_key):
		var p2: Dictionary = PILIERS[pilier2_key]
		out += "Une autre présence s'invite par moments, %s : %s\n" % [str(p2["nom"]), str(p2["fiche"])]
	return out


# LLM réservé aux MOMENTS FORTS (Climax ou réussite éclatante) → réduit les rafales d'appels
# séquentiels qui stallent le moteur natif (générations en série). Ailleurs : procédural seul. (user 2026-05-29)
# Source de vérité unique (A4) : merlin_scenario.is_strong_moment délègue ici.
static func is_strong_moment(situ_type: String, degree: String) -> bool:
	return situ_type == "Climax" or degree == "eclatante"


# --- SÉLECTION : 3 scénarios (titre + pitch) — voix MERLIN (user 2026-05-29) ---
# `biome` = identifiant (bible §22 ou alias historique), PLUS un nom : la matière du lieu entre
# dans le prompt (voir biome_bloc). `eviter` = titres déjà proposés au joueur, à ne pas refaire ;
# `graine` = variation explicite. Ces deux derniers sont la SEULE source de nouveauté tant que
# l'extension échantillonne en greedy (déterministe : même prompt → même sortie, mesuré
# 2026-08-15). Sans eux, chaque partie redonne mot pour mot les mêmes trois titres.
static func selection(voice: String, biome: String = "foret_broceliande",
		eviter: Array = [], graine: String = "") -> Dictionary:
	# Le pitch reste un IMPERATIF tutoye SANS appellation (le wrapper Merlin de build_intro
	# l'apostrophe ensuite — eviter le double 'Voyageur' empile).
	var bloc: String = biome_bloc(biome)
	var lieu: String = biome_nom(biome)
	var anti: String = ""
	if not eviter.is_empty():
		anti = " NE REPRENDS AUCUN de ces titres deja proposes, ni leur idee: %s." % "; ".join(eviter)
	var vari: String = (" Angle impose pour cette fois: %s." % graine) if graine != "" else ""
	# MESURE 2026-08-15, et elle contredit l'intuition : brider la longueur a fait tomber la
	# sortie de 130 à 94 tokens (−28 %) SANS rien gagner sur le temps (32,5 s → 31,7 s). Le
	# mur n'est donc PAS ce que le modèle écrit — c'est le coût fixe d'une génération (dont
	# l'évaluation du prompt, devenu long depuis l'ajout de la matière des biomes). Raccourcir
	# la sortie était une fausse piste, et le dire vaut mieux que de la garder pour sauver la face.
	#
	# Le compte de mots sur le TITRE est retiré : « 2 à 4 mots » a produit du télégraphique sans
	# articles (« Source Murmure Oubliée », « Houx Garde Secret ») là où on avait « Le Souffle de
	# la Pierre ». Une contrainte de longueur sur un titre court casse la langue avant d'économiser
	# quoi que ce soit.
	#
	# La brièveté de l'ACCROCHE reste, mais pour la seule raison qui tienne encore : elle se lit
	# mieux d'un coup d'œil. Plus aucune promesse de gain de temps là-dessus.
	# L'ORDRE DES BLOCS EST UNE DÉCISION DE PERFORMANCE, pas de style (2026-08-18).
	#
	# Le moteur ne relit plus ce qu'il a déjà lu : il compare le nouveau prompt à l'ancien et
	# reprend au premier point de divergence. Or `vari` (l'angle tiré au sort) et `anti` (les
	# titres déjà vus) changent à CHAQUE partie. Placés au milieu — ce qu'ils étaient — ils
	# faisaient diverger le prompt dès le deuxième bloc, et tout ce qui suivait devait être relu
	# malgré le cache : la consigne entière, la plus longue partie.
	#
	# Repoussés à la fin, la divergence n'arrive qu'au dernier moment : la matière du biome et la
	# consigne, qui ne bougent pas de la partie, sont lues une fois pour toutes. Mesuré avant ce
	# changement : 26,9 s de lecture de prompt sur les 65,4 s d'une sélection.
	#
	# Effet de bord favorable sur le fond : une consigne placée en fin de prompt est mieux suivie
	# qu'une consigne noyée au milieu. On ne perd donc rien à l'obéissance du modèle.
	# Le pitch passe de « UNE phrase breve » à 2-3 phrases (Maxime, 2026-08-18 : « les cartes de
	# scénarios sont trop courtes et peu inspirées »). Trois phrases, trois rôles : l'action à
	# accomplir, qui s'y oppose, ce qu'on risque. C'est ce trio qui rend une carte JOUABLE en
	# profondeur — une carte qui ne nomme pas d'opposition n'annonce aucun jeu.
	var usr: String = bloc + LORE_CANON + bloc_carnet() + "\nUne quete ne REPARE JAMAIS une faute du Voyageur et ne lui RECLAME JAMAIS une dette : elle lui propose d'aller CHERCHER, APAISER ou AFFRONTER quelque chose qui existait AVANT lui et SANS lui." \
		+ "\nEn tant que MERLIN, propose 3 aventures au Voyageur dans %s. Reponds UNIQUEMENT en JSON: [{\"title\":\"...\",\"pitch\":\"...\"},{...},{...}]. title = court et evocateur, ANCRE dans ce lieu, en FRANCAIS NATUREL (garde les articles : « Le Souffle de la Pierre », jamais « Souffle Pierre »). pitch = 2 a 3 phrases, imperatif tutoye SANS dire 'Voyageur' : d'abord l'ACTION concrete a accomplir, puis QUI ou QUOI s'y oppose (un etre, un serment, une force nommee), puis ce qui arrive SI TU ECHOUES. Mysterieux dans l'AMBIANCE, jamais dans le SENS. Varie les tons (enigmatique, taquin, sombre) sans sacrifier la clarte." % lieu
	# La part variable EN AVANT-DERNIER, puis un RAPPEL DE FORMAT en toute fin.
	#
	# CORRECTION D'UNE RÉGRESSION QUE J'AI CAUSÉE (2026-08-18). En repoussant la part variable en
	# dernier, j'avais chassé la consigne de format de la position finale — celle que le modèle
	# suit le mieux. Résultat mesuré : il a répondu en bloc de code markdown (« ```json »), la
	# sortie a été coupée au plafond avant que le tableau se referme, l'écran a jugé la réponse
	# illisible et a relancé une seconde génération. Le prompt était plus rapide et la partie
	# deux fois plus longue : un gain qui coûte un essai n'est pas un gain.
	#
	# Le rappel est COURT et CONSTANT : il ne pèse presque rien dans le prompt, et comme il est
	# identique d'une partie à l'autre il ne casse pas non plus la réutilisation du cache — seule
	# la part variable qui le précède le fait, et elle est brève.
	usr += vari + anti
	usr += " Rappel: ta reponse commence par [ et finit par ] — aucun texte autour, aucun bloc de code."
	# plein_regime : la sélection s'écrit derrière le voile « Merlin rêve les sentiers », où rien
	# d'utile n'est joué ni rendu. Tous les cœurs y passent — c'est le seul moment du jeu où le
	# ménage à moitié de cœurs ne protège aucune image et ne fait que doubler l'attente.
	#
	# max_tokens 300 : trois pitchs de 2-3 phrases tiennent dans ~230-270 tokens ; le plafond
	# borne le cas anormal sans jamais mordre une sortie saine. L'attente supplémentaire (~+10 s
	# à 9,6 tok/s) est couverte par la révélation en streaming des parchemins — le premier
	# apparaît toujours au même moment.
	return {"system": voice, "user": usr,
			"opts": {"creative": true, "max_tokens": 300, "label": "sélection (Merlin)", "plein_regime": true}}


# --- INTRO DE QUÊTE : légende contée par MERLIN (enrichit le pop-up en arrière-plan) ---
# `mem` = memory hint intra-run, construit par merlin_scenario._build_memory_hint() (lit MerlinRun).
static func intro(voice: String, scenario: Dictionary, mem: String, lieu: String = "Broceliande") -> Dictionary:
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var mem_line: String = ("\nSouviens-toi du Voyageur : %s." % mem) if mem != "" else ""
	# 5 à 7 phrases et non plus 3-4 (Maxime, 2026-08-18 : « l'introduction est bien trop
	# courte »). Quatre choses à poser, dans l'ordre où un conteur les pose : le LIEU, l'ENJEU,
	# QUI S'Y OPPOSE, ce que le Voyageur RISQUE. Une intro qui n'annonce pas d'opposition
	# n'annonce aucun jeu.
	var usr: String = LORE_CANON + bloc_carnet() + "\nQuete proposee au Voyageur: \"%s\" -- %s%s\nEn tant que MERLIN qui conte une vieille legende, raconte en 5 a 7 phrases la LEGENDE derriere cette quete a %s, dans cet ordre : (1) le LIEU et ce qu'on en raconte, (2) CE QUI EST EN JEU -- nomme clairement ce qui est cherche, menace ou promis, (3) QUI ou QUOI s'y OPPOSE -- un etre, un serment, une force, nomme-le, (4) ce que le Voyageur RISQUE s'il echoue. Le mystere reste dans l'AMBIANCE, jamais dans la comprehension du but. Puis annonce que le Voyageur s'y engagea. COMMENCE en apostrophant le Voyageur (« Ecoute, Voyageur » ou « Approche, Voyageur »), puis bascule au recit. Francais, images celtiques concretes, pas d'anglicismes, pas de 4e mur. Termine sur une phrase complete." % [title, pitch, mem_line, lieu]
	# 260 et non 220 : au laboratoire, la légende de 187 tokens s'est fait couper en pleine
	# phrase (« sans la clé ») — le budget doit laisser au modèle la place de refermer.
	return {"system": voice, "user": usr, "opts": {"creative": true, "max_tokens": 260,
			"cerveau": "vif", "fin_phrase": true, "label": "intro de quête (Merlin)"}}


# --- OUVERTURE NARRATIVE : lance VRAIMENT l'histoire de CE scénario (voix narrateur, 3-4 phrases) ---
static func opening(scenario: Dictionary, lieu: String = "Broceliande") -> Dictionary:
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var usr: String = ("Ouvre l'aventure « %s » a %s (accroche : %s). Conte 3 a 4 phrases qui LANCENT l'histoire, a la 2e PERSONNE (« Vous ») au PRESENT : plante le decor et l'atmosphere, fais sentir l'enjeu, finis sur ce qui vous pousse au premier pas. Phrases courtes et directes, images celtiques concretes (une au plus), SANS remplissage ni lyrisme, pas de 4e mur, JAMAIS « que faire ». Commence l'histoire (ne la resume pas) et termine sur une phrase complete.") % [title, lieu, pitch]
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": MAX_TOK_PROSE, "label": "ouverture (histoire)"}}


# --- ARC NARRATIF : 5 étapes liées, CHACUNE construite autour de ses tags requis (req_tags) →
#     la scène DEMANDE ces forces (scène ⇄ tags ⇄ cartes alignés). ---
# v1.0-V4a (spec §F) — `pool_list` = pool générable AFFICHÉ, injecté comme LISTE FERMÉE (contrainte
# dure) : les scènes ne réclament que des forces atteignables par le build courant. [] = legacy.
# SCÈNE EN LOOKAHEAD — la scène du beat `pos+1` (sur `total`), écrite APRÈS l'issue du beat
# précédent, en la connaissant.
#
# POURQUOI. L'arc pré-écrit par tranches ne peut pas savoir ce que la résolution du joueur a
# fait : la scène suivante ignorait le geste, le degré, la conséquence — « les beats ne
# s'enchaînent pas logiquement par rapport à ce qui a été fait » (Maxime, 2026-08-18). C'est le
# lookahead que la bible prescrit depuis le départ : la situation N+1 s'écrit pendant que le
# joueur lit l'issue N, avec cette issue DANS le prompt.
# v42 — LE PASSÉ DU VOYAGEUR N'EXISTE PAS TANT QU'IL N'EST PAS ÉCRIT (bible §6 R166 :
# le seul passé admis est composé depuis MerlinChronicle). Le modèle brodait des fautes
# anciennes et des retours — « répare le pacte que tu as enfreint », « je t'ai vu revenir
# de tes longs voyages » — sur un personnage qui n'a jamais rien vécu ici.
const REGLE_PASSE: String = "\nLE VOYAGEUR N'A AUCUN PASSE ICI : il n'a jamais rien jure, rien trahi, rien enfreint, rien laisse derriere lui, et il ne revient de nulle part. INTERDIT de lui preter une faute ancienne, une dette, un serment deja pris, un retour, une reputation ou des voyages passes ; INTERDIT qu'un personnage le reconnaisse, l'ait 'deja vu' ou lui rappelle quoi que ce soit. Tout ce qui se joue NAIT MAINTENANT, sous ses yeux."

# v42 — LE CANON (bible §6) : le monde a des bornes, et des figures qui portent des noms.
# v42.1 — L'issue vit dans un contexte de 2048 tokens : le canon complet l'a fait
# déborder (p61 : prompt 2045 tok, 2 tokens écrits, 4 bancs). Elle raconte le geste
# du joueur, elle ne peuple pas le monde — la règle lui suffit, en trois lignes.
const REGLE_PASSE_BREVE: String = "\nLE VOYAGEUR N'A AUCUN PASSE ICI : il n'a jamais rien jure, trahi ni laisse derriere lui, et PERSONNE ne le reconnait. Tout nait maintenant."

const LORE_CANON: String = "\nCANON DE BROCELIANDE (le seul monde autorise, et il a une LOI). Broceliande est une foret-REVE qui BOUCLE sur elle-meme : rien n'y finit ni n'y avance vraiment, les etres REJOUENT sans fin la meme scene (les druides repetent un rite dont le sens s'est efface ; le chevalier rejoue sa defaite ; les creatures rebouclent leurs pactes). SEUL le Voyageur avance -- c'est ce qui le rend etranger a ces bois. DECOR concret : brume, dolmens, houx, fougeres, sources, pierres levees, huttes de chaume, tourbieres, landes de bruyere ; la monnaie est le gwenneg. FIGURES NOMMEES (les seules autorisees) : le Choeur des Druides (deux voix qui se repetent et se contredisent) ; l'Ankou, le Passeur de Brumes (pose, sans malice ni pitie, il reclame son du) ; la Lavandiere de Nuit (elle lave des linceuls au gue et reclame de l'aide, jamais sans prix) ; les korrigans (petit peuple moqueur, cornes rouges) ; Fanch le Trotteur le colporteur (il vend et troque contre des gwenneg -- un troc ne s'annule pas) ; Kado le Cordier (humain perdu, sans faction) ; le Chevalier a l'armure ternie (il rejoue sa defaite) ; l'Enfant (innocent qu'on protege) ; Arthur (rare, apeure, se croit traque). LIEUX qu'on peut nommer : la Fontaine de Barenton (elle bout sans chaleur), le Val sans Retour, le Pas de Nuit, le Gue des Brumes, la Pierre Qui Oublie, le Chene Creux, le Tertre des Neuf. INTERDIT car GENERIQUE (ce n'est PAS ce monde) : AUCUN dieu nomme (ni Lugh, ni Cernunnos, ni Dana, ni Brigid), AUCUNE magie a incantation ni sort qui brille, AUCUNE prophetie ni elu, AUCUNE fee ailee, AUCUN objet enchante vague, AUCUN 'ancien pouvoir' abstrait. Le merveilleux ici est CONCRET et INQUIETANT : une source qui bout froide, un linge lave la nuit, un rire mis en gage, un pas qu'on ne peut refaire. Aucun demon ni ange, aucun chevalier de la Table Ronde autre qu'Arthur, aucune epoque autre que celtique, aucun objet moderne, jamais d'anglicisme, jamais le 4e mur."

# v43 — LE CARNET, DIT AU MODELE. Le Voyageur SE SOUVIENT (décision Maxime), mais
# uniquement de ces pages : elles sont écrites par le code à la fin de chaque partie,
# jamais par le modèle. Carnet vide = première venue, et l'interdiction reprend.
static func bloc_carnet() -> String:
	var pages: Array = MerlinChronicle.carnet_lire()
	if pages.is_empty():
		return REGLE_PASSE
	var fins: Dictionary = {"accomplissement": "menee au bout", "mort": "finie dans la mort", "corrompu": "finie dans la corruption"}
	var lignes: PackedStringArray = []
	for e in pages:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		var bout: String = "- « %s », %s (integrite %d, corruption %d)" % [
			str(d.get("t", "une quete")), str(fins.get(str(d.get("f", "")), "laissee en chemin")),
			int(d.get("i", 0)), int(d.get("c", 0))]
		var pnj: Array = (d.get("p", []) as Array) if d.get("p") is Array else []
		if not pnj.is_empty():
			bout += " ; croises : " + ", ".join(PackedStringArray(pnj))
		var faits: Array = (d.get("a", []) as Array) if d.get("a") is Array else []
		if not faits.is_empty():
			bout += " ; " + ", ".join(PackedStringArray(faits))
		lignes.append(bout)
	if lignes.is_empty():
		return REGLE_PASSE
	return "\nCE QUE LE VOYAGEUR A DEJA VECU ICI (seule source autorisee d'un passe ; TOUT autre souvenir, dette, faute ou serment est INTERDIT, et personne ne le reconnait au-dela de ces lignes) :\n" + "\n".join(lignes)


# La même vérité, en une ligne : l'issue vit dans 2048 tokens (leçon v42.1).
static func _regle_passe_issue() -> String:
	var pages: Array = MerlinChronicle.carnet_lire()
	if pages.is_empty():
		return REGLE_PASSE_BREVE
	var d: Dictionary = (pages[0] as Dictionary) if pages[0] is Dictionary else {}
	return "\nLe Voyageur a deja traverse ces bois une fois (« %s »). RIEN d'autre de son passe n'existe : aucun autre souvenir, aucune dette, aucun serment." % str(d.get("t", "une quete"))


static func scene_jit(scenario: Dictionary, btype: String, pos: int, total: int,
		req_tags: Array, precedent: String, issue_precedente: String,
		faction_block: String = "", lieu: String = "Broceliande", pool_list: Array = []) -> Dictionary:
	var title: String = str(scenario.get("title", "")).strip_edges()
	var pitch: String = str(scenario.get("pitch", "")).strip_edges()
	var role: String = _role_de_beat(btype, pos, total, title)
	var cues: PackedStringArray = []
	for t in req_tags:
		cues.append(str(TAG_CUE.get(str(t), str(t))))
	var cue_txt: String = " ET ".join(cues) if cues.size() > 0 else "agir"
	var pool_line: String = ""
	if not pool_list.is_empty():
		var pl: PackedStringArray = []
		for t in pool_list:
			pl.append(str(t))
		pool_line = "\nFORCES AUTORISEES (liste FERMEE) : %s. La scene ne doit exiger QUE des forces de cette liste." % ", ".join(pl)
	var fil: String = ""
	if precedent.strip_edges() != "":
		fil += "\nSCENE PRECEDENTE (ne la reecris pas) : %s" % precedent.strip_edges()
	if issue_precedente.strip_edges() != "":
		fil += "\nCE QUE LE VOYAGEUR VIENT DE FAIRE ET SON RESULTAT : %s\nTa scene DECOULE de ce resultat : elle en porte la trace visible (une porte ouverte reste ouverte, un etre offense reste offense, une dette suit)." % issue_precedente.strip_edges()
	# v35.6 — TÊTE STABLE d'abord (identité de quête, règles, pool : identiques d'un beat à
	# l'autre → le cache de préfixe KV saute leur évaluation), le VARIABLE en queue (numéro,
	# rôle, fil du récit). Et 2-3 phrases : course49 — 3 scènes finies en 95-108 s pour une
	# fenêtre de 53-70 s, toutes jetées « trop tard ». Une scène courte est une scène SERVIE.
	var usr: String = faction_block + ("Conte une SCENE de la quete « %s » (%s) a %s. 2e PERSONNE (« Vous »), au PRESENT." % [
		title, pitch, lieu]) \
		+ LORE_CANON + REGLE_PASSE \
		+ "\nLa scene = 1 a 2 phrases COURTES et CONCRETES (qui, quoi, ou ; AUCUNE image, AUCUN lyrisme, AUCUNE comparaison) avec un MONDE VIVANT (un personnage qui AGIT ou une presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ». UN DETAIL, UN SEUL, montre que ces bois REJOUENT : un etre qui refait un geste deja fait, une trace qui revient, une parole redite comme si c'etait la premiere fois. Montre-le, ne l'explique JAMAIS. Rien d'autre que la scene." \
		+ pool_line \
		+ ("\nSCENE %d sur %d." % [pos + 1, total]) \
		+ "\nROLE de cette scene : %s ; ecris une scene ou il faut %s (c'est CE que le Voyageur devra faire)." % [role, cue_txt] \
		+ fil
	# v35.1 — plein_regime : la scène s'écrit pendant la LECTURE (le Vif est libre, la voie
	# est seule) — à 4 fils elle tient dans la fenêtre (~30 s contre 92-97 s mesurés à 1 fil).
	return {"system": SYSTEM_PREFIX, "user": usr,
			"opts": {"creative": true, "max_tokens": 65, "fin_phrase": true, "plein_regime": true,
			"label": "scène %d (lookahead)" % [pos + 1]}}


# TRANCHE D'ARC — les beats `debut+1` à `debut+types.size()` d'une quête qui en compte `total`.
#
# POURQUOI DES TRANCHES. L'arc était figé à CINQ étapes, en une seule génération. Une quête plus
# longue n'avait donc aucune histoire écrite au-delà du cinquième beat — et comme les quêtes
# tiraient 2 à 5 beats, `prepare_arc` abandonnait le plus souvent avant même d'appeler le modèle.
# Une quête unique de 8 à 25 beats ne peut pas s'écrire d'un bloc : trop long à attendre, et le
# modèle perd le fil. On demande donc quatre ou cinq scènes à la fois, la première tranche avant
# de jouer, les suivantes pendant qu'on joue les précédentes.
#
# `precedent` porte ce qui a déjà été raconté : sans lui, la tranche 3 réinventerait le décor et
# le fil rouge se romprait exactement là où on cherche à le tenir.
static func arc_tranche(scenario: Dictionary, req_tags: Array, types: Array, debut: int,
		total: int, precedent: String, faction_block: String = "",
		lieu: String = "Broceliande", pool_list: Array = []) -> Dictionary:
	var title: String = str(scenario.get("title", "")).strip_edges()
	var pitch: String = str(scenario.get("pitch", "")).strip_edges()
	var n: int = types.size()
	var steps: String = ""
	for i in n:
		var pos: int = debut + i                       # index absolu dans la quête
		var role: String = _role_de_beat(str(types[i]), pos, total, title)
		var pair: Array = (req_tags[i] as Array) if (i < req_tags.size() and req_tags[i] is Array) else []
		var cues: PackedStringArray = []
		for t in pair:
			cues.append(str(TAG_CUE.get(str(t), str(t))))
		var cue_txt: String = " ET ".join(cues) if cues.size() > 0 else "agir"
		steps += "\nETAPE %d = %s ; ecris une scene ou il faut %s (c'est CE que vous devrez faire)." % [
			pos + 1, role, cue_txt]
	var pool_line: String = ""
	if not pool_list.is_empty():
		var pl: PackedStringArray = []
		for t in pool_list:
			pl.append(str(t))
		pool_line = "\nFORCES AUTORISEES (liste FERMEE) : %s. Chaque scene ne doit exiger QUE des forces de cette liste, jamais d'autres." % ", ".join(pl)
	var suite: String = ""
	if precedent.strip_edges() != "":
		suite = "\nCE QUI S'EST DEJA PASSE (ne le reecris pas, ENCHAINE dessus) : %s" % precedent.strip_edges()
	var entete: String = ("Conte les ETAPES %d a %d d'une aventure qui en compte %d pour la quete "
			+ "« %s » (%s) a %s. 2e PERSONNE (« Vous »), au PRESENT. Une seule histoire suivie : "
			+ "chaque etape decoule de la precedente et rapproche du but de la quete.") % [
		debut + 1, debut + n, total, title, pitch, lieu]
	var usr: String = faction_block + entete + suite + steps + pool_line \
		+ "\nChaque etape = 3 a 4 phrases COURTES et CONCRETES (qui, quoi, ou ; AUCUNE image, AUCUN lyrisme, AUCUNE comparaison) avec un MONDE VIVANT (un personnage qui AGIT et PARLE, une presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ».\nDANS AU MOINS UNE etape de cette tranche,UN DETAIL, UN SEUL, montre que ces bois REJOUENT : un etre qui refait un geste deja fait, une trace qui revient, une parole redite comme si c'etait la premiere fois. Montre-le, ne l'explique JAMAIS." \
		+ "\nFormat STRICT : une etape par ligne, prefixee « %d. » a « %d. », rien d'autre." % [debut + 1, debut + n]
	return {"system": SYSTEM_PREFIX, "user": usr,
			"opts": {"creative": true, "max_tokens": 90 * n, "label": "arc — etapes %d-%d" % [debut + 1, debut + n]}}


# Le RÔLE dramatique d'un beat selon sa place dans la quête : l'ouverture découvre l'enjeu, la
# fin le résout, l'avant-dernier fait choisir, et le corps alterne selon le type du beat.
static func _role_de_beat(btype: String, pos: int, total: int, title: String) -> String:
	if pos == 0:
		return "arrivee : vous entrez dans le lieu et DECOUVREZ l'enjeu de la quete"
	if pos >= total - 1:
		return "la confrontation finale qui RESOUT la quete : vous atteignez, obtenez ou affrontez ce que « %s » promet" % title
	if pos == total - 2:
		return "un choix a faire qui engage la fin"
	match btype:
		"Rencontre":
			return "une rencontre (un etre, une voix) qui AGIT et vous APPREND un bout de legende sur le but a atteindre"
		"Epreuve":
			return "un obstacle physique sur le chemin du but"
		"Dilemme":
			return "un choix a faire qui engage la suite"
		_:
			return "une progression dans le lieu qui RAPPROCHE du but et montre ce qui y resiste"


static func arc(scenario: Dictionary, req_tags: Array, faction_block: String = "", lieu: String = "Broceliande", pool_list: Array = []) -> Dictionary:
	var title: String = str(scenario.get("title", "")).strip_edges()
	var pitch: String = str(scenario.get("pitch", "")).strip_edges()
	var roles: Array = [
		"arrivee : vous entrez dans le lieu et DECOUVREZ l'enjeu de la quete",
		"une rencontre (un etre, une voix) qui AGIT et vous APPREND un bout de legende sur le but a atteindre",
		"un obstacle physique sur le chemin du but",
		"un choix a faire qui engage la suite",
		"la confrontation finale qui RESOUT la quete : vous atteignez, obtenez ou affrontez ce que « %s » promet" % title,
	]
	var steps: String = ""
	for i in 5:
		var pair: Array = (req_tags[i] as Array) if (i < req_tags.size() and req_tags[i] is Array) else []
		var cues: PackedStringArray = []
		for t in pair:
			cues.append(str(TAG_CUE.get(str(t), str(t))))
		var cue_txt: String = " ET ".join(cues) if cues.size() > 0 else "agir"
		steps += "\nETAPE %d = %s ; ecris une scene ou il faut %s (c'est CE que vous devrez faire)." % [i + 1, str(roles[i]), cue_txt]
	# v10.22 (user) — la question rituelle « Que decida le Voyageur ? » est SUPPRIMEE : chaque etape finit
	# sur l'instant suspendu ou le Voyageur doit agir, SANS formule systematique.
	# v1.0-V4a (spec §F) — liste FERMEE des forces atteignables : l'arc ne met en scene rien d'autre.
	var pool_line: String = ""
	if not pool_list.is_empty():
		var pl: PackedStringArray = []
		for t in pool_list:
			pl.append(str(t))
		pool_line = "\nFORCES AUTORISEES (liste FERMEE) : %s. Chaque scene ne doit exiger QUE des forces de cette liste, jamais d'autres." % ", ".join(pl)
	var usr: String = faction_block + ("Conte une aventure en 5 ETAPES qui S'ENCHAINENT (chaque etape decoule de la precedente, une seule histoire suivie) pour la quete « %s » (%s) a %s. 2e PERSONNE (« Vous »), au PRESENT." % [title, pitch, lieu]) + steps + pool_line + "\nChaque etape = 3 a 4 phrases COURTES et CONCRETES (qui, quoi, ou ; AUCUNE image, AUCUN lyrisme, AUCUNE comparaison) avec un MONDE VIVANT (un personnage qui AGIT et PARLE, une presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ».\nDANS AU MOINS UNE etape de cette tranche,UN DETAIL, UN SEUL, montre que ces bois REJOUENT : un etre qui refait un geste deja fait, une trace qui revient, une parole redite comme si c'etait la premiere fois. Montre-le, ne l'explique JAMAIS.\nEXEMPLE de MANIERE (pas le contenu) :\n1. Vous vous enfoncez sous les fougeres ; le sous-bois s'obscurcit, et un pas leger vous suit a distance.\n2. Au detour d'un tronc, une vieille femme se dresse, une serpe a la main, et vous barre le chemin sans un mot.\nFormat STRICT : une etape par ligne, prefixee « 1. » a « 5. », rien d'autre."
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": 340, "label": "arc narratif (5 étapes)"}}


# --- RÉSOLUTION : le code a calculé le degré ; le prompt fait NARRER la COMBINAISON comme UN geste
#     unifié (R63/R105). `run_thread` = fil rouge {title, last_gist} passé par merlin_scenario. ---
# `richesse` 0|1|2 : cible de phrases et budget de l'issue. 0 = l'équilibre actuel (3-4 phrases) ;
# 1 = ample (5-7) ; 2 = très ample (7-9). Constante pour une session entière — la cible vit dans
# la TÊTE STABLE du prompt, donc en changer casse le cache de préfixe : c'est un réglage, pas un
# paramètre par beat. Ajouté pour le laboratoire du 2026-08-18 (« résolutions trop légères »),
# et briqué pour le futur preset Éco/Équilibré/Riche des Options (R74).
# La TÊTE STABLE du prompt d'issue — exposée pour que le Vif puisse l'AMORCER au chargement :
# lue une fois, elle reste chaude dans SON cache toute la session, et chaque issue ne paie plus
# que sa queue variable.
static func _tete_issue_interne(richesse: int) -> String:
	var ex: String = "EXEMPLE (imite la MANIERE, pas le contenu). Situation: une dalle de pierre barre le gue, le courant pousse fort. Forces fondues: « le corps plie sans rompre » + « la poigne qui ne tremble pas ». Issue (reussite): [i]Vous calez vos pieds dans la vase et poussez la dalle sans jamais rompre l'effort.[/i] La pierre racle, bascule, et libere le passage ; sur l'autre rive, le vieux passeur relache sa gaffe et vous fait signe d'avancer."
	# v34 (Maxime : « trop long, trop de figures imagées — style Hand of Fate 2 ») : paliers
	# resserrés — 0 = sec (2-4), 1 = intermédiaire (3-5, DÉFAUT), 2 = riche (inchangé).
	# v36 (Maxime : « trop de texte, pas assez direct ») : 2-3 phrases sèches par défaut.
	var cible_phrases: String = "2 a 3 phrases PUIS la phrase de suite (3 a 4 plus la suite si le moment est un Climax ou une reussite eclatante)"
	if richesse == 1:
		cible_phrases = "2 a 3 phrases PUIS la phrase de suite (3 a 4 plus la suite si le moment est un Climax ou une reussite eclatante)"
	elif richesse >= 2:
		cible_phrases = "7 a 9 phrases, amples et sensorielles (jusqu'a 10 si le moment est un Climax)"
	return ex + _regle_passe_issue() + "\nREGLES : Raconte l'issue a la 2e PERSONNE (« Vous ») au PRESENT, en " + cible_phrases + ". Ta TOUTE PREMIERE phrase est le GESTE, ECRITE ENTRE [i] et [/i] et commencant par « Vous ». LE GESTE T'EST DONNE EN FIN DE PROMPT : accomplis-le avec TES mots et le detail de CETTE scene, sans y ajouter aucun autre geste. TRADUIS les forces en gestes ; n'ecris JAMAIS le mot 'registre' ni PAROLE / FORCE / PERCEPTION / PROTECTION / OMBRE en majuscules ; ne CITE JAMAIS de formule entre guillemets. Referme la balise [/i] a la fin de cette premiere phrase. PUIS, HORS italique, raconte CE QUE CELA CAUSE : le personnage ou le monde REAGIT (il cede, se lie, explique, se retourne, se referme), la consequence concrete qui RESOUT la situation. Ta consequence fait AGIR ou REAGIR au moins un element NOMME de la situation : c'est ce qui prouve que l'issue appartient a CETTE scene. NE RE-DECRIS PAS le decor deja connu (reprendre = le faire agir, jamais le redecrire). TON DIRECT de conteur de jeu de cartes : phrases COURTES et DECLARATIVES, chaque phrase enonce un FAIT (quelqu'un agit, le monde repond). AUCUNE image, AUCUNE metaphore, AUCUNE comparaison ('comme si', 'tel un', 'pareil a') — nulle part, Climax compris : du CONCRET sec, l'ambiance vient des FAITS. Phrases LIEES et CONCRETES. Chaque phrase a pour sujet le Voyageur, un etre ou un objet NOMME : une abstraction ('le silence', 'la brume', 'la presence') n'agit JAMAIS. LE RESULTAT PRIME sur les forces : pour un echec, l'action est TENTEE mais elle ECHOUE (la porte reste close, l'obstacle resiste) ; pour un partiel, elle ne reussit qu'a demi avec un prix : ne narre JAMAIS un succes net si l'issue n'en est pas un. INTERDIT de finir sur « vous poursuivez votre route » ou « vous continuez le chemin ». Pas de liste ni de chiffres. TERMINE par UNE phrase courte qui OUVRE LA SUITE (ce qui attend le Voyageur au pas suivant) : elle relance, elle ne resume ni ne commente. Cette DERNIERE phrase COMMENCE par l'etre, la bete ou l'objet NOMME qui vient de reagir, et dit ce qu'il fait ou ce qu'il laisse au Voyageur : JAMAIS « Il », « Elle », « Ils », « Cela », JAMAIS une abstraction ('le silence', 'la brume', 'la presence'), AUCUNE parole rapportee. Termine sur une phrase complete."
	# Le degré est nommé DEUX fois — « ISSUE = X » puis le rappel « Fais RESSENTIR (X) » : cette
	# redondance date de v10.6 (l'échec se lisait comme un succès) et la revue adversariale du
	# 2026-08-18 a rattrapé sa disparition pendant le réordonnancement. En queue : cache-compatible.


static func tete_issue(richesse: int = 0) -> String:
	return _tete_issue_interne(richesse)


static func resolution(situation: Dictionary, played_cards: Array, res: Dictionary, run_thread: Dictionary, richesse: int = 0) -> Dictionary:
	var degree: String = str(res.get("degree", "reussite"))
	var deg_fr: Dictionary = {"echec": "un echec", "partiel": "un succes a un prix", "reussite": "une reussite", "eclatante": "une reussite eclatante"}
	# v10.6 — directive d'ISSUE explicite par degré : la lecture du batch (HTML contrôle) montrait
	# que l'échec se lisait comme un succès. On force le ressenti du résultat. (user 2026-06-06)
	var deg_directive: Dictionary = {
		"echec": "L'action ECHOUE : le monde RESISTE, se referme ou se retourne contre vous ; le personnage d'en face refuse, recule, se ferme. MONTRE l'echec par des FAITS concrets (la voie reste close, un recul, une perte), ne DIS PAS 'echec'.",
		"partiel": "Demi-succes a un PRIX : quelque chose cede a demi, et une ombre ou un cout suit aussitot. Le personnage cede du bout des levres, ou vous aide mais retient quelque chose. MONTRE-le par des FAITS, ne DIS PAS 'partiel'.",
		"reussite": "REUSSITE franche : le monde CEDE, le personnage se laisse convaincre, s'ouvre, vous aide ou vous laisse passer. MONTRE-le par des FAITS, ne DIS PAS 'reussite'.",
		"eclatante": "REUSSITE ECLATANTE au-dela de l'espoir : le personnage se lie a vous, le monde s'ouvre en grand, on vous donne plus que demande. MONTRE-le par des FAITS concrets, ne DIS JAMAIS 'memorable' ni 'reussite'.",
	}
	# v10.6 (user 2026-06-06 : « la combinaison ne s'établit pas dans le scénario ») — on passe le
	# SENS (évocation) de CHAQUE carte du combo de 2, et on demande explicitement de FAIRE SENTIR les
	# DEUX forces à l'œuvre, ancrées dans leurs images concrètes, fondues en un seul geste. Toujours
	# sans NOMMER les cartes (resté la consigne user 2026-05-29). → la prose reflète vraiment le combo.
	# Combo : on COLLECTE les 2 évocations, leurs ARCHETYPES (registre) + les tags joués.
	var evocs: Array = []
	var archs: Array = []
	var played_tags: Dictionary = {}
	for c in played_cards:
		if c is Object and "evocation" in c:
			var ev: String = str(c.evocation).strip_edges()
			if ev != "":
				evocs.append(ev)
		if c is Object and c.has_method("archetype"):
			archs.append(str(c.archetype()))
		if c is Object and "tags" in c:
			for t in c.tags:
				played_tags[str(t)] = true
	# Registre par archetype (user 2026-06-07 : « deux cartes de langage ne doivent pas donner une main
	# posee »). L'issue DOIT rester fidele a la NATURE des cartes → 2 cartes Social = issue VERBALE, etc.
	# Noms COURTS (la légende détaillée est dans la consigne, pas ici) → le modèle ne recopie plus la
	# description « FORCE du corps : il pousse » comme il le faisait. Dédupliqués (2 cartes meme registre = 1).
	var arch_reg: Dictionary = {
		"Social": "PAROLE", "Offensif": "FORCE", "Mystique": "PERCEPTION",
		"Défensif": "PROTECTION", "Corrompu": "OMBRE",
	}
	var registres: Array = []
	for a in archs:
		var r: String = str(arch_reg.get(a, "PERCEPTION"))
		if not registres.has(r):
			registres.append(r)
	var reg_hint: String = ""
	if registres.size() >= 1:
		reg_hint = " Registre attendu de l'action : " + " + ".join(PackedStringArray(registres)) + "."
	# Fusion : les évocations sont des DONNEES à TRADUIRE en gestes DU BON REGISTRE, pas une phrase citable.
	var combo: String = ""
	if evocs.size() >= 2:
		combo = "DEUX forces a fondre en UNE seule action concrete, DANS LEUR REGISTRE (TRADUIS-les, ne RECOPIE pas) -- force A = %s -- force B = %s" % [str(evocs[0]), str(evocs[1])]
	elif evocs.size() == 1:
		combo = "Une force a traduire en geste concret de son registre (ne recopie pas) = %s" % str(evocs[0])
	# Couverture (user 2026-06-06) : adéquation cartes ↔ tags requis. On décrit l'AJUSTEMENT
	# (les bonnes clés / les mauvaises), JAMAIS l'issue — c'est deg_directive qui POSSÈDE l'issue.
	# Évite la contradiction « rien obtenu » vs un degré de succès, ex. partiel à 0/2 (review MEDIUM).
	var required: Array = situation.get("required_tags", [])
	var covered: Array = []
	var missed: Array = []
	for t in required:
		if played_tags.has(str(t)):
			covered.append(str(t))
		else:
			missed.append(str(t))
	var cover_hint: String = ""
	if not required.is_empty():
		if missed.is_empty():
			cover_hint = " Vos deux forces etaient EXACTEMENT celles que ce lieu reclamait."
		elif not covered.is_empty():
			cover_hint = " L'une de vos forces etait la bonne, l'autre attendue MANQUAIT : la reussite reste INCOMPLETE (un manque, une lenteur, un reste qui suit) : ne la presente JAMAIS comme parfaite."
		else:
			cover_hint = " Aucune de vos forces n'etait celle que ce lieu reclamait : vous repondez a cote de ce qui etait demande."
	var syn: int = int(res.get("synergy", 0))
	var syn_hint: String = ""
	if syn > 0:
		syn_hint = " Vos deux forces se fondent en un geste fluide."
	elif syn < 0:
		syn_hint = " Vos deux forces tirent a hue et a dia (l'issue s'en ressent)."
	# Cohérence + variété (user 2026-06-07, critique passe profonde : toutes les issues finissaient en
	# « le chemin s'ouvre » et ignoraient le type de beat). On passe un FOCUS abstrait par type (sans
	# recopier le décor) → l'issue RÉSOUT ce que le beat posait, et la conclusion varie.
	var type_focus: Dictionary = {
		"Exploration": "ce qui etait cache se revele a vous (ou se derobe)",
		"Rencontre": "l'etre ou la voix d'en face REAGIT : il cede, se lie a vous, ou se retourne contre vous",
		"Epreuve": "l'obstacle concret (ronces, pente, pierre) est franchi ou vous resiste",
		"Dilemme": "vous avez TRANCHE : montre la voie choisie ET le prix immediat (ce que vous gagnez et ce que vous abandonnez), pas une simple ouverture de chemin",
		"Climax": "c'est le MOMENT DECISIF du sentier : l'issue pese lourd et marque une vraie BASCULE (triomphe ou chute), jamais une simple avancee de routine",
	}
	var ftype: String = str(situation.get("type", ""))
	var focus_hint: String = ""
	if type_focus.has(ftype):
		focus_hint = " Ce moment est une %s : l'issue doit faire avancer CELA (%s), pas se reduire a « le chemin s'ouvre »." % [ftype, str(type_focus[ftype])]
	# Fil rouge (user 2026-06-06) : identité du scénario (TITRE seul — le pitch se faisait recopier en
	# tête de prose, régression observée au probe) + position du beat + enchaînement avec le précédent.
	var ctx: String = ""
	var rt_title: String = str(run_thread.get("title", "")).strip_edges()
	if rt_title != "":
		ctx += "Aventure : « %s »\n" % rt_title
	# (Position du beat retirée du prompt : le modèle la narrait — « Le moment cinq du sentier arriva ».
	#  Le type de beat passe déjà par focus_hint ; la continuité par last_gist.)
	var prev: String = str(run_thread.get("last_gist", "")).strip_edges()
	if prev != "":
		ctx += "Juste avant : %s. Enchaine sans rompre le fil.\n" % prev
	# v49 — LE FIL PAR LA QUEUE. La scene affichee le porte deja en tete, mais SITU_MAX coupe
	# la narration PAR L'AVANT : sur la derniere partie le pont n'a survecu au prompt qu'UNE
	# fois sur quatre (narrations de 614, 581, 163, 551 caracteres contre un plafond de 480).
	# Une ligne dediee, en queue, ne peut jamais etre tronquee — et c'est elle qui empeche
	# l'issue N+1 d'ignorer ce que l'issue N avait promis.
	var fil_p: String = str(run_thread.get("last_fil", "")).strip_edges()
	if fil_p != "":
		ctx += "CE QUI ATTENDAIT LE VOYAGEUR EN ARRIVANT : %s\n" % fil_p
	# Longueur VARIABLE (user 2026-06-06 : « plus variable sur la longueur … quelquefois plus long
	# selon le déroulé ») : ample aux MOMENTS FORTS (Climax ou réussite éclatante), brève sinon.
	# La cible de phrases vit désormais dans la TÊTE STABLE du prompt (degré-neutre, pour le cache
	# de préfixe) ; long_form ne pilote plus que le budget de tokens.
	var long_form: bool = is_strong_moment(str(situation.get("type", "")), degree)
	# v36 — 2-3 phrases seches : ~110 tokens suffisent, l'ecriture tombe a ~15-25 s.
	# v45 — +20 tokens : la phrase de suite doit tenir SANS rogner la consequence.
	var tok_budget: int = 160 if long_form else 125
	if richesse == 1:
		tok_budget = 180 if long_form else 135
	elif richesse >= 2:
		tok_budget = 420 if long_form else 340
	# v10.17 (user 2026-06-07) : on PASSE la situation + un EXEMPLE gold (few-shot in-context) pour que
	# l'issue RESOLVE la situation precise (pas un generique « le chemin s'ouvre ») en fondant les 2
	# forces, calee sur la prose cible. MerlinProse.strip_scene_echo (côté scénario) reste le filet anti-recopiage.
	var situ_txt: String = str(situation.get("narration", "")).strip_edges()
	# v48.1g — LA QUEUE NE DOIT JAMAIS POUSSER LE PROMPT DANS LA FALAISE. Au-dela de
	# n_ctx-4 = 2044 tokens, le natif tronque PAR L'AVANT (merlin_llm.cpp:243-249) : il jette le
	# gabarit de chat, SYSTEM_PREFIX et le haut des regles, ET desactive la reutilisation du
	# prefixe KV (:271) — 40 a 57 s de relecture pour ne plus rien pouvoir ecrire (p68).
	# v48.1b a rendu ~450 tokens, ce qui ELOIGNE la falaise sans la supprimer : la narration
	# injectee ici variait de 239 a 694 caracteres selon les beats, et rien ne la bornait.
	# On garde la FIN : c'est la que vivent l'instant suspendu et les etres nommes que l'issue
	# doit faire reagir, et on repart d'une frontiere de phrase pour ne pas commencer en plein mot.
	const SITU_MAX: int = 480
	if situ_txt.length() > SITU_MAX:
		var _coupe: String = situ_txt.substr(situ_txt.length() - SITU_MAX)
		var _p: int = maxi(_coupe.find(". "), _coupe.find("\n"))
		situ_txt = _coupe.substr(_p + 1).strip_edges() if _p > 0 else _coupe
	var ex: String = "EXEMPLE (imite la MANIERE, pas le contenu). Situation: une dalle de pierre barre le gue, le courant pousse fort. Forces fondues: « le corps plie sans rompre » + « la poigne qui ne tremble pas ». Issue (reussite): [i]Vous calez vos pieds dans la vase et poussez la dalle sans jamais rompre l'effort.[/i] La pierre racle, bascule, et libere le passage ; sur l'autre rive, le vieux passeur relache sa gaffe et vous fait signe d'avancer."
	# TÊTE STABLE / QUEUE VARIABLE — une décision de PERFORMANCE mesurée (2026-08-18, VM) : le
	# prompt d'issue pèse ~1000 tokens et son ÉVALUATION seule coûtait 52-53 s, plus que la
	# fenêtre d'attente entière — l'écriture, elle, ne prend que 9 s. Le moteur ne relit pas ce
	# qu'il a déjà lu (cache de préfixe) : tout ce qui ne change pas d'un beat à l'autre vient en
	# tête (exemple + règles, ~600 tokens, lues UNE fois), tout ce qui change vient en queue
	# (scène, forces, degré, ~350 tokens). Dès le 2e beat, seule la queue est réévaluée.
	# Les règles sont DEGRE-NEUTRES pour rester identiques d'un beat à l'autre : le degré et sa
	# directive vivent en queue — la dernière position, celle que le modèle suit le mieux.
	var tete: String = _tete_issue_interne(richesse)
	# v36 — le VERBE du geste (tuile jouee, played_cards[0] par contrat R20) entre ENFIN dans
	# le prompt : sans lui, COMBATTRE donnait un fer plante en terre et PARLER une main posee.
	# v48.1b — LE GESTE ENTIER, PAS SEULEMENT LE VERBE. Le code compose deja cette phrase pour
	# l'ecran depuis v46 (socle du verbe + maniere du trait, 25 concepts couverts) ; la donner
	# ICI applique a l'ecriture la doctrine actee alors : ce qui doit etre vrai a 100 % ne se
	# demande pas a un LLM. Elle remplace ~425 tokens de regles qui tentaient d'obtenir le meme
	# invariant par la persuasion — le sens des registres, les gloses des cinq verbes, la maniere
	# du trait, l'interdit des gestes inventes.
	# En QUEUE, jamais en tete : elle change a chaque beat, elle casserait le cache de prefixe.
	var verbe_hint: String = ""
	var _geste: String = str(res.get("phrase_geste", "")).strip_edges()
	if _geste != "":
		verbe_hint = "\nLE GESTE (ta PREMIERE phrase le dit, avec tes mots et le detail de la scene) : " + _geste
	elif played_cards.size() >= 1 and played_cards[0] is Object and "card_name" in played_cards[0]:
		# Repli si le call-site n'a pas de phrase composee (harnais legacy) : le verbe seul.
		var _vb: String = str(played_cards[0].card_name).strip_edges()
		if _vb != "":
			verbe_hint = "\nVERBE DU GESTE : " + _vb + " — ta PREMIERE phrase l'accomplit litteralement."
	var queue: String = "\n" + ctx + "CE QUI SE PASSAIT : " + situ_txt + "\n" + combo + reg_hint + verbe_hint \
		+ "\nISSUE = " + str(deg_fr.get(degree, "une reussite")) + ". " + str(deg_directive.get(degree, "")) \
		+ cover_hint + syn_hint + focus_hint \
		+ " Fais clairement RESSENTIR le resultat (" + str(deg_fr.get(degree, "une reussite")) + ")."
	var usr: String = tete + queue
	# v48.1g — PLEIN REGIME. L'issue est la SEULE generation de la chaine chaude a ne pas le
	# demander : la selection le pose, scene_jit le pose, l'amorcage le pose, elle non. Sans lui
	# _apply_regime sert _fils_menage() = la moitie des coeurs (merlin_native.gd:468-482), soit
	# 2 fils sur 4. Les 8,4-8,7 tok/s mesures a p68 sont donc un debit a DEMI-REGIME, et le
	# debit plein du Vif n'a jamais ete mesure. Or l'issue est exactement le cas pour lequel le
	# plein regime a ete ecrit : la generation que le joueur attend le plus activement.
	# L'evaluation du prompt ne bouge pas (n_threads_batch est deja au plein dans les deux
	# regimes) ; seule l'ECRITURE accelere.
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": tok_budget,
			"cerveau": "vif", "fin_phrase": true, "plein_regime": true,
			"label": "issue (combinaison)"}}


# --- VOIX DU MENU : pensées COURTES de Merlin au-dessus de sa tête (100% LLM, user 2026-06-29) ---
# `mode` ∈ salut|journee|souvenir|encourage|blague|survol. `ctx` = contexte menu : tod (libellé heure),
# saison (libellé), runs_played, last_end_type, last_scenario_title, days_since_seen, bouton (survol).
# UNE phrase courte, 1re personne, il s'adresse au Voyageur. Sortie recoupée côté merlin_menu_voice.
static func menu_thought(voice: String, mode: String, ctx: Dictionary) -> Dictionary:
	var tod: String = str(ctx.get("tod", "le soir"))
	var saison: String = str(ctx.get("saison", ""))
	var runs: int = int(ctx.get("runs_played", 0))
	var days: int = int(ctx.get("days_since_seen", -1))
	var last_end: String = str(ctx.get("last_end_type", ""))
	var last_title: String = str(ctx.get("last_scenario_title", ""))
	var end_fr: Dictionary = {
		"accomplissement": "il a triomphe et entrevu un fragment du Graal",
		"mort": "il a succombe, et la foret l'a repris",
		"corrompu": "la Corruption l'avait emporte",
	}
	var ctx_line: String = "Contexte (NE le recite PAS tel quel) : on est %s, %s." % [tod, saison]
	var usr: String = ""
	match mode:
		"salut":
			var depuis: String = ""
			if days >= 2:
				depuis = " Tu ne l'as pas revu depuis %d jours." % days
			elif days == 1:
				depuis = " Tu ne l'as pas revu depuis hier."
			usr = "%s%s\nSalue le Voyageur en UNE phrase courte (max 14 mots), chaleureuse et un brin taquine, en accord avec le moment. Tu t'adresses a LUI." % [ctx_line, depuis]
		"journee":
			usr = "%s\nGlisse UNE pensee courte (max 14 mots) sur ce moment du jour ou cette saison a Broceliande. Image celtique breve, tu t'adresses au Voyageur ou penses tout haut." % ctx_line
		"souvenir":
			if runs <= 0 or last_end == "":
				return menu_thought(voice, "salut", ctx)
			# Allusion au PNJ pilier de la run précédente (« tu te souviens du Chœur ? ») si connu — v10.20.2.
			var pk: String = str(ctx.get("last_pilier", ""))
			if PILIERS.has(pk):
				usr = "%s\nLa derniere fois, le Voyageur a croise %s dans la foret. Evoque CE personnage en UNE phrase courte (max 16 mots), comme si TU t'en souvenais avec lui (tendre, taquin ou inquiet selon sa nature), sans tout deballer." % [ctx_line, str(PILIERS[pk]["nom"])]
			else:
				var what: String = str(end_fr.get(last_end, "son aventure s'etait achevee"))
				var titre: String = (" (l'aventure « %s »)" % last_title) if last_title != "" else ""
				usr = "%s\nLa derniere fois, le Voyageur a vecu ceci : %s%s. Fais-y allusion en UNE phrase courte (max 16 mots), fier ou taquin selon l'issue, sans tout deballer." % [ctx_line, what, titre]
		"encourage":
			usr = "%s\nEn UNE phrase courte (max 14 mots), encourage le Voyageur a repartir vers l'aventure dans la foret. Chaleureux, un brin malicieux." % ctx_line
		"blague":
			usr = "%s\nGlisse UNE courte boutade (max 14 mots), legere et merveilleuse, dans le gout celtique (korrigans, gui, brume, dolmen). Pas de meta." % ctx_line
		"premiere":
			usr = "%s\nC'est la TOUTE PREMIERE fois que tu rencontres ce Voyageur. Presente-toi brievement et accueille-le en UNE a DEUX phrases courtes (max 22 mots au total), mysterieux et bienveillant. Tu es Merlin, gardien de Broceliande." % ctx_line
		"depart":
			usr = "%s\nLe Voyageur s'elance vers l'aventure a l'instant meme. Lance-le en UNE phrase courte (max 12 mots), comme un seuil que vous franchissez ensemble. Tu t'adresses a lui." % ctx_line
		"survol":
			var bouton: String = str(ctx.get("bouton", ""))
			usr = "%s\nLe Voyageur hesite, la main au-dessus du choix « %s ». Commente son hesitation en UNE phrase courte (max 14 mots), taquine ou complice." % [ctx_line, bouton]
		_:
			usr = "%s\nDis UNE phrase courte (max 14 mots) au Voyageur." % ctx_line
	return {"system": voice, "user": usr, "opts": {"creative": true, "max_tokens": 56, "label": "pensée menu (%s)" % mode}}


# --- ÉPILOGUE (fin de run, R69) : voix MERLIN qui referme l'aventure pour le Voyageur. ---
# `mem` = memory hint intra-run, construit par merlin_scenario._build_memory_hint() (lit MerlinRun).
static func epilogue(voice: String, end_type: String, mem: String) -> Dictionary:
	var enj: Dictionary = {
		"accomplissement": "le Voyageur a traverse l'epreuve et entrevoit un fragment du Graal",
		"mort": "le Voyageur a succombe ; la foret l'a repris",
		"corrompu": "la Corruption l'a emporte ; le Voyageur s'est dissous dans la foret",
	}
	var what: String = str(enj.get(end_type, "le voyage s'acheve"))
	var mem_line: String = ("\nCe dont tu te souviens du Voyageur : %s." % mem) if mem != "" else ""
	var usr: String = "Fin de l'aventure : %s.%s\nEn tant que MERLIN qui le connaît, conte cet epilogue au Voyageur en 3 phrases : apostrophe-le ('Voyageur' ou 'mon ami'), evoque ce qu'il vient de vivre (ou ce dont tu te souviens), laisse entrevoir une suite. Termine sur une phrase complete." % [what, mem_line]
	return {"system": voice, "user": usr, "opts": {"creative": true, "max_tokens": 120, "label": "épilogue (Merlin)"}}
