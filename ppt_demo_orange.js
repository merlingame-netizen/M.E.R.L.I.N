/**
 * Démonstration Charte Orange - 4 slides
 */

const pptxgen = require('pptxgenjs');

const COLORS = {
    orange: 'FF7900',
    black: '000000',
    white: 'FFFFFF',
    grayDark: '595959'
};

const pres = new pptxgen();
pres.author = 'Orange';
pres.title = 'Démonstration Charte Orange';
pres.defineLayout({ name: 'ORANGE', width: 10, height: 5.625 });
pres.layout = 'ORANGE';

// Small Logo helper
function addSmallLogo(slide, x = 9.2, y = 5.0) {
    slide.addShape('rect', { x, y, w: 0.5, h: 0.5, fill: { color: COLORS.orange } });
    slide.addShape('line', { x: x + 0.05, y: y + 0.25, w: 0.4, h: 0, line: { color: COLORS.white, width: 2 } });
}

// ========== SLIDE 1: Titre ==========
const s1 = pres.addSlide();
s1.background = { color: COLORS.black };
s1.addShape('rect', { x: 0, y: 0, w: '100%', h: 0.8, fill: { color: COLORS.orange } });
s1.addText("On fait simple", {
    x: 0.5, y: 1.8, w: 9, h: 1.2,
    fontFace: 'Arial', fontSize: 44, bold: true, color: COLORS.white
});
s1.addText("Parce que chez Orange, on parle vrai", {
    x: 0.5, y: 3.2, w: 9, h: 0.6,
    fontFace: 'Arial', fontSize: 20, bold: true, color: COLORS.orange
});
addSmallLogo(s1, 9.2, 4.9);

// ========== SLIDE 2: Contenu ==========
const s2 = pres.addSlide();
s2.background = { color: COLORS.white };
s2.addShape('rect', { x: 0, y: 0, w: '100%', h: 0.1, fill: { color: COLORS.orange } });
s2.addText("Ce qui nous rend uniques", {
    x: 0.5, y: 0.3, w: 9, h: 0.8,
    fontFace: 'Arial', fontSize: 32, bold: true, color: COLORS.black
});

const bullets2 = [
    { text: "On est proches de vous, vraiment", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 14 }},
    { text: "On parle comme dans la vraie vie", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 14 }},
    { text: "On ose faire les choses différemment", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 14 }},
    { text: "On construit ensemble, pas tout seuls", options: { bullet: { code: '25A0', color: COLORS.orange }, fontSize: 18, fontFace: 'Arial', color: COLORS.black, paraSpaceAfter: 14 }}
];
s2.addText(bullets2, { x: 0.5, y: 1.4, w: 9, h: 3.5, valign: 'top' });
addSmallLogo(s2);

// ========== SLIDE 3: Section orange ==========
const s3 = pres.addSlide();
s3.background = { color: COLORS.orange };
s3.addText("01", {
    x: 0.5, y: 1.2, w: 2, h: 1.2,
    fontFace: 'Arial', fontSize: 72, bold: true, color: COLORS.white
});
s3.addText("Le numérique pour tous", {
    x: 0.5, y: 2.8, w: 9, h: 1,
    fontFace: 'Arial', fontSize: 36, bold: true, color: COLORS.white
});
s3.addText("Accessible, responsable, audacieux", {
    x: 0.5, y: 3.8, w: 9, h: 0.5,
    fontFace: 'Arial', fontSize: 18, color: COLORS.white
});

// ========== SLIDE 4: Fin ==========
const s4 = pres.addSlide();
s4.background = { color: COLORS.black };
s4.addText("Et voilà !", {
    x: 0, y: 1.8, w: '100%', h: 1,
    fontFace: 'Arial', fontSize: 48, bold: true, color: COLORS.orange, align: 'center'
});
s4.addText("Orange est là", {
    x: 0, y: 3.8, w: '100%', h: 0.5,
    fontFace: 'Arial', fontSize: 18, color: COLORS.white, align: 'center'
});
s4.addShape('rect', { x: 4.7, y: 4.4, w: 0.6, h: 0.6, fill: { color: COLORS.orange } });
s4.addShape('line', { x: 4.75, y: 4.7, w: 0.5, h: 0, line: { color: COLORS.white, width: 2 } });

// Sauvegarde
pres.writeFile({ fileName: 'Demo_Orange.pptx' })
    .then(() => console.log('Créé: Demo_Orange.pptx'))
    .catch(console.error);
