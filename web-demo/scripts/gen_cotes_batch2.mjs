import fs from 'fs';

const cardsPath = 'c:/Users/PGNK2128/Godot-MCP/web-demo/public/data/cards.json';
const cards = JSON.parse(fs.readFileSync(cardsPath, 'utf8'));

const newCards = [
  {
    narrative: "Les vagues se fracassent contre les falaises de granit, projetant des gerbes d'ecume argentee. Un phoque au regard humain emerge des flots et te fixe intensement.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'contempler', text: "Tu restes immobile, laissant le regard du phoque te traverser. Une sagesse ancienne coule de ses yeux.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:8','HEAL_LIFE:3'] },
      { verb: 'plonger', text: "Tu entres dans les eaux froides, rejoignant la creature dans son element. Le froid est une claque salvatrice.", faction: 'anciens', effects: ['DAMAGE_LIFE:4','ADD_REPUTATION:anciens:12'] },
      { verb: 'reculer', text: "Tu recules prudemment, respectant la frontiere entre deux mondes.", faction: 'druides', effects: ['ADD_REPUTATION:druides:6'] }
    ]
  },
  {
    narrative: "Une barque de bois noire se balance pres du rivage sans capitaine visible. Ses rames semblent bouger seules. L'horizon brumeux cache une ile absente des cartes.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'embarquer', text: "Tu montes dans la barque. Les rames te guident a travers le brouillard.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:15','DAMAGE_LIFE:5'] },
      { verb: 'observer', text: "Tu attends et regardes. La barque repart seule, laissant un objet echoue sur le sable.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:7','HEAL_LIFE:2'] },
      { verb: 'appeler', text: "Tu cries dans le brouillard. Une voix repond, distordue par le vent.", faction: 'korrigans', effects: ['ADD_REPUTATION:korrigans:9','DAMAGE_LIFE:2'] }
    ]
  },
  {
    narrative: "Un pecheur assis sur un rocher replie ses filets avec des gestes rituels. Il fredonne une chanson en langue ancienne. Ses yeux sont fermes mais ses mains savent exactement ou aller.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'ecouter', text: "Tu t'assieds pres de lui en silence, laissant les mots anciens te traverser.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:10','HEAL_LIFE:4'] },
      { verb: 'aider', text: "Tu joins tes mains aux siennes pour replier les filets. Il ouvre les yeux et te sourit.", faction: 'druides', effects: ['ADD_REPUTATION:druides:8','ADD_REPUTATION:anciens:5'] },
      { verb: 'interroger', text: "Tu poses une question. Il soupire et s'en va sans repondre.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:6','DAMAGE_LIFE:2'] }
    ]
  },
  {
    narrative: "Des ossements blanchis s'accumulent au pied d'une falaise. Des oiseaux de mer noirs les surveillent. L'air sent le sel et quelque chose de plus lourd.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'prier', text: "Tu recites une priere pour les ames qui reposent ici. Les oiseaux s'envolent en cercles.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:12','HEAL_LIFE:2'] },
      { verb: 'fuir', text: "Tu t'eloignes rapidement. Certains lieux ne sont pas pour les vivants.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:4','HEAL_LIFE:3'] },
      { verb: 'examiner', text: "Tu t'approches avec respect. Une tache d'encre sur un os — un message grave.", faction: 'druides', effects: ['ADD_REPUTATION:druides:14','DAMAGE_LIFE:3'] }
    ]
  },
  {
    narrative: "Une sirene aux ecailles vertes est prise dans un filet abandonne. Elle ne crie pas, ne se debat plus — elle attend avec une patience qui n'appartient pas aux etres de chair.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'liberer', text: "Tu denoues le filet avec soin. Elle glisse dans l'eau sans un mot.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:18','HEAL_LIFE:5'] },
      { verb: 'negocier', text: "Tu lui parles avant de la liberer, cherchant une promesse en echange.", faction: 'korrigans', effects: ['ADD_REPUTATION:korrigans:12','ADD_REPUTATION:niamh:5'] },
      { verb: 'ignorer', text: "Tu passes ton chemin. Ce qui appartient a la mer doit y retourner seul.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:8','DAMAGE_LIFE:4'] }
    ]
  },
  {
    narrative: "La maree basse a revele une grotte inconnue. Sur ses parois, des spirales sont gravees — certaines fraichement incisees. La mer ne peut pas avoir fait cela.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'entrer', text: "Tu avances dans la grotte. L'air y est immobile malgre le vent dehors.", faction: 'druides', effects: ['ADD_REPUTATION:druides:16','DAMAGE_LIFE:6'] },
      { verb: 'tracer', text: "Tu ajoutes ta propre spirale aux autres. Quelque chose guide ton geste.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:13','ADD_REPUTATION:druides:4'] },
      { verb: 'memoriser', text: "Tu contemples les motifs, gravant chaque detail dans ta memoire.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:7','HEAL_LIFE:2'] }
    ]
  },
  {
    narrative: "Une tempete eclate sans prevenir sur une mer calme. Des eclairs violets zebrent le ciel. Au centre des vagues, une silhouette danse sans etre emportee.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'resister', text: "Tu t'ancres au rocher, refusant de ceder. Chaque vague te laisse plus fort.", faction: 'anciens', effects: ['DAMAGE_LIFE:8','ADD_REPUTATION:anciens:20'] },
      { verb: 'abriter', text: "Tu cherches refuge dans les rochers. La tempete passe et tu es intact.", faction: 'druides', effects: ['ADD_REPUTATION:druides:5','HEAL_LIFE:3'] },
      { verb: 'approcher', text: "Tu marches vers la silhouette dans la tempete. La folie a parfois ses recompenses.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:12','DAMAGE_LIFE:10'] }
    ]
  },
  {
    narrative: "Un enfant construit un chateau de sable alors que la maree monte. Il travaille avec une concentration absolue, comme si le monde dependait de cette construction.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'aider', text: "Tu t'agenouilles et l'aides a finir le chateau. Vous travaillez dans un silence complice.", faction: 'korrigans', effects: ['ADD_REPUTATION:korrigans:10','HEAL_LIFE:4'] },
      { verb: 'regarder', text: "Tu t'assieds pour observer. La mer engloutit tout, et il recommence.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:8','HEAL_LIFE:2'] },
      { verb: 'prevenir', text: "Tu lui expliques que la maree va tout detruire. Il hausse les epaules.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:6','ADD_REPUTATION:anciens:6'] }
    ]
  },
  {
    narrative: "Une lanterne flotte sur l'eau sans source visible, sa flamme vert pale inalterable par le vent. Elle suit le courant vers un promontoire ou des silhouettes veillent.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'suivre', text: "Tu longes le rivage. La lanterne t'amene a une clairiere ou des druides psalmodient.", faction: 'druides', effects: ['ADD_REPUTATION:druides:15','HEAL_LIFE:3'] },
      { verb: 'ignorer', text: "Tu detournes le regard. Les feux de nuit ne sont pas tous pour les vivants.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:7'] },
      { verb: 'capturer', text: "Tu plonges la main dans l'eau. Ta main traverse le feu sans bruler.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:14','DAMAGE_LIFE:5'] }
    ]
  },
  {
    narrative: "Des pieuvres geantes ont envahi le port au crepuscule, leurs tentacules enroules autour des piliers. Les pecheurs regardent depuis la berge, indecis.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'chasser', text: "Tu prends un long baton et fais du bruit. Elles reculent lentement.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:9','DAMAGE_LIFE:5'] },
      { verb: 'observer', text: "Tu etudies leurs patterns. Elles ne detruisent pas — elles cherchent quelque chose.", faction: 'druides', effects: ['ADD_REPUTATION:druides:11','HEAL_LIFE:2'] },
      { verb: 'reculer', text: "Tu recules avec les pecheurs. La prudence n'est pas lachete face a l'inconnu.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:5','HEAL_LIFE:4'] }
    ]
  },
  {
    narrative: "Un vieux phare abandonne clignote encore, sans electricite connue. Son faisceau dessine un message en Morse sur les nuages — mais tu ne connais pas le code.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'dechiffrer', text: "Tu observes les intervalles, notes les rythmes sur le sable. Quelque chose ressemble a un nom.", faction: 'druides', effects: ['ADD_REPUTATION:druides:13','ADD_REPUTATION:anciens:4'] },
      { verb: 'grimper', text: "Tu escalades le phare pour comprendre. La source est a la fois etrange et simple.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:15','DAMAGE_LIFE:7'] },
      { verb: 'repondre', text: "Tu allumes ton propre feu sur la plage. Le phare s'eteint. Le message est recu.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:10','ADD_REPUTATION:ankou:5'] }
    ]
  },
  {
    narrative: "Le cadavre d'une baleine bleue s'est echoue sur la plage. Les villageois s'approchent avec des couteaux — par tradition et survie, non par cruaute.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'participer', text: "Tu prends part au rituel communautaire. La baleine nourrit tout un village pour l'hiver.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:14','HEAL_LIFE:5'] },
      { verb: 'benissir', text: "Tu recites une benediction pour l'ame de la creature avant que quiconque ne touche.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:16','ADD_REPUTATION:anciens:3'] },
      { verb: 'proteger', text: "Tu demandes qu'on laisse la baleine en paix. Les regards sont mecontents.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:9','DAMAGE_LIFE:3'] }
    ]
  },
  {
    narrative: "Une femme en blanc marche sur l'eau a cent metres du rivage. Elle ne s'enfonce pas. Elle ne regarde pas vers toi. Elle marche vers un horizon que seuls ses yeux voient.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'contempler', text: "Tu restes jusqu'a ce qu'elle disparaisse dans la brume. Une paix etrange s'installe.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:13','HEAL_LIFE:4'] },
      { verb: 'appeler', text: "Tu cries n'importe quel nom. Elle s'arrete, tourne la tete, puis continue.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:11','DAMAGE_LIFE:2'] },
      { verb: 'documenter', text: "Tu memorises chaque detail: la demarche, la robe, la direction.", faction: 'druides', effects: ['ADD_REPUTATION:druides:9','ADD_REPUTATION:niamh:4'] }
    ]
  },
  {
    narrative: "Une crique cachee revele une source d'eau douce jaillissant du rocher face a la mer. Des pierres votives s'accumulent la depuis des siecles. L'eau sent la menthe et les algues.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'boire', text: "Tu portes l'eau a tes levres. Elle est douce, fraiche, et quelque chose en toi se repose.", faction: 'niamh', effects: ['HEAL_LIFE:5','ADD_REPUTATION:niamh:7'] },
      { verb: 'offrir', text: "Tu poses une pierre ronde parmi les offrandes et fais une promesse.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:12','ADD_REPUTATION:druides:5'] },
      { verb: 'analyser', text: "Tu goutes l'eau prudemment, cherchant a comprendre cette source.", faction: 'druides', effects: ['ADD_REPUTATION:druides:10','HEAL_LIFE:2'] }
    ]
  },
  {
    narrative: "Des korrigans dansent en cercle sur les galets a minuit, leurs ombres plus longues que leurs corps. Ils rient d'un son comme des cailloux roules par la vague.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'rejoindre', text: "Tu entres dans le cercle en dansant. Les korrigans t'accueillent avec des exclamations.", faction: 'korrigans', effects: ['ADD_REPUTATION:korrigans:18','DAMAGE_LIFE:3'] },
      { verb: 'chanter', text: "Tu restes a l'ecart et chantes. Ils s'arretent, ecoutent, reprennent en integrant ton air.", faction: 'korrigans', effects: ['ADD_REPUTATION:korrigans:11','HEAL_LIFE:2'] },
      { verb: 'fuir', text: "Tu te sauves sans bruit. Les korrigans la nuit ne plaisantent qu'avec ceux qui acceptent.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:6','HEAL_LIFE:3'] }
    ]
  },
  {
    narrative: "Un bateau naufrage emerge lors d'une maree extraordinairement basse. Son nom en lettres dorees: An Anaon. Sa coque est intacte mais vide depuis des decennies.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'monter', text: "Tu montes a bord. Le pont craque mais tient. Ce que tu trouves en bas change ta comprehension.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:17','DAMAGE_LIFE:8'] },
      { verb: 'prier', text: "Tu recites une priere sur le rivage pour les marins perdus.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:13','HEAL_LIFE:2'] },
      { verb: 'cartographier', text: "Tu notes la position du navire pour les archives du port.", faction: 'druides', effects: ['ADD_REPUTATION:druides:8','ADD_REPUTATION:anciens:6'] }
    ]
  },
  {
    narrative: "Trois soeurs en robes de deuil tirent un filet hors de la mer au lever du soleil. Le filet est plein de quelque chose qui brille — ni poisson, ni coquillage.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'aider', text: "Tu t'approches pour aider a tirer. Elles acceptent sans poser de questions.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:11','ADD_REPUTATION:anciens:6'] },
      { verb: 'observer', text: "Tu restes a distance, fascinee. Elles semblent performer un rituel immemoriel.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:9','HEAL_LIFE:2'] },
      { verb: 'demander', text: "Tu t'approches et demandes ce qu'elles pechent. Elles repondent dans une langue inconnue que tu comprends.", faction: 'druides', effects: ['ADD_REPUTATION:druides:12','ADD_REPUTATION:niamh:5'] }
    ]
  },
  {
    narrative: "Un cerf mi-cerf mi-poisson emerge de l'ocean avec des algues dans ses bois de nacre. Il te regarde depuis le rivage avec une dignite absolue.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'agenouiller', text: "Tu t'agenouilles sur le sable mouille. Le cerf s'approche et touche ton front de ses bois.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:16','HEAL_LIFE:5'] },
      { verb: 'degager', text: "Tu enleves les algues de ses bois delicatement. Il reste immobile et patient.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:14','ADD_REPUTATION:anciens:4'] },
      { verb: 'reciter', text: "Tu recites une invocation ancienne. Le cerf incline la tete, puis retourne dans les vagues.", faction: 'druides', effects: ['ADD_REPUTATION:druides:13','HEAL_LIFE:3'] }
    ]
  },
  {
    narrative: "La brume s'epaissit subitement, reduisant la visibilite a quelques pas. Des voix humaines semblent venir de partout — certaines en colere, d'autres chantant.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'avancer', text: "Tu avances avec confiance dans la brume. Tu sors sur une plage que tu ne reconnais pas.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:11','DAMAGE_LIFE:4'] },
      { verb: 'attendre', text: "Tu t'assieds et attends. La brume se dissipe, et tu es exactement ou tu etais.", faction: 'druides', effects: ['ADD_REPUTATION:druides:7','HEAL_LIFE:2'] },
      { verb: 'parler', text: "Tu parles aux voix comme si elles etaient reelles. Certaines se taisent. D'autres repondent.", faction: 'ankou', effects: ['ADD_REPUTATION:ankou:14','ADD_REPUTATION:niamh:4'] }
    ]
  },
  {
    narrative: "A l'aube, les galets du rivage sont couverts de formes tracees — oghams, spirales, visages stylises. L'art a ete cree cette nuit et aucun pecheur ne l'a vu faire.",
    biome: 'cotes_sauvages',
    options: [
      { verb: 'preserver', text: "Tu organises des pierres pour proteger l'art de la maree. Le village doit voir cela.", faction: 'anciens', effects: ['ADD_REPUTATION:anciens:13','ADD_REPUTATION:druides:5'] },
      { verb: 'dechiffrer', text: "Tu passes des heures a lire les oghams. Certains mots emergent: passage, eau, retour.", faction: 'druides', effects: ['ADD_REPUTATION:druides:18','DAMAGE_LIFE:2'] },
      { verb: 'emporter', text: "Tu prends un galet marque comme souvenir. Quelque chose te dit que ce n'est pas un vol.", faction: 'niamh', effects: ['ADD_REPUTATION:niamh:8','HEAL_LIFE:2'] }
    ]
  }
];

