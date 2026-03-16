## =============================================================================
## QuizData — Personality quiz questions, axes, and archetypes
## =============================================================================
## Pure data extracted from IntroPersonalityQuiz.gd.
## =============================================================================

extends RefCounted
class_name QuizData

const PERSONALITY_AXES := {
	"approche": {"negative": "prudent", "positive": "audacieux", "neutral": "adaptable"},
	"relation": {"negative": "solitaire", "positive": "social", "neutral": "equilibre"},
	"esprit": {"negative": "analytique", "positive": "intuitif", "neutral": "polyvalent"},
	"coeur": {"negative": "pragmatique", "positive": "compassionnel", "neutral": "nuance"},
}

const ARCHETYPES := {
	"gardien": {
		"pattern": {"approche": -1, "coeur": 1},
		"title": "Le Gardien",
		"desc": "Tu proteges ceux qui ne peuvent se defendre.\nTa prudence cache un coeur immense.",
	},
	"explorateur": {
		"pattern": {"approche": 1, "esprit": 1},
		"title": "L'Explorateur",
		"desc": "Le monde t'appelle et tu reponds.\nTon instinct te guide vers l'inconnu.",
	},
	"sage": {
		"pattern": {"relation": -1, "esprit": -1},
		"title": "Le Sage",
		"desc": "Tu observes, tu analyses, tu comprends.\nLa solitude nourrit ta reflexion.",
	},
	"heros": {
		"pattern": {"approche": 1, "relation": 1},
		"title": "Le Heros",
		"desc": "Tu avances sans peur vers le danger.\nLes autres trouvent force a tes cotes.",
	},
	"guerisseur": {
		"pattern": {"coeur": 1, "relation": 1},
		"title": "Le Guerisseur",
		"desc": "Tu ressens la douleur des autres.\nTa presence apaise les ames troublees.",
	},
	"stratege": {
		"pattern": {"esprit": -1, "approche": -1},
		"title": "Le Stratege",
		"desc": "Chaque action est calculee.\nTu vois dix coups a l'avance.",
	},
	"mystique": {
		"pattern": {"esprit": 1, "relation": -1},
		"title": "Le Mystique",
		"desc": "Tu percois ce que d'autres ignorent.\nLes brumes te murmurent leurs secrets.",
	},
	"guide": {
		"pattern": {"coeur": 1, "esprit": 1},
		"title": "Le Guide",
		"desc": "Ton intuition eclaire le chemin.\nTu menes par l'exemple et la bienveillance.",
	},
}

