/**
 * Test Cours PPT Template — 4 slides de validation
 * Reproduit le pattern generate_cours.js (IDRAC style)
 */

const pptxgen = require('pptxgenjs');
const path = require('path');
const fs = require('fs');

// ============================================
// COULEURS COURS (IDRAC palette)
// ============================================
const C = {
    RED: 'A71F28',
    DARK: '343A40',
    LGRAY: 'DAE0E5',
    LAVENDER: 'E8E8F8',
    WHITE: 'FFFFFF',
    AMBER: 'FFF3CD',
    AMBER_BORDER: 'FFD200',
    LIGHT_RED: 'F4B8BB',
    TEAL: 'D4EDDA',
    BLUE_LIGHT: 'D6EAF8',
    GRAY_TEXT: '666666',
    BG_LIGHT: 'F8F9FA',
    PINK: 'F5C6C9'
};

const F = 'Arial';
let sn = 0;

const p = new pptxgen();
p.defineLayout({ name: 'COURS_16x9', width: 10, height: 5.625 });
p.layout = 'COURS_16x9';
p.author = 'Orange';
p.company = 'Orange';
p.title = 'Test Template Cours';

// ============================================
// HELPERS
// ============================================

function addSN(s) {
    sn++;
    s.addText(String(sn), {
        x: 9.3, y: 5.15, w: 0.5, h: 0.3,
        fontFace: F, fontSize: 8, color: C.GRAY_TEXT,
        align: 'right', bold: true, shrinkText: true, bullet: false
    });
}

function tBar(s) {
    s.addShape('rect', {
        x: 0, y: 0, w: 10, h: 0.08,
        fill: { color: C.RED }, line: { type: 'none' }
    });
}

function aL(s, y) {
    s.addShape('rect', {
        x: 0.4, y: y, w: 1.2, h: 0.04,
        fill: { color: C.RED }, line: { type: 'none' }
    });
}

function ttl(s, t) {
    s.addText(t, {
        x: 0.4, y: 0.25, w: 9.2, h: 0.65,
        fontFace: F, fontSize: 28, bold: true, color: C.DARK,
        shrinkText: true, bullet: false
    });
}

function takeaway(s, text) {
    const y = 4.5, h = 0.65;
    // Fond lavande
    s.addShape('rect', {
        x: 0.4, y: y, w: 9.2, h: h,
        fill: { color: C.LAVENDER }, line: { type: 'none' }
    });
    // Bande rouge a gauche
    s.addShape('rect', {
        x: 0.4, y: y, w: 0.06, h: h,
        fill: { color: C.RED }, line: { type: 'none' }
    });
    // Texte
    s.addText(text, {
        x: 0.6, y: y + 0.05, w: 8.8, h: h - 0.1,
        fontFace: F, fontSize: 12, bold: true, color: C.DARK,
        valign: 'middle', shrinkText: true, bullet: false
    });
}

function tipBox(s, text, y, h) {
    y = y || 3.8;
    h = h || 0.55;
    s.addShape('rect', {
        x: 0.4, y: y, w: 9.2, h: h,
        fill: { color: C.AMBER },
        line: { color: C.AMBER_BORDER, width: 1.5 }
    });
    s.addText('\u{1F4A1} ' + text, {
        x: 0.6, y: y + 0.05, w: 8.8, h: h - 0.1,
        fontFace: F, fontSize: 11, bold: true, color: C.DARK,
        valign: 'middle', shrinkText: true, bullet: false
    });
}

// Formatters
function H(t) {
    return { text: t, options: { fontSize: 18, color: C.RED, bold: true, bullet: false, breakLine: true } };
}

function Sm(t) {
    return { text: t, options: { fontSize: 14, color: C.GRAY_TEXT, bullet: false, breakLine: true } };
}

function fmtBody(text, fontSize) {
    fontSize = fontSize || 16;
    return {
        text: text,
        options: {
            fontSize: fontSize,
            bullet: { code: '25A0', color: C.RED },
            breakLine: true,
            paraSpaceAfter: 3
        }
    };
}

// ============================================
// SLIDE 1 — TITLE SLIDE (fond sombre + barres rouges)
// ============================================
const s1 = p.addSlide();
s1.background = { color: C.DARK };
// Barre rouge haut
s1.addShape('rect', { x: 0, y: 0, w: 10, h: 0.18, fill: { color: C.RED }, line: { type: 'none' } });
// Barre rouge bas
s1.addShape('rect', { x: 0, y: 5.445, w: 10, h: 0.18, fill: { color: C.RED }, line: { type: 'none' } });
// Titre
s1.addText('Introduction\nau Machine Learning', {
    x: 0.6, y: 1.2, w: 8.8, h: 2.0,
    fontFace: F, fontSize: 38, bold: true, color: C.WHITE,
    align: 'left', valign: 'middle', shrinkText: true, bullet: false
});
// Sous-titre
s1.addText('MBA1 Data & IA \u2014 IDRAC Business School', {
    x: 0.6, y: 3.3, w: 8.8, h: 0.6,
    fontFace: F, fontSize: 20, color: C.LGRAY,
    align: 'left', valign: 'top', shrinkText: true, bullet: false
});
// Info bas
s1.addText('Semestre 2 \u2014 2026', {
    x: 0.6, y: 4.6, w: 4, h: 0.4,
    fontFace: F, fontSize: 14, color: C.GRAY_TEXT,
    shrinkText: true, bullet: false
});

