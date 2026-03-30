// ═══════════════════════════════════════════════════════════════════════════════
// Card System — Card generation, FastRoute fallback, minigame selection
// ═══════════════════════════════════════════════════════════════════════════════

import { ACTION_VERBS, FIELD_MINIGAMES, MINIGAME_CATALOGUE, type FactionId } from './Constants';

// --- Card types ---

export interface CardOption {
  readonly verb: string;
  readonly text: string;
  readonly field: string;
  readonly effects: readonly string[];
}

export interface Card {
  readonly id: string;
  readonly narrative: string;
  readonly options: readonly [CardOption, CardOption, CardOption];
  readonly biome: string;
  readonly source: 'fastroute' | 'llm';
}

// --- FastRoute (hardcoded fallback cards) ---

let cardCounter = 0;

function nextCardId(): string {
  return `card_${Date.now()}_${++cardCounter}`;
}

/** Picks a random item from an array. */
function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Maps a verb to its lexical field. */
export function verbToField(verb: string): string {
  for (const [field, verbs] of Object.entries(ACTION_VERBS)) {
    if (verbs.includes(verb)) return field;
  }
  return 'esprit';
}

/** Picks a minigame appropriate for a lexical field. */
export function pickMinigame(field: string): string {
  const options = FIELD_MINIGAMES[field];
  if (!options || options.length === 0) return 'traces';
  return pick(options);
}

