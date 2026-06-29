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

const SYSTEM_PREFIX: String = "Tu es MERLIN, l'enchanteur de Broceliande, et tu CONTES l'aventure du Voyageur comme une vieille legende celtique. REGLES: raconte a la 3e PERSONNE, parle TOUJOURS du « Voyageur » (JAMAIS 'tu', JAMAIS 'je'). Temps du CONTE: passe simple et imparfait (« le Voyageur s'enfonca », « la brume montait », « il choisit de »). Francais SIMPLE et CLAIR, phrases qui S'ENCHAINENT (une action PUIS sa consequence), CONCRETES (qui, quoi, ou) — JAMAIS d'enigme, de sujet abstrait ('le vide', 'le nom') ni de phrases hachees deconnectees. Raconte les EVENEMENTS et les GESTES precis, pas des descriptions vagues. Pas d'anglicismes. Reste dans Broceliande. Ne romps JAMAIS le 4e mur (INTERDIT 'jeu', 'carte', 'joueur', 'IA', 'simulation'). Evite les cliches ('union parfaite', 'murmure ancien', 'silence sacre', 'energie ancienne'). Ne recopie JAMAIS cette consigne dans ta reponse."

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


# LLM réservé aux MOMENTS FORTS (Climax ou réussite éclatante) → réduit les rafales d'appels
# séquentiels qui stallent le moteur natif (générations en série). Ailleurs : procédural seul. (user 2026-05-29)
# Source de vérité unique (A4) : merlin_scenario.is_strong_moment délègue ici.
static func is_strong_moment(situ_type: String, degree: String) -> bool:
	return situ_type == "Climax" or degree == "eclatante"


# --- SÉLECTION : 3 scénarios (titre + pitch) — voix MERLIN (user 2026-05-29) ---
static func selection(voice: String) -> Dictionary:
	# Le pitch reste un IMPERATIF tutoye SANS appellation (le wrapper Merlin de build_intro
	# l'apostrophe ensuite — eviter le double 'Voyageur' empile).
	var usr: String = "En tant que MERLIN, propose 3 aventures au Voyageur dans Broceliande. Reponds UNIQUEMENT en JSON: [{\"title\":\"...\",\"pitch\":\"...\"},{...},{...}]. title = court et evocateur. pitch = UNE seule phrase d'appel a l'aventure, imperatif tutoye SANS dire 'Voyageur' (ex: 'Infiltre le marche aux noms voles.', 'Poursuis le gobelin jusque dans la foret.', 'Va sonder la source qui ne ment pas.'). Varie les tons (enigmatique, taquin, sombre, intrigant)."
	return {"system": voice, "user": usr, "opts": {"creative": true, "max_tokens": 220, "label": "sélection (Merlin)"}}


# --- INTRO DE QUÊTE : légende contée par MERLIN (enrichit le pop-up en arrière-plan) ---
# `mem` = memory hint intra-run, construit par merlin_scenario._build_memory_hint() (lit MerlinRun).
static func intro(voice: String, scenario: Dictionary, mem: String) -> Dictionary:
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var mem_line: String = ("\nSouviens-toi du Voyageur : %s." % mem) if mem != "" else ""
	var usr: String = "Quete proposee au Voyageur: \"%s\" — %s%s\nEn tant que MERLIN qui conte une vieille legende, raconte en 3 a 4 phrases la LEGENDE derriere cette quete a Broceliande : ce qu'on raconte du lieu, ce qui s'y serait perdu ou cache, le danger qui y rode. Puis annonce que le Voyageur s'y engagea. COMMENCE en apostrophant le Voyageur (« Ecoute, Voyageur » ou « Approche, Voyageur »), puis bascule au recit. Francais, images celtiques concretes, pas d'anglicismes, pas de 4e mur. Termine sur une phrase complete." % [title, pitch, mem_line]
	return {"system": voice, "user": usr, "opts": {"creative": true, "max_tokens": 120, "label": "intro de quête (Merlin)"}}


# --- OUVERTURE NARRATIVE : lance VRAIMENT l'histoire de CE scénario (voix narrateur, 3-4 phrases) ---
static func opening(scenario: Dictionary) -> Dictionary:
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var usr: String = ("Ouvre l'aventure « %s » a Broceliande (accroche : %s). Conte 3 a 4 phrases qui LANCENT l'histoire, a la 3e PERSONNE (« le Voyageur ») au temps du CONTE : plante le decor et l'atmosphere, fais sentir l'enjeu, finis sur ce qui le pousse au premier pas. Images celtiques concretes, SANS remplissage, pas de 4e mur. Commence l'histoire (ne la resume pas) et termine sur une phrase complete.") % [title, pitch]
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": MAX_TOK_PROSE, "label": "ouverture (histoire)"}}