// Validate constraints
let valid = true;
const MAX_HEAL = 5, MAX_DMG = 15, MAX_REP = 20;
newCards.forEach((card, ci) => {
  card.options.forEach((opt, oi) => {
    (opt.effects || []).forEach(eff => {
      const parts = eff.split(':');
      const type = parts[0];
      const val = parseInt(parts[parts.length - 1] || '0', 10);
      if (type === 'HEAL_LIFE' && val > MAX_HEAL) { console.error('HEAL violation card', ci, 'opt', oi, val); valid = false; }
      if (type === 'DAMAGE_LIFE' && val > MAX_DMG) { console.error('DAMAGE violation card', ci, 'opt', oi, val); valid = false; }
      if (type === 'ADD_REPUTATION' && Math.abs(val) > MAX_REP) { console.error('REP violation card', ci, 'opt', oi, val); valid = false; }
    });
  });
});

if (!valid) { console.error('CONSTRAINT VIOLATIONS — ABORT'); process.exit(1); }

// Faction distribution report
const factionCount = {};
newCards.forEach(c => c.options.forEach(o => { factionCount[o.faction] = (factionCount[o.faction] || 0) + 1; }));
const total = newCards.length * 3;
console.log('Faction dist (total opts=' + total + '):', JSON.stringify(factionCount));
console.log('niamh%:', Math.round((factionCount['niamh'] || 0) * 100 / total), '(target ~35%)');
console.log('ankou%:', Math.round((factionCount['ankou'] || 0) * 100 / total), '(target ~20%)');

const allCards = [...cards, ...newCards];
fs.writeFileSync(cardsPath, JSON.stringify(allCards, null, 2));
console.log('SUCCESS: total cards', allCards.length, '(added', newCards.length, 'cotes_sauvages batch2)');
