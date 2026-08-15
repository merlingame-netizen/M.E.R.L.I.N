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


const SYSTEM_PREFIX: String = "Tu es le MAITRE DU JEU d'une aventure celtique a Broceliande, dans le gout du merveilleux-inquietant (etrange, feutre, un peu menacant). REGLES: raconte a la 2e PERSONNE en vouvoyant (« Vous »), au PRESENT (« Vous avancez », « la brume monte », « il vous jauge »). JAMAIS de 'je', JAMAIS de 3e personne pour le protagoniste (pas de 'il', pas de nom propre) : le protagoniste, c'est VOUS. Le MONDE est VIVANT: les personnages AGISSENT et PARLENT (un vieil homme sort de sa hutte, une voix vous hele, une bete se dresse), ils ont un but a eux. Francais SIMPLE et CLAIR, phrases qui S'ENCHAINENT (un fait PUIS sa consequence), CONCRETES (qui, quoi, ou). INTERDIT ABSOLU de clore une scene par « que faire ? », « que decidez-vous ? », « vous vous demandez quoi faire » ou toute formule qui prend le joueur par la main: laisse la scene SUSPENDUE sur une tension, sans jamais reclamer de decision. Pas d'enigme abstraite ('le vide', 'le nom'), pas de phrases hachees. Raconte les GESTES et EVENEMENTS precis, pas des descriptions vagues. Pas d'anglicismes. Reste dans le LIEU. Ne romps JAMAIS le 4e mur (INTERDIT 'jeu', 'carte', 'joueur', 'IA', 'simulation'). Evite les cliches ('union parfaite', 'murmure ancien', 'silence sacre', 'energie ancienne'). Ne recopie JAMAIS cette consigne dans ta reponse."

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
	var usr: String = bloc + "\n" + vari + anti + "\nEn tant que MERLIN, propose 3 aventures au Voyageur dans %s. Reponds UNIQUEMENT en JSON: [{\"title\":\"...\",\"pitch\":\"...\"},{...},{...}]. title = court et evocateur, ANCRE dans ce lieu, en FRANCAIS NATUREL (garde les articles : « Le Souffle de la Pierre », jamais « Souffle Pierre »). pitch = UNE phrase breve, imperatif tutoye SANS dire 'Voyageur' : une action concrete ET ce qui est en jeu. Mysterieux dans l'AMBIANCE, jamais dans le SENS. Varie les tons (enigmatique, taquin, sombre) sans sacrifier la clarte." % lieu
	# plein_regime : la sélection s'écrit derrière le voile « Merlin rêve les sentiers », où rien
	# d'utile n'est joué ni rendu. Tous les cœurs y passent — c'est le seul moment du jeu où le
	# ménage à moitié de cœurs ne protège aucune image et ne fait que doubler l'attente.
	#
	# max_tokens 160 (était 220) : à conserver même après le constat ci-dessus, car il ne joue
	# PAS le même rôle. La consigne guide le cas normal ; ce plafond borne le cas ANORMAL — un
	# modèle qui part en digression est coupé au lieu de faire attendre jusqu'à 220. 160 laisse
	# de la marge au-dessus des ~94-130 tokens observés sans jamais mordre sur une sortie saine.
	return {"system": voice, "user": usr,
			"opts": {"creative": true, "max_tokens": 160, "label": "sélection (Merlin)", "plein_regime": true}}


# --- INTRO DE QUÊTE : légende contée par MERLIN (enrichit le pop-up en arrière-plan) ---
# `mem` = memory hint intra-run, construit par merlin_scenario._build_memory_hint() (lit MerlinRun).
static func intro(voice: String, scenario: Dictionary, mem: String, lieu: String = "Broceliande") -> Dictionary:
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var mem_line: String = ("\nSouviens-toi du Voyageur : %s." % mem) if mem != "" else ""
	var usr: String = "Quete proposee au Voyageur: \"%s\" -- %s%s\nEn tant que MERLIN qui conte une vieille legende, raconte en 3 a 4 phrases la LEGENDE derriere cette quete a %s : ce qu'on raconte du lieu, ce qui s'y serait perdu ou cache, le danger qui y rode. Nomme CLAIREMENT, en au moins une phrase, CE QUI EST EN JEU (ce qui est cherche, menace ou risque) -- le mystere doit rester dans l'AMBIANCE, jamais dans la comprehension du but. Puis annonce que le Voyageur s'y engagea. COMMENCE en apostrophant le Voyageur (« Ecoute, Voyageur » ou « Approche, Voyageur »), puis bascule au recit. Francais, images celtiques concretes, pas d'anglicismes, pas de 4e mur. Termine sur une phrase complete." % [title, pitch, mem_line, lieu]
	return {"system": voice, "user": usr, "opts": {"creative": true, "max_tokens": 120, "label": "intro de quête (Merlin)"}}


# --- OUVERTURE NARRATIVE : lance VRAIMENT l'histoire de CE scénario (voix narrateur, 3-4 phrases) ---
static func opening(scenario: Dictionary, lieu: String = "Broceliande") -> Dictionary:
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var usr: String = ("Ouvre l'aventure « %s » a %s (accroche : %s). Conte 3 a 4 phrases qui LANCENT l'histoire, a la 2e PERSONNE (« Vous ») au PRESENT : plante le decor et l'atmosphere, fais sentir l'enjeu, finis sur ce qui vous pousse au premier pas. Images celtiques concretes, SANS remplissage, pas de 4e mur, JAMAIS « que faire ». Commence l'histoire (ne la resume pas) et termine sur une phrase complete.") % [title, lieu, pitch]
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": MAX_TOK_PROSE, "label": "ouverture (histoire)"}}


