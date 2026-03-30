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
