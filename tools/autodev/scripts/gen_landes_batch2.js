// Cycle 17 — landes_bruyere batch2 card generation
// anciens >= 35% of options, druides <= 3 cards, HEAL_LIFE <= 5
const fs = require('fs');

const newCards = [
  {
    "narrative": "Une vieille femme des anciens prie devant un cairn de pierres plates au milieu de la lande. Elle pose chaque pierre en murmurant un nom de disparu.",
    "options": [
      { "verb": "s'agenouiller", "text": "Tu t'agenouilles pres d'elle et poses une pierre a ton tour, honorant les memoires perdues.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_ANAM:3"] },
      { "verb": "ecouter", "text": "Tu restes immobile et ecoutes les noms egrenes, laissant les mots te traverser.", "effects": ["ADD_REPUTATION:anciens:8", "HEAL_LIFE:3"] },
      { "verb": "questionner", "text": "Tu lui demandes si ces rites du souvenir ont encore un sens sur ces landes desertees.", "effects": ["ADD_REPUTATION:anciens:6", "ADD_REPUTATION:druides:4"] }
    ]
  },
  {
    "narrative": "Au sommet d'une butte, un menhir fendu en deux par la foudre se dresse encore. Entre ses deux moities, la lande s'engouffre comme si la pierre respirait.",
    "options": [
      { "verb": "passer", "text": "Tu passes entre les deux eclats de pierre et sens une energie ancienne traverser ton corps.", "effects": ["HEAL_LIFE:4", "ADD_ANAM:4"] },
      { "verb": "toucher", "text": "Tu poses les deux mains sur les faces fracturees, les yeux fermes.", "effects": ["ADD_REPUTATION:anciens:9", "ADD_ANAM:2"] },
      { "verb": "contourner", "text": "Tu choisis de ne pas perturber ce monument brise et le contournes avec respect.", "effects": ["ADD_REPUTATION:anciens:7", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    "narrative": "Un berger tres age conduit un troupeau de moutons blancs sur la lande. Chaque bete porte une marque ocre derriere l'oreille, tracee d'un signe que tu reconnais comme un Ogham Beith.",
    "options": [
      { "verb": "s'approcher", "text": "Tu t'approches du berger et lui demandes pourquoi il marque ses betes d'oghams.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_ANAM:3"] },
      { "verb": "dechiffrer", "text": "Tu examines les marques sur les flancs des moutons: chaque signe est un ogham Beith, protection de naissance.", "effects": ["ADD_REPUTATION:druides:6", "ADD_ANAM:4"] },
      { "verb": "observer", "text": "Tu observes le cortege paisible de loin, touche par cette transmission silencieuse.", "effects": ["ADD_REPUTATION:anciens:6", "HEAL_LIFE:3"] }
    ]
  },
  {
    "narrative": "Une fontaine de pierre moussue murmure dans un creux de la lande. Trois bols de terre cuite sont poses en offrande sur le rebord. L'eau a une odeur de tourbe et de serpolet.",
    "options": [
      { "verb": "boire", "text": "Tu bois une gorgee de l'eau ambree. Elle est froide et goutee de memoire.", "effects": ["HEAL_LIFE:5", "ADD_ANAM:2"] },
      { "verb": "offrir", "text": "Tu deposes un objet personnel dans l'un des bols en signe de gratitude aux anciens.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_BIOME_CURRENCY:2"] },
      { "verb": "purifier", "text": "Tu asperges ton visage et tes mains, practiquant une purification transmise par les anciens.", "effects": ["HEAL_LIFE:4", "ADD_REPUTATION:anciens:7"] }
    ]
  },
  {
    "narrative": "Sur la lande bat le vent de l'equinoxe. Un groupe d'anciens trace un grand cercle dans l'herbe avec leurs batons ferres, calculant la course du soleil couchant.",
    "options": [
      { "verb": "participer", "text": "Tu prends un baton et rejoins le cercle, alignant ton geste sur celui des anciens.", "effects": ["ADD_REPUTATION:anciens:12", "ADD_ANAM:3"] },
      { "verb": "mesurer", "text": "Tu proposes de mesurer l'ombre portee du plus grand menhir pour affiner leurs calculs.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_REPUTATION:druides:5"] },
      { "verb": "noter", "text": "Tu memorises les angles traces, sachant que cette connaissance traversera les siecles.", "effects": ["ADD_ANAM:5", "ADD_REPUTATION:anciens:6"] }
    ]
  },
  {
    "narrative": "Un tumulus herbu se dresse isole au milieu des bruyeres mauves. Une ouverture basse marquee de dalles obliques en signale l'entree. Un vieil homme est assis sur le seuil, les yeux fermes.",
    "options": [
      { "verb": "respecter", "text": "Tu salues le gardien silencieux et attends qu'il t'invite a parler.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_ANAM:2"] },
      { "verb": "entrer", "text": "L'ancien ouvre les yeux et hoche la tete. Tu te courbes pour franchir le seuil vers l'obscurite pieuse.", "effects": ["ADD_ANAM:4", "ADD_REPUTATION:anciens:8"] },
      { "verb": "veiller", "text": "Tu t'assois a cote de lui sur la dalle froide et gardes le tumulus en silence jusqu'au coucher du soleil.", "effects": ["HEAL_LIFE:3", "ADD_REPUTATION:anciens:9"] }
    ]
  },
  {
    "narrative": "Un chant monte des bruyeres. Trois femmes aux cheveux blancs marchent en procession en se passant une torche. Elles appellent les ames errantes de la lande pour les guider vers le repos.",
    "options": [
      { "verb": "suivre", "text": "Tu marches derriere elles a bonne distance, gardant la flamme dans ton champ de vue.", "effects": ["ADD_REPUTATION:anciens:9", "ADD_ANAM:3"] },
      { "verb": "chanter", "text": "Tu reprends le refrain que tu crois reconnaitre d'une vie anterieure. Les femmes se retournent et sourient.", "effects": ["ADD_REPUTATION:anciens:11", "HEAL_LIFE:3"] },
      { "verb": "porter", "text": "Tu proposes de porter la torche pour soulager la plus agee des trois.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    "narrative": "Un renard traverse la lande en portant dans sa gueule une branche de gui. Il s'arrete, te regarde, puis pose la branche a tes pieds avant de disparaitre dans les genets.",
    "options": [
      { "verb": "ramasser", "text": "Tu ramasses le gui avec soin. Les anciens disent que le renard est le messager de l'entre-monde.", "effects": ["ADD_ANAM:5", "ADD_REPUTATION:anciens:7"] },
      { "verb": "laisser", "text": "Tu laisses la branche sur place, refusant d'interpreter le message comme un don personnel.", "effects": ["ADD_REPUTATION:anciens:6", "HEAL_LIFE:4"] },
      { "verb": "planter", "text": "Tu plantes la branche de gui dans la terre tourbeuse de la lande, replantant le signe.", "effects": ["ADD_BIOME_CURRENCY:4", "ADD_REPUTATION:anciens:8"] }
    ]
  },
  {
    "narrative": "Un monument funeraire gaulois oublie emerge a demi de la tourbe. Des sculptures frustes representent des visages aux yeux creux regardant quatre horizons. Les anciens les appellent les Veilleurs.",
    "options": [
      { "verb": "nettoyer", "text": "Tu degages la mousse et la tourbe qui effacent les traits des Veilleurs avec tes mains.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_ANAM:3"] },
      { "verb": "saluer", "text": "Tu touches le front de chaque visage grave en prononcant les quatre directions en vieux celtique.", "effects": ["ADD_REPUTATION:anciens:12", "ADD_ANAM:2"] },
      { "verb": "memoriser", "text": "Tu dessines les visages dans ta memoire pour les transmettre plus tard. Les Veilleurs meritent d'etre connus.", "effects": ["ADD_ANAM:4", "ADD_BIOME_CURRENCY:2"] }
    ]
  },
  {
    "narrative": "La bruyere en fleur forme un tapis mauve a perte de vue. Une jeune bergere dit qu'un ancien lui a appris que chaque teinte de bruyere correspond a une saison de la vie humaine.",
    "options": [
      { "verb": "apprendre", "text": "Tu ecoutes son enseignement improvise sur les nuances de la bruyere, emu par cette transmission orale.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_ANAM:4"] },
      { "verb": "contribuer", "text": "Tu ajoutes ce que tu sais des cycles celtiques de vie, enrichissant la lecon de part et d'autre.", "effects": ["ADD_REPUTATION:anciens:7", "ADD_REPUTATION:druides:4"] },
      { "verb": "cueillir", "text": "Tu cueillis un bouquet de bruyere de trois teintes differentes pour honorer l'enseignement recu.", "effects": ["HEAL_LIFE:3", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    "narrative": "Un orage de printemps balaie soudain la lande. L'eclat de foudre illumine un dolmen que tu n'avais pas vu. Sous la dalle principale se tient abri une vieille druide qui attend calmement.",
    "options": [
      { "verb": "s'abriter", "text": "Tu rejoins l'abri du dolmen. La druide t'accueille en silence avec un geste d'invitation.", "effects": ["HEAL_LIFE:4", "ADD_REPUTATION:druides:8"] },
      { "verb": "resister", "text": "Tu restes debout dans la pluie battante, bras ouverts, recevant la tempete comme un bapteme.", "effects": ["ADD_ANAM:5", "DAMAGE_LIFE:2"] },
      { "verb": "observer", "text": "Tu regardes la druide de loin, curieux de voir comment une telle personne regarde l'orage.", "effects": ["ADD_REPUTATION:druides:6", "ADD_ANAM:3"] }
    ]
  },
  {
    "narrative": "Un champ de cromlechs miniatures s'etend dans un vallon cache des vents. Chaque mini-cercle fait a peine un metre de diametre, comme des terrains de jeu pour des enfants de pierre.",
    "options": [
      { "verb": "s'asseoir", "text": "Tu t'assois au centre du plus grand des petits cercles. Le vent s'apaise instantanement autour de toi.", "effects": ["HEAL_LIFE:5", "ADD_ANAM:2"] },
      { "verb": "compter", "text": "Tu comptes les cercles: vingt-cinq exactement. Les anciens disaient qu'ils correspondaient aux lunes d'une generation.", "effects": ["ADD_REPUTATION:anciens:9", "ADD_ANAM:3"] },
      { "verb": "danser", "text": "Tu improvises une ronde entre les cercles, les pieds evitant instinctivement chaque frontiere de pierre.", "effects": ["ADD_BIOME_CURRENCY:4", "HEAL_LIFE:3"] }
    ]
  },
  {
    "narrative": "Un vieil homme sculpte une silhouette humaine dans une souche de chene noircie par le temps. Il dit qu'il cree le corps d'un ancetre pour que son ame puisse reposer en paix sur la lande.",
    "options": [
      { "verb": "aider", "text": "Tu tiens la souche pendant qu'il travaille, participant en silence a ce rite funebre.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_ANAM:3"] },
      { "verb": "graver", "text": "Tu proposes de graver un ogham Luis sur la figure, symbole de protection de l'ame.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_REPUTATION:druides:5"] },
      { "verb": "nommer", "text": "Tu demandes le nom de l'ancetre. Le vieil homme te le dit dans un souffle, la premiere fois qu'il le prononce depuis la mort.", "effects": ["ADD_ANAM:5", "ADD_REPUTATION:anciens:9"] }
    ]
  },
  {
    "narrative": "Des vestiges de haies bocageres en terre et pierre dessinent des parcelles sur la lande. Un paysan ancien te dit que chaque haie est un message: la frontiere entre deux familles, deux memoires.",
    "options": [
      { "verb": "marcher", "text": "Tu longes les haies les unes apres les autres, lisant les territoires comme un livre ouvert.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_BIOME_CURRENCY:3"] },
      { "verb": "reparer", "text": "Tu aides le paysan a repositionner les pierres tombees sur une haie qui s'effondre.", "effects": ["ADD_REPUTATION:anciens:11", "HEAL_LIFE:3"] },
      { "verb": "questionner", "text": "Tu lui demandes quelle haie est la plus ancienne et ce qu'elle gardait autrefois.", "effects": ["ADD_ANAM:4", "ADD_REPUTATION:anciens:7"] }
    ]
  },
  {
    "narrative": "La nuit tombe sur la lande. Des feux follets dansent au loin au-dessus d'une tourbiere. Une ancienne assise pres d'un feu de camp dit qu'ils sont les ames de ceux qui ont oublie leurs noms.",
    "options": [
      { "verb": "s'approcher", "text": "Tu t'approches des feux follets avec respect, murmurant des noms inventes pour guider ces ames.", "effects": ["ADD_ANAM:5", "ADD_REPUTATION:anciens:8"] },
      { "verb": "reciter", "text": "Tu recites la liste des ancetres dont tu te souviens, offrant tes memoires a ces errants de lumiere.", "effects": ["ADD_REPUTATION:anciens:12", "ADD_ANAM:3"] },
      { "verb": "attendre", "text": "Tu restes pres du feu de camp avec l'ancienne jusqu'a ce que les feux follets s'eteignent un a un.", "effects": ["HEAL_LIFE:4", "ADD_REPUTATION:anciens:7"] }
    ]
  },
  {
    "narrative": "Un chemin creux s'enfonce entre deux talus couverts de lierre et de campanules. A l'intersection d'un second chemin, une croix de pierre ancienne porte encore des traces d'ocre rouge.",
    "options": [
      { "verb": "graver", "text": "Tu graves un signe minimal sur la croix avec une pierre pointue, un voeu pour les vivants.", "effects": ["ADD_REPUTATION:anciens:9", "ADD_ANAM:4"] },
      { "verb": "offrir", "text": "Tu positionnes trois epis d'herbe seche en triangle au pied de la croix selon l'usage des anciens.", "effects": ["ADD_REPUTATION:anciens:11", "ADD_BIOME_CURRENCY:2"] },
      { "verb": "lire", "text": "Tu dechiffres les ocres encore visibles: un Ogham Nion, protection du voyageur. Tu en traces un nouveau par-dessus.", "effects": ["ADD_ANAM:5", "ADD_REPUTATION:anciens:8"] }
    ]
  },
  {
    "narrative": "Un enfant creuse dans la tourbe avec un baton et decouvre une perle de verre bleu. Sa grand-mere accourt et lui explique que les perles des anciens enterrees dans la tourbe gardent la memoire des echanges.",
    "options": [
      { "verb": "temoigner", "text": "Tu confirmes a l'enfant que cette perle traversait peut-etre les routes celtiques depuis mille ans.", "effects": ["ADD_REPUTATION:anciens:8", "ADD_ANAM:3"] },
      { "verb": "examiner", "text": "Tu examines la perle. La teinte et le motif spirale correspondent aux productions de la periode ancienne.", "effects": ["ADD_REPUTATION:anciens:7", "ADD_BIOME_CURRENCY:4"] },
      { "verb": "reenterrer", "text": "Tu proposes de remettre la perle en terre apres observation, respectant le depot ancestral.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_ANAM:4"] }
    ]
  },
  {
    "narrative": "Une pierre de sacrifice plate et rectangulaire git dans les bruyeres. Des rigoles taillees dans la pierre convergent vers un creux central. Un ancien y depose chaque matin quelques gouttes de lait.",
    "options": [
      { "verb": "offrir", "text": "Tu verses l'eau que tu portes dans la pierre sacrificielle en hommage aux anciens rites.", "effects": ["ADD_REPUTATION:anciens:10", "ADD_BIOME_CURRENCY:3"] },
      { "verb": "toucher", "text": "Tu poses la paume dans le creux central encore humide. Une chaleur inattendue monte dans ton bras.", "effects": ["HEAL_LIFE:5", "ADD_ANAM:3"] },
      { "verb": "questionner", "text": "Tu demandes a l'ancien pourquoi le lait plutot que tout autre offrande. Il repond: le lait est la promesse de la vie qui continue.", "effects": ["ADD_REPUTATION:anciens:9", "ADD_ANAM:4"] }
    ]
  },
  {
    "narrative": "Un arc-en-ciel incomplet se dresse sur la lande apres l'averse. Il ne touche pas la terre: les anciens disaient qu'un arc incomplet est un message non encore traduit.",
    "options": [
      { "verb": "interpreter", "text": "Tu medites sur l'arc incomplet: il annonce une transition, ni finissant ni commencant.", "effects": ["ADD_ANAM:5", "ADD_REPUTATION:anciens:7"] },
      { "verb": "attendre", "text": "Tu attends que l'arc se complete ou disparaisse, sans rien forcer.", "effects": ["HEAL_LIFE:4", "ADD_REPUTATION:anciens:6"] },
      { "verb": "marcher", "text": "Tu marches vers l'endroit ou l'arc semble descendre, esperant trouver le lieu ou le message aboutit.", "effects": ["ADD_BIOME_CURRENCY:3", "ADD_ANAM:4"] }
    ]
  },
  {
    "narrative": "Pres d'une tourbiere noire, une ancienne tresse des roseaux en forme humaine. Elle dit que chaque effigie de roseau peut porter les peines d'une personne si on la confie aux eaux.",
    "options": [
      { "verb": "confier", "text": "Tu confies une peine recente a l'effigie de roseau et la regardes disparaitre lentement dans la tourbe.", "effects": ["HEAL_LIFE:5", "ADD_ANAM:3"] },
      { "verb": "tresser", "text": "Tu apprends rapidement le tressage et fabriques ta propre effigie avec l'aide de l'ancienne.", "effects": ["ADD_REPUTATION:anciens:11", "ADD_ANAM:3"] },
      { "verb": "contempler", "text": "Tu regardes l'effigie flotter, te demandant si les tourbieres gardent vraiment la memoire de nos peines.", "effects": ["ADD_REPUTATION:anciens:8", "HEAL_LIFE:3"] }
    ]
  }
];

