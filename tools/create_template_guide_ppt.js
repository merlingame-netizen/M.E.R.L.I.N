/**
 * Guide du template Orange — Voix du Client DEF
 * Presentation du template officiel et de ses regles
 * Usage: node tools/create_template_guide_ppt.js
 * Sortie: C:\Users\PGNK2128\Downloads\Guide_Template_Orange_VoC_DEF.pptx
 */

const {
    ORANGE_COLORS,
    ORANGE_FONTS,
    POS,
    LOGO_SAFE_Y,
    getTheme,
    createOrangePres,
    addOrangeLogo,
    addSlideNumber,
    addTitleSlide,
    addSectionSlide,
    addEndSlide
} = require('./create_orange_ppt.js');

const THEME = getTheme('blanc');
let slideN = 0;

function S(pres) {
    slideN++;
    const slide = pres.addSlide();
    slide.background = { color: THEME.bg };
    addOrangeLogo(slide);
    addSlideNumber(slide, slideN, THEME);
    return slide;
}

function H(slide, text) {
    slide.addText(text, {
        x: POS.title.x, y: POS.title.y, w: POS.title.w, h: POS.title.h,
        fontFace: ORANGE_FONTS.title, fontSize: 20, bold: true,
        color: ORANGE_COLORS.primary.orange,
        lineSpacingPercent: 90, shrinkText: true, bullet: false
    });
}

function Body(slide, items, opts = {}) {
    const rows = items.map(t => ({
        text: t,
        options: {
            fontFace: ORANGE_FONTS.body, fontSize: opts.fontSize || 14, bold: true,
            color: opts.color || THEME.bodyL2,
            bullet: false,
            paraSpaceBefore: 6, paraSpaceAfter: 6
        }
    }));
    slide.addText(rows, {
        x: opts.x || POS.body.x, y: opts.y || POS.body.y,
        w: opts.w || POS.body.w, h: opts.h || POS.body.h,
        valign: 'top', shrinkText: true
    });
}

function Box(slide, x, y, w, h, fill) {
    slide.addShape('rect', { x, y, w, h, fill: { color: fill || 'F5F5F5' }, rectRadius: 0.05 });
}

function BoxText(slide, text, x, y, w, h, opts = {}) {
    slide.addText(text, {
        x, y, w, h,
        fontFace: opts.fontFace || ORANGE_FONTS.body,
        fontSize: opts.fontSize || 11, bold: true,
        color: opts.color || ORANGE_COLORS.primary.black,
        align: opts.align || 'center', valign: opts.valign || 'middle',
        shrinkText: true, bullet: false
    });
}

function ColorSwatch(slide, color, label, x, y) {
    slide.addShape('rect', { x, y, w: 0.5, h: 0.5, fill: { color }, rectRadius: 0.03 });
    slide.addText(`#${color}`, {
        x, y: y + 0.55, w: 0.5, h: 0.2,
        fontFace: ORANGE_FONTS.body, fontSize: 7, bold: true,
        color: ORANGE_COLORS.primary.grayDark, align: 'center',
        shrinkText: true, bullet: false
    });
    slide.addText(label, {
        x, y: y + 0.75, w: 0.5, h: 0.2,
        fontFace: ORANGE_FONTS.body, fontSize: 7, bold: true,
        color: ORANGE_COLORS.primary.grayDark, align: 'center',
        shrinkText: true, bullet: false
    });
}