// FastRoute card templates (simplified — the full 500+ set would come from JSON)
const FASTROUTE_TEMPLATES: readonly {
  narrative: string;
  options: readonly [
    { verb: string; text: string; effects: readonly string[] },
    { verb: string; text: string; effects: readonly string[] },
    { verb: string; text: string; effects: readonly string[] },
  ];
}[] = [
  {
    narrative: 'Une brume epaisse s\'eleve entre les chenes centenaires. Des murmures anciens resonnent dans le feuillage. Un sentier se dessine, a peine visible, menant vers une clairiere ou scintille une lumiere doree.',
    options: [
      { verb: 'observer', text: 'Tu scrutes la brume, cherchant un signe dans les volutes argentees.', effects: ['HEAL_LIFE:3', 'ADD_REPUTATION:druides:5'] },
      { verb: 'se faufiler', text: 'Tu te glisses entre les racines noueuses vers la lumiere.', effects: ['ADD_BIOME_CURRENCY:5', 'DAMAGE_LIFE:2'] },
      { verb: 'apaiser', text: 'Tu respires profondement, laissant la foret te guider.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:3'] },
    ],
  },
  {
    narrative: 'Un korrigan surgit d\'un tertre moussu, ses yeux brillant d\'une malice millenaire. Il brandit un caillou grave de runes et te lance un defi : deviner le symbole cache dans la pierre.',
    options: [
      { verb: 'dechiffrer', text: 'Tu te concentres sur les gravures, cherchant le motif cache.', effects: ['ADD_REPUTATION:korrigans:8', 'ADD_ANAM:3'] },
      { verb: 'marchander', text: 'Tu proposes un echange plutot qu\'un defi.', effects: ['ADD_BIOME_CURRENCY:8', 'ADD_REPUTATION:korrigans:-3'] },
      { verb: 'combattre', text: 'Tu refuses le jeu et montres ta force.', effects: ['DAMAGE_LIFE:5', 'ADD_REPUTATION:ankou:5'] },
    ],
  },
  {
    narrative: 'Au bord d\'un lac immobile, une silhouette feminine se tient sur l\'eau. Niamh, la dame du lac, te fixe de ses yeux d\'argent. "Qu\'es-tu venu chercher ici, mortel ?" murmure-t-elle.',
    options: [
      { verb: 'parler', text: 'Tu reponds avec respect, partageant ta quete.', effects: ['ADD_REPUTATION:niamh:10', 'HEAL_LIFE:8'] },
      { verb: 'se concentrer', text: 'Tu restes silencieux, laissant ton esprit parler.', effects: ['ADD_REPUTATION:niamh:5', 'ADD_REPUTATION:druides:5'] },
      { verb: 'fuir', text: 'L\'aura surnaturelle t\'effraie. Tu recules.', effects: ['DAMAGE_LIFE:3', 'ADD_REPUTATION:niamh:-5'] },
    ],
  },
  {
    narrative: 'Un cairn imposant se dresse a la croisee de deux sentiers. Des ossements blanchis tapissent sa base. Un vent glacial souffle du nord, portant l\'odeur de la tourbe et du fer.',
    options: [
      { verb: 'fouiller a l\'aveugle', text: 'Tu fouilles parmi les offrandes deposees au pied du cairn.', effects: ['ADD_BIOME_CURRENCY:10', 'DAMAGE_LIFE:4'] },
      { verb: 'mediter', text: 'Tu t\'agenouilles et honores les ancetres.', effects: ['ADD_REPUTATION:anciens:10', 'HEAL_LIFE:3'] },
      { verb: 'pister', text: 'Tu suis les traces qui s\'eloignent du cairn.', effects: ['ADD_REPUTATION:ankou:3', 'ADD_ANAM:5'] },
    ],
  },
  {
    narrative: 'Le sol tremble sous tes pieds. Les racines d\'un if millenaire percent la terre, revelant une cavite ou pulse une lueur verdatre. Un druide age t\'observe depuis l\'ombre des branches.',
    options: [
      { verb: 'examiner', text: 'Tu t\'approches prudemment de la cavite lumineuse.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:8'] },
      { verb: 'resister mentalement', text: 'Tu fermes les yeux, refusant l\'appel de la lumiere.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'escalader', text: 'Tu grimpes dans l\'arbre pour avoir une meilleure vue.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Une melodie lointaine guide tes pas vers un cercle de pierres dressees. Chaque menhir porte un ogham different, et la musique semble provenir du centre exact du cercle.',
    options: [
      { verb: 'ecouter', text: 'Tu tends l\'oreille, laissant la melodie te guider.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:druides:6'] },
      { verb: 'dechiffrer', text: 'Tu etudies les oghams graves dans la pierre.', effects: ['ADD_ANAM:8', 'ADD_REPUTATION:anciens:4'] },
      { verb: 'courir', text: 'Tu traverses le cercle en courant, bravant l\'inconnu.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:5', 'ADD_REPUTATION:ankou:3'] },
    ],
  },
  // --- foret_broceliande + druides (20 cards) ---
  {
    narrative: 'Un chene sacre se dresse au coeur d\'une clairiere baignee de lumiere doree. Ses branches portent des rubans de tissu noues par des generations de druides. Un corbeau blanc t\'observe depuis la cime.',
    options: [
      { verb: 'mediter', text: 'Tu t\'assieds au pied du chene et fermes les yeux, absorbant l\'energie ancienne.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:druides:8'] },
      { verb: 'escalader', text: 'Tu grimpes le long du tronc rugueux pour atteindre le corbeau.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
      { verb: 'observer', text: 'Tu etudies les rubans, cherchant des motifs dans leurs couleurs.', effects: ['ADD_ANAM:4', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Une source jaillit entre des racines enchevelrees, son eau d\'un bleu impossible. Un druide agenouille y trempe une branche de gui, murmurant des paroles que le vent t\'apporte par bribes.',
    options: [
      { verb: 'parler', text: 'Tu t\'approches du druide et lui adresses la parole avec respect.', effects: ['ADD_REPUTATION:druides:10', 'HEAL_LIFE:4'] },
      { verb: 'cueillir', text: 'Tu cueillis discretement du gui sur une branche basse.', effects: ['ADD_BIOME_CURRENCY:8', 'ADD_REPUTATION:druides:-4'] },
      { verb: 'scruter', text: 'Tu observes le rituel a distance, memorisant chaque geste.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:druides:3'] },
    ],
  },
  {
    narrative: 'Le sentier se divise en trois. A gauche, des champignons luminescents forment un chemin ferique. Au centre, des empreintes de loup menent dans l\'obscurite. A droite, une fumee parfumee s\'eleve.',
    options: [
      { verb: 'suivre', text: 'Tu suis la lumiere des champignons, fascinee par leur eclat.', effects: ['ADD_BIOME_CURRENCY:5', 'HEAL_LIFE:3'] },
      { verb: 'pister', text: 'Tu suis les empreintes de loup dans l\'ombre.', effects: ['ADD_REPUTATION:ankou:6', 'DAMAGE_LIFE:2'] },
      { verb: 'sentir', text: 'Tu te diriges vers la fumee, intriguee par son parfum.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:druides:5'] },
    ],
  },
  {
    narrative: 'Un cercle de pierres mousseuses entoure un bassin d\'eau noire. Des libellules aux ailes dorees dansent a la surface. Le reflet dans l\'eau ne montre pas le ciel mais un reseau d\'oghams entrelaces.',
    options: [
      { verb: 'dechiffrer', text: 'Tu te penches pour lire les oghams dans le reflet.', effects: ['ADD_ANAM:8', 'ADD_REPUTATION:druides:6'] },
      { verb: 'tenter sa chance', text: 'Tu plonges la main dans l\'eau noire.', effects: ['ADD_BIOME_CURRENCY:10', 'DAMAGE_LIFE:5'] },
      { verb: 'se concentrer', text: 'Tu fermes les yeux et laisses les symboles venir a toi.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:niamh:5'] },
    ],
  },
  {
    narrative: 'Une biche blanche traverse le sentier devant toi, s\'arretant un instant pour te fixer de ses yeux d\'ambre. Derriere elle, la foret semble s\'ouvrir sur un passage secret entre les fougeres geantes.',
    options: [
      { verb: 's\'approcher', text: 'Tu avances lentement vers la biche, la main tendue.', effects: ['ADD_REPUTATION:niamh:8', 'HEAL_LIFE:5'] },
      { verb: 'se faufiler', text: 'Tu te glisses vers le passage secret qu\'elle a revele.', effects: ['ADD_BIOME_CURRENCY:7', 'ADD_REPUTATION:korrigans:3'] },
      { verb: 'attendre', text: 'Tu restes immobile, laissant la scene se deployer.', effects: ['HEAL_LIFE:3', 'ADD_ANAM:4'] },
    ],
  },
  {
    narrative: 'Les ruines d\'un nemeton apparaissent entre les arbres. Quatre piliers de granit marquent les points cardinaux, et au centre, une dalle gravee pulse d\'une lumiere verte a chaque battement de ton coeur.',
    options: [
      { verb: 'examiner', text: 'Tu etudies les gravures sur les piliers un par un.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:8'] },
      { verb: 'apaiser', text: 'Tu poses les mains sur la dalle et synchronises ta respiration.', effects: ['HEAL_LIFE:8', 'ADD_REPUTATION:druides:5'] },
      { verb: 'forcer', text: 'Tu tentes de soulever la dalle centrale.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:6'] },
    ],
  },
  {
    narrative: 'Un vieil if se tord au bord d\'un precipice, ses racines a moitie dans le vide. Dans ses branches, des dizaines de corbeaux noirs se taisent a ton approche. Un crane humain est encastre dans le tronc.',
    options: [
      { verb: 'resister mentalement', text: 'Tu affrontes l\'aura sinistre de l\'arbre sans ciller.', effects: ['ADD_REPUTATION:ankou:8', 'ADD_ANAM:5'] },
      { verb: 'contourner', text: 'Tu fais un large detour pour eviter cet arbre maudit.', effects: ['HEAL_LIFE:2', 'ADD_BIOME_CURRENCY:3'] },
      { verb: 'analyser', text: 'Tu cherches a comprendre pourquoi les druides ont place ce crane ici.', effects: ['ADD_REPUTATION:druides:6', 'ADD_REPUTATION:anciens:4'] },
    ],
  },
  {
    narrative: 'Une colonne de fumee bleue s\'eleve d\'un foyer cache entre les racines d\'un hetre immense. L\'odeur de sauge et de verveine emplit l\'air. Une voix feminile chante un air ancien.',
    options: [
      { verb: 'ecouter', text: 'Tu t\'assieds et laisses le chant te bercer.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:druides:5'] },
      { verb: 'charmer', text: 'Tu ajoutes ta voix au chant, improvisant une harmonie.', effects: ['ADD_REPUTATION:niamh:7', 'ADD_ANAM:3'] },
      { verb: 'inspecter', text: 'Tu cherches l\'origine du feu et de la chanteuse.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_REPUTATION:korrigans:4'] },
    ],
  },
  {
    narrative: 'Le sol vibre sous tes pieds. Les arbres autour de toi semblent se rapprocher, leurs branches formant une voute impenetrable. Une luciole solitaire pulse devant toi, comme pour te guider.',
    options: [
      { verb: 'suivre', text: 'Tu suis la luciole a travers le labyrinthe de branches.', effects: ['ADD_BIOME_CURRENCY:6', 'HEAL_LIFE:3'] },
      { verb: 'resister physiquement', text: 'Tu repousses les branches et forces ton chemin.', effects: ['DAMAGE_LIFE:4', 'ADD_REPUTATION:ankou:5'] },
      { verb: 'calmer', text: 'Tu murmures des mots d\'apaisement a la foret elle-meme.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:druides:7'] },
    ],
  },
  {
    narrative: 'Un dolmen couvert de mousse se revele au detour du chemin. Sous sa table de pierre, un renard roux monte la garde. A ses pieds, des fragments d\'ambre brillent faiblement.',
    options: [
      { verb: 'amadouer', text: 'Tu t\'accroupis et tends la main vers le renard.', effects: ['ADD_REPUTATION:korrigans:6', 'HEAL_LIFE:3'] },
      { verb: 'fouiller a l\'aveugle', text: 'Tu ramasses les fragments d\'ambre, risquant la morsure.', effects: ['ADD_BIOME_CURRENCY:9', 'DAMAGE_LIFE:4'] },
      { verb: 'memoriser', text: 'Tu graves la scene dans ta memoire — le renard, l\'ambre, la pierre.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Un pont de bois enjambe un ruisseau murmurant. Chaque planche porte un ogham different. Le pont oscille doucement, comme s\'il respirait. De l\'autre cote, un bosquet de bouleaux blancs brille dans la penombre.',
    options: [
      { verb: 'dechiffrer', text: 'Tu lis chaque ogham en traversant, un pas apres l\'autre.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:druides:5'] },
      { verb: 'esquiver', text: 'Tu traverses en courant, evitant les planches qui semblent fragiles.', effects: ['ADD_BIOME_CURRENCY:5', 'DAMAGE_LIFE:2'] },
      { verb: 'endurer', text: 'Tu traverses lentement malgre le vertige, chaque pas delibere.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:anciens:6'] },
    ],
  },
  {
    narrative: 'Une clairiere parfaite s\'ouvre devant toi, bordee de menhirs graves. Au centre, un chaudron de bronze repose sur trois pierres. Un liquide argente y bouillonne sans source de chaleur visible.',
    options: [
      { verb: 'deviner', text: 'Tu tentes de deviner la nature du breuvage par son odeur.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:druides:4'] },
      { verb: 'decoder', text: 'Tu etudies les gravures sur le chaudron pour comprendre son usage.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'se cacher', text: 'Tu te dissimules et observes — quelqu\'un viendra surement.', effects: ['HEAL_LIFE:3', 'ADD_REPUTATION:korrigans:5'] },
    ],
  },
  {
    narrative: 'Des chants d\'oiseaux impossibles emplissent l\'air — des melodies qui forment des mots en ancien gaelique. Les feuilles des arbres se teintent d\'or a chaque note, puis retrouvent leur vert.',
    options: [
      { verb: 'flairer', text: 'Tu suis ton instinct, laissant les sons te mener vers leur source.', effects: ['ADD_REPUTATION:niamh:6', 'HEAL_LIFE:4'] },
      { verb: 'interpreter', text: 'Tu traduis les paroles anciennes, piegeant leur sens.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:druides:5'] },
      { verb: 'combattre', text: 'Tu chantes plus fort, defiant les voix de la foret.', effects: ['ADD_REPUTATION:ankou:5', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Un arbre creux t\'invite a passer. A l\'interieur du tronc, l\'espace semble plus grand que possible. Des racines forment un escalier en spirale qui descend dans les tenebres.',
    options: [
      { verb: 'se faufiler', text: 'Tu te glisses dans le tronc et descends l\'escalier vegetal.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:3'] },
      { verb: 'refuser', text: 'Tu refuses l\'invitation et poursuis ton chemin en surface.', effects: ['HEAL_LIFE:3', 'ADD_REPUTATION:anciens:4'] },
      { verb: 'etudier', text: 'Tu examines le phenomene sans entrer, notant chaque detail.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:6'] },
    ],
  },
  {
    narrative: 'Une pluie fine commence a tomber, mais chaque goutte brille d\'un eclat vert emeraude. Partout ou l\'eau touche le sol, de minuscules fleurs blanches eclosent instantanement.',
    options: [
      { verb: 'cueillir', text: 'Tu recoltes les fleurs ephemeres avant qu\'elles ne fanent.', effects: ['ADD_BIOME_CURRENCY:7', 'ADD_REPUTATION:druides:4'] },
      { verb: 'fixer', text: 'Tu observes le phenomene avec attention, gravant le spectacle.', effects: ['ADD_ANAM:5', 'HEAL_LIFE:4'] },
      { verb: 'courir', text: 'Tu cours sous la pluie magique, bras eccartes, riant.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:niamh:5'] },
    ],
  },
  {
    narrative: 'Un loup gris emerge du brouillard, son regard intelligent et calme. Il porte un collier tresse de lierre. Derriere lui, trois louvetaux jouent entre les fougeres.',
    options: [
      { verb: 'negocier', text: 'Tu t\'adresses au loup comme a un egal, offrant du respect.', effects: ['ADD_REPUTATION:druides:7', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'fuir', text: 'Tu recules lentement, sans briser le contact visuel.', effects: ['HEAL_LIFE:2', 'ADD_BIOME_CURRENCY:3'] },
      { verb: 'se concentrer', text: 'Tu projettes des pensees de paix vers le loup.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:6'] },
    ],
  },
  {
    narrative: 'Une toile d\'araignee geante s\'etend entre deux chenes, chaque fil incrustes de rosee qui brille comme des diamants. Au centre, un motif complexe ressemble a une carte du ciel.',
    options: [
      { verb: 'analyser', text: 'Tu decryptes la carte celeste tissee dans la soie.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:druides:6'] },
      { verb: 'traverser', text: 'Tu passes sous la toile en rampant, evitant les fils.', effects: ['ADD_BIOME_CURRENCY:5', 'DAMAGE_LIFE:2'] },
      { verb: 'tendre l\'oreille', text: 'Tu ecoutes les vibrations de la toile, qui semble chanter.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Un tertre de terre recouvert de trefles a quatre feuilles se dresse au milieu du chemin. Une porte minuscule, pas plus haute qu\'un genou, est enchassee dans sa base.',
    options: [
      { verb: 'convaincre', text: 'Tu parles a travers la porte, implorant les korrigans de t\'aider.', effects: ['ADD_REPUTATION:korrigans:8', 'ADD_ANAM:3'] },
      { verb: 'pousser', text: 'Tu pousses la petite porte de toutes tes forces.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:4', 'ADD_REPUTATION:korrigans:-3'] },
      { verb: 'accepter', text: 'Tu deposes une offrande et attends patiemment.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:druides:5'] },
    ],
  },
  {
    narrative: 'Le tonnerre gronde au loin, mais aucun eclair n\'illumine le ciel. Les arbres frissonnent, et tu realises que le grondement vient de sous la terre. Un vieux druide apparait, appuye sur un baton de frene.',
    options: [
      { verb: 'parler', text: 'Tu salues le druide et lui demandes l\'explication du grondement.', effects: ['ADD_REPUTATION:druides:10', 'ADD_ANAM:5'] },
      { verb: 'mentir', text: 'Tu pretends etre un initie pour gagner sa confiance.', effects: ['ADD_BIOME_CURRENCY:8', 'ADD_REPUTATION:druides:-5'] },
      { verb: 'resoudre', text: 'Tu cherches toi-meme l\'origine du grondement souterrain.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Au pied d\'un saule pleureur, une harpe de bois repose contre le tronc. Ses cordes vibrent seules, jouant un air triste et beau. Des larmes de seve coulent le long de l\'ecorce.',
    options: [
      { verb: 'apaiser', text: 'Tu poses les mains sur les cordes, apaisant leur chant.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:niamh:7'] },
      { verb: 'marchander', text: 'Tu proposes un marche a l\'esprit de l\'arbre — un chant contre un secret.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:korrigans:5'] },
      { verb: 'resoudre', text: 'Tu cherches a comprendre pourquoi le saule pleure.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:druides:6'] },
    ],
  },
  // --- cotes_sauvages + niamh (20 cards) ---
  {
    narrative: 'Les vagues se brisent contre des rochers noirs sculptes par les siecles. Entre deux affleurements, un bassin naturel miroite d\'un bleu surnaturel. Une silhouette feminine flotte juste sous la surface.',
    options: [
      { verb: 'parler', text: 'Tu t\'adresses a la silhouette, ta voix couvrant le ressac.', effects: ['ADD_REPUTATION:niamh:10', 'HEAL_LIFE:5'] },
      { verb: 'observer', text: 'Tu etudies le bassin, cherchant a comprendre ce phenomene.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:4'] },
      { verb: 'tenter sa chance', text: 'Tu plonges la main dans l\'eau lumineuse.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:4'] },
    ],
  },
  {
    narrative: 'Un phare en ruine domine la falaise. Sa lanterne brisee laisse passer le vent sale. Au pied de la tour, des coquillages forment un motif en spirale qui pulse d\'une lumiere bleutee.',
    options: [
      { verb: 'dechiffrer', text: 'Tu etudies la spirale de coquillages, cherchant un message.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'escalader', text: 'Tu grimpes les marches du phare pour voir au-dela de l\'horizon.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
      { verb: 'ecouter', text: 'Tu fermes les yeux et laisses le vent te raconter l\'histoire du phare.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:niamh:6'] },
    ],
  },
  {
    narrative: 'Une grotte marine s\'ouvre dans la falaise, accessible uniquement a maree basse. A l\'interieur, des stalactites cristallines chantent quand le vent s\'engouffre. Des offrandes anciennes jonchent le sol.',
    options: [
      { verb: 'se faufiler', text: 'Tu te glisses dans la grotte avant que la maree ne remonte.', effects: ['ADD_BIOME_CURRENCY:9', 'DAMAGE_LIFE:5'] },
      { verb: 'mediter', text: 'Tu t\'assieds a l\'entree et ecoutes le chant des cristaux.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:niamh:8'] },
      { verb: 'examiner', text: 'Tu etudies les offrandes pour comprendre qui venait ici.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:6'] },
    ],
  },
  {
    narrative: 'Un banc de poissons argentees saute hors de l\'eau en formation parfaite, dessinant un arc-en-ciel d\'ecailles. Derriere eux, un dauphin blanc t\'observe avec une intelligence troublante.',
    options: [
      { verb: 's\'approcher', text: 'Tu avances dans l\'eau jusqu\'aux genoux vers le dauphin.', effects: ['ADD_REPUTATION:niamh:9', 'HEAL_LIFE:4'] },
      { verb: 'fixer', text: 'Tu memorises chaque detail de cette vision marine.', effects: ['ADD_ANAM:5', 'HEAL_LIFE:3'] },
      { verb: 'courir', text: 'Tu longes la cote en suivant le banc de poissons.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_REPUTATION:korrigans:4'] },
    ],
  },
  {
    narrative: 'Le sentier cotier s\'effondre devant toi, revele par l\'erosion. Dans la coupe de terre, des ossements anciens brillent d\'un eclat nacre. La mer gronde en contrebas.',
    options: [
      { verb: 'resister mentalement', text: 'Tu affrontes le vertige et le poids de la mort ancienne.', effects: ['ADD_REPUTATION:ankou:7', 'ADD_ANAM:4'] },
      { verb: 'contourner', text: 'Tu fais un detour par les rochers pour eviter l\'eboulement.', effects: ['HEAL_LIFE:3', 'ADD_BIOME_CURRENCY:4'] },
      { verb: 'cueillir', text: 'Tu recuperes un fragment nacre — un talisman peut-etre.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Une source d\'eau douce jaillit directement de la falaise, tombant en cascade dans la mer. La ou les eaux se melangent, un brouillard irise se forme, revelant des formes fugaces.',
    options: [
      { verb: 'se concentrer', text: 'Tu fixes le brouillard, tentant de discerner les formes.', effects: ['ADD_REPUTATION:niamh:7', 'ADD_ANAM:5'] },
      { verb: 'cueillir', text: 'Tu remplis ta gourde a la source d\'eau douce.', effects: ['HEAL_LIFE:6', 'ADD_BIOME_CURRENCY:3'] },
      { verb: 'combattre', text: 'Tu traverses le rideau de brouillard sans hesiter.', effects: ['ADD_REPUTATION:ankou:5', 'DAMAGE_LIFE:4'] },
    ],
  },
  {
    narrative: 'Un cercle de menhirs se dresse sur un promontoire battu par les vents. Chaque pierre est polie par le sel marin. Au centre, une dalle plate porte les traces de feux anciens.',
    options: [
      { verb: 'analyser', text: 'Tu etudies les traces de rituels sur la dalle centrale.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:druides:5'] },
      { verb: 'apaiser', text: 'Tu allumes un petit feu symbolique sur la dalle.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:anciens:7'] },
      { verb: 'fouiller a l\'aveugle', text: 'Tu fouilles autour des menhirs, cherchant des objets caches.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Une vieille barque echouee porte encore ses filets. Dans les mailles, des etoiles de mer phosphorescentes brillent comme des lanternes. Un chant melancolique monte des profondeurs.',
    options: [
      { verb: 'ecouter', text: 'Tu t\'allonges dans la barque et laisses le chant te bercer.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:niamh:6'] },
      { verb: 'marchander', text: 'Tu prends quelques etoiles pour les echanger plus tard.', effects: ['ADD_BIOME_CURRENCY:7', 'ADD_REPUTATION:niamh:-3'] },
      { verb: 'suivre', text: 'Tu suis le chant vers les rochers au large.', effects: ['ADD_REPUTATION:niamh:8', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Des algues geantes s\'echouent sur le rivage apres la tempete. Entre leurs frondes, des pierres polies portent des gravures oghamiques inconnues. L\'air sent l\'iode et le mystere.',
    options: [
      { verb: 'dechiffrer', text: 'Tu rassembles les pierres et tentes de lire les oghams.', effects: ['ADD_ANAM:8', 'ADD_REPUTATION:druides:4'] },
      { verb: 'sentir', text: 'Tu suis ton instinct et choisis la pierre qui vibre le plus.', effects: ['ADD_REPUTATION:niamh:6', 'HEAL_LIFE:4'] },
      { verb: 'fuir', text: 'L\'etrangete de la scene t\'inquiete. Tu t\'eloignes.', effects: ['HEAL_LIFE:2', 'ADD_BIOME_CURRENCY:3'] },
    ],
  },
  {
    narrative: 'Un pecheur solitaire repare ses filets sur un rocher plat. Ses yeux sont d\'un gris identique a la mer. Il ne leve pas la tete mais dit : "La mer prend et la mer rend. Que cherches-tu ?"',
    options: [
      { verb: 'parler', text: 'Tu lui confies ta quete avec sincerite.', effects: ['ADD_REPUTATION:niamh:5', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'negocier', text: 'Tu proposes ton aide en echange d\'informations.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'observer', text: 'Tu t\'assieds en silence et regardes ses mains travailler.', effects: ['HEAL_LIFE:4', 'ADD_ANAM:4'] },
    ],
  },
  {
    narrative: 'La maree descendante revele un passage entre deux ilots rocheux. Le fond sablonneux est parseme de coquillages dores. Mais les nuages s\'amoncellent et la maree ne tardera pas.',
    options: [
      { verb: 'courir', text: 'Tu traverses en courant avant que la mer ne revienne.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:4'] },
      { verb: 'attendre', text: 'Tu restes sur la rive et observes le cycle de la mer.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:5'] },
      { verb: 'deviner', text: 'Tu estimes le temps qu\'il te reste et calcules ton parcours.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_ANAM:4'] },
    ],
  },
  {
    narrative: 'Un rocher en forme de trone se dresse face a l\'ocean. Des traces d\'usure montrent que quelqu\'un s\'y assied regulierement. De ce point, on voit trois iles a l\'horizon, alignees comme des perles.',
    options: [
      { verb: 'mediter', text: 'Tu t\'assieds sur le trone de pierre et fixes l\'horizon.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:niamh:7'] },
      { verb: 'scruter', text: 'Tu observes les iles, cherchant des signes de vie.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:4'] },
      { verb: 'escalader', text: 'Tu grimpes plus haut pour avoir une vue panoramique.', effects: ['ADD_BIOME_CURRENCY:5', 'DAMAGE_LIFE:2'] },
    ],
  },
  {
    narrative: 'Un phoque gris repose sur un rocher, sa fourrure brillante de gouttelettes. Il te fixe sans crainte. Les legendes disent que les selkies prennent forme humaine a la pleine lune.',
    options: [
      { verb: 'amadouer', text: 'Tu t\'approches lentement, paumes ouvertes, en murmurant.', effects: ['ADD_REPUTATION:niamh:8', 'HEAL_LIFE:3'] },
      { verb: 'interpreter', text: 'Tu cherches dans tes souvenirs les legendes des selkies.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:druides:4'] },
      { verb: 'pister', text: 'Tu suis les traces du phoque vers sa colonie.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:korrigans:3'] },
    ],
  },
  {
    narrative: 'Le vent apporte des flocons d\'ecume qui ressemblent a des plumes blanches. Ils se posent sur tes epaules comme des benedictions. Chaque flocon qui touche ta peau laisse une sensation de fraicheur bienfaisante.',
    options: [
      { verb: 'accepter', text: 'Tu ouvres les bras et accueilles l\'ecume comme un don.', effects: ['HEAL_LIFE:8', 'ADD_REPUTATION:niamh:5'] },
      { verb: 'examiner', text: 'Tu captures un flocon et l\'observes fondre lentement.', effects: ['ADD_ANAM:4', 'ADD_REPUTATION:druides:5'] },
      { verb: 'resister physiquement', text: 'Tu avances face au vent, chaque pas une victoire.', effects: ['ADD_REPUTATION:ankou:5', 'ADD_BIOME_CURRENCY:4'] },
    ],
  },
  {
    narrative: 'Une arche naturelle de roche rouge enjambe une crique etroite. L\'eau en dessous est si claire qu\'on voit le fond a dix metres. Des hippocampes dansent entre les algues.',
    options: [
      { verb: 'se faufiler', text: 'Tu passes sous l\'arche en longeant la paroi rocheuse.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:niamh:4'] },
      { verb: 'flairer', text: 'Tu sens l\'air marin charge de sel et d\'algues medicinales.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'se concentrer', text: 'Tu projettes ta conscience vers les hippocampes dansants.', effects: ['ADD_REPUTATION:niamh:7', 'ADD_ANAM:4'] },
    ],
  },
  {
    narrative: 'Un cairn immense se dresse au bord de la falaise, construit de galets blancs et noirs en alternance. A son sommet, une coupe de bronze recueille l\'eau de pluie. L\'eau luit d\'une lueur argentee.',
    options: [
      { verb: 'memoriser', text: 'Tu graves dans ta memoire le motif noir et blanc du cairn.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'apaiser', text: 'Tu verses quelques gouttes de l\'eau sacree sur tes mains.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:niamh:5'] },
      { verb: 'forcer', text: 'Tu tentes de soulever la coupe de bronze.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:5'] },
    ],
  },
  {
    narrative: 'Les restes d\'un naufrage emergent du sable a maree basse. La proue sculptee represente une femme aux yeux fermes. Des coraux ont pousse sur ses traits, lui donnant une couronne vivante.',
    options: [
      { verb: 'decoder', text: 'Tu cherches le nom du navire parmi les planches brisees.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'calmer', text: 'Tu rends hommage aux marins perdus en silence.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:6'] },
      { verb: 'fouiller a l\'aveugle', text: 'Tu fouilles l\'epave a la recherche de tresors.', effects: ['ADD_BIOME_CURRENCY:9', 'DAMAGE_LIFE:4'] },
    ],
  },
  {
    narrative: 'Un sentier de pierres plates traverse une vasiere ou des oiseaux limicoles cherchent leur nourriture. Le ciel se reflete parfaitement dans la boue argentee, creant un monde miroir.',
    options: [
      { verb: 'suivre', text: 'Tu suis le sentier de pierres avec precaution.', effects: ['ADD_BIOME_CURRENCY:5', 'HEAL_LIFE:3'] },
      { verb: 'tendre l\'oreille', text: 'Tu ecoutes les cris des oiseaux, cherchant un message.', effects: ['ADD_REPUTATION:niamh:5', 'ADD_ANAM:5'] },
      { verb: 'endurer', text: 'Tu traverses la vasiere a pied, enfonçant dans la boue.', effects: ['ADD_REPUTATION:ankou:4', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Une mare de maree forme un miroir parfait dans un creux de rocher. En te penchant, ton reflet ne bouge pas avec toi — il sourit quand tu fronces les sourcils, et te fait signe de la main.',
    options: [
      { verb: 'se concentrer', text: 'Tu fixes le reflet et tentes de communiquer avec lui.', effects: ['ADD_REPUTATION:niamh:9', 'ADD_ANAM:5'] },
      { verb: 'mentir', text: 'Tu pretends ne rien voir et continues ton chemin.', effects: ['ADD_BIOME_CURRENCY:4', 'ADD_REPUTATION:niamh:-4'] },
      { verb: 'resister mentalement', text: 'Tu refuses de ceder a l\'illusion et detournes le regard.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Au bout d\'une jetee de pierres disjointes, un feu follet bleu danse au-dessus de l\'eau. Il pulse au rythme des vagues, comme un coeur marin. D\'autres lumieres repondent au loin, depuis les iles.',
    options: [
      { verb: 'charmer', text: 'Tu chantes un air ancien pour attirer le feu follet.', effects: ['ADD_REPUTATION:niamh:8', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'analyser', text: 'Tu etudies le rythme des pulsations, cherchant un code.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:druides:4'] },
      { verb: 'esquiver', text: 'Tu contournes la jetee, mefiant des lumieres trompeuses.', effects: ['HEAL_LIFE:3', 'ADD_BIOME_CURRENCY:5'] },
    ],
  },
  // --- landes_bruyere + anciens (20 cards) ---
  {
    narrative: 'Un tumulus couvert de bruyere violette se dresse au milieu de la lande. Le vent siffle entre les pierres empilees a son sommet, produisant une melodie plaintive. Des traces de pas anciens sont gravees dans la roche.',
    options: [
      { verb: 'examiner', text: 'Tu etudies les pierres empilees et les gravures sur le tumulus.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:8'] },
      { verb: 'ecouter', text: 'Tu laisses la melodie du vent te guider vers un message cache.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:druides:5'] },
      { verb: 'fouiller a l\'aveugle', text: 'Tu cherches une entree dans le tumulus.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:4'] },
    ],
  },
  {
    narrative: 'Un cercle de pierres basses emerge de la bruyere, a peine visible sous le tapis violet. Au centre, une pierre plate porte un bol de pierre rempli d\'eau de pluie. Des runes oghamiques encerclent le bol.',
    options: [
      { verb: 'dechiffrer', text: 'Tu te penches pour lire les runes autour du bol sacre.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'mediter', text: 'Tu t\'assieds au bord du cercle et honores l\'ancien lieu.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:anciens:7'] },
      { verb: 'tenter sa chance', text: 'Tu bois une gorgee de l\'eau du bol de pierre.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Des poneys sauvages broutent la bruyere a flanc de colline. Leur chef, un etalon gris au regard fier, s\'avance vers toi. Sa criniere flotte comme un drapeau dans le vent des landes.',
    options: [
      { verb: 'amadouer', text: 'Tu tends la main ouverte vers l\'etalon, paumes vers le ciel.', effects: ['ADD_REPUTATION:anciens:8', 'HEAL_LIFE:4'] },
      { verb: 'observer', text: 'Tu etudies le troupeau a distance, notant leur comportement.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:5'] },
      { verb: 'fuir', text: 'Tu recules devant la puissance de l\'animal sauvage.', effects: ['HEAL_LIFE:2', 'ADD_BIOME_CURRENCY:4'] },
    ],
  },
  {
    narrative: 'Un cairn massif marque un carrefour de sentiers oublies. Chaque voyageur y a depose sa pierre au fil des siecles. Une inscription usee dit: "Souviens-toi du serment." Un corbeau croasse depuis le sommet.',
    options: [
      { verb: 'accepter', text: 'Tu deposes ta propre pierre et prononces un serment silencieux.', effects: ['ADD_REPUTATION:anciens:10', 'HEAL_LIFE:3'] },
      { verb: 'analyser', text: 'Tu etudies les differentes pierres, cherchant des indices.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:druides:4'] },
      { verb: 'contourner', text: 'Tu evites le cairn, peu desireux de t\'engager.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_REPUTATION:anciens:-3'] },
    ],
  },
  {
    narrative: 'Un orage violet s\'amoncelle au-dessus des landes. Les eclairs frappent un menhir solitaire encore et encore, mais la pierre ne se fend pas. Chaque impact fait briller les oghams graves dans le granite.',
    options: [
      { verb: 'se concentrer', text: 'Tu fixes les oghams illumines, tentant de les memoriser.', effects: ['ADD_ANAM:8', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'resister physiquement', text: 'Tu affrontes la tempete pour atteindre le menhir.', effects: ['ADD_REPUTATION:ankou:6', 'DAMAGE_LIFE:5'] },
      { verb: 'attendre', text: 'Tu te mets a l\'abri et observes le spectacle naturel.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:druides:5'] },
    ],
  },
  {
    narrative: 'Un vieux berger se tient pres d\'un muret de pierres seches, son chien couche a ses pieds. Il sculpte un baton de frene sans te regarder. "Les anciens savaient lire le vent," dit-il simplement.',
    options: [
      { verb: 'parler', text: 'Tu t\'assieds pres du berger et lui demandes ses histoires.', effects: ['ADD_REPUTATION:anciens:8', 'ADD_ANAM:4'] },
      { verb: 'scruter', text: 'Tu observes les motifs qu\'il grave dans le bois de frene.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:6'] },
      { verb: 'marchander', text: 'Tu proposes d\'echanger un service contre le baton.', effects: ['ADD_BIOME_CURRENCY:7', 'ADD_REPUTATION:korrigans:4'] },
    ],
  },
  {
    narrative: 'Un dolmen effondre git a moitie dans la tourbe. Sa table de pierre brisee revele une chambre souterraine ou des racines de bruyere forment un reseau luminescent. Un bourdonnement grave emane des profondeurs.',
    options: [
      { verb: 'se faufiler', text: 'Tu te glisses dans la chambre souterraine du dolmen.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:4'] },
      { verb: 'apaiser', text: 'Tu poses les mains sur la pierre et murmures des mots anciens.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'etudier', text: 'Tu notes les motifs luminescents des racines sans entrer.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:druides:5'] },
    ],
  },
  {
    narrative: 'La bruyere s\'ecarte pour reveler un sentier pave de dalles gravees. Chaque dalle porte le nom d\'un ancetre oublie. Marcher dessus te donne l\'impression de fouler l\'histoire elle-meme.',
    options: [
      { verb: 'memoriser', text: 'Tu lis chaque nom a voix haute, les gravant dans ta memoire.', effects: ['ADD_REPUTATION:anciens:10', 'ADD_ANAM:5'] },
      { verb: 'resoudre', text: 'Tu cherches un ordre logique dans les noms et les dalles.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:anciens:4'] },
      { verb: 'courir', text: 'Tu traverses le sentier en courant, sans t\'attarder.', effects: ['ADD_BIOME_CURRENCY:5', 'DAMAGE_LIFE:2'] },
    ],
  },
  {
    narrative: 'Un puits celtique s\'ouvre dans la lande, son margelle de granit couverte de lichen orange. L\'eau au fond reflète non pas le ciel mais un reseau d\'etoiles, meme en plein jour.',
    options: [
      { verb: 'deviner', text: 'Tu jettes une pierre et ecoutes le son qu\'elle fait en touchant l\'eau.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'se concentrer', text: 'Tu fixes le reflet etoile, cherchant un message celeste.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:niamh:5'] },
      { verb: 'refuser', text: 'Tu detournes le regard — certains mysteres doivent rester scelles.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:anciens:6'] },
    ],
  },
  {
    narrative: 'Un alignement de menhirs traverse la lande sur des centaines de metres. A l\'extremite, le dernier menhir est fendu en deux, et entre les moities pousse un sorbier charge de baies rouges.',
    options: [
      { verb: 'cueillir', text: 'Tu cueilles des baies de sorbier — protection des anciens.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_REPUTATION:anciens:7'] },
      { verb: 'examiner', text: 'Tu etudies comment le menhir s\'est fendu au fil des siecles.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'pousser', text: 'Tu tentes de rassembler les deux moities du menhir.', effects: ['DAMAGE_LIFE:5', 'ADD_REPUTATION:ankou:5'] },
    ],
  },
  {
    narrative: 'Des tourbières noires s\'etendent a perte de vue, parsemees d\'iles de bruyere. Sur l\'une d\'elles, un feu de tourbe brule sans fumee, entretenu par personne. Son odeur acre et ancienne porte des visions.',
    options: [
      { verb: 'se concentrer', text: 'Tu t\'approches du feu et laisses les visions venir.', effects: ['ADD_REPUTATION:anciens:8', 'ADD_ANAM:6'] },
      { verb: 'resister mentalement', text: 'Tu repousses les visions et gardes l\'esprit clair.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:ankou:4'] },
      { verb: 'chercher au hasard', text: 'Tu fouilles autour du feu, cherchant qui l\'a allume.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Un chant grave monte de la terre. Les pierres vibrent sous tes pieds. Au loin, une procession spectrale traverse la lande — des guerriers anciens portant des boucliers ronds ornes de spirales.',
    options: [
      { verb: 'mediter', text: 'Tu t\'agenouilles et honores la procession des guerriers tombes.', effects: ['ADD_REPUTATION:anciens:10', 'HEAL_LIFE:4'] },
      { verb: 'combattre', text: 'Tu brandis un baton et te joins a la procession fantome.', effects: ['ADD_REPUTATION:ankou:7', 'DAMAGE_LIFE:4'] },
      { verb: 'fixer', text: 'Tu observes chaque detail des spectres — armes, visages, symboles.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:anciens:4'] },
    ],
  },
  {
    narrative: 'Un ruisseau serpente entre les collines, ses berges tapissees de menthe sauvage. A un coude, un gue de pierres plates traverse le courant. Sur la rive opposee, un cercle de champignons forme une porte ferique.',
    options: [
      { verb: 'traverser', text: 'Tu franchis le gue prudemment, pierre apres pierre.', effects: ['ADD_BIOME_CURRENCY:5', 'HEAL_LIFE:3'] },
      { verb: 'inspecter', text: 'Tu examines le cercle de champignons sans le franchir.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:korrigans:6'] },
      { verb: 'calmer', text: 'Tu t\'assieds au bord du ruisseau et respires la menthe.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Un tertre funeraire s\'ouvre sur la lande, son entree basse gardee par deux pierres sculptees en forme de loups. A l\'interieur, l\'obscurite est totale mais une chaleur etrange en emane.',
    options: [
      { verb: 'se faufiler', text: 'Tu te glisses entre les loups de pierre et penetres dans le tertre.', effects: ['ADD_BIOME_CURRENCY:9', 'DAMAGE_LIFE:5'] },
      { verb: 'apaiser', text: 'Tu deposes une offrande devant les gardiens et attends.', effects: ['ADD_REPUTATION:anciens:9', 'HEAL_LIFE:3'] },
      { verb: 'interpreter', text: 'Tu etudies les sculptures de loups, y cherchant un clan.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Le brouillard tombe sur la lande comme un voile. Des lumieres dansent au loin — feux follets ou lanternes de voyageurs? Un poteau de bois grave d\'oghams emerge du sol, indiquant trois directions.',
    options: [
      { verb: 'dechiffrer', text: 'Tu lis les oghams sur le poteau, cherchant le bon chemin.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'suivre', text: 'Tu suis les lumieres dansantes dans le brouillard.', effects: ['ADD_REPUTATION:korrigans:5', 'DAMAGE_LIFE:3'] },
      { verb: 'endurer', text: 'Tu attends que le brouillard se leve, patient et stoique.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:anciens:6'] },
    ],
  },
  {
    narrative: 'Une source chaude bouillonne au creux d\'une cuvette de pierre. La vapeur qui s\'en echappe dessine des visages ephemeres — les ancetres qui veillent. L\'eau sent le soufre et le fer.',
    options: [
      { verb: 'observer', text: 'Tu etudies les visages de vapeur, y reconnaissant des traits.', effects: ['ADD_REPUTATION:anciens:7', 'ADD_ANAM:5'] },
      { verb: 'cueillir', text: 'Tu remplis ta gourde d\'eau chaude minerale.', effects: ['HEAL_LIFE:8', 'ADD_BIOME_CURRENCY:3'] },
      { verb: 'resoudre', text: 'Tu cherches l\'origine geologique de cette source.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:druides:5'] },
    ],
  },
  {
    narrative: 'Un if millenaire pousse au centre d\'un enclos de pierres. Son tronc tordu porte les cicatrices de mille hivers. A ses pieds, des offrandes recentes — fleurs sechees, rubans, pieces de cuivre.',
    options: [
      { verb: 'accepter', text: 'Tu ajoutes ta propre offrande et prononces une priere ancienne.', effects: ['ADD_REPUTATION:anciens:9', 'HEAL_LIFE:5'] },
      { verb: 'decoder', text: 'Tu etudies les offrandes pour comprendre qui vient encore ici.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'escalader', text: 'Tu grimpes dans l\'if pour voir plus loin sur la lande.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Le vent emporte des graines de chardon geant qui volent comme des etoiles blanches au-dessus de la bruyere. Certaines se posent sur ta peau et y laissent des marques ephemeres en forme d\'oghams.',
    options: [
      { verb: 'memoriser', text: 'Tu lis les oghams dessines par les graines sur ta peau.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'flairer', text: 'Tu suis le courant de graines vers leur source.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_REPUTATION:druides:5'] },
      { verb: 'se concentrer', text: 'Tu fermes les yeux et laisses le vent parler a travers les graines.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:5'] },
    ],
  },
  {
    narrative: 'Un mur de pierres seches traverse la lande, vestige d\'une frontiere oubliee entre deux clans. Chaque pierre a ete placee avec soin, sans mortier, tenant par sa seule forme. Une breche invite au passage.',
    options: [
      { verb: 'resoudre', text: 'Tu repares la breche en trouvant la pierre manquante.', effects: ['ADD_REPUTATION:anciens:8', 'HEAL_LIFE:3'] },
      { verb: 'se faufiler', text: 'Tu passes par la breche vers le territoire inconnu.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:3'] },
      { verb: 'etudier', text: 'Tu analyses la technique de construction du mur ancien.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:anciens:5'] },
    ],
  },
  {
    narrative: 'Au sommet d\'une colline battue par le vent, un faucon crecerelle plane immobile dans le ciel. En dessous, la lande entiere s\'etend comme une mer violette. Un autel de pierre plate domine le panorama.',
    options: [
      { verb: 'mediter', text: 'Tu t\'assieds a l\'autel et contemples l\'immensite de la lande.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:anciens:7'] },
      { verb: 'scruter', text: 'Tu suis le regard du faucon, cherchant ce qu\'il surveille.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:5'] },
      { verb: 'charmer', text: 'Tu leves le bras, invitant le faucon a se poser.', effects: ['ADD_REPUTATION:korrigans:5', 'ADD_BIOME_CURRENCY:5'] },
    ],
  },
  // ═══════════════════════════════════════════════════════════════════════════
  // BIOME: villages_celtes — FACTION: korrigans (20 templates, cycle 5)
  // Themes: market days, blacksmiths, traveling bards, hidden fairy doors,
  //         mischievous pranks, secret passages, borrowed tools, midnight dances
  // Caps: rep ≤10, heal ≤8, dmg ≤5
  // ═══════════════════════════════════════════════════════════════════════════
  {
    narrative: 'Le jour du marche bat son plein sur la place du village. Entre les etals de miel et de lin, un korrigan deguise en marchand vend des pommes qui changent de couleur a chaque regard. "Trois pour le prix d\'une ame !" crie-t-il.',
    options: [
      { verb: 'marchander', text: 'Tu negocies le prix avec l\'astuce d\'un korrigan.', effects: ['ADD_REPUTATION:korrigans:8', 'ADD_BIOME_CURRENCY:6'] },
      { verb: 'observer', text: 'Tu etudies les pommes magiques sans toucher.', effects: ['ADD_ANAM:4', 'HEAL_LIFE:5'] },
      { verb: 'apaiser', text: 'Tu calmes la foule mefiante autour de l\'etal.', effects: ['ADD_REPUTATION:niamh:5', 'ADD_REPUTATION:korrigans:4'] },
    ],
  },
  {
    narrative: 'Le forgeron du village frappe sans relache sur son enclume, mais les etincelles forment des runes dans l\'air. Chaque coup de marteau chante une note differente, composant une melodie ancienne que seul le fer connait.',
    options: [
      { verb: 'dechiffrer', text: 'Tu lis les runes forgees dans les etincelles.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'aider', text: 'Tu actionnes le soufflet pour aviver les flammes.', effects: ['ADD_REPUTATION:korrigans:7', 'HEAL_LIFE:4'] },
      { verb: 'combattre', text: 'Tu defies le forgeron a un concours de force.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:4'] },
    ],
  },
  {
    narrative: 'Un barde itinerant accorde sa harpe sur le pont de pierre. Ses doigts effleurent les cordes et les pierres du pont commencent a vibrer en harmonie. Les poissons de la riviere sautent au rythme de la musique.',
    options: [
      { verb: 'parler', text: 'Tu partages tes propres histoires avec le barde.', effects: ['ADD_REPUTATION:korrigans:6', 'ADD_REPUTATION:niamh:4'] },
      { verb: 'mediter', text: 'Tu fermes les yeux et te laisses porter par la melodie.', effects: ['HEAL_LIFE:8', 'ADD_REPUTATION:druides:3'] },
      { verb: 'danser', text: 'Tu danses sur le pont, faisant trembler les pierres.', effects: ['ADD_BIOME_CURRENCY:5', 'ADD_REPUTATION:korrigans:5'] },
    ],
  },
  {
    narrative: 'Derriere la taverne, une porte minus­cule est sculptee dans le tronc d\'un vieux sureau. Des rires etouffes s\'en echappent, et une minuscule lumiere doree pulse au rythme d\'une musique inaudible.',
    options: [
      { verb: 'se faufiler', text: 'Tu te penches et frappes trois coups sur la porte feerique.', effects: ['ADD_REPUTATION:korrigans:10', 'DAMAGE_LIFE:3'] },
      { verb: 'ecouter', text: 'Tu colles l\'oreille au tronc pour saisir les murmures.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'proteger', text: 'Tu plantes un cercle de houx autour du sureau.', effects: ['ADD_REPUTATION:druides:5', 'HEAL_LIFE:5'] },
    ],
  },
  {
    narrative: 'Les poules du village courent en cercles parfaits autour du puits, les yeux vitreux. Le fermier jure que c\'est un tour de korrigan. Un rire cristallin resonne depuis l\'interieur du puits.',
    options: [
      { verb: 'resoudre', text: 'Tu descends dans le puits chercher le farceur.', effects: ['ADD_REPUTATION:korrigans:8', 'DAMAGE_LIFE:4'] },
      { verb: 'apaiser', text: 'Tu brises le sortilege avec une comptine ancienne.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'ruser', text: 'Tu proposes au korrigan un meilleur tour.', effects: ['ADD_REPUTATION:korrigans:9', 'ADD_BIOME_CURRENCY:4'] },
    ],
  },
  {
    narrative: 'Un passage secret s\'ouvre dans le mur de l\'eglise desaffectee quand le soleil frappe une pierre precise a midi. Derriere, un escalier en spirale descend dans une obscurite parfumee d\'herbes sechees.',
    options: [
      { verb: 'explorer', text: 'Tu descends prudemment les marches usees par le temps.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:3'] },
      { verb: 'etudier', text: 'Tu examines les inscriptions gravees sur les murs.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'invoquer', text: 'Tu appelles les esprits gardiens du passage.', effects: ['ADD_REPUTATION:korrigans:7', 'ADD_REPUTATION:ankou:3'] },
    ],
  },
  {
    narrative: 'Un paysan se plaint que sa pelle parle. Effectivement, l\'outil marmonne des insultes a chaque pelletee de terre. "C\'est la derniere fois que j\'emprunte quoi que ce soit a un korrigan," soupire-t-il.',
    options: [
      { verb: 'marchander', text: 'Tu negocies avec la pelle pour qu\'elle se taise.', effects: ['ADD_REPUTATION:korrigans:8', 'ADD_ANAM:3'] },
      { verb: 'dechiffrer', text: 'Tu ecoutes les insultes — elles cachent un message code.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:korrigans:5'] },
      { verb: 'apaiser', text: 'Tu chantes une berceuse a l\'outil enchante.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:5'] },
    ],
  },
  {
    narrative: 'A minuit, la fontaine du village se met a couler du cidre dore. Les korrigans dansent autour en une ronde effrenable. Quiconque les rejoint dansera jusqu\'a l\'aube — mais recevra un don en echange.',
    options: [
      { verb: 'danser', text: 'Tu rejoins la ronde des korrigans sans hesiter.', effects: ['ADD_REPUTATION:korrigans:10', 'DAMAGE_LIFE:5'] },
      { verb: 'observer', text: 'Tu regardes la danse, memorisant les pas secrets.', effects: ['ADD_ANAM:5', 'HEAL_LIFE:4'] },
      { verb: 'offrir', text: 'Tu deposes un present au bord de la fontaine.', effects: ['ADD_REPUTATION:korrigans:7', 'ADD_BIOME_CURRENCY:5'] },
    ],
  },
  {
    narrative: 'Le toit de la maison du druide est couvert de mousse lumines­cente qui trace une carte du ciel. Ce soir, les etoiles sur le toit ne correspondent plus au vrai ciel — elles montrent un futur possible.',
    options: [
      { verb: 'decoder', text: 'Tu compares les deux ciels pour lire la prophetie.', effects: ['ADD_ANAM:7', 'ADD_REPUTATION:druides:5'] },
      { verb: 'mediter', text: 'Tu t\'allonges sous la mousse et laisses la lumiere t\'envahir.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:niamh:4'] },
      { verb: 'gratter', text: 'Tu preleves un echantillon de mousse propheti­que.', effects: ['ADD_BIOME_CURRENCY:6', 'ADD_REPUTATION:korrigans:4'] },
    ],
  },
  {
    narrative: 'L\'aubergiste sert une soupe dont le fumet change selon qui la regarde. Pour toi, elle sent la foret apres la pluie. Le chat de l\'auberge, lui, fixe le bol avec une intelligence suspecte.',
    options: [
      { verb: 'gouter', text: 'Tu bois la soupe en acceptant le risque.', effects: ['HEAL_LIFE:8', 'ADD_REPUTATION:korrigans:3'] },
      { verb: 'flairer', text: 'Tu analyses les ingredients par l\'odeur.', effects: ['ADD_ANAM:4', 'ADD_REPUTATION:druides:5'] },
      { verb: 'ruser', text: 'Tu echanges ton bol avec celui du chat.', effects: ['ADD_REPUTATION:korrigans:8', 'ADD_BIOME_CURRENCY:4'] },
    ],
  },
  {
    narrative: 'Le lavoir du village revele des images dans l\'eau de rinçage. Les lavandieres y lisent l\'avenir entre deux draps — aujourd\'hui, elles voient ton visage dans les plis mouilles.',
    options: [
      { verb: 'ecouter', text: 'Tu demandes aux lavandieres ce qu\'elles ont vu.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:6'] },
      { verb: 'plonger', text: 'Tu plonges tes mains dans l\'eau pour voir toi-meme.', effects: ['ADD_REPUTATION:niamh:6', 'DAMAGE_LIFE:3'] },
      { verb: 'offrir', text: 'Tu offres tes services pour aider au lavage.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:korrigans:6'] },
    ],
  },
  {
    narrative: 'Un enfant du village jure avoir vu sa toupie tourner toute seule pendant la nuit. Quand tu l\'examines, elle porte de minuscules gravures — et tourne effectivement quand personne ne regarde.',
    options: [
      { verb: 'dechiffrer', text: 'Tu etudies les gravures microscopiques sur la toupie.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:korrigans:5'] },
      { verb: 'jouer', text: 'Tu lances la toupie et observes sa danse.', effects: ['ADD_REPUTATION:korrigans:7', 'ADD_BIOME_CURRENCY:5'] },
      { verb: 'proteger', text: 'Tu enveloppes la toupie dans une feuille de gui.', effects: ['ADD_REPUTATION:druides:5', 'HEAL_LIFE:5'] },
    ],
  },
  {
    narrative: 'Le cimetiere du village borde un cercle de champignons parfait. Les anciens disent que c\'est une porte entre les mondes. Ce soir, les champignons emettent une lueur violette palpitante.',
    options: [
      { verb: 'invoquer', text: 'Tu t\'agenouilles dans le cercle et appelles les esprits.', effects: ['ADD_REPUTATION:ankou:6', 'ADD_REPUTATION:korrigans:5'] },
      { verb: 'observer', text: 'Tu dessines le motif exact du cercle de champignons.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'cueillir', text: 'Tu recoltes un champignon luminescent avec precaution.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:4'] },
    ],
  },
  {
    narrative: 'La route entre deux villages est gardee par un pont qu\'aucun cheval ne veut traverser. Sous l\'arche, des yeux jaunes clignotent et une voix rauque demande un peage en enigmes.',
    options: [
      { verb: 'resoudre', text: 'Tu acceptes l\'enigme du gardien du pont.', effects: ['ADD_REPUTATION:korrigans:9', 'ADD_ANAM:4'] },
      { verb: 'combattre', text: 'Tu franchis le pont par la force.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:5'] },
      { verb: 'charmer', text: 'Tu flattes le troll avec des compliments elabores.', effects: ['ADD_REPUTATION:korrigans:7', 'HEAL_LIFE:3'] },
    ],
  },
  {
    narrative: 'La tisserande du village tisse une tapisserie qui bouge. Les personnages brodes marchent, combattent et mangent dans leur monde de fil. Elle cherche quelqu\'un pour lui fournir le fil de la fin de l\'histoire.',
    options: [
      { verb: 'aider', text: 'Tu files le lin magique pour completer la tapisserie.', effects: ['ADD_REPUTATION:anciens:7', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'etudier', text: 'Tu dechiffres l\'histoire brodee dans le tissu.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:niamh:4'] },
      { verb: 'couper', text: 'Tu tranches un fil pour liberer un personnage brode.', effects: ['ADD_REPUTATION:korrigans:8', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Un coq chante a rebours — du soir vers le matin. Le temps semble ralentir dans la ferme ou il perche. Les korrigans l\'auraient enchante pour gagner quelques heures de nuit supplementaires.',
    options: [
      { verb: 'decoder', text: 'Tu ecoutes le chant inverse pour comprendre le sortilege.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:korrigans:6'] },
      { verb: 'apaiser', text: 'Tu nourris le coq avec du grain beni pour le delivrer.', effects: ['HEAL_LIFE:6', 'ADD_REPUTATION:druides:5'] },
      { verb: 'profiter', text: 'Tu profites du temps ralenti pour explorer la ferme.', effects: ['ADD_BIOME_CURRENCY:7', 'ADD_REPUTATION:korrigans:4'] },
    ],
  },
  {
    narrative: 'Le puits du village ancien est scelle depuis des generations. Mais cette nuit, le couvercle de pierre vibre et un filet de brume argentee s\'echappe. Les anciens disent qu\'un tresor de korrigan dort au fond.',
    options: [
      { verb: 'explorer', text: 'Tu descelles le puits et descends dans les tenebres.', effects: ['ADD_BIOME_CURRENCY:8', 'DAMAGE_LIFE:5'] },
      { verb: 'ecouter', text: 'Tu presses l\'oreille contre la pierre scellee.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:korrigans:6'] },
      { verb: 'proteger', text: 'Tu renforces le sceau avec des symboles druidiques.', effects: ['ADD_REPUTATION:druides:6', 'HEAL_LIFE:5'] },
    ],
  },
  {
    narrative: 'Un chat noir portant un collier d\'or traverse la place du marche. Chaque villageois qu\'il frole trouve une piece de cuivre dans sa poche. Le chat te regarde fixement et s\'assied a tes pieds.',
    options: [
      { verb: 'caresser', text: 'Tu te penches et gratte le chat derriere les oreilles.', effects: ['ADD_REPUTATION:korrigans:7', 'ADD_BIOME_CURRENCY:6'] },
      { verb: 'suivre', text: 'Tu suis le chat quand il repart vers la foret.', effects: ['ADD_ANAM:4', 'ADD_REPUTATION:niamh:5'] },
      { verb: 'examiner', text: 'Tu inspectes les runes gravees sur le collier d\'or.', effects: ['ADD_ANAM:6', 'ADD_REPUTATION:korrigans:5'] },
    ],
  },
  {
    narrative: 'Le moulin a eau du village tourne a l\'envers depuis l\'aube, mais la farine produite est d\'un blanc lumineux qui guerit les maux de tete. La meuniere soupçonne un bienfait de korrigan — ou un piege.',
    options: [
      { verb: 'gouter', text: 'Tu goutes la farine miraculeuse sans crainte.', effects: ['HEAL_LIFE:7', 'ADD_REPUTATION:korrigans:4'] },
      { verb: 'resoudre', text: 'Tu examines le mecanisme inverse du moulin.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:korrigans:6'] },
      { verb: 'distribuer', text: 'Tu partages la farine guerisseuse avec le village.', effects: ['ADD_REPUTATION:anciens:5', 'ADD_REPUTATION:korrigans:5'] },
    ],
  },
  {
    narrative: 'L\'ecole du village est vide depuis des jours — les enfants ont tous suivi un korrigan joueur de flute dans la colline. Les parents sont inquiets mais les enfants reviennent chaque soir, les poches pleines de baies inconnues.',
    options: [
      { verb: 'suivre', text: 'Tu suis la piste du joueur de flute dans la colline.', effects: ['ADD_REPUTATION:korrigans:9', 'DAMAGE_LIFE:4'] },
      { verb: 'parler', text: 'Tu interroges les enfants sur leurs aventures.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:korrigans:5'] },
      { verb: 'proteger', text: 'Tu negocies avec le korrigan pour limiter les escapades.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:anciens:6'] },
    ],
  },
];

/** Generate a card using FastRoute (hardcoded templates). */
export function generateFastRouteCard(biome: string): Card {
  const template = pick(FASTROUTE_TEMPLATES);
  const options = template.options.map((opt) => ({
    verb: opt.verb,
    text: opt.text,
    field: verbToField(opt.verb),
    effects: opt.effects,
  })) as unknown as [CardOption, CardOption, CardOption];

  return {
    id: nextCardId(),
    narrative: template.narrative,
    options,
    biome,
    source: 'fastroute',
  };
}

/** Detect which minigame to play based on the chosen option's field. */
export function detectMinigame(card: Card, chosenOption: number): string {
  const option = card.options[chosenOption];
  if (!option) return 'traces';
  return pickMinigame(option.field);
}