const QUESTIONS := [
	# Q1: Approche (prudent vs audacieux)
	{
		"text": "Tu te reveilles dans une foret inconnue.\nLa brume enveloppe tout.\nQue fais-tu en premier?",
		"choices": [
			{"text": "J'observe les environs en silence", "axes": {"approche": -2, "esprit": -1}},
			{"text": "J'appelle pour voir si quelqu'un repond", "axes": {"relation": 2, "approche": 1}},
			{"text": "Je cherche un point haut pour voir plus loin", "axes": {"approche": 1, "esprit": -1}},
			{"text": "Je reste immobile et j'ecoute", "axes": {"approche": -1, "esprit": 1}},
		]
	},
	# Q2: Relation (solitaire vs social)
	{
		"text": "Une voix murmure ton nom depuis les arbres.\nElle semble... familiere.",
		"choices": [
			{"text": "Je m'approche prudemment", "axes": {"approche": -1, "relation": 1}},
			{"text": "Je demande qui est la", "axes": {"approche": 1, "relation": 1}},
			{"text": "Je m'eloigne sans bruit", "axes": {"approche": -1, "relation": -2}},
			{"text": "Je tends l'oreille pour en savoir plus", "axes": {"esprit": 1, "relation": 0}},
		]
	},
	# Q3: Esprit (analytique vs intuitif)
	{
		"text": "Tu trouves un objet brillant au sol.\nIl pulse doucement d'une lueur bleutee.",
		"choices": [
			{"text": "Je le ramasse immediatement", "axes": {"approche": 2, "esprit": 1}},
			{"text": "Je l'examine sans le toucher", "axes": {"approche": -1, "esprit": -2}},
			{"text": "Je le laisse et continue mon chemin", "axes": {"coeur": -1, "approche": 0}},
			{"text": "Je ressens son energie avant de decider", "axes": {"esprit": 2, "coeur": 1}},
		]
	},
	# Q4: Coeur (pragmatique vs compassionnel)
	{
		"text": "Un animal blesse te regarde.\nSes yeux semblent pleins d'intelligence.",
		"choices": [
			{"text": "J'essaie de le soigner", "axes": {"coeur": 2, "relation": 1}},
			{"text": "Je lui parle doucement pour le rassurer", "axes": {"coeur": 1, "esprit": 1}},
			{"text": "Je passe mon chemin, la nature suit son cours", "axes": {"coeur": -2, "approche": 1}},
			{"text": "J'evalue s'il peut m'etre utile", "axes": {"coeur": -1, "esprit": -1}},
		]
	},
	# Q5: Relation deeper
	{
		"text": "La brume s'ecarte et revele un chemin.\nA gauche, des lumieres et des voix.\nA droite, le silence profond.",
		"choices": [
			{"text": "Je vais vers les lumieres", "axes": {"relation": 2, "approche": 1}},
			{"text": "Je choisis le silence", "axes": {"relation": -2, "esprit": 1}},
			{"text": "J'attends de voir si quelque chose change", "axes": {"approche": -1, "esprit": -1}},
			{"text": "Je crie pour signaler ma presence", "axes": {"relation": 1, "approche": 2}},
		]
	},
	# Q6: Approche in conflict
	{
		"text": "Tu decouvres un campement abandonne.\nUn feu couve encore. Des traces de lutte...",
		"choices": [
			{"text": "Je fouille les restes a la recherche d'indices", "axes": {"esprit": -1, "approche": 1}},
			{"text": "Je pars immediatement, c'est trop dangereux", "axes": {"approche": -2, "coeur": -1}},
			{"text": "Je cherche des survivants aux alentours", "axes": {"coeur": 2, "approche": 1}},
			{"text": "Je m'installe et attends le retour des occupants", "axes": {"relation": 1, "approche": -1}},
		]
	},
	# Q7: Esprit under pressure
	{
		"text": "Un enigme est gravee sur une pierre ancienne.\nElle promet un tresor... ou un piege.",
		"choices": [
			{"text": "J'analyse chaque symbole methodiquement", "axes": {"esprit": -2, "approche": -1}},
			{"text": "Je fais confiance a mon premier instinct", "axes": {"esprit": 2, "approche": 1}},
			{"text": "Je contourne la pierre et ignore l'enigme", "axes": {"coeur": -1, "approche": 0}},
			{"text": "Je cherche quelqu'un pour m'aider", "axes": {"relation": 2, "esprit": 0}},
		]
	},
	# Q8: Coeur in moral dilemma
	{
		"text": "Un voyageur te demande de l'aide.\nMais quelque chose dans son regard te trouble.",
		"choices": [
			{"text": "Je l'aide malgre mes doutes", "axes": {"coeur": 2, "approche": 1}},
			{"text": "Je refuse poliment et m'eloigne", "axes": {"coeur": -1, "approche": -1}},
			{"text": "Je l'interroge avant de decider", "axes": {"esprit": -1, "relation": 1}},
			{"text": "Je fais confiance a mon malaise", "axes": {"esprit": 2, "coeur": 0}},
		]
	},
	# Q9: Crisis situation
	{
		"text": "Un cri dechire la nuit.\nIl vient de la direction opposee a ton but.",
		"choices": [
			{"text": "Je cours vers le cri sans hesiter", "axes": {"approche": 2, "coeur": 2}},
			{"text": "Je reste sur mon chemin, j'ai une mission", "axes": {"coeur": -2, "esprit": -1}},
			{"text": "J'avance prudemment vers le son", "axes": {"approche": -1, "coeur": 1}},
			{"text": "Je cherche un point d'observation", "axes": {"esprit": -1, "approche": -1}},
		]
	},
	# Q10: Final reflection
	{
		"text": "Devant un lac immobile, tu vois ton reflet.\nIl te pose une question muette.\nQui es-tu vraiment?",
		"choices": [
			{"text": "Celui qui protege les autres", "axes": {"coeur": 2, "relation": 1}},
			{"text": "Celui qui cherche la verite", "axes": {"esprit": -1, "approche": 1}},
			{"text": "Celui qui suit son instinct", "axes": {"esprit": 2, "approche": 1}},
			{"text": "Celui qui avance seul dans l'ombre", "axes": {"relation": -2, "approche": -1}},
		]
	},
]
