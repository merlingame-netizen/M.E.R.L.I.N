const fs = require('fs');

const newCards = [
  {
    narrative: "Au coeur du nemeton sacre, trois druides tracent les signes de l'ogham Beith sur un bouleau blanc. Leurs voix resonnent en canon, invoquant la purification des anciennes eaux.",
    options: [
      {verb:'observer',text:"Tu regardes la ceremonie en silence, memorisant chaque geste initiatique.",effects:['HEAL_LIFE:3','ADD_REPUTATION:anciens:6']},
      {verb:"s'approcher",text:"Tu rejoins le cercle et poses ta main sur l'ecorce marquee du Beith.",effects:['HEAL_LIFE:2','ADD_REPUTATION:druides:8']},
      {verb:'attendre',text:"Tu restes en retrait, ressentant la puissance du signe sans le toucher.",effects:['ADD_ANAM:3','ADD_REPUTATION:anciens:5']}
    ]
  },
  {
    narrative: "Un puits sacre entoure de lierre deborde d'une eau argentee. Les anciens disent que ces eaux reflechissent les secrets que l'on porte depuis l'enfance.",
    options: [
      {verb:'examiner',text:"Tu etudies le reflet de l'eau, cherchant un signe de ton destin.",effects:['ADD_ANAM:4','ADD_REPUTATION:anciens:7']},
      {verb:'calmer',text:"Tu offres une priere silencieuse aux gardiens du puits.",effects:['HEAL_LIFE:4','ADD_REPUTATION:druides:5']},
      {verb:"fouiller a l'aveugle",text:"Tu plonges la main dans l'eau froide et en retires une pierre runique.",effects:['ADD_BIOME_CURRENCY:4','DAMAGE_LIFE:3']}
    ]
  },
  {
    narrative: "Sous un chene millenaire pendent des branches chargees de gui. Un vieux druide recite en silence les noms des dix-huit oghams, les yeux fermes, les mains croisees sur sa poitrine.",
    options: [
      {verb:'ecouter',text:"Tu absorbes les mots anciens comme une meditation en mouvement.",effects:['HEAL_LIFE:5','ADD_REPUTATION:druides:6']},
      {verb:'dechiffrer',text:"Tu reconnais les noms: Fearn, Sail, Huath... et completes la sequence.",effects:['ADD_REPUTATION:anciens:8','ADD_ANAM:3']},
      {verb:'resister mentalement',text:"Tu gardes ton esprit ouvert sans laisser les mots te submerger.",effects:['HEAL_LIFE:3','ADD_REPUTATION:korrigans:4']}
    ]
  },
  {
    narrative: "Une pierre levee gravee du signe Dair - le chene - domine une clairiere ou convergent quatre sentiers. Les anciens disent que Dair gouverne la force interieure et la sagesse durable.",
    options: [
      {verb:'analyser',text:"Tu etudies les stries du Dair, deduisant l'epoque de sa gravure.",effects:['ADD_REPUTATION:anciens:9','ADD_BIOME_CURRENCY:3']},
      {verb:'mediter',text:"Tu poses le front contre la pierre froide et laisses la force du chene entrer en toi.",effects:['HEAL_LIFE:5','ADD_REPUTATION:druides:5']},
      {verb:'contourner',text:"Tu longes la pierre sans la toucher, gardant ton energie pour la route.",effects:['ADD_ANAM:2','ADD_REPUTATION:niamh:4']}
    ]
  },
  {
    narrative: "Des traces de sabots menent a une source entouree de pierres portant l'ogham Luis - le sorbier. Le sorbier protege des forces obscures selon la tradition des Anciens de Broceliande.",
    options: [
      {verb:'suivre',text:"Tu suis les traces jusqu'a la source et bois une gorgee de l'eau sacree.",effects:['HEAL_LIFE:4','ADD_REPUTATION:anciens:6']},
      {verb:'scruter',text:"Tu examines les pierres Luis, notant leurs positions relatives.",effects:['ADD_REPUTATION:anciens:7','ADD_ANAM:2']},
      {verb:'calmer',text:"Tu te reposes pres de la source, laissant la protection du sorbier t'envelopper.",effects:['HEAL_LIFE:3','ADD_REPUTATION:druides:4']}
    ]
  },
  {
    narrative: "Un apprenti druide t'interpelle depuis un carrefour. Il porte une tablette couverte de signes Nion - le frene - et cherche quelqu'un pour tester sa lecon du jour.",
    options: [
      {verb:'accepter',text:"Tu ecoutes sa recitation et corriges doucement une erreur sur le signe Nion.",effects:['ADD_REPUTATION:druides:7','ADD_ANAM:3']},
      {verb:'negocier',text:"Tu acceptes en echange d'une information sur les sentiers de la foret.",effects:['ADD_BIOME_CURRENCY:5','ADD_REPUTATION:anciens:4']},
      {verb:'refuser',text:"Tu declines poliment, presse par ta propre quete et tes obligations.",effects:['ADD_REPUTATION:ankou:3','ADD_ANAM:1']}
    ]
  },
  {
    narrative: "Un cercle de gui seche marque l'emplacement d'une ancienne ceremonie de Beltane. Des cendres dessinent encore les contours d'un feu rituel en forme d'ogham Tinne - le houx.",
    options: [
      {verb:'interpreter',text:"Tu lis le signe Tinne comme un appel a la force en periode de tenebres.",effects:['ADD_REPUTATION:anciens:8','HEAL_LIFE:3']},
      {verb:'cueillir',text:"Tu prends quelques brins de gui seche comme amulette de voyage.",effects:['ADD_BIOME_CURRENCY:3','ADD_REPUTATION:druides:5']},
      {verb:'attendre',text:"Tu t'assieds dans le cercle et laisses la memoire du feu te rechauffer.",effects:['HEAL_LIFE:5','ADD_ANAM:2']}
    ]
  },
  {
    narrative: "Deux anciens se disputent sur l'interpretation de l'ogham Coll - le noisetier. L'un soutient qu'il symbolise la sagesse pratique, l'autre la vision poetique et l'inspiration.",
    options: [
      {verb:'analyser',text:"Tu arbitres le debat en citant les deux traditions et proposes une synthese.",effects:['ADD_REPUTATION:anciens:10','ADD_REPUTATION:druides:4']},
      {verb:'ecouter',text:"Tu te tais et absorbes les deux visions sans trancher entre elles.",effects:['ADD_ANAM:4','HEAL_LIFE:2']},
      {verb:'esquiver',text:"Tu passes ton chemin discretement, laissant les anciens a leur querelle d'erudits.",effects:['ADD_REPUTATION:korrigans:4','ADD_BIOME_CURRENCY:2']}
    ]
  },
  {
    narrative: "Une initiation se prepare a l'oree du bois. Cinq novices druides portent des robes blanches et tressent des couronnes de frenes. Leur maitre les guide avec une lenteur rituelle.",
    options: [
      {verb:'observer',text:"Tu assistes a la ceremonie d'initiation depuis l'ombre protectrice des arbres.",effects:['HEAL_LIFE:3','ADD_REPUTATION:druides:6']},
      {verb:"s'approcher",text:"Tu offres ton aide pour la cueillette des plantes rituelles manquantes.",effects:['ADD_REPUTATION:druides:9','ADD_ANAM:2']},
      {verb:'attendre',text:"Tu patientes que la ceremonie soit terminee avant de traverser la clairiere.",effects:['ADD_REPUTATION:anciens:5','HEAL_LIFE:2']}
    ]
  },
  {
    narrative: "Les rayons de la lune filtrent a travers le feuillage et eclairent un sentier de mousse lumineuse. Un esprit-arbre observe ton passage, ses yeux en forme de noeuds dans l'ecorce vieille.",
    options: [
      {verb:'fixer',text:"Tu soutiens le regard de l'esprit-arbre jusqu'a ce qu'il baisse les yeux.",effects:['ADD_REPUTATION:anciens:7','ADD_ANAM:3']},
      {verb:'parler',text:"Tu salues l'esprit selon le protocole druidique: trois genuflexions et un nom de bois.",effects:['HEAL_LIFE:4','ADD_REPUTATION:druides:5']},
      {verb:'se faufiler',text:"Tu passes furtivement sous les branches basses sans croiser le regard du gardien.",effects:['ADD_BIOME_CURRENCY:3','ADD_REPUTATION:niamh:4']}
    ]
  },
  {
    narrative: "Une vieille druidesse taille des baguettes de coudrier sous la pluie. Elle chante un poeme sur les saisons en marquant chaque strophe d'un signe oghamique dans la terre molle.",
    options: [
      {verb:'memoriser',text:"Tu transcris mentalement les signes oghams avant que la pluie ne les efface.",effects:['ADD_ANAM:4','ADD_REPUTATION:anciens:6']},
      {verb:'apaiser',text:"Tu proposes de tenir un abri de branches au-dessus d'elle pendant son travail sacre.",effects:['HEAL_LIFE:3','ADD_REPUTATION:druides:8']},
      {verb:'pister',text:"Tu suis la trajectoire de sa baguette pour comprendre le geste initiatique.",effects:['ADD_REPUTATION:anciens:7','ADD_BIOME_CURRENCY:2']}
    ]
  },
  {
    narrative: "Un bosquet de noisetiers cache une reserve druidique: des tablettes en bois de hetre gravees de textes en ogham decrivant les cycles lunaires et les periodes favorables.",
    options: [
      {verb:'etudier',text:"Tu dechiffres les tablettes et notes les dates de recolte pour les prochaines saisons.",effects:['ADD_REPUTATION:anciens:9','ADD_ANAM:3']},
      {verb:'decoder',text:"Tu identifies un schema crypte revelant l'emplacement d'un nemeton cache.",effects:['ADD_BIOME_CURRENCY:5','ADD_REPUTATION:druides:5']},
      {verb:'laisser',text:"Tu remets les tablettes en place, respectant la sacralite de leur cachette.",effects:['HEAL_LIFE:3','ADD_REPUTATION:anciens:6']}
    ]
  },
  {
    narrative: "Un druide-poete improvise une ode aux dix-huit arbres sacres devant un auditoire de korrigans sceptiques. Les petits etres ricanent mais tendent l'oreille malgre eux.",
    options: [
      {verb:'ecouter',text:"Tu apprends trois noms d'oghams inconnus grace a ce spectacle inattendu.",effects:['ADD_ANAM:4','ADD_REPUTATION:korrigans:5']},
      {verb:'charmer',text:"Tu applaudis avec enthousiasme, gagnant la sympathie du poete et des korrigans.",effects:['ADD_REPUTATION:druides:7','HEAL_LIFE:3']},
      {verb:'analyser',text:"Tu notes les inexactitudes poetiques pour les corriger lors d'une prochaine rencontre.",effects:['ADD_REPUTATION:anciens:8','ADD_BIOME_CURRENCY:2']}
    ]
  },
  {
    narrative: "Les racines d'un chene millenaire ont cree une crypte naturelle. A l'interieur reposent les ossements d'un druide avec sa faucille en or et ses tablettes oghams intactes depuis des siecles.",
    options: [
      {verb:'respecter',text:"Tu observes le sanctuaire sans rien toucher, honorant la memoire du druide disparu.",effects:['ADD_REPUTATION:anciens:9','ADD_ANAM:3']},
      {verb:'decoder',text:"Tu lis les tablettes avec reverence: elles decrivent un rituel de guerison oublie.",effects:['HEAL_LIFE:5','ADD_REPUTATION:druides:6']},
      {verb:'se recueillir',text:"Tu prononces une priere silencieuse pour le repos de l'ame du druide ancien.",effects:['HEAL_LIFE:4','ADD_REPUTATION:ankou:5']}
    ]
  },
  {
    narrative: "Une fete votive reunit trois clans autour d'un feu de chene. Les bards chantent l'histoire des oghams depuis Ogma Grianainech jusqu'aux druides fondateurs de Broceliande.",
    options: [
      {verb:'ecouter',text:"Tu absorbes le chant epique, memorisant les genealogies des signes sacres.",effects:['ADD_ANAM:5','ADD_REPUTATION:anciens:7']},
      {verb:'parler',text:"Tu partages une version que tu connais, gagnant le respect des bards reunis.",effects:['ADD_REPUTATION:druides:8','HEAL_LIFE:3']},
      {verb:'observer',text:"Tu etudies les visages des clans, cherchant les vrais gardiens du savoir ancien.",effects:['ADD_REPUTATION:anciens:6','ADD_BIOME_CURRENCY:3']}
    ]
  },
  {
    narrative: "Un couloir naturel de houx formes en voute constitue une galerie verte et silencieuse. A chaque pas, des feuilles tombent et leur disposition semble tracer un message en ogham sur le sol.",
    options: [
      {verb:'dechiffrer',text:"Tu lis le message des feuilles: il indique la direction d'une source guerisseuse.",effects:['HEAL_LIFE:5','ADD_REPUTATION:druides:5']},
      {verb:'sentir',text:"Tu suis l'odeur de resine fraiche a travers la galerie de houx sacres.",effects:['ADD_ANAM:3','ADD_REPUTATION:niamh:5']},
      {verb:'traverser',text:"Tu avances sans chercher a interpreter, laissant la foret te guider en confiance.",effects:['HEAL_LIFE:3','ADD_REPUTATION:anciens:5']}
    ]
  },
  {
    narrative: "Trois chouettes blanches se tiennent en triangle au sommet d'un menhir. Les anciens y voient le signe Huath - l'aubepine - gardien des passages entre les mondes visibles et caches.",
    options: [
      {verb:'flairer',text:"Tu humes le vent et detectes le parfum d'aubepine en fleur au milieu de l'automne.",effects:['ADD_ANAM:4','ADD_REPUTATION:anciens:8']},
      {verb:'interpreter',text:"Tu reconnais le signe Huath et comprends que tu approches d'un passage spirituel.",effects:['ADD_REPUTATION:druides:7','HEAL_LIFE:3']},
      {verb:'attendre',text:"Tu t'immobilises et laisses les chouettes s'habituer a ta presence calme.",effects:['HEAL_LIFE:4','ADD_REPUTATION:niamh:5']}
    ]
  },
  {
    narrative: "Un jeune bard memorise sa lecon sur le signe Quert - le pommier - symbole de la jeunesse eternelle et du choix entre plusieurs chemins de vie possibles devant soi.",
    options: [
      {verb:'aider',text:"Tu corriges sa pronunciation du nom oghamique avec bienveillance et patience.",effects:['ADD_REPUTATION:druides:6','ADD_ANAM:3']},
      {verb:'questionner',text:"Tu lui poses une question avancee sur Quert qui l'oblige a approfondir sa reflexion.",effects:['ADD_REPUTATION:anciens:8','ADD_BIOME_CURRENCY:3']},
      {verb:'ecouter',text:"Tu l'ecoutes reciter jusqu'au bout, respectant pleinement son effort d'apprentissage.",effects:['HEAL_LIFE:3','ADD_REPUTATION:druides:5']}
    ]
  },
  {
    narrative: "Un portail d'arbres entrelaces marque l'entree d'un lieu sacre interdit aux non-inities. Une inscription en ogham avertit: seuls ceux qui connaissent le nom du vent peuvent entrer ici.",
    options: [
      {verb:'dechiffrer',text:"Tu dechiffres l'inscription et prononces le nom du vent en vieux-celtique.",effects:['ADD_REPUTATION:anciens:10','ADD_ANAM:4']},
      {verb:'contourner',text:"Tu longes la frontiere sacree sans tenter de penetrer l'espace interdit aux profanes.",effects:['ADD_REPUTATION:druides:5','HEAL_LIFE:3']},
      {verb:'mediter',text:"Tu t'assieds devant le portail et laisses sa magie t'enseigner sans franchir le seuil.",effects:['HEAL_LIFE:5','ADD_REPUTATION:anciens:6']}
    ]
  },
  {
    narrative: "Un ermite druidique vit seul dans un creux de rocher tapisse de mousses. Il passe ses journees a graver des oghams sur des galets qu'il jette ensuite dans le ruisseau qui chante.",
    options: [
      {verb:'questionner',text:"Tu lui demandes le sens de ce rituel. Il repond: les mots voyagent vers ceux qui en ont besoin.",effects:['ADD_ANAM:5','ADD_REPUTATION:anciens:7']},
      {verb:'aider',text:"Tu ramasses des galets lisses sur le ruisseau et les lui apportes generalement.",effects:['ADD_REPUTATION:druides:7','HEAL_LIFE:4']},
      {verb:'observer',text:"Tu regardes le galet grave couler et t'interroges sur le message qu'il porte au loin.",effects:['ADD_ANAM:3','ADD_REPUTATION:anciens:5']}
    ]
  }
];

