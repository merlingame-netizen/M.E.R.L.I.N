// Cycle 20 — append 20 villages_celtes batch2 cards to cards.json
const fs = require('fs');
const path = 'C:/Users/PGNK2128/Godot-MCP/web-demo/public/data/cards.json';
const cards = JSON.parse(fs.readFileSync(path, 'utf8'));

const batch2 = [
  {
    narrative: "Au centre du village, le puits ancien est cercle de pierres gravees de signes que personne ne sait plus lire. Ce soir, quelqu'un y a depose une couronne de ronces fleuries.",
    biome: "villages_celtes",
    options: [
      { verb: "dechiffrer", text: "Tu traces les signes dans la terre, cherchant leur signification parmi les oghams que tu connais.", effects: ["ADD_REPUTATION:anciens:16", "ADD_REPUTATION:druides:8"] },
      { verb: "offrir", text: "Tu ajoutes une pierre a la margelle du puits en murmurant une priere aux esprits de l'eau.", effects: ["ADD_REPUTATION:korrigans:14", "HEAL_LIFE:3"] },
      { verb: "veiller", text: "Tu t'installes a proximite pour observer qui viendra au puits a l'aube.", effects: ["ADD_REPUTATION:niamh:12", "ADD_ANAM:2"] }
    ]
  },
  {
    narrative: "La forge du village crache des etincelles d'or dans la nuit. Le forgeron frappe un metal qui n'existe dans aucun filon connu, et chaque coup resonne comme un mot dans une langue oubliee.",
    biome: "villages_celtes",
    options: [
      { verb: "observer", text: "Tu regardes le forgeron travailler sans l'interrompre, memorisant la cadence de ses frappes.", effects: ["ADD_REPUTATION:anciens:14", "ADD_ANAM:3"] },
      { verb: "demander", text: "Tu interroges le forgeron sur l'origine de ce metal lumineux et sa destination.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:druides:6"] },
      { verb: "souffler", text: "Tu actionnes les soufflets pour alimenter la forge, offrant ta force au travail sacre.", effects: ["ADD_REPUTATION:ankou:10", "HEAL_LIFE:4", "DAMAGE_LIFE:3"] }
    ]
  },
  {
    narrative: "Le marche hebdomadaire bat son plein. Parmi les etals de legumes et de tissu, une marchande masquee propose des objets que personne ne peut identifier mais dont chacun sent instinctivement la valeur.",
    biome: "villages_celtes",
    options: [
      { verb: "marchander", text: "Tu engages la conversation avec la marchande, proposant un echange de savoirs contre un de ses objets.", effects: ["ADD_REPUTATION:korrigans:18", "ADD_BIOME_CURRENCY:3"] },
      { verb: "avertir", text: "Tu previens discretement les villageois que ces objets portent peut-etre une influence ancienne.", effects: ["ADD_REPUTATION:druides:14", "ADD_REPUTATION:anciens:8"] },
      { verb: "acheter", text: "Tu acquiers un objet sans poser de questions, lui faisant confiance au feeling.", effects: ["ADD_REPUTATION:niamh:16", "ADD_ANAM:2"] }
    ]
  },
  {
    narrative: "Trois vieilles femmes sont assises devant une chaumiere, filant de la laine d'une couleur indefinissable. Elles parlent en se passant le fil l'une a l'autre sans jamais briser le rythme.",
    biome: "villages_celtes",
    options: [
      { verb: "ecouter", text: "Tu t'assieds a distance respectable et tends l'oreille, captant des bribes de leur recit tisse.", effects: ["ADD_REPUTATION:anciens:16", "ADD_REPUTATION:niamh:10"] },
      { verb: "rejoindre", text: "Tu demandes a te joindre a elles, proposant tes mains pour tenir la laine.", effects: ["ADD_REPUTATION:korrigans:14", "HEAL_LIFE:5"] },
      { verb: "questionner", text: "Tu leur poses une question sur l'avenir, sachant qu'elles savent ce que cachent les fils.", effects: ["ADD_REPUTATION:niamh:18", "DAMAGE_LIFE:2", "ADD_ANAM:4"] }
    ]
  },
  {
    narrative: "Un barde etranger s'est installe sous le grand chene de la place. Sa voix change de timbre a chaque couplet, comme si plusieurs personnes chantaient a travers lui.",
    biome: "villages_celtes",
    options: [
      { verb: "applaudir", text: "Tu exprimes ton admiration ouvertement, encourageant le barde a continuer son recit.", effects: ["ADD_REPUTATION:korrigans:12", "ADD_REPUTATION:niamh:8"] },
      { verb: "defier", text: "Tu proposes un duel de chant, offrant ta propre voix contre la sienne.", effects: ["ADD_REPUTATION:korrigans:16", "DAMAGE_LIFE:4", "ADD_ANAM:3"] },
      { verb: "noter", text: "Tu transcris les paroles du barde dans le sable, preservant ce savoir sonore.", effects: ["ADD_REPUTATION:anciens:14", "ADD_BIOME_CURRENCY:2"] }
    ]
  },
  {
    narrative: "Le conseil des anciens du village se reunit sous les etoiles. Un siege reste vide au centre du cercle — le siege du Parlant, reserve a celui qui vient du dehors avec des nouvelles du monde.",
    biome: "villages_celtes",
    options: [
      { verb: "sieger", text: "Tu prends la place du Parlant et partages ce que tu as vu sur les routes.", effects: ["ADD_REPUTATION:anciens:18", "ADD_REPUTATION:druides:6"] },
      { verb: "rapporter", text: "Tu informes le conseil des mouvements de troupes et des rumeurs entendues aux carrefours.", effects: ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:korrigans:10"] },
      { verb: "decliner", text: "Tu refuses respectueusement, laissant le siege vide — certaines nouvelles ne se disent pas encore.", effects: ["ADD_REPUTATION:niamh:14", "ADD_ANAM:3"] }
    ]
  },
  {
    narrative: "La fete des moissons commence au crepuscule. Les villageois portent des gerbes tressees representant des visages que personne ne nomme, mais que chacun reconnait.",
    biome: "villages_celtes",
    options: [
      { verb: "danser", text: "Tu rejoins la ronde autour du feu de joie, portant une gerbe comme les autres.", effects: ["ADD_REPUTATION:korrigans:16", "HEAL_LIFE:4"] },
      { verb: "benir", text: "Tu prononces les formules anciennes sur les gerbes, invoquant la generosite de la terre.", effects: ["ADD_REPUTATION:druides:12", "ADD_REPUTATION:anciens:10"] },
      { verb: "memoriser", text: "Tu observes les visages dans les gerbes et taches de comprendre qui ils representent.", effects: ["ADD_REPUTATION:niamh:14", "ADD_ANAM:2"] }
    ]
  },
  {
    narrative: "Un enfant du village te montre une pierre plate couverte de motifs en spirale qu'il a trouvee dans son jardin. Il affirme l'avoir entendue sonner comme une cloche la nuit derniere.",
    biome: "villages_celtes",
    options: [
      { verb: "examiner", text: "Tu etudies la pierre avec soin, reconnaissant des motifs lies aux calendriers celtes.", effects: ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:druides:8"] },
      { verb: "frapper", text: "Tu tapotes doucement la pierre pour verifier si elle produit ce son dont parle l'enfant.", effects: ["ADD_REPUTATION:korrigans:16", "ADD_ANAM:2"] },
      { verb: "proteger", text: "Tu conseilles a l'enfant de replacer la pierre exactement ou il l'a trouvee avant la tombee de la nuit.", effects: ["ADD_REPUTATION:niamh:12", "HEAL_LIFE:3"] }
    ]
  },
  {
    narrative: "La maison du guerisseur est marquee d'une croix de sureau sur la porte. A l'interieur, des dizaines de bocaux contiennent des substances dont certaines semblent vivantes, tournant lentement d'elles-memes.",
    biome: "villages_celtes",
    options: [
      { verb: "apprendre", text: "Tu demandes au guerisseur de t'expliquer la composition et l'usage de ses remedes.", effects: ["ADD_REPUTATION:druides:16", "HEAL_LIFE:5"] },
      { verb: "echanger", text: "Tu offres une plante rare de ta reserve contre un remede adapte a ta condition.", effects: ["ADD_REPUTATION:korrigans:14", "HEAL_LIFE:4", "DAMAGE_LIFE:1"] },
      { verb: "confier", text: "Tu decris tes blessures interieures au guerisseur, cherchant un soin que la medecine ordinaire ne peut offrir.", effects: ["ADD_REPUTATION:niamh:16", "ADD_ANAM:3"] }
    ]
  },
  {
    narrative: "A l'entree du village, un poteau sculpte represente une figure mi-humaine, mi-cerf. Des offrandes recentes y sont accrochees : des rubans rouges, des dents d'animaux, une petite flute de roseau.",
    biome: "villages_celtes",
    options: [
      { verb: "saluer", text: "Tu t'inclines devant la figure et prononces les mots d'accueil que tu as appris des druides.", effects: ["ADD_REPUTATION:druides:14", "ADD_REPUTATION:korrigans:8"] },
      { verb: "ajouter", text: "Tu deposes ta propre offrande au pied du poteau, te placant sous sa protection pour la duree de ton sejour.", effects: ["ADD_REPUTATION:korrigans:18", "HEAL_LIFE:3"] },
      { verb: "jouer", text: "Tu prends la flute de roseau et joues une melodie pour honorer l'esprit du lieu.", effects: ["ADD_REPUTATION:niamh:16", "ADD_ANAM:2"] }
    ]
  },
  {
    narrative: "Le druide du village est en meditation depuis trois jours sur le toit de la grande longere. Les villageois deposent des bols de nourriture au pied de l'echelle sans jamais monter.",
    biome: "villages_celtes",
    options: [
      { verb: "monter", text: "Tu grimpes rejoindre le druide, portant toi aussi un bol — pour partager l'espace de sa vision.", effects: ["ADD_REPUTATION:druides:18", "ADD_ANAM:4"] },
      { verb: "attendre", text: "Tu t'installes parmi les villageois et patientes, respectant le temps sacre de la meditation.", effects: ["ADD_REPUTATION:anciens:14", "HEAL_LIFE:4"] },
      { verb: "appeler", text: "Tu prononces doucement le nom du druide, portant une question urgente que les etoiles seules ne peuvent resoudre.", effects: ["ADD_REPUTATION:druides:12", "ADD_REPUTATION:korrigans:10", "DAMAGE_LIFE:2"] }
    ]
  },
  {
    narrative: "Une querelle eclate entre deux familles du village pour un champ de frontiere. Les anciens arbitrent, mais les deux clans attendent que tu tranches, toi l'etranger sans attaches.",
    biome: "villages_celtes",
    options: [
      { verb: "trancher", text: "Tu proposes une solution fondee sur le droit ancien des chemins et l'usage de la terre.", effects: ["ADD_REPUTATION:anciens:16", "ADD_REPUTATION:korrigans:8"] },
      { verb: "medier", text: "Tu proposes une reunion commune ou chaque famille expose ses griefs sans interruption.", effects: ["ADD_REPUTATION:korrigans:14", "ADD_REPUTATION:niamh:10"] },
      { verb: "esquiver", text: "Tu refuses de trancher mais offres a chaque clan un conseil prive pour trouver sa propre voie.", effects: ["ADD_REPUTATION:niamh:18", "ADD_ANAM:2"] }
    ]
  },
  {
    narrative: "La nuit de l'equinoxe, les korrigans du bois voisin entrent dans le village pour y commercer. Ils apportent des champignons lumineux, des fils d'araignee d'argent et des rires qui rendent etrange.",
    biome: "villages_celtes",
    options: [
      { verb: "commercer", text: "Tu t'avances pour acheter un champignon lumineux, sachant que leur lumiere revele ce qui est cache.", effects: ["ADD_REPUTATION:korrigans:20", "ADD_ANAM:3"] },
      { verb: "rire", text: "Tu te meles aux korrigans en riant avec eux, jouant leur jeu sans chercher a comprendre.", effects: ["ADD_REPUTATION:korrigans:16", "HEAL_LIFE:5"] },
      { verb: "garder", text: "Tu observes les echanges depuis un seuil, protegerant discretement un villageois qui semble debousole.", effects: ["ADD_REPUTATION:niamh:14", "ADD_REPUTATION:anciens:8"] }
    ]
  },
  {
    narrative: "Un cheval blanc sans cavalier traverse le village au pas, comme s'il cherchait quelque chose. Les villageois s'ecartent en silence. Le cheval s'arrete devant toi et ne bouge plus.",
    biome: "villages_celtes",
    options: [
      { verb: "approcher", text: "Tu tends la main lentement vers le cheval, accueillant ce que ce signe vient t'annoncer.", effects: ["ADD_REPUTATION:niamh:18", "ADD_ANAM:4"] },
      { verb: "monter", text: "Tu enfourches le cheval blanc, lui faisant confiance pour te mener la ou tu dois aller.", effects: ["ADD_REPUTATION:korrigans:14", "ADD_REPUTATION:niamh:10", "DAMAGE_LIFE:3"] },
      { verb: "guider", text: "Tu conduis doucement le cheval hors du village jusqu'a l'oree du bois ou tu le liberes.", effects: ["ADD_REPUTATION:anciens:14", "HEAL_LIFE:3"] }
    ]
  },
  {
    narrative: "La femme du meunier refuse de rentrer chez elle depuis deux jours. Elle dit avoir vu son reflet dans la riviere sourire alors qu'elle pleurait. Elle demande si tu peux lui expliquer ce presage.",
    biome: "villages_celtes",
    options: [
      { verb: "rassurer", text: "Tu lui expliques que les rivieres refletent parfois ce qui pourrait etre plutot que ce qui est.", effects: ["ADD_REPUTATION:niamh:16", "HEAL_LIFE:4"] },
      { verb: "interpreter", text: "Tu analyses le presage selon les signes que tu connais, lui donnant une lecture honnete.", effects: ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:druides:8"] },
      { verb: "accompagner", text: "Tu l'accompagnes jusqu'a la riviere pour observer ensemble ce que l'eau a a dire.", effects: ["ADD_REPUTATION:korrigans:16", "ADD_ANAM:3"] }
    ]
  },
  {
    narrative: "Une procession silencieuse traverse le village a minuit. Les participants portent des lanternes de bois sculptees en cranes d'animaux. Ils ne semblent pas voir ceux qui les regardent.",
    biome: "villages_celtes",
    options: [
      { verb: "suivre", text: "Tu te joins a la procession en silence, portant une branche comme si c'etait une lanterne.", effects: ["ADD_REPUTATION:ankou:16", "ADD_ANAM:4"] },
      { verb: "compter", text: "Tu comptes les participants en cherchant un motif dans leur nombre et dans leur ordre.", effects: ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:korrigans:8"] },
      { verb: "prier", text: "Tu prononces les mots de passage pour les ames en transit, depuis le seuil d'une maison.", effects: ["ADD_REPUTATION:ankou:14", "ADD_REPUTATION:niamh:10"] }
    ]
  },
  {
    narrative: "Le tisserand du village realise une tapisserie qui montre des evenements futurs avec une precision troublante. Chaque nuit, des scenes nouvelles y apparaissent sans que personne ne les ait tissees.",
    biome: "villages_celtes",
    options: [
      { verb: "contempler", text: "Tu passes la nuit a etudier la tapisserie, cherchant un futur qui concerne ta quete.", effects: ["ADD_REPUTATION:niamh:18", "ADD_ANAM:3"] },
      { verb: "questionner", text: "Tu interroges le tisserand sur les fils utilises et comment la tapisserie se remplit seule.", effects: ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:druides:8"] },
      { verb: "effacer", text: "Tu defais prudemment un fil qui montre une catastrophe proche, esperant modifier ce destin.", effects: ["ADD_REPUTATION:korrigans:14", "DAMAGE_LIFE:4", "ADD_ANAM:5"] }
    ]
  },
  {
    narrative: "Un groupe d'enfants joue a un jeu ancien dans la rue : ils tracent des cercles dans la poussiere et chantent des comptines dont certains mots sont des noms dans une langue que tu ne connais pas.",
    biome: "villages_celtes",
    options: [
      { verb: "jouer", text: "Tu te mets a quatre pattes pour rejoindre le jeu, adoptant les regles sans les comprendre.", effects: ["ADD_REPUTATION:korrigans:16", "HEAL_LIFE:5"] },
      { verb: "apprendre", text: "Tu memorises les comptines et leur melodie, pressentant qu'elles contiennent une cle.", effects: ["ADD_REPUTATION:anciens:14", "ADD_ANAM:3"] },
      { verb: "chanter", text: "Tu completes les comptines avec les mots qui te viennent, sans savoir d'ou ils surgissent.", effects: ["ADD_REPUTATION:niamh:18", "DAMAGE_LIFE:2"] }
    ]
  },
  {
    narrative: "Dans la taverne du village, un vieux marin qui n'a jamais vu la mer raconte des voyages impossibles. Chacun l'ecoute comme si ses histoires etaient vraies. Peut-etre le sont-elles.",
    biome: "villages_celtes",
    options: [
      { verb: "ecouter", text: "Tu commandes une chope et t'installes pour entendre l'integralite du voyage impossible.", effects: ["ADD_REPUTATION:korrigans:14", "ADD_REPUTATION:niamh:10"] },
      { verb: "reconnaitre", text: "Tu identifies dans son recit des lieux que tu as traverses, ce qui arrete net sa narration.", effects: ["ADD_REPUTATION:anciens:16", "ADD_ANAM:4"] },
      { verb: "ajouter", text: "Tu completes son histoire d'un episode qu'il n'a pas vecu mais qui pourrait etre vrai.", effects: ["ADD_REPUTATION:korrigans:18", "ADD_REPUTATION:niamh:8"] }
    ]
  },
  {
    narrative: "La cloche de l'assemblee sonne trois fois en dehors de toute heure prevue. Les villageois se rassemblent spontanement sur la place, mais personne n'a sonne la cloche — la corde pendait, immobile.",
    biome: "villages_celtes",
    options: [
      { verb: "annoncer", text: "Tu montes sur la margelle du puits et parles a l'assemblee improvisee, prenant la cloche au mot.", effects: ["ADD_REPUTATION:anciens:16", "ADD_REPUTATION:korrigans:10"] },
      { verb: "enqueter", text: "Tu inspectes le clocher a la recherche d'une explication naturelle avant de conclure au prodige.", effects: ["ADD_REPUTATION:druides:14", "ADD_REPUTATION:anciens:8"] },
      { verb: "recueillir", text: "Tu notes ce que chaque villageois a ressenti au son des trois coups, cherchant un message commun.", effects: ["ADD_REPUTATION:niamh:16", "ADD_ANAM:3"] }
    ]
  }
];

cards.push(...batch2);
fs.writeFileSync(path, JSON.stringify(cards, null, 2));
console.log('Total cards:', cards.length);

// Validate constraints
let korrigansOptions = 0, niamhOptions = 0, druideCards = 0, healViolations = 0, repViolations = 0, effectsViolations = 0;
batch2.forEach(card => {
  let hasDruide = false;
  card.options.forEach(opt => {
    if (opt.effects.length > 3) effectsViolations++;
    opt.effects.forEach(e => {
      if (e.includes('korrigans')) korrigansOptions++;
      if (e.includes('niamh')) niamhOptions++;
      if (e.includes('druides')) hasDruide = true;
      const mHeal = e.match(/HEAL_LIFE:(\d+)/);
      if (mHeal && parseInt(mHeal[1]) > 5) healViolations++;
      const mRep = e.match(/ADD_REPUTATION:\w+:(\d+)/);
      if (mRep && parseInt(mRep[1]) > 20) repViolations++;
    });
  });
  if (hasDruide) druideCards++;
});
console.log('korrigans effect-lines:', korrigansOptions, '(expected >=8 options)');
console.log('niamh effect-lines:', niamhOptions, '(expected >=4)');
console.log('druide cards:', druideCards, '(max 3)');
console.log('heal violations (>5):', healViolations, '(expected 0)');
console.log('rep violations (>20):', repViolations, '(expected 0)');
console.log('effects-per-option violations (>3):', effectsViolations, '(expected 0)');
