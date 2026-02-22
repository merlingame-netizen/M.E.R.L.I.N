/**
 * Validation PPT Orange v1 + Rich Components — 8 slides (fond blanc)
 * Teste TOUS les layouts et composants riches du guide PPT
 */
const {
    ORANGE_COLORS,
    createOrangePres,
    addTitleSlide,
    addSectionSlide,
    addContentSlide,
    addTwoColumnSlide,
    addComparisonSlide,
    addCardGridSlide,
    addBadgeSlide,
    addColorPaletteSlide,
    addEndSlide
} = require('./create_orange_ppt.js');

const { pres, theme } = createOrangePres('Validation Charte Orange v1 + Rich', 'blanc');

// SLIDE 1 — Couverture (Layout 2, 55pt)
addTitleSlide(pres, 'Validation\ncharte Orange', 'v1 + composants riches du guide PPT', theme, {
    sideText: 'Fevrier 2026\nDirection Data & IA'
});

// SLIDE 2 — Section (Layout 4, 55pt)
addSectionSlide(pres, 'Les composants\ndu guide', 1, theme);

// SLIDE 3 — Contenu classique (Layout 1, bullets en-dash)
addContentSlide(pres, 'Les piliers de notre strategie data', [
    'Qualite des donnees et gouvernance',
    'Democratisation de l\'acces aux donnees',
    'IA responsable et ethique',
    'Conformite RGPD et securite',
    'Formation et montee en competence'
], theme, { slideNum: 3 });

// SLIDE 4 — Comparaison (2 cards + info box, inspire slide 3 du guide)
addComparisonSlide(pres, 'Deux variantes du template', {
    title: 'Fond noir',
    body: '\u2013  Eco-branding (defaut)\n\u2013  Titres blancs\n\u2013  Corps blanc\n\u2013  Usage digital',
    bgColor: ORANGE_COLORS.primary.black,
    titleColor: ORANGE_COLORS.primary.white,
    bodyColor: ORANGE_COLORS.primary.white
}, {
    title: 'Fond blanc',
    body: '\u2013  Presentations externes\n\u2013  Titres orange\n\u2013  Corps noir\n\u2013  Usage print/projection',
    bgColor: ORANGE_COLORS.bg.card,
    titleColor: ORANGE_COLORS.primary.orange,
    bodyColor: ORANGE_COLORS.primary.grayDark
}, theme, {
    slideNum: 4,
    infoBox: 'Regle : toujours demander "Fond noir ou fond blanc ?" avant toute generation de presentation.'
});

// SLIDE 5 — Palette de couleurs (swatches + panneau regles, inspire slide 4 du guide)
addColorPaletteSlide(pres, 'Palette de couleurs', [
    { color: 'FF7900', label: '#FF7900' },
    { color: '000000', label: '#000000' },
    { color: 'FFFFFF', label: '#FFFFFF' },
    { color: '595959', label: '#595959' },
    { color: '8F8F8F', label: '#8F8F8F' },
    { color: 'D6D6D6', label: '#D6D6D6' },
    { color: '4BB4E6', label: '#4BB4E6' },
    { color: '50BE87', label: '#50BE87' },
    { color: 'FFB4E6', label: '#FFB4E6' },
    { color: 'FFD200', label: '#FFD200' },
    { color: 'A885D8', label: '#A885D8' }
], theme, {
    slideNum: 5,
    cols: 6,
    rulesPanel: '\u2013  Orange #FF7900 = couleur emblematique\n\u2013  Noir, blanc, gris = couleurs principales\n\u2013  Bleu, vert, rose, jaune, pourpre = secondaires\n\u2013  Regle 80/20 : max 20% de secondaires\n\u2013  Texte : SEULS noir, blanc, orange autorises'
});

// SLIDE 6 — Badges / Typographie (pilules orange, inspire slide 5 du guide)
addBadgeSlide(pres, 'Typographie', [
    { label: 'Helvetica 75 Bold', description: 'Titres, sous-titres, tout le texte (v1 style guide PPT)' },
    { label: 'Arial Bold', description: 'Fallback universel si Helvetica Neue non disponible' },
    { label: '55 pt', description: 'Taille titres couverture et section (bigTitle)' },
    { label: '20 pt / 14 pt', description: 'Titre contenu (20pt) et corps de texte (14pt)' }
], theme, { slideNum: 6 });

// SLIDE 7 — Card Grid (4 cards avec bande haute, inspire slide 7 du guide)
addCardGridSlide(pres, 'Les 4 types de slides', [
    {
        title: 'Couverture',
        body: 'Titre 55pt + sous-titre 18pt + texte lateral + logo bas-gauche'
    },
    {
        title: 'Section',
        body: 'Numero (01, 02...) + titre 55pt, pleine page, separateur visuel'
    },
    {
        title: 'Contenu',
        body: 'Titre 20pt orange + bullets en-dash, corps 14pt, logo + slide number'
    },
    {
        title: 'Fin',
        body: '"Merci" centre 55pt, logo bas-gauche, pas de slide number'
    }
], theme, { slideNum: 7 });

// SLIDE 8 — Fin (Merci)
addEndSlide(pres, 'Merci', theme);

const outPath = process.env.USERPROFILE + '\\Downloads\\validation_charte_orange_v1_rich_blanc.pptx';
pres.writeFile({ fileName: outPath })
    .then(() => console.log('OK: ' + outPath))
    .catch(err => console.error('Erreur:', err));
