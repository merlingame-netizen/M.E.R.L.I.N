/**
 * Présentation: L'utilisation de Claude chez Orange
 * Conforme à la charte graphique Orange
 */

const pptxgen = require('pptxgenjs');

// Couleurs Orange
const COLORS = {
    orange: 'FF7900',
    black: '000000',
    white: 'FFFFFF',
    grayDark: '595959',
    grayLight: 'D6D6D6'
};

// Création de la présentation
const pres = new pptxgen();
pres.author = 'Orange';
pres.company = 'Orange';
pres.title = "L'utilisation de Claude chez Orange";
pres.defineLayout({ name: 'ORANGE', width: 10, height: 5.625 });
pres.layout = 'ORANGE';

// Fonction pour ajouter le Small Logo
function addSmallLogo(slide, x = 9.2, y = 5.0) {
    slide.addShape('rect', {
        x: x, y: y, w: 0.5, h: 0.5,
        fill: { color: COLORS.orange }
    });
    slide.addShape('line', {
        x: x + 0.05, y: y + 0.25, w: 0.4, h: 0,
        line: { color: COLORS.white, width: 2 }
    });
}

// ============================================
// SLIDE 1 : Titre
// ============================================
const slide1 = pres.addSlide();
slide1.background = { color: COLORS.black };

// Bandeau orange
slide1.addShape('rect', {
    x: 0, y: 0, w: '100%', h: 0.8,
    fill: { color: COLORS.orange }
});

// Titre principal
slide1.addText("L'utilisation de Claude chez Orange", {
    x: 0.5, y: 1.8, w: 9, h: 1.2,
    fontFace: 'Arial',
    fontSize: 36,
    bold: true,
    color: COLORS.white,
    align: 'left'
});

// Sous-titre
slide1.addText("Intelligence artificielle au service de nos équipes", {
    x: 0.5, y: 3.2, w: 9, h: 0.6,
    fontFace: 'Arial',
    fontSize: 20,
    bold: true,
    color: COLORS.orange,
    align: 'left'
});

addSmallLogo(slide1, 9.2, 4.9);

// ============================================
// SLIDE 2 : Qu'est-ce que Claude ?
// ============================================
const slide2 = pres.addSlide();
slide2.background = { color: COLORS.white };

// Ligne orange en haut
slide2.addShape('rect', {
    x: 0, y: 0, w: '100%', h: 0.1,
    fill: { color: COLORS.orange }
});

// Titre
slide2.addText("Qu'est-ce que Claude ?", {
    x: 0.5, y: 0.3, w: 9, h: 0.8,
    fontFace: 'Arial',
    fontSize: 32,
    bold: true,
    color: COLORS.black
});

// Contenu avec puces carrées orange
const bullets2 = [
    { text: "Assistant IA développé par Anthropic", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Capable de comprendre et générer du texte de manière naturelle", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Conçu avec un focus sur la sécurité et l'éthique", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Disponible via API et interface conversationnelle", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }}
];

slide2.addText(bullets2, {
    x: 0.5, y: 1.4, w: 9, h: 3.5,
    valign: 'top'
});

addSmallLogo(slide2);

// ============================================
// SLIDE 3 : Cas d'usage chez Orange
// ============================================
const slide3 = pres.addSlide();
slide3.background = { color: COLORS.white };

// Ligne orange
slide3.addShape('rect', {
    x: 0, y: 0, w: '100%', h: 0.1,
    fill: { color: COLORS.orange }
});

// Titre
slide3.addText("Cas d'usage chez Orange", {
    x: 0.5, y: 0.3, w: 9, h: 0.8,
    fontFace: 'Arial',
    fontSize: 32,
    bold: true,
    color: COLORS.black
});

// Contenu
const bullets3 = [
    { text: "Assistance au développement et revue de code", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Rédaction et synthèse de documents techniques", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Analyse de données et reporting automatisé", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Support aux équipes pour la résolution de problèmes", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }},
    { text: "Création de présentations et contenus conformes à la charte", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 12 }}
];

slide3.addText(bullets3, {
    x: 0.5, y: 1.4, w: 9, h: 3.5,
    valign: 'top'
});

addSmallLogo(slide3);

// ============================================
// SLIDE 4 : Fin
// ============================================
const slide4 = pres.addSlide();
slide4.background = { color: COLORS.black };

// Message principal
slide4.addText("Des questions ?", {
    x: 0, y: 1.8, w: '100%', h: 1,
    fontFace: 'Arial',
    fontSize: 44,
    bold: true,
    color: COLORS.orange,
    align: 'center'
});

// Signature
slide4.addText("Orange est là", {
    x: 0, y: 3.8, w: '100%', h: 0.5,
    fontFace: 'Arial',
    fontSize: 18,
    color: COLORS.white,
    align: 'center'
});

// Logo centré
slide4.addShape('rect', {
    x: 4.7, y: 4.4, w: 0.6, h: 0.6,
    fill: { color: COLORS.orange }
});
slide4.addShape('line', {
    x: 4.75, y: 4.7, w: 0.5, h: 0,
    line: { color: COLORS.white, width: 2 }
});

// Sauvegarde
const fileName = 'Claude_chez_Orange.pptx';
pres.writeFile({ fileName })
    .then(() => console.log(`Présentation créée: ${fileName}`))
    .catch(err => console.error('Erreur:', err));