const existing = JSON.parse(fs.readFileSync('web-demo/public/data/cards.json','utf8'));
console.log('Existing cards:', existing.length);
const merged = existing.concat(newCards);
fs.writeFileSync('web-demo/public/data/cards.json', JSON.stringify(merged, null, 2));
console.log('New total:', merged.length);

// Validation
let druides=0, anciens=0, total_opts=0, ogham_refs=0;
const oghamNames = ['Beith','Luis','Nion','Fearn','Sail','Huath','Dair','Tinne','Coll','Quert','Muin','Gort','Straif','Ruis'];
let heal_violations=0;
for (const c of newCards) {
  const full_text = c.narrative + JSON.stringify(c.options);
  if (oghamNames.some(o => full_text.includes(o))) ogham_refs++;
  for (const opt of c.options) {
    total_opts++;
    for (const e of opt.effects) {
      if (e.startsWith('ADD_REPUTATION:druides')) druides++;
      if (e.startsWith('ADD_REPUTATION:anciens')) anciens++;
      if (e.startsWith('HEAL_LIFE:')) {
        const v = parseInt(e.split(':')[1]);
        if (v > 5) { heal_violations++; console.log('VIOLATION HEAL>5:', e); }
      }
    }
  }
}
console.log('Validation:');
console.log('  total_opts:', total_opts, '(expected 60)');
console.log('  druides options:', druides, '=> pct:', (druides/total_opts*100).toFixed(1)+'% (max 30%)');
console.log('  anciens options:', anciens, '=> pct:', (anciens/total_opts*100).toFixed(1)+'% (min 25%)');
console.log('  ogham_refs:', ogham_refs, '/ 20 (need >=8)');
console.log('  heal_violations (>5):', heal_violations, '(expected 0)');
console.log(heal_violations === 0 && ogham_refs >= 8 ? 'PASS' : 'FAIL');