# --- ARC NARRATIF : 5 étapes liées, CHACUNE construite autour de ses tags requis (req_tags) →
#     la scène DEMANDE ces forces (scène ⇄ tags ⇄ cartes alignés). ---
# v1.0-V4a (spec §F) — `pool_list` = pool générable AFFICHÉ, injecté comme LISTE FERMÉE (contrainte
# dure) : les scènes ne réclament que des forces atteignables par le build courant. [] = legacy.
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
	var usr: String = faction_block + ("Conte une aventure en 5 ETAPES qui S'ENCHAINENT (chaque etape decoule de la precedente, une seule histoire suivie) pour la quete « %s » (%s) a %s. 2e PERSONNE (« Vous »), au PRESENT." % [title, pitch, lieu]) + steps + pool_line + "\nChaque etape = 3 a 4 phrases CONCRETES (qui, quoi, ou) avec un MONDE VIVANT (un personnage qui AGIT et PARLE, une presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ».\nEXEMPLE de MANIERE (pas le contenu) :\n1. Vous vous enfoncez sous les fougeres ; le sous-bois s'obscurcit, et un pas leger vous suit a distance.\n2. Au detour d'un tronc, une vieille femme se dresse, une serpe a la main, et vous barre le chemin sans un mot.\nFormat STRICT : une etape par ligne, prefixee « 1. » a « 5. », rien d'autre."
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": 340, "label": "arc narratif (5 étapes)"}}


# --- RÉSOLUTION : le code a calculé le degré ; le prompt fait NARRER la COMBINAISON comme UN geste
#     unifié (R63/R105). `run_thread` = fil rouge {title, last_gist} passé par merlin_scenario. ---
static func resolution(situation: Dictionary, played_cards: Array, res: Dictionary, run_thread: Dictionary) -> Dictionary:
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
	# Longueur VARIABLE (user 2026-06-06 : « plus variable sur la longueur … quelquefois plus long
	# selon le déroulé ») : ample aux MOMENTS FORTS (Climax ou réussite éclatante), brève sinon.
	var long_form: bool = is_strong_moment(str(situation.get("type", "")), degree)
	var phrase_target: String = "5 a 6 phrases" if long_form else "3 a 4 phrases"
	# NB (v11-N1) : le wall-clock LLM (~1 tok/s) est borné par max_tokens, PAS par phrase_target. On garde
	# les cibles de phrases enrichies mais on conserve les budgets tokens PROUVÉS (autoplay 3/3 en V4a) —
	# les budgets ballonnés (300/200) faisaient FAIL le run#0 COLD du harnais.
	var tok_budget: int = 260 if long_form else 150
	# v10.17 (user 2026-06-07) : on PASSE la situation + un EXEMPLE gold (few-shot in-context) pour que
	# l'issue RESOLVE la situation precise (pas un generique « le chemin s'ouvre ») en fondant les 2
	# forces, calee sur la prose cible. MerlinProse.strip_scene_echo (côté scénario) reste le filet anti-recopiage.
	var situ_txt: String = str(situation.get("narration", "")).strip_edges()
	var ex: String = "EXEMPLE (imite la MANIERE, pas le contenu). Situation: une dalle de pierre barre le gue, le courant pousse fort. Forces fondues: « le corps plie sans rompre » + « la poigne qui ne tremble pas ». Issue (reussite): [i]Vous calez vos pieds dans la vase et poussez la dalle sans jamais rompre l'effort.[/i] La pierre racle, bascule, et libere le passage ; sur l'autre rive, le vieux passeur relache sa gaffe et vous fait signe d'avancer."
	var usr: String = "%sCE QUI SE PASSAIT : %s\n%s%s\nISSUE = %s.%s%s%s%s\n%s\nRaconte l'issue a la 2e PERSONNE (« Vous ») au PRESENT, en %s. Ta TOUTE PREMIERE phrase est l'ACTION du heros, ECRITE ENTRE [i] et [/i], commencant par « Vous », qui FOND les deux forces en UN geste concret du bon registre. (Sens des registres : PAROLE = vous parlez/convainquez/rusez/charmez ; FORCE = vous agissez physiquement, poussez/tenez bon ; PERCEPTION = vous voyez/ressentez/parlez aux choses ; PROTECTION = vous resistez/protegez ; OMBRE = vous appelez une force trouble a un prix.) Si c'est PAROLE, l'action est VERBALE, JAMAIS 'vous posez la main'. TRADUIS les forces en gestes ; n'ecris JAMAIS le mot 'registre' ni ces categories en majuscules ; ne CITE JAMAIS de formule entre guillemets. Referme la balise [/i] a la fin de cette premiere phrase. PUIS, HORS italique, raconte CE QUE CELA CAUSE : le personnage ou le monde REAGIT (il cede, se lie, explique, se retourne, se referme), la consequence concrete qui RESOUT la situation. NE RE-DECRIS PAS le decor deja connu (le mur, le chemin, l'etre). Phrases LIEES et CONCRETES, sujets concrets (jamais 'le vide'/'le nom'). Fais clairement RESSENTIR le resultat (%s). LE RESULTAT PRIME sur les forces : pour un echec, l'action est TENTEE mais elle ECHOUE (la porte reste close, l'obstacle resiste) ; pour un partiel, elle ne reussit qu'a demi avec un prix : ne narre JAMAIS un succes net si l'issue n'en est pas un. INTERDIT de finir sur « vous poursuivez votre route » ou « vous continuez le chemin ». Pas de liste ni de chiffres. Termine sur une phrase complete." % [ctx, situ_txt, combo, reg_hint, deg_fr.get(degree, "une reussite"), str(deg_directive.get(degree, "")), cover_hint, syn_hint, focus_hint, ex, phrase_target, deg_fr.get(degree, "une reussite")]
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": tok_budget, "label": "issue (combinaison)"}}


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