async function generate() {
    const { pres } = createOrangePres('Guide du template Orange — VoC DEF', 'blanc');

    // ==========================================
    // SLIDE 1 — TITRE
    // ==========================================
    slideN++;
    addTitleSlide(pres,
        'Guide du template\nOrange',
        'Voix du Client — Direction Entreprises France',
        THEME,
        { sideText: 'Fevrier 2026\nBonnes pratiques\npour vos presentations' }
    );

    // ==========================================
    // SLIDE 2 — POURQUOI CE GUIDE
    // ==========================================
    const s2 = S(pres);
    H(s2, 'Pourquoi ce guide ?');

    Body(s2, [
        "L'equipe VoC DEF produit regulierement des presentations pour des audiences variees : comites de direction, equipes metier, partenaires internes (GP, DSI, Juridique).",
        "Ce guide presente les regles du template officiel Orange afin d'assurer une identite visuelle coherente et professionnelle sur tous nos supports.",
        "Source : templates officiels OFR (brand.orange.com), analyses et validation par la direction de la communication Orange."
    ], { fontSize: 13 });

    // ==========================================
    // SLIDE 3 — LES DEUX VARIANTES
    // ==========================================
    const s3 = S(pres);
    H(s3, 'Deux variantes disponibles');

    // Variante Fond noir
    Box(s3, POS.body.x, POS.body.y, 4.2, 2.5, '000000');
    BoxText(s3, 'Fond noir', POS.body.x + 0.2, POS.body.y + 0.15, 3.8, 0.35,
        { color: ORANGE_COLORS.primary.orange, fontSize: 14, align: 'left' });
    BoxText(s3, 'Eco-branding digital', POS.body.x + 0.2, POS.body.y + 0.5, 3.8, 0.25,
        { color: ORANGE_COLORS.primary.grayMedium, fontSize: 10, align: 'left' });

    const noirItems = ['Presentations sur ecran', 'Webinaires et visioconferences', 'Dashboards et restitutions BI', 'Usage recommande par defaut'];
    noirItems.forEach((t, i) => {
        BoxText(s3, '–  ' + t, POS.body.x + 0.2, POS.body.y + 0.85 + i * 0.35, 3.8, 0.3,
            { color: ORANGE_COLORS.primary.white, fontSize: 11, align: 'left' });
    });

    // Variante Fond blanc
    Box(s3, 5.15, POS.body.y, 4.2, 2.5, 'F5F5F5');
    BoxText(s3, 'Fond blanc', 5.35, POS.body.y + 0.15, 3.8, 0.35,
        { color: ORANGE_COLORS.primary.orange, fontSize: 14, align: 'left' });
    BoxText(s3, 'Impressions et contexte externe', 5.35, POS.body.y + 0.5, 3.8, 0.25,
        { color: ORANGE_COLORS.primary.grayDark, fontSize: 10, align: 'left' });

    const blancItems = ['Documents imprimes', 'Presentations externes', 'Supports partages par email', 'Contexte ou le noir est inadapte'];
    blancItems.forEach((t, i) => {
        BoxText(s3, '–  ' + t, 5.35, POS.body.y + 0.85 + i * 0.35, 3.8, 0.3,
            { color: ORANGE_COLORS.primary.black, fontSize: 11, align: 'left' });
    });

    // Callout (au-dessus de la zone logo)
    Box(s3, POS.body.x, 3.9, 8.97, 0.4, 'F5F5F5');
    s3.addShape('rect', { x: POS.body.x, y: 3.9, w: 0.06, h: 0.4, fill: { color: ORANGE_COLORS.primary.orange } });
    BoxText(s3, 'Seules differences : couleur de fond et couleurs du texte. Positions, fonts, bullets et logo sont identiques.',
        POS.body.x + 0.2, 3.9, 8.6, 0.4, { fontSize: 11, color: ORANGE_COLORS.primary.grayDark, align: 'left' });

    // ==========================================
    // SLIDE 4 — PALETTE DE COULEURS
    // ==========================================
    const s4 = S(pres);
    H(s4, 'Palette de couleurs officielle');

    // Primaires
    BoxText(s4, 'Couleurs principales (80% minimum)', POS.body.x, POS.body.y, 4, 0.3,
        { color: ORANGE_COLORS.primary.orange, fontSize: 12, align: 'left' });

    const primaries = [
        { color: 'FF7900', label: 'Orange' },
        { color: '000000', label: 'Noir' },
        { color: 'FFFFFF', label: 'Blanc' },
        { color: '595959', label: 'Gris F.' },
        { color: '8F8F8F', label: 'Gris M.' },
        { color: 'D6D6D6', label: 'Gris C.' },
    ];
    primaries.forEach((p, i) => {
        const swatchX = POS.body.x + i * 0.75;
        ColorSwatch(s4, p.color, p.label, swatchX, POS.body.y + 0.4);
    });

    // Secondaires
    BoxText(s4, 'Couleurs secondaires (20% maximum)', POS.body.x, POS.body.y + 1.5, 4, 0.3,
        { color: ORANGE_COLORS.primary.orange, fontSize: 12, align: 'left' });

    const secondaries = [
        { color: '4BB4E6', label: 'Bleu' },
        { color: '50BE87', label: 'Vert' },
        { color: 'FFB4E6', label: 'Rose' },
        { color: 'FFD200', label: 'Jaune' },
        { color: 'A885D8', label: 'Pourpre' },
    ];
    secondaries.forEach((p, i) => {
        ColorSwatch(s4, p.color, p.label, POS.body.x + i * 0.75, POS.body.y + 1.9);
    });

    // Regles textuelles
    Box(s4, 5.5, POS.body.y, 4.15, 3.5, 'F5F5F5');
    BoxText(s4, 'Regles couleurs', 5.7, POS.body.y + 0.1, 3.75, 0.3,
        { color: ORANGE_COLORS.primary.orange, fontSize: 12, align: 'left' });

    const colorRules = [
        '80% de couleurs principales minimum',
        '20% de couleurs secondaires maximum',
        'Orange #FF7900 = couleur emblematique',
        'Titres toujours en orange',
        'Texte corps : noir (fond blanc) ou blanc (fond noir)',
        'Jamais de couleurs hors palette'
    ];
    colorRules.forEach((t, i) => {
        BoxText(s4, '–  ' + t, 5.7, POS.body.y + 0.5 + i * 0.4, 3.75, 0.35,
            { color: ORANGE_COLORS.primary.black, fontSize: 10, align: 'left' });
    });

    // ==========================================
    // SLIDE 5 — TYPOGRAPHIE ET TAILLES
    // ==========================================
    const s5 = S(pres);
    H(s5, 'Typographie et tailles officielles');

    // Tableau des tailles
    const fontRows = [
        ['Element', 'Taille', 'Font', 'Usage'],
        ['Titre (couverture/section)', '55pt', 'Helvetica 75 Bold', 'Slides de titre et sections'],
        ['Titre de contenu', '20pt', 'Helvetica 75 Bold', 'Toutes les slides de contenu'],
        ['Corps de texte', '14pt', 'Helvetica 75 Bold', 'Texte principal, bullets'],
        ['Niveaux 4-5', '14pt', 'Helvetica 55 Roman', 'Sous-details (rare)'],
        ['Numero de slide', '8pt', 'Helvetica 75 Bold', 'Bas-droite de chaque slide'],
    ];

    fontRows.forEach((row, idx) => {
        const isHeader = idx === 0;
        const y = POS.body.y + idx * 0.42;
        const bg = isHeader ? ORANGE_COLORS.primary.orange : (idx % 2 === 0 ? 'F5F5F5' : 'FFFFFF');
        const fg = isHeader ? ORANGE_COLORS.primary.white : ORANGE_COLORS.primary.black;
        const colWidths = [2.8, 0.8, 2.4, 3.3];
        let x = POS.body.x;
        row.forEach((cell, ci) => {
            Box(s5, x, y, colWidths[ci], 0.4, bg);
            BoxText(s5, cell, x, y, colWidths[ci], 0.4,
                { color: fg, fontSize: 10, align: ci === 0 ? 'left' : 'center', fontFace: isHeader ? ORANGE_FONTS.title : ORANGE_FONTS.body });
            x += colWidths[ci];
        });
    });

    // Regles interdites (au-dessus zone logo)
    Box(s5, POS.body.x, 3.9, 9.312, 0.5, 'F5F5F5');
    s5.addShape('rect', { x: POS.body.x, y: 3.9, w: 0.06, h: 0.5, fill: { color: 'CD3C14' } });
    BoxText(s5, 'Interdit', POS.body.x + 0.2, 3.9, 1.2, 0.22,
        { color: 'CD3C14', fontSize: 12, align: 'left' });
    BoxText(s5, 'Jamais d\'italique  |  Jamais de majuscules completes  |  Jamais de polices hors Helvetica/Arial  |  Line spacing: 85-90%',
        POS.body.x + 1.5, 3.9, 7.5, 0.22, { color: ORANGE_COLORS.primary.grayDark, fontSize: 10, align: 'left' });
    BoxText(s5, 'Fallback Arial si Helvetica indisponible  |  Pas de bande orange en haut  |  Logo toujours bas-gauche',
        POS.body.x + 0.2, 4.15, 8.8, 0.22, { color: ORANGE_COLORS.primary.grayDark, fontSize: 10, align: 'left' });

    // ==========================================
    // SLIDE 6 — BULLETS ET MISE EN FORME
    // ==========================================
    const s6 = S(pres);
    H(s6, 'Puces et mise en forme du texte');

    // Tableau bullets
    BoxText(s6, 'Regles de puces par niveau', POS.body.x, POS.body.y, 4, 0.3,
        { color: ORANGE_COLORS.primary.orange, fontSize: 12, align: 'left' });

    const bulletRules = [
        { level: 'Niveau 1', bullet: 'Aucune puce', desc: 'Texte en orange ou blanc, sans puce' },
        { level: 'Niveau 2', bullet: 'Tiret "–" (U+2013)', desc: 'Texte noir ou blanc, indentation' },
        { level: 'Niveau 3', bullet: 'Section "§" (U+00A7)', desc: 'Puce en orange' },
        { level: 'Niveaux 4-5', bullet: 'Tiret "–"', desc: 'Helvetica 55 Roman' },
    ];

    bulletRules.forEach((r, i) => {
        const y = POS.body.y + 0.45 + i * 0.6;
        Box(s6, POS.body.x, y, 4.2, 0.55, 'F5F5F5');
        BoxText(s6, r.level, POS.body.x + 0.15, y + 0.02, 1.5, 0.25,
            { color: ORANGE_COLORS.primary.orange, fontSize: 11, align: 'left' });
        BoxText(s6, r.bullet, POS.body.x + 1.6, y + 0.02, 1.8, 0.25,
            { color: ORANGE_COLORS.primary.black, fontSize: 11, align: 'left' });
        BoxText(s6, r.desc, POS.body.x + 0.15, y + 0.28, 3.9, 0.22,
            { color: ORANGE_COLORS.primary.grayDark, fontSize: 9, align: 'left' });
    });

    // Logo et position
    BoxText(s6, 'Logo et elements fixes', 5.5, POS.body.y, 4, 0.3,
        { color: ORANGE_COLORS.primary.orange, fontSize: 12, align: 'left' });

    Box(s6, 5.5, POS.body.y + 0.4, 4.15, 2.8, 'F5F5F5');

    // Mini schema slide
    Box(s6, 5.8, POS.body.y + 0.6, 3.5, 2.0, 'EEEEEE');
    BoxText(s6, 'Titre (20pt orange)', 5.95, POS.body.y + 0.7, 2.5, 0.3,
        { color: ORANGE_COLORS.primary.orange, fontSize: 9, align: 'left' });
    BoxText(s6, 'Corps du texte (14pt)', 5.95, POS.body.y + 1.1, 2.5, 0.2,
        { color: ORANGE_COLORS.primary.grayDark, fontSize: 8, align: 'left' });

    // Logo position indicator
    s6.addShape('rect', {
        x: 5.95, y: POS.body.y + 2.15, w: 0.3, h: 0.3,
        fill: { color: ORANGE_COLORS.primary.orange }
    });
    BoxText(s6, 'Logo', 6.3, POS.body.y + 2.15, 0.8, 0.3,
        { color: ORANGE_COLORS.primary.grayDark, fontSize: 8, align: 'left' });

    BoxText(s6, 'N°', 8.8, POS.body.y + 2.15, 0.3, 0.3,
        { color: ORANGE_COLORS.primary.grayMedium, fontSize: 7, align: 'right' });
    BoxText(s6, 'Slide #', 8.0, POS.body.y + 2.35, 1.1, 0.2,
        { color: ORANGE_COLORS.primary.grayDark, fontSize: 8, align: 'right' });

    BoxText(s6, 'Positions cles :', 5.7, POS.body.y + 2.8, 3.7, 0.2,
        { color: ORANGE_COLORS.primary.black, fontSize: 9, align: 'left' });
    BoxText(s6, 'Logo: bas-gauche (0.34", 4.63") 0.67"x0.67"\nSlide #: bas-droite (9.35", 4.96") 8pt',
        5.7, POS.body.y + 3.0, 3.7, 0.35,
        { color: ORANGE_COLORS.primary.grayDark, fontSize: 8, align: 'left', valign: 'top' });

    // ==========================================
    // SLIDE 7 — LES 4 TYPES DE SLIDES
    // ==========================================
    const s7 = S(pres);
    H(s7, 'Les 4 types de slides principaux');

    const types = [
        { title: 'Couverture', desc: 'Titre 55pt\nSous-titre 18pt\nTexte lateral\nLogo bas-gauche', color: 'F5F5F5', accent: ORANGE_COLORS.primary.orange },
        { title: 'Section', desc: 'Numero 55pt\nTitre 55pt\nPlein ecran\nLogo bas-gauche', color: 'F5F5F5', accent: ORANGE_COLORS.primary.orange },
        { title: 'Contenu', desc: 'Titre 20pt orange\nCorps 14pt\nSlide number\nLogo bas-gauche', color: 'F5F5F5', accent: ORANGE_COLORS.secondary.blue },
        { title: 'Fin', desc: '"Merci" ou\n"Questions ?" 55pt\nCentre vertical\nLogo bas-gauche', color: 'F5F5F5', accent: ORANGE_COLORS.secondary.green },
    ];

    types.forEach((t, i) => {
        const x = POS.body.x + i * 2.35;
        Box(s7, x, POS.body.y, 2.2, 2.5, t.color);
        s7.addShape('rect', { x, y: POS.body.y, w: 2.2, h: 0.06, fill: { color: t.accent } });
        BoxText(s7, t.title, x + 0.1, POS.body.y + 0.15, 2.0, 0.3,
            { color: t.accent, fontSize: 14, align: 'left' });
        BoxText(s7, t.desc, x + 0.1, POS.body.y + 0.55, 2.0, 1.7,
            { color: ORANGE_COLORS.primary.grayDark, fontSize: 10, align: 'left', valign: 'top' });
    });

    // Note (au-dessus zone logo)
    Box(s7, POS.body.x, 3.9, 9.312, 0.4, 'F5F5F5');
    s7.addShape('rect', { x: POS.body.x, y: 3.9, w: 0.06, h: 0.4, fill: { color: ORANGE_COLORS.primary.orange } });
    BoxText(s7, 'Autres layouts disponibles : Deux contenus (2 colonnes), Titre seul, Image pleine page, Vide, Sommaire (TOC)',
        POS.body.x + 0.2, 3.9, 8.8, 0.4, { color: ORANGE_COLORS.primary.grayDark, fontSize: 11, align: 'left' });

    // ==========================================
    // SLIDE 8 — QUESTIONS
    // ==========================================
    slideN++;
    addEndSlide(pres, 'Questions ?', THEME);

    // ==========================================
    // EXPORT
    // ==========================================
    const outputPath = 'C:\\Users\\PGNK2128\\Downloads\\Guide_Template_Orange_VoC_DEF_v2.pptx';
    await pres.writeFile({ fileName: outputPath });
    console.log(`Presentation generee : ${outputPath}`);
    console.log('8 slides — Guide template Orange (fond blanc)');
}

generate().catch(err => {
    console.error('Erreur:', err);
    process.exit(1);
});