const existing = JSON.parse(fs.readFileSync('web-demo/public/data/cards.json', 'utf8'));
const merged = existing.concat(newCards);
fs.writeFileSync('web-demo/public/data/cards.json', JSON.stringify(merged, null, 2), 'utf8');

const final = JSON.parse(fs.readFileSync('web-demo/public/data/cards.json', 'utf8'));
console.log('Cards total:', final.length);
console.log('Added:', final.length - existing.length);

let anciensOpts = 0, druiCards = 0, totalOpts = 0;
const newBatch = final.slice(-20);
newBatch.forEach(function(c) {
  var hasDruides = false;
  c.options.forEach(function(o) {
    totalOpts++;
    var effs = o.effects.join(' ');
    if(effs.indexOf(':anciens:') !== -1) anciensOpts++;
    if(effs.indexOf(':druides:') !== -1) hasDruides = true;
  });
  if(hasDruides) druiCards++;
});
console.log('anciens_opts:', anciensOpts + '/' + totalOpts + ' = ' + Math.round(anciensOpts/totalOpts*100) + '%');
console.log('druides_cards:', druiCards, '(max 3)');

var healViolations = 0;
newBatch.forEach(function(c) {
  c.options.forEach(function(o) {
    o.effects.forEach(function(e) {
      var m = e.match(/^HEAL_LIFE:(\d+)/);
      if(m && parseInt(m[1]) > 5) healViolations++;
    });
  });
});
console.log('HEAL_LIFE>5 violations:', healViolations);
console.log('STATUS: ' + (healViolations === 0 && druiCards <= 3 ? 'PASS' : 'FAIL'));