// ============================================
// SLIDE 2 — CONTENT SLIDE (cSlide pattern)
// ============================================
const s2 = p.addSlide();
s2.background = { color: C.WHITE };
tBar(s2);
ttl(s2, 'Objectifs du module');
aL(s2, 1.05);

s2.addText([
    H('A la fin de ce module, vous saurez'),
    fmtBody('Definir les concepts cles du Machine Learning'),
    fmtBody('Distinguer apprentissage supervise et non-supervise'),
    fmtBody('Evaluer un modele avec precision, rappel et F1-score'),
    fmtBody('Appliquer un pipeline ML avec Python et scikit-learn'),
    Sm('Taxonomie de Bloom : Niveaux 1 a 4 (Connaitre, Comprendre, Appliquer, Analyser)')
], {
    x: 0.4, y: 1.2, w: 9.2, h: 3.1,
    fontFace: F, fontSize: 16, color: C.DARK,
    valign: 'top', shrinkText: true, bullet: false,
    paraSpaceAfter: 3
});

takeaway(s2, 'Takeaway : Le ML est un outil de decision data-driven, pas une boite noire magique.');
addSN(s2);

// ============================================
// SLIDE 3 — TWO COLUMN (tcSlide pattern)
// ============================================
const s3 = p.addSlide();
s3.background = { color: C.WHITE };
tBar(s3);
ttl(s3, 'Supervise vs Non-supervise');
aL(s3, 1.05);

const colY = 1.3, colH = 2.8, colW = 4.2;

// Colonne gauche (lavande)
s3.addShape('roundRect', {
    x: 0.4, y: colY, w: colW, h: colH,
    fill: { color: C.LAVENDER }, line: { type: 'none' }, rectRadius: 0.05
});
s3.addText('Apprentissage supervise', {
    x: 0.6, y: colY + 0.1, w: colW - 0.4, h: 0.4,
    fontFace: F, fontSize: 18, bold: true, color: C.RED,
    shrinkText: true, bullet: false
});
s3.addText([
    fmtBody('Donnees labellisees (X, y)'),
    fmtBody('Classification et Regression'),
    fmtBody('Exemples : spam, prix immo, churn'),
    fmtBody('Metriques : accuracy, RMSE, AUC')
], {
    x: 0.6, y: colY + 0.55, w: colW - 0.4, h: colH - 0.7,
    fontFace: F, fontSize: 14, color: C.DARK,
    valign: 'top', shrinkText: true, paraSpaceAfter: 3
});

// Colonne droite (gris clair)
s3.addShape('roundRect', {
    x: 5.4, y: colY, w: colW, h: colH,
    fill: { color: C.BG_LIGHT }, line: { type: 'none' }, rectRadius: 0.05
});
s3.addText('Apprentissage non-supervise', {
    x: 5.6, y: colY + 0.1, w: colW - 0.4, h: 0.4,
    fontFace: F, fontSize: 18, bold: true, color: C.RED,
    shrinkText: true, bullet: false
});
s3.addText([
    fmtBody('Pas de labels (X seul)'),
    fmtBody('Clustering et reduction dim.'),
    fmtBody('Exemples : segmentation, PCA'),
    fmtBody('Metriques : silhouette, inertie')
], {
    x: 5.6, y: colY + 0.55, w: colW - 0.4, h: colH - 0.7,
    fontFace: F, fontSize: 14, color: C.DARK,
    valign: 'top', shrinkText: true, paraSpaceAfter: 3
});

tipBox(s3, 'Astuce : commencez toujours par une approche supervisee si vous avez des labels.', 4.3, 0.5);
addSN(s3);

// ============================================
// SLIDE 4 — SECTION DIVIDER (secSlide pattern)
// ============================================
const s4 = p.addSlide();
s4.background = { color: C.RED };
// Label
s4.addText('PARTIE 1', {
    x: 0.6, y: 1.5, w: 8.8, h: 0.5,
    fontFace: F, fontSize: 18, color: C.PINK,
    bold: true, shrinkText: true, bullet: false
});
// Titre section
s4.addText('Les fondamentaux\ndu Machine Learning', {
    x: 0.6, y: 2.1, w: 8.8, h: 2.0,
    fontFace: F, fontSize: 34, bold: true, color: C.WHITE,
    align: 'left', valign: 'top', shrinkText: true, bullet: false
});
// Ellipse decorative
s4.addShape('ellipse', {
    x: 7.5, y: 3.8, w: 2.5, h: 2.5,
    fill: { color: C.LIGHT_RED, transparency: 60 },
    line: { type: 'none' }
});

// ============================================
// SAVE
// ============================================
const output = path.join(process.env.USERPROFILE || '', 'Downloads', 'Test_Template_Cours_v1.pptx');
p.writeFile({ fileName: output })
    .then(() => console.log('OK:', output))
    .catch(err => console.error('Erreur:', err));
