// gen_cercles_batch2.js — Cycle 19 narrative-designer agent
// Appends 20 cercles_pierres batch2 cards to public/data/cards.json
// Constraints: korrigans 6/20, anciens 5/20, HEAL_LIFE<=5, REP<=20, DAMAGE<=15

const fs = require('fs');
const CARDS_PATH = 'C:/Users/PGNK2128/Godot-MCP/web-demo/public/data/cards.json';

const newCards = [
  {
    narrative: "Un alignement de menhirs s'etend devant toi, vingt-deux pierres dressees selon un angle que les etoiles seules pourraient expliquer. Au centre, une flamme bleue brule sans combustible visible.",
    biome: "cercles_pierres",
    options: [
      { verb: "approcher", text: "Tu avances vers la flamme en suivant l'axe des pierres, respectant la geometrie du lieu.", effects: ["ADD_REPUTATION:anciens:14", "ADD_ANAM:3"] },
      { verb: "contourner", text: "Tu longes l'alignement sans le traverser, observant chaque menhir depuis la peripherie.", effects: ["ADD_REPUTATION:korrigans:10", "ADD_BIOME_CURRENCY:4"] },
      { verb: "toucher", text: "Tu poses la main sur la premiere pierre et laisses le reseau de l'alignement te traverser.", effects: ["ADD_REPUTATION:anciens:8", "HEAL_LIFE:4", "DAMAGE_LIFE:3"] }
    ]
  },
  {
    narrative: "Un korrigan assis sur un dolmen te fixe sans sourciller. Il tient dans sa main gauche une pierre runique et dans sa droite une pomme rouge dont il ne mange pas.",
    biome: "cercles_pierres",
    options: [
      { verb: "negocier", text: "Tu lui proposes un echange — ta connaissance d'un chemin contre la pierre runique.", effects: ["ADD_REPUTATION:korrigans:16", "ADD_BIOME_CURRENCY:5"] },
      { verb: "attendre", text: "Tu t'installes face a lui sans parler, dans une patience qui respecte le sien.", effects: ["ADD_REPUTATION:anciens:12", "ADD_ANAM:2"] },
      { verb: "passer", text: "Tu le salues d'un geste bref et continues ton chemin sans t'arreter.", effects: ["ADD_REPUTATION:ankou:9", "HEAL_LIFE:3"] }
    ]
  },
  {
    narrative: "Le solstice approche. Les ombres des pierres se raccourcissent jusqu'a disparaitre exactement au zenith. Un druide en robe blanche attend ce moment, les bras leves.",
    biome: "cercles_pierres",
    options: [
      { verb: "assister", text: "Tu te places a distance respectueuse et observes le rituel solsticial dans le silence requis.", effects: ["ADD_REPUTATION:druides:14", "ADD_REPUTATION:anciens:8"] },
      { verb: "participer", text: "Le druide t'invite d'un geste. Tu te joins au rituel, portant l'intention collective.", effects: ["ADD_REPUTATION:druides:12", "HEAL_LIFE:5", "ADD_ANAM:2"] },
      { verb: "noter", text: "Tu traces sur une tablette d'argile la position exacte des ombres au zenith.", effects: ["ADD_REPUTATION:anciens:15", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    narrative: "Entre deux pierres levees, un portail d'air dense scintille. Des korrigans dansent autour en chantant une melodie sans paroles, les mains jointes.",
    biome: "cercles_pierres",
    options: [
      { verb: "ecouter", text: "Tu t'assieds et laisses la melodie korrigane penetrer en toi sans chercher a la saisir.", effects: ["ADD_REPUTATION:korrigans:18", "ADD_ANAM:3"] },
      { verb: "traverser", text: "Tu franchis le portail d'un pas decide, acceptant ce que l'autre cote peut offrir.", effects: ["ADD_REPUTATION:niamh:14", "DAMAGE_LIFE:5", "ADD_ANAM:4"] },
      { verb: "chanter", text: "Tu reprends la melodie a ta facon, ajoutant ta voix au choeur des korrigans.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:niamh:8"] }
    ]
  },
  {
    narrative: "Une pierre tombee depuis des siecles git au sol, couverte de lichens orange. Des gravures celtiques y sont encore lisibles — un calendrier lunaire de trente-sept lunes.",
    biome: "cercles_pierres",
    options: [
      { verb: "dechiffrer", text: "Tu passes une heure a recopier chaque symbole, restituant le calendrier dans sa sequence.", effects: ["ADD_REPUTATION:anciens:16", "ADD_BIOME_CURRENCY:4"] },
      { verb: "relever", text: "Tu fais un frottage de la pierre avec du tissu sombre, preservant le motif exact.", effects: ["ADD_REPUTATION:anciens:12", "ADD_ANAM:2"] },
      { verb: "mediter", text: "Tu poses le front contre la pierre et laisses les trente-sept lunes te traverser.", effects: ["ADD_REPUTATION:korrigans:10", "HEAL_LIFE:4"] }
    ]
  },
  {
    narrative: "Trois enfants jouent a cache-cache entre les menhirs en criant des noms anciens — des noms de pierres, ou peut-etre de dieux oublies que seul ce lieu conserve.",
    biome: "cercles_pierres",
    options: [
      { verb: "jouer", text: "Tu te glisses entre les pierres et participes au jeu, appelant toi-meme les noms entendus.", effects: ["ADD_REPUTATION:korrigans:14", "ADD_REPUTATION:niamh:8", "HEAL_LIFE:3"] },
      { verb: "questionner", text: "Tu demandes aux enfants l'origine de ces noms avec une curiosite respectueuse.", effects: ["ADD_REPUTATION:anciens:13", "ADD_ANAM:2"] },
      { verb: "garder", text: "Tu surveilles les abords du cercle pendant leur jeu, assurant leur securite silencieuse.", effects: ["ADD_REPUTATION:ankou:11", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    narrative: "Un arc-en-ciel nocturne s'arc-boute d'une pierre a l'autre, formant un demi-cercle lumineux dans le ciel sans nuages. La lune en est l'unique source.",
    biome: "cercles_pierres",
    options: [
      { verb: "contempler", text: "Tu restes sous l'arc et leves les yeux jusqu'a ce que le phenomene s'efface naturellement.", effects: ["ADD_REPUTATION:niamh:16", "HEAL_LIFE:5", "ADD_ANAM:2"] },
      { verb: "localiser", text: "Tu tentes de determiner quelle propriete des pierres cree cet effet avec la lumiere lunaire.", effects: ["ADD_REPUTATION:anciens:14", "ADD_BIOME_CURRENCY:3"] },
      { verb: "marcher", text: "Tu traverses l'arc d'une extremite a l'autre, lentement, sans te presser.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:niamh:6"] }
    ]
  },
  {
    narrative: "Un serpent de pierre s'enroule autour du menhir central du cercle. Sa gueule ouverte pointe vers le nord magnetique exact, comme une boussole taillee dans le granit.",
    biome: "cercles_pierres",
    options: [
      { verb: "offrir", text: "Tu deposes une herbe aromatique dans la gueule du serpent, selon une intuition ancienne.", effects: ["ADD_REPUTATION:anciens:15", "ADD_ANAM:3"] },
      { verb: "mesurer", text: "Tu traces la direction exacte indiquee par la gueule et la notes avec soin.", effects: ["ADD_REPUTATION:anciens:12", "ADD_BIOME_CURRENCY:4"] },
      { verb: "encercler", text: "Tu fais le tour du menhir dans le sens inverse des aiguilles, respectant le symbole serpentin.", effects: ["ADD_REPUTATION:korrigans:13", "HEAL_LIFE:3"] }
    ]
  },
  {
    narrative: "Un orage eclate brutalement sur le cercle de pierres, mais la foudre frappe uniquement les menhirs les plus hauts — jamais le sol entre eux.",
    biome: "cercles_pierres",
    options: [
      { verb: "abriter", text: "Tu te places au centre du cercle, protege par la geometrie des paratonnerres naturels.", effects: ["ADD_REPUTATION:anciens:11", "HEAL_LIFE:4"] },
      { verb: "compter", text: "Tu comptes les eclairs sur chaque pierre, cherchant un pattern dans la sequence.", effects: ["ADD_REPUTATION:anciens:13", "ADD_BIOME_CURRENCY:3", "DAMAGE_LIFE:3"] },
      { verb: "resister", text: "Tu restes debout sous l'orage, bras ouverts, accueillant la force electrique du moment.", effects: ["ADD_REPUTATION:ankou:14", "DAMAGE_LIFE:6", "ADD_ANAM:4"] }
    ]
  },
  {
    narrative: "Une femme ancienne grave a la pointe une nouvelle rune dans un menhir. Chaque coup de burin produit un son different — pas le meme metal, pas la meme pierre, chaque fois.",
    biome: "cercles_pierres",
    options: [
      { verb: "observer", text: "Tu t'assieds a distance et regardes travailler la graveuse, memorisant sa technique.", effects: ["ADD_REPUTATION:anciens:16", "ADD_ANAM:2"] },
      { verb: "aider", text: "Tu lui tiens l'outil de reserve et nettoies les eclats de pierre au fur et a mesure.", effects: ["ADD_REPUTATION:anciens:12", "ADD_REPUTATION:korrigans:8", "HEAL_LIFE:3"] },
      { verb: "questionner", text: "Tu lui demandes ce que chaque son different signifie pour elle.", effects: ["ADD_REPUTATION:anciens:14", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    narrative: "Le cercle de pierres est partiellement englouti dans la tourbe. Deux menhirs ont disparu sous la surface, leurs sommets affleurant a peine. On devine leur presence plus qu'on ne les voit.",
    biome: "cercles_pierres",
    options: [
      { verb: "fouiller", text: "Tu degages prudemment la tourbe autour du premier sommet visible, revelant la pierre.", effects: ["ADD_REPUTATION:korrigans:15", "ADD_BIOME_CURRENCY:5", "DAMAGE_LIFE:3"] },
      { verb: "mesurer", text: "Tu reconstitues la geometrie du cercle original en projetant les positions manquantes.", effects: ["ADD_REPUTATION:anciens:14", "ADD_ANAM:2"] },
      { verb: "honorer", text: "Tu honores les pierres cachees par un rituel au-dessus de la tourbe, sans les decouvrir.", effects: ["ADD_REPUTATION:anciens:12", "ADD_REPUTATION:niamh:8"] }
    ]
  },
  {
    narrative: "Au lever du soleil d'equinoxe, un rayon traverse exactement deux fentes dans les pierres et eclaire une cavite au sol — un cache ancien rempli de graines calcifiees.",
    biome: "cercles_pierres",
    options: [
      { verb: "prélever", text: "Tu preleves une graine et un eclat du bol, temoins de ce rituel oublie.", effects: ["ADD_REPUTATION:anciens:13", "ADD_ANAM:3", "DAMAGE_LIFE:2"] },
      { verb: "recouvrir", text: "Tu refermes la cavite exactement comme tu l'as trouvee, preservant son secret.", effects: ["ADD_REPUTATION:druides:12", "ADD_REPUTATION:anciens:10"] },
      { verb: "documenter", text: "Tu dessines la position exacte de la cache et la geometrie des fentes qui l'eclairent.", effects: ["ADD_REPUTATION:anciens:16", "ADD_BIOME_CURRENCY:4"] }
    ]
  },
  {
    narrative: "Un renard blanc s'assied au pied du menhir le plus ancien et commence a gratter la terre avec une methodique lenteur. Il semble chercher quelque chose de precis.",
    biome: "cercles_pierres",
    options: [
      { verb: "suivre", text: "Tu observes ce qu'il decouvre, pret a intervenir si une aide humaine devient necessaire.", effects: ["ADD_REPUTATION:niamh:14", "ADD_ANAM:3"] },
      { verb: "aider", text: "Tu t'agenoilles a ses cotes et creuses doucement de l'autre cote du menhir.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:niamh:8", "HEAL_LIFE:3"] },
      { verb: "attendre", text: "Tu restes a distance et laisses le renard agir selon sa propre logique, sans intervenir.", effects: ["ADD_REPUTATION:ankou:11", "ADD_BIOME_CURRENCY:3"] }
    ]
  },
  {
    narrative: "Des korrigans ont construit une maquette du cercle de pierres en miniature — chaque pierre representee par un caillou peint. Ils debattent de la position correcte d'un element manquant.",
    biome: "cercles_pierres",
    options: [
      { verb: "arbitrer", text: "Tu ecoutes les arguments de chaque korrigan et proposes une position mediee.", effects: ["ADD_REPUTATION:korrigans:16", "ADD_BIOME_CURRENCY:4"] },
      { verb: "consulter", text: "Tu verifies la position sur le vrai cercle et rapportes les mesures exactes.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:anciens:10"] },
      { verb: "construire", text: "Tu ajoutes toi-meme l'element manquant selon ta propre interpretation du cercle.", effects: ["ADD_REPUTATION:korrigans:14", "ADD_ANAM:3", "DAMAGE_LIFE:2"] }
    ]
  },
  {
    narrative: "La neige tombe en spirale autour du cercle, comme repoussee par une force centrifuge invisible. Le centre reste parfaitement sec et un degre plus chaud que les alentours.",
    biome: "cercles_pierres",
    options: [
      { verb: "rester", text: "Tu t'installes au centre chaud du cercle et laisses la spirale de neige tourner autour de toi.", effects: ["ADD_REPUTATION:anciens:13", "HEAL_LIFE:5"] },
      { verb: "traverser", text: "Tu marches deliberement dans la spirale, te laissant couvrir de neige avant de revenir au centre.", effects: ["ADD_REPUTATION:ankou:12", "DAMAGE_LIFE:3", "ADD_ANAM:3"] },
      { verb: "tester", text: "Tu mesures la frontiere exacte entre froid et chaud, pierre par pierre.", effects: ["ADD_REPUTATION:anciens:14", "ADD_BIOME_CURRENCY:4"] }
    ]
  },
  {
    narrative: "Une inscription en ogham court le long d'un menhir de gauche a droite — sens inverse de la convention. Un vieux sage assis en face la relit depuis l'aube sans broncher.",
    biome: "cercles_pierres",
    options: [
      { verb: "lire", text: "Tu dechiffres l'inscription a rebours et partages ta traduction avec le sage.", effects: ["ADD_REPUTATION:anciens:15", "ADD_REPUTATION:druides:8", "ADD_ANAM:2"] },
      { verb: "questionner", text: "Tu demandes au sage ce qu'il voit dans le texte que les autres ne voient pas.", effects: ["ADD_REPUTATION:anciens:16", "ADD_BIOME_CURRENCY:3"] },
      { verb: "copier", text: "Tu transcris l'inscription exactement, en preservant le sens inverse, sans interpreter.", effects: ["ADD_REPUTATION:anciens:12", "ADD_ANAM:3"] }
    ]
  },
  {
    narrative: "Un feu de camp brule entre les pierres. Autour, sept silhouettes encapuchonnees gardent le silence. Une chaise vide leur fait face — la huitieme place du cercle.",
    biome: "cercles_pierres",
    options: [
      { verb: "accepter", text: "Tu prends la chaise vide et t'installes dans le cercle, adoptant leur silence.", effects: ["ADD_REPUTATION:druides:14", "ADD_REPUTATION:anciens:10", "HEAL_LIFE:4"] },
      { verb: "refuser", text: "Tu salues les silhouettes et continues ton chemin, respectant leur cercle ferme.", effects: ["ADD_REPUTATION:ankou:12", "ADD_BIOME_CURRENCY:3"] },
      { verb: "observer", text: "Tu restes a l'ecart et regardes jusqu'a ce que le cercle se dissolve de lui-meme.", effects: ["ADD_REPUTATION:korrigans:11", "ADD_ANAM:2"] }
    ]
  },
  {
    narrative: "Des traces de pattes — trop grandes pour un renard, trop petites pour un loup — forment un cercle parfait dans la boue fraiche autour d'un menhir isole.",
    biome: "cercles_pierres",
    options: [
      { verb: "suivre", text: "Tu suis les traces en sens inverse pour trouver leur point de depart.", effects: ["ADD_REPUTATION:korrigans:15", "ADD_ANAM:3"] },
      { verb: "relever", text: "Tu traces chaque empreinte sur une feuille de bouleau avant que la pluie ne les efface.", effects: ["ADD_REPUTATION:anciens:13", "ADD_BIOME_CURRENCY:4"] },
      { verb: "reproduire", text: "Tu marches dans les traces en sens horaire, mimant le parcours de la creature.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:niamh:8", "DAMAGE_LIFE:2"] }
    ]
  },
  {
    narrative: "Le brouillard matinal se leve sur le cercle et revele une toile d'araignee gigantesque tissee entre les menhirs, couverte de rosee — un filet de lumiere qui retient le soleil levant.",
    biome: "cercles_pierres",
    options: [
      { verb: "preserver", text: "Tu contournes le cercle en faisant attention a ne pas rompre un seul fil de la toile.", effects: ["ADD_REPUTATION:niamh:14", "ADD_ANAM:3", "HEAL_LIFE:3"] },
      { verb: "traverser", text: "Tu traverses doucement la toile, sachant qu'elle se reformera d'ici le lendemain.", effects: ["ADD_REPUTATION:korrigans:13", "ADD_BIOME_CURRENCY:3"] },
      { verb: "contempler", text: "Tu restes immobile devant la toile jusqu'a ce que le soleil ait fini de traverser ses fils.", effects: ["ADD_REPUTATION:anciens:12", "ADD_REPUTATION:niamh:10"] }
    ]
  },
  {
    narrative: "Deux menhirs se font face a exactement sept metres, formes d'une meme roche bien qu'ils soient a cent lieues de toute carriere connue. Entre eux, l'air vibre sans cause apparente.",
    biome: "cercles_pierres",
    options: [
      { verb: "resonner", text: "Tu chantes entre les deux pierres, testant les harmoniques que leur ecart produit.", effects: ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:korrigans:8", "ADD_ANAM:3"] },
      { verb: "mesurer", text: "Tu verifies la distance et l'orientation avec precision, a la recherche d'une logique cachee.", effects: ["ADD_REPUTATION:anciens:16", "ADD_BIOME_CURRENCY:4"] },
      { verb: "franchir", text: "Tu passes entre les deux pierres lentement, sentant la vibration monter puis retomber.", effects: ["ADD_REPUTATION:niamh:12", "HEAL_LIFE:4", "DAMAGE_LIFE:2"] }
    ]
  }
];

// --- Constraint validation ---
let valid = true;
const factionCounts = {};
newCards.forEach((card, i) => {
  card.options.forEach(opt => {
    // Check 3 effects max
    if (opt.effects.length > 3) {
      console.error(`Card ${i} option '${opt.verb}': too many effects (${opt.effects.length})`);
      valid = false;
    }
    opt.effects.forEach(eff => {
      const healMatch = eff.match(/^HEAL_LIFE:(\d+)$/);
      if (healMatch && parseInt(healMatch[1]) > 5) {
        console.error(`HEAL cap violation card ${i} '${opt.verb}': ${eff}`);
        valid = false;
      }
      const dmgMatch = eff.match(/^DAMAGE_LIFE:(\d+)$/);
      if (dmgMatch && parseInt(dmgMatch[1]) > 15) {
        console.error(`DAMAGE cap violation card ${i}: ${eff}`);
        valid = false;
      }
      const repMatch = eff.match(/^ADD_REPUTATION:([^:]+):(\d+)$/);
      if (repMatch) {
        if (parseInt(repMatch[2]) > 20) {
          console.error(`REP cap violation card ${i}: ${eff}`);
          valid = false;
        }
        factionCounts[repMatch[1]] = (factionCounts[repMatch[1]] || 0) + 1;
      }
    });
  });
});

console.log('Constraint validation:', valid ? 'PASS' : 'FAIL');
console.log('Faction option counts:', JSON.stringify(factionCounts));
console.log('New cards:', newCards.length);

if (!valid) {
  console.error('Aborting due to constraint violations.');
  process.exit(1);
}

const cards = JSON.parse(fs.readFileSync(CARDS_PATH, 'utf8'));
cards.push(...newCards);
fs.writeFileSync(CARDS_PATH, JSON.stringify(cards, null, 2));
console.log('Total cards after append:', cards.length);