# --- ARC NARRATIF : 5 étapes liées, CHACUNE construite autour de ses 2 tags requis (req_tags) →
#     la scène DEMANDE ces forces (scène ⇄ tags ⇄ cartes alignés). ---
static func arc(scenario: Dictionary, req_tags: Array) -> Dictionary:
	var title: String = str(scenario.get("title", "")).strip_edges()
	var pitch: String = str(scenario.get("pitch", "")).strip_edges()
	var roles: Array = [
		"arrivee : le Voyageur entre dans le lieu et DECOUVRE l'enjeu de la quete",
		"une rencontre (un etre, une voix) qui lui APPREND un bout de legende sur le but a atteindre",
		"un obstacle physique sur le chemin du but",
		"un choix a faire qui engage la suite",
		"la confrontation finale qui RESOUT la quete : le Voyageur atteint, obtient ou affronte ce que « %s » promet" % title,
	]
	var steps: String = ""
	for i in 5:
		var pair: Array = (req_tags[i] as Array) if (i < req_tags.size() and req_tags[i] is Array) else []
		var cues: PackedStringArray = []
		for t in pair:
			cues.append(str(TAG_CUE.get(str(t), str(t))))
		var cue_txt: String = " ET ".join(cues) if cues.size() > 0 else "agir"
		steps += "\nETAPE %d = %s ; ecris une scene ou il faut %s (c'est CE que le Voyageur devra faire)." % [i + 1, str(roles[i]), cue_txt]
	var usr: String = ("Conte une aventure en 5 ETAPES qui S'ENCHAINENT (chaque etape decoule de la precedente, une seule histoire suivie) pour la quete « %s » (%s) a Broceliande. 3e PERSONNE (« le Voyageur »), temps du CONTE (passe simple / imparfait)." % [title, pitch]) + steps + "\nChaque etape = 2 a 3 phrases CONCRETES (qui, quoi, ou), SANS abstraction, et FINIT sur l'instant ou le Voyageur doit agir (« Que decida le Voyageur ? »).\nEXEMPLE de MANIERE (pas le contenu) :\n1. Le Voyageur s'enfonca sous les fougeres ; le sous-bois s'obscurcit, et l'on peinait a voir. Que decida le Voyageur ?\n2. Au detour d'un tronc, le Voyageur croisa une creature blessee, paisible, allongee sur la mousse. Il se demandait que faire.\nFormat STRICT : une etape par ligne, prefixee « 1. » a « 5. », rien d'autre."
	return {"system": SYSTEM_PREFIX, "user": usr, "opts": {"creative": true, "max_tokens": 340, "label": "arc narratif (5 étapes)"}}


