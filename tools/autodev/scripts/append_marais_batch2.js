// Script: append marais_korrigans_ankou_batch2 (20 cards) to public/data/cards.json
// T044 — Cycle 14 narrative designer wave
// Constraints: ankou>=7, druides<=3, niamh=3, anciens=3, korrigans=4
// Heal<=5, dmg<=5, rep<=10. No 3+ negative effects per option.

const fs = require('fs');
const CARDS_PATH = 'C:/Users/PGNK2128/Godot-MCP/web-demo/public/data/cards.json';

const newCards = [
  // C14-01 — ankou — perception / finesse / esprit
  {
    narrative: "Un chien noir de la taille d'un veau bloque le sentier du marais. Ses yeux sont deux braises rouges qui ne clignotent pas. Il ne grogne pas, ne bouge pas. Les anciens disent que le chien noir guide les ames — ou les devore.",
    options: [
      { verb: "pister", text: "Tu etudies le sol autour du chien, cherchant par ou il est venu.", effects: ["ADD_REPUTATION:ankou:7", "ADD_ANAM:4"] },
      { verb: "apaiser", text: "Tu t'accroupis et lui parles doucement, sans contact visuel.", effects: ["HEAL_LIFE:4", "ADD_REPUTATION:niamh:5"] },
      { verb: "resister mentalement", text: "Tu fixes les braises rouges et refuses de detourner les yeux.", effects: ["ADD_REPUTATION:ankou:9", "DAMAGE_LIFE:3"] }
    ]
  },
  // C14-02 — ankou — chance / vigueur / bluff
  {
    narrative: "La charrette de l'Ankou est enlisee dans la tourbe. Le passeur des morts te regarde — son visage porte les traits de quelqu'un que tu as connu, mais ses mains sont de bois et d'os. Il tend l'une d'elles vers toi.",
    options: [
      { verb: "tenter sa chance", text: "Tu saisis la main d'os et tires de toutes tes forces.", effects: ["ADD_REPUTATION:ankou:8", "DAMAGE_LIFE:4"] },
      { verb: "mentir", text: "Tu pretends ne pas comprendre ce qu'il demande.", effects: ["ADD_BIOME_CURRENCY:6", "ADD_REPUTATION:korrigans:4"] },
      { verb: "resister physiquement", text: "Tu cales tes pieds dans la boue et pousses la roue.", effects: ["ADD_REPUTATION:anciens:7", "DAMAGE_LIFE:3"] }
    ]
  },
  // C14-03 — korrigans — logique / chance / finesse
  {
    narrative: "Trois korrigans des marais jouent aux osselets sur un rondin flottant. Ils te proposent une partie : si tu gagnes, ils te montrent le passage sec. Si tu perds, tu portes leurs sacs jusqu'au prochain tertre. Les osselets luisent d'un vert pale.",
    options: [
      { verb: "resoudre", text: "Tu etudies les regles du jeu et joues avec methode.", effects: ["ADD_REPUTATION:korrigans:8", "ADD_BIOME_CURRENCY:5"] },
      { verb: "deviner", text: "Tu joues a l'instinct, ignorant les subtilites des regles.", effects: ["ADD_BIOME_CURRENCY:7", "DAMAGE_LIFE:2"] },
      { verb: "se faufiler", text: "Tu fais semblant de jouer tout en repérant le passage qu'ils gardent.", effects: ["ADD_REPUTATION:korrigans:6", "ADD_ANAM:3"] }
    ]
  },
  // C14-04 — ankou — observation / esprit / perception
  {
    narrative: "Une balance d'or est suspendue entre deux arbres morts, oscillant sans vent. Sur un plateau, une plume noire. Sur l'autre, une pierre blanche. Un souffle glacial t'indique que la balance mesure quelque chose qui t'appartient.",
    options: [
      { verb: "observer", text: "Tu etudies l'oscillation de la balance sans jamais la toucher.", effects: ["ADD_ANAM:6", "ADD_REPUTATION:ankou:7"] },
      { verb: "se concentrer", text: "Tu fermes les yeux et explores ce que la balance pourrait peser en toi.", effects: ["HEAL_LIFE:3", "ADD_REPUTATION:druides:6"] },
      { verb: "accepter", text: "Tu deposes ta main sur le plateau vide, offrant ton poids a la mesure.", effects: ["ADD_REPUTATION:ankou:10", "DAMAGE_LIFE:4"] }
    ]
  },
  // C14-05 — niamh — esprit / bluff / perception
  {
    narrative: "Une femme vetue de blanc se tient au bord d'un etang noir, lavant des vetements invisibles. Elle chante un air doux qui contraste avec le froid du lieu. Ses bras sont translucides jusqu'aux coudes.",
    options: [
      { verb: "ecouter", text: "Tu t'assieds a distance et laisses le chant te traverser.", effects: ["HEAL_LIFE:5", "ADD_REPUTATION:niamh:7"] },
      { verb: "parler", text: "Tu lui demandes pour qui elle lave ce soir.", effects: ["ADD_ANAM:5", "ADD_REPUTATION:ankou:6"] },
      { verb: "convaincre", text: "Tu lui proposes de l'aider en echange d'un passage sur.", effects: ["ADD_BIOME_CURRENCY:5", "ADD_REPUTATION:korrigans:5"] }
    ]
  },
  // C14-06 — anciens — logique / observation / finesse
  {
    narrative: "Un cairn marque le milieu exact du marais. Chaque pierre a ete posee par quelqu'un qui a traverse le passage entre la vie et la mort. Les plus anciennes portent des noms graves en ogham. La tienne manque.",
    options: [
      { verb: "dechiffrer", text: "Tu lis les noms oghamiques, apprenant qui est passe avant toi.", effects: ["ADD_ANAM:7", "ADD_REPUTATION:anciens:8"] },
      { verb: "analyser", text: "Tu etudies l'architecture du cairn pour estimer son anciennete.", effects: ["ADD_REPUTATION:anciens:6", "ADD_BIOME_CURRENCY:4"] },
      { verb: "accepter", text: "Tu graves ton nom sur une pierre et la poses au sommet du cairn.", effects: ["ADD_REPUTATION:ankou:8", "HEAL_LIFE:3"] }
    ]
  },
  // C14-07 — ankou — finesse / chance / vigueur
  {
    narrative: "Un pont de corde enjambe une tourbiere profonde. A mi-chemin, les cordes commencent a se defaire fibre par fibre. De l'autre cote, une lumiere chaude promet abri et repos. En dessous, le noir absolu du marecage.",
    options: [
      { verb: "traverser", text: "Tu acceleres, courant pour atteindre l'autre rive avant la rupture.", effects: ["ADD_REPUTATION:ankou:7", "DAMAGE_LIFE:4"] },
      { verb: "tenter sa chance", text: "Tu testes chaque section avant de poser le pied, methodique.", effects: ["ADD_BIOME_CURRENCY:6", "HEAL_LIFE:3"] },
      { verb: "escalader", text: "Tu contournes par les berges, cherchant un autre passage.", effects: ["ADD_REPUTATION:anciens:5", "DAMAGE_LIFE:2"] }
    ]
  },
  // C14-08 — korrigans — bluff / finesse / chance
  {
    narrative: "Un korrigan masque te propose un marche etrange : une carte du marais garantie fausse si payee au prix plein, vraie si marchandee. Son sourire cache quelque chose de deliberement paradoxal.",
    options: [
      { verb: "marchander", text: "Tu joues le jeu et proposes la moitie du prix avec aplomb.", effects: ["ADD_REPUTATION:korrigans:8", "ADD_BIOME_CURRENCY:4"] },
      { verb: "esquiver", text: "Tu fais semblant de partir, esperant qu'il te rappelle.", effects: ["ADD_ANAM:4", "ADD_REPUTATION:korrigans:6"] },
      { verb: "se faufiler", text: "Tu memorises la carte d'un coup d'oeil rapide sans l'acheter.", effects: ["ADD_BIOME_CURRENCY:5", "ADD_REPUTATION:niamh:4"] }
    ]
  },
  // C14-09 — ankou — esprit / logique / bluff
  {
    narrative: "L'Ankou t'adresse la parole — une voix sans corps, venue de la tourbe elle-meme. 'Tu traverses mon domaine. Donne-moi une raison de ne pas te compter parmi les miens ce soir.' Il attend, patient comme la mort.",
    options: [
      { verb: "parler", text: "Tu reponds avec honnetete — ta quete, tes raisons, ta vie.", effects: ["ADD_REPUTATION:ankou:9", "HEAL_LIFE:4"] },
      { verb: "dechiffrer", text: "Tu cherches dans la question elle-meme un indice sur la bonne reponse.", effects: ["ADD_ANAM:6", "ADD_REPUTATION:anciens:5"] },
      { verb: "resister mentalement", text: "Tu refuses de te justifier — personne ne doit de compte a la mort.", effects: ["ADD_REPUTATION:ankou:8", "DAMAGE_LIFE:3"] }
    ]
  },
  // C14-10 — niamh — perception / esprit / observation
  {
    narrative: "Des fleurs de nenuphar blanc s'ouvrent a minuit sur un etang immobile. Chacune projette un rayon de lumiere qui dessine un visage dans l'eau — des visages de disparus que tu as connus.",
    options: [
      { verb: "se concentrer", text: "Tu fixes le visage le plus familier dans l'eau, cherchant un message.", effects: ["ADD_REPUTATION:niamh:8", "ADD_ANAM:5"] },
      { verb: "scruter", text: "Tu etudies tous les visages pour comprendre leur schema commun.", effects: ["ADD_REPUTATION:anciens:6", "HEAL_LIFE:3"] },
      { verb: "apaiser", text: "Tu murmures un adieu a chaque visage et regardes les fleurs se fermer.", effects: ["HEAL_LIFE:5", "ADD_REPUTATION:ankou:6"] }
    ]
  },
  // C14-11 — ankou — vigueur / chance / finesse
  {
    narrative: "Un squelette de cheval emerge a demi de la tourbe, immobile depuis des siecles. Autour de son cou pend une clochette de bronze sans trace de rouille. Les korrigans evitent cet endroit meme en plein jour.",
    options: [
      { verb: "cueillir", text: "Tu retires la clochette du cou de l'ossature avec precaution.", effects: ["ADD_BIOME_CURRENCY:8", "DAMAGE_LIFE:4"] },
      { verb: "examiner", text: "Tu etudies les gravures sur la clochette sans la toucher.", effects: ["ADD_ANAM:5", "ADD_REPUTATION:ankou:7"] },
      { verb: "apaiser", text: "Tu deposes des herbes sechees pres du crane du cheval en silence.", effects: ["HEAL_LIFE:4", "ADD_REPUTATION:druides:5"] }
    ]
  },
  // C14-12 — korrigans — perception / finesse / chance
  {
    narrative: "Des korrigans ont construit un labyrinthe de roseaux tresses au bord du marais. A son centre scintille quelque chose de precieux. Ils parient entre eux sur le temps que tu mettras a te perdre.",
    options: [
      { verb: "pister", text: "Tu traces les motifs du labyrinthe depuis l'exterieur avant d'entrer.", effects: ["ADD_REPUTATION:korrigans:7", "ADD_BIOME_CURRENCY:5"] },
      { verb: "se faufiler", text: "Tu suis instinctivement la direction de la lumiere interieure.", effects: ["ADD_BIOME_CURRENCY:7", "DAMAGE_LIFE:2"] },
      { verb: "resoudre", text: "Tu appliques la regle de la main droite pour cartographier le parcours.", effects: ["ADD_ANAM:5", "ADD_REPUTATION:anciens:5"] }
    ]
  },
  // C14-13 — ankou — observation / logique / esprit
  {
    narrative: "Un miroir brise en sept morceaux est dispose en cercle dans une clairiere. Chaque fragment reflete un moment different — passe, present et futur melanges. L'un d'eux montre un instant qui n'a pas encore eu lieu.",
    options: [
      { verb: "observer", text: "Tu examines chaque fragment sans les toucher, cataloguant les scenes.", effects: ["ADD_ANAM:7", "ADD_REPUTATION:ankou:7"] },
      { verb: "interpreter", text: "Tu cherches le fil narratif qui relie tous les fragments entre eux.", effects: ["ADD_REPUTATION:druides:6", "ADD_BIOME_CURRENCY:4"] },
      { verb: "refuser", text: "Tu te detournes — certains futurs ne doivent pas etre connus.", effects: ["HEAL_LIFE:5", "ADD_REPUTATION:anciens:6"] }
    ]
  },
  // C14-14 — anciens — vigueur / bluff / observation
  {
    narrative: "Des ossements anciens affleurent de la tourbe apres les pluies recentes. Un creux en forme de silhouette indique qu'un corps a ete retire tres recemment. Les traces autour sont fraiches de quelques heures.",
    options: [
      { verb: "pister", text: "Tu suis les traces pour comprendre qui est venu ici.", effects: ["ADD_REPUTATION:anciens:8", "ADD_ANAM:4"] },
      { verb: "proteger", text: "Tu recouvres soigneusement les ossements de tourbe fraiche.", effects: ["HEAL_LIFE:4", "ADD_REPUTATION:druides:5"] },
      { verb: "endurer", text: "Tu restes immobile un long moment, rendant hommage au lieu.", effects: ["ADD_REPUTATION:ankou:7", "HEAL_LIFE:3"] }
    ]
  },
  // C14-15 — ankou — chance / finesse / vigueur
  {
    narrative: "La brume se solidifie autour de toi en une cage de vapeur froide. Elle n'est pas hostile — juste presente. L'Ankou teste ta reaction face a ce qui ne peut etre combattu, seulement endure ou accepte.",
    options: [
      { verb: "accepter", text: "Tu te detends et laisses la cage de brume exister autour de toi.", effects: ["ADD_REPUTATION:ankou:9", "HEAL_LIFE:4"] },
      { verb: "tenter sa chance", text: "Tu marches en avant, ignorant la brume, esperant la traverser.", effects: ["ADD_BIOME_CURRENCY:5", "DAMAGE_LIFE:2"] },
      { verb: "escalader", text: "Tu tentes de depasser la brume en montant sur un rondin flottant.", effects: ["ADD_ANAM:4", "ADD_REPUTATION:korrigans:5"] }
    ]
  },
  // C14-16 — korrigans — logique / perception / chance
  {
    narrative: "Un korrigan solitaire pose des pierres sur un muret imaginaire au milieu de l'eau. Les pierres flottent. Il s'arrete et te regarde : 'Je cherche un assistant. La qualite requise : voir ce que les autres ne voient pas.'",
    options: [
      { verb: "deviner", text: "Tu tentes de comprendre le schema dans les pierres flottantes.", effects: ["ADD_REPUTATION:korrigans:7", "ADD_ANAM:4"] },
      { verb: "observer", text: "Tu regardes en silence, laissant le motif se reveler de lui-meme.", effects: ["ADD_REPUTATION:niamh:5", "ADD_BIOME_CURRENCY:4"] },
      { verb: "resoudre", text: "Tu poses ta propre pierre a l'emplacement logique suivant.", effects: ["ADD_REPUTATION:anciens:6", "ADD_ANAM:5"] }
    ]
  },
  // C14-17 — ankou — bluff / esprit / finesse
  {
    narrative: "Le voile entre les mondes est si mince ici que tu vois les morts a leurs occupations quotidiennes, superimposees sur le marais. L'un d'eux — un paysan d'un autre siecle — te voit aussi et semble surpris.",
    options: [
      { verb: "parler", text: "Tu l'interpelles doucement dans la langue ancienne.", effects: ["ADD_REPUTATION:ankou:8", "ADD_ANAM:5"] },
      { verb: "convaincre", text: "Tu lui expliques avec calme que tu es vivant et que ce monde lui appartient.", effects: ["ADD_REPUTATION:anciens:7", "HEAL_LIFE:3"] },
      { verb: "charmer", text: "Tu lui souris et continues ton chemin, normalisant la rencontre.", effects: ["ADD_BIOME_CURRENCY:5", "ADD_REPUTATION:korrigans:5"] }
    ]
  },
  // C14-18 — niamh — esprit / observation / bluff
  {
    narrative: "Une source d'eau chaude jaillit de la tourbe, formant une vasque naturelle. La vapeur dessine des silhouettes — un enfant qui joue, une vieille femme qui tisse, un homme qui marche. Les sources chaudes sont associees aux passages de Niamh.",
    options: [
      { verb: "se concentrer", text: "Tu fixes les formes de vapeur, cherchant un message pour toi.", effects: ["ADD_REPUTATION:niamh:8", "ADD_ANAM:4"] },
      { verb: "examiner", text: "Tu testes la temperature de l'eau du bout des doigts.", effects: ["HEAL_LIFE:5", "ADD_REPUTATION:anciens:5"] },
      { verb: "scruter", text: "Tu cherches la source geologique de la chaleur sous la surface.", effects: ["ADD_BIOME_CURRENCY:5", "ADD_REPUTATION:druides:4"] }
    ]
  },
  // C14-19 — ankou — perception / vigueur / chance
  {
    narrative: "Une croix de bois noir marque le point ou trois personnes sont enterrees au meme endroit, a trois epoques differentes. Le sol vibre doucement sous tes pieds. Les trois presences ne sont pas hostiles — elles sont curieuses.",
    options: [
      { verb: "pister", text: "Tu examines les strates de la terre pour dater les sepultures.", effects: ["ADD_ANAM:5", "ADD_REPUTATION:ankou:7"] },
      { verb: "apaiser", text: "Tu allumes un petit feu et chantes pour les trois presences.", effects: ["HEAL_LIFE:5", "ADD_REPUTATION:ankou:6"] },
      { verb: "courir", text: "Tu traverses le lieu en courant, portant leur curiosite avec toi.", effects: ["ADD_BIOME_CURRENCY:6", "DAMAGE_LIFE:3"] }
    ]
  },
  // C14-20 — anciens — observation / logique / esprit
  {
    narrative: "Au centre du marais, une butte de tourbe porte les cendres d'un tres ancien feu de joie. Elles forment encore un cercle parfait. Un baton de bois vert — coupe aujourd'hui — repose au milieu des cendres.",
    options: [
      { verb: "etudier", text: "Tu analyses les cendres et le baton pour comprendre le rituel.", effects: ["ADD_REPUTATION:anciens:9", "ADD_ANAM:5"] },
      { verb: "interpreter", text: "Tu deduis de l'alignement des cendres quand et pourquoi ce feu a brule.", effects: ["ADD_REPUTATION:druides:6", "ADD_BIOME_CURRENCY:4"] },
      { verb: "accepter", text: "Tu allumes le baton vert et le poses dans les cendres pour continuer le rituel.", effects: ["ADD_REPUTATION:ankou:8", "HEAL_LIFE:4"] }
    ]
  }
];