# --- RÉSOLUTION : le code a calculé le degré ; le prompt fait NARRER la COMBINAISON comme UN geste
#     unifié (R63/R105). `run_thread` = fil rouge {title, last_gist} passé par merlin_scenario. ---
static func resolution(situation: Dictionary, played_cards: Array, res: Dictionary, run_thread: Dictionary) -> Dictionary:
	var degree: String = str(res.get("degree", "reussite"))
	var deg_fr: Dictionary = {"echec": "un echec", "partiel": "un succes a un prix", "reussite": "une reussite", "eclatante": "une reussite eclatante"}
	# v10.6 — directive d'ISSUE explicite par degré : la lecture du batch (HTML contrôle) montrait
	# que l'échec se lisait comme un succès. On force le ressenti du résultat. (user 2026-06-06)
	var deg_directive: Dictionary = {
		"echec": "Le geste ECHOUE : la foret RESISTE, repousse ou se referme ; rien n'est obtenu, ou pire quelque chose se retourne contre le Voyageur. MONTRE l'echec par des FAITS concrets (la voie reste fermee, un recul, une perte), ne DIS PAS 'echec'.",
		"partiel": "Demi-succes a un PRIX : quelque chose cede mais incomplet, et une ombre ou un cout suit aussitot. MONTRE-le par des FAITS (on avance un peu, mais quelque chose est pris en echange), ne DIS PAS 'partiel'.",
		"reussite": "REUSSITE franche : le geste porte, la voie s'ouvre, la foret cede. MONTRE-le par des FAITS, ne DIS PAS 'reussite'.",
		"eclatante": "Reussite ECLATANTE au-dela de l'espoir : la voie s'ouvre en grand, la lumiere monte, la foret cede sans resistance. MONTRE-le par des FAITS concrets, ne DIS JAMAIS 'memorable' ni 'reussite'.",
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
			cover_hint = " Les deux forces du Voyageur etaient EXACTEMENT celles que ce lieu reclamait."
		elif not covered.is_empty():
			cover_hint = " L'une des forces du Voyageur etait celle qu'il fallait, l'autre attendue MANQUAIT : la reussite reste INCOMPLETE (un manque, une lenteur, un reste qui suit) — ne la presente JAMAIS comme parfaite."
		else:
			cover_hint = " Aucune des forces du Voyageur n'etait celle que ce lieu reclamait : il repond a cote de ce qui etait demande."
	var syn: int = int(res.get("synergy", 0))
	var syn_hint: String = ""
	if syn > 0:
		syn_hint = " Les deux forces se fondent en un geste fluide."
	elif syn < 0:
		syn_hint = " Les deux forces tirent a hue et a dia (l'issue s'en ressent)."
	# Cohérence + variété (user 2026-06-07, critique passe profonde : toutes les issues finissaient en
	# « le chemin s'ouvre » et ignoraient le type de beat). On passe un FOCUS abstrait par type (sans
	# recopier le décor) → l'issue RÉSOUT ce que le beat posait, et la conclusion varie.
	var type_focus: Dictionary = {
		"Exploration": "ce qui etait cache se revele au Voyageur (ou se derobe a lui)",
		"Rencontre": "l'etre ou la voix d'en face reagit : il cede, se lie au Voyageur, ou se retourne contre lui",
		"Epreuve": "l'obstacle concret (ronces, pente, pierre) est franchi ou resiste au Voyageur",
		"Dilemme": "le Voyageur a TRANCHE : montre la voie qu'il choisit ET le prix immediat (ce qu'il gagne et ce qu'il abandonne), pas une simple ouverture de chemin",
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
		ctx += "Juste avant, %s enchaine sans rompre le fil.\n" % prev
	# Longueur VARIABLE (user 2026-06-06 : « plus variable sur la longueur … quelquefois plus long
	# selon le déroulé ») : ample aux MOMENTS FORTS (Climax ou réussite éclatante), brève sinon.
	var long_form: bool = is_strong_moment(str(situation.get("type", "")), degree)
	var phrase_target: String = "4 a 5 phrases" if long_form else "2 a 3 phrases"
	var tok_budget: int = 260 if long_form else 150
	# v10.17 (user 2026-06-07) : on PASSE la situation + un EXEMPLE gold (few-shot in-context) pour que
	# l'issue RESOLVE la situation precise (pas un generique « le chemin s'ouvre ») en fondant les 2
	# forces, calee sur la prose cible. MerlinProse.strip_scene_echo (côté scénario) reste le filet anti-recopiage.
	var situ_txt: String = str(situation.get("narration", "")).strip_edges()
	var ex: String = "EXEMPLE (imite la MANIERE, pas le contenu) — Situation: une dalle de pierre barrait le gue, le courant poussait fort. Forces fondues: « le corps plie sans rompre » + « la poigne qui ne tremble pas ». Issue (reussite): Le Voyageur choisit de caler ses pieds dans la vase et de pousser sans rompre. La dalle racla, bascula et libera le passage ; il franchit le gue, trempe mais debout."
	var usr: String = "%sCE QUI SE PASSAIT : %s\n%s%s\nISSUE = %s.%s%s%s%s\n%s\nRaconte l'issue en %s, a la 3e PERSONNE et au temps du CONTE (passe simple / imparfait). Ta TOUTE PREMIERE phrase DOIT commencer par « Le Voyageur choisit de » suivi de l'action concrete qui FOND les deux forces dans le registre attendu. (Sens des registres : PAROLE = il parle/convainc/ruse/charme ; FORCE = il agit physiquement, pousse/tient bon ; PERCEPTION = il voit/ressent/parle aux choses ; PROTECTION = il resiste/protege ; OMBRE = il appelle une force trouble a un prix.) Si c'est PAROLE, l'issue est VERBALE, JAMAIS un geste comme 'il pose la main'. TRADUIS les forces en actions ; n'ecris JAMAIS le mot 'registre' ni ces categories en majuscules ; ne CITE JAMAIS les formulations entre guillemets ; n'ecris JAMAIS 'fond deux gestes en un seul'. NE RE-DECRIS PAS la scene (le mur, le chemin, l'etre sont deja connus). PUIS raconte CE QUE CELA CAUSA : la consequence concrete qui RESOUT la situation (l'etre, l'obstacle ou le choix precis). Phrases LIEES et CONCRETES, sujets concrets (jamais 'le vide'/'le nom'). Fais clairement RESSENTIR le resultat (%s). LE RESULTAT PRIME sur les cartes : pour un echec, l'action est TENTEE mais elle ECHOUE (la porte reste close, l'obstacle resiste) ; pour un partiel, elle ne reussit qu'a demi avec un prix — ne narre JAMAIS un succes net si l'issue n'en est pas un, meme si une carte evoque la reussite. Varie la fin (pas toujours 'le chemin s'ouvre'). Pas de liste ni de chiffres. Termine sur une phrase complete." % [ctx, situ_txt, combo, reg_hint, deg_fr.get(degree, "une reussite"), str(deg_directive.get(degree, "")), cover_hint, syn_hint, focus_hint, ex, phrase_target, deg_fr.get(degree, "une reussite")]
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
			var what: String = str(end_fr.get(last_end, "son aventure s'etait achevee"))
			var titre: String = (" (l'aventure « %s »)" % last_title) if last_title != "" else ""
			usr = "%s\nLa derniere fois, le Voyageur a vecu ceci : %s%s. Fais-y allusion en UNE phrase courte (max 16 mots), fier ou taquin selon l'issue, sans tout deballer." % [ctx_line, what, titre]
		"encourage":
			usr = "%s\nEn UNE phrase courte (max 14 mots), encourage le Voyageur a repartir vers l'aventure dans la foret. Chaleureux, un brin malicieux." % ctx_line
		"blague":
			usr = "%s\nGlisse UNE courte boutade (max 14 mots), legere et merveilleuse, dans le gout celtique (korrigans, gui, brume, dolmen). Pas de meta." % ctx_line
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