console.log('New cards count:', newCards.length);

// Count faction distribution
const factionCount = {};
newCards.forEach(card => {
  card.options.forEach(opt => {
    opt.effects.forEach(e => {
      const m = e.match(/ADD_REPUTATION:([a-z]+):(\d+)/);
      if (m && parseInt(m[2]) > 0) factionCount[m[1]] = (factionCount[m[1]] || 0) + 1;
    });
  });
});
console.log('Faction distribution (positive rep options):', factionCount);

// Validate effect caps
let issues = 0;
newCards.forEach((card, i) => {
  card.options.forEach((opt, j) => {
    opt.effects.forEach(e => {
      const healM = e.match(/HEAL_LIFE:(\d+)/);
      if (healM && parseInt(healM[1]) > 5) { console.warn('Card', i+1, 'opt', j+1, 'heal>5:', e); issues++; }
      const dmgM = e.match(/DAMAGE_LIFE:(\d+)/);
      if (dmgM && parseInt(dmgM[1]) > 5) { console.warn('Card', i+1, 'opt', j+1, 'dmg>5:', e); issues++; }
      const repM = e.match(/ADD_REPUTATION:[a-z]+:(\d+)/);
      if (repM && parseInt(repM[1]) > 10) { console.warn('Card', i+1, 'opt', j+1, 'rep>10:', e); issues++; }
    });
    // Check no 3+ negative effects per option
    const negCount = opt.effects.filter(e => e.match(/DAMAGE_LIFE|ADD_REPUTATION:[a-z]+:-/)).length;
    if (negCount >= 3) { console.warn('Card', i+1, 'opt', j+1, 'has 3+ negative effects'); issues++; }
  });
});
if (issues === 0) console.log('Validation OK: all effects within caps, no option has 3+ negatives');

// Append to cards.json
const existing = JSON.parse(fs.readFileSync(CARDS_PATH, 'utf8'));
const merged = [...existing, ...newCards];
fs.writeFileSync(CARDS_PATH, JSON.stringify(merged, null, 2), 'utf8');
const stat = fs.statSync(CARDS_PATH);
console.log('cards.json updated:', merged.length, 'total templates,', Math.round(stat.size / 1024), 'KB');
