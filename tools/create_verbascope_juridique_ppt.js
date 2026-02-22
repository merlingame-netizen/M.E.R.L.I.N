/**
 * Verbascope DEF — Presentation pour le Juridique
 * ISO template officiel Orange (fond noir)
 * Usage: node tools/create_verbascope_juridique_ppt.js
 *
 * 18 slides — Positions, fonts, bullets conformes au .potx officiel
 * Sortie: C:\Users\PGNK2128\Downloads\Verbascope_DEF_Juridique_v5.pptx
 */

const {
    ORANGE_COLORS,
    ORANGE_FONTS,
    POS,
    getTheme,
    createOrangePres,
    addOrangeLogo,
    addSlideNumber,
    addTitleSlide,
    addSectionSlide,
    addEndSlide
} = require('./create_orange_ppt.js');

// ============================================
// THEME — FOND NOIR
// ============================================
const THEME = getTheme('noir');

// ============================================
// HELPERS INTERNES (adaptes fond noir)
// ============================================

let slideCounter = 0;

function S(pres) {
    slideCounter++;
    const slide = pres.addSlide();
    slide.background = { color: THEME.bg };
    addOrangeLogo(slide);
    addSlideNumber(slide, slideCounter, THEME);
    return slide;
}

function H(slide, text, opts = {}) {
    slide.addText(text, {
        x: opts.x || POS.title.x,
        y: opts.y || POS.title.y,
        w: opts.w || POS.title.w,
        h: opts.h || POS.title.h,
        fontFace: ORANGE_FONTS.title,
        fontSize: opts.fontSize || 20,
        bold: true,
        color: ORANGE_COLORS.primary.orange,
        lineSpacingPercent: 90,
        shrinkText: true,
        bullet: false
    });
}

function Bullets(slide, items, opts = {}) {
    const bulletItems = items.map(text => ({
        text: text,
        options: {
            fontFace: ORANGE_FONTS.body,
            fontSize: opts.fontSize || 14,
            bold: true,
            color: opts.color || THEME.bodyL1,
            bullet: false,
            paraSpaceBefore: 6,
            paraSpaceAfter: opts.paraSpaceAfter || 6
        }
    }));

    slide.addText(bulletItems, {
        x: opts.x || POS.body.x,
        y: opts.y || POS.body.y,
        w: opts.w || POS.body.w,
        h: opts.h || POS.body.h,
        valign: 'top',
        shrinkText: true
    });
}

function Callout(slide, text, opts = {}) {
    const y = opts.y || 4.05;
    const h = opts.h || 0.35;
    const bgColor = opts.bgColor || '333333';

    // Fond gris fonce (au-dessus zone logo)
    slide.addShape('rect', {
        x: POS.body.x, y: y, w: 8.3, h: h,
        fill: { color: bgColor },
        rectRadius: 0.05
    });
    // Barre orange a gauche
    slide.addShape('rect', {
        x: POS.body.x, y: y, w: 0.06, h: h,
        fill: { color: ORANGE_COLORS.primary.orange }
    });
    // Texte
    slide.addText(text, {
        x: POS.body.x + 0.2, y: y + 0.03, w: 7.9, h: h - 0.06,
        fontFace: ORANGE_FONTS.body,
        fontSize: 10,
        bold: true,
        color: ORANGE_COLORS.primary.white,
        shrinkText: true,
        bullet: false,
        valign: 'middle'
    });
}

function Box(slide, label, x, y, w, h, fillColor, textColor) {
    slide.addShape('rect', {
        x, y, w, h,
        fill: { color: fillColor || '2D2D2D' },
        rectRadius: 0.05
    });
    slide.addText(label, {
        x, y, w, h,
        fontFace: ORANGE_FONTS.body,
        fontSize: 9,
        bold: true,
        color: textColor || ORANGE_COLORS.primary.white,
        align: 'center',
        valign: 'middle',
        shrinkText: true,
        bullet: false
    });
}

function Arrow(slide, x, y, w) {
    slide.addShape('line', {
        x, y, w, h: 0,
        line: { color: ORANGE_COLORS.primary.grayMedium, width: 1.5, headEnd: { type: 'arrow' } }
    });
}

function ArrowDown(slide, x, y, h) {
    slide.addShape('line', {
        x, y, w: 0, h,
        line: { color: ORANGE_COLORS.primary.grayMedium, width: 1.5, headEnd: { type: 'arrow' } }
    });
}

function Table(slide, headers, rows, opts = {}) {
    const fontSize = opts.fontSize || 11;

    const headerRow = headers.map(h => ({
        text: h,
        options: {
            fontFace: ORANGE_FONTS.title,
            fontSize: fontSize,
            bold: true,
            color: ORANGE_COLORS.primary.white,
            fill: { color: ORANGE_COLORS.primary.orange },
            align: 'center',
            valign: 'middle'
        }
    }));

    const dataRows = rows.map((row, idx) => {
        const bg = idx % 2 === 0 ? '1A1A1A' : '000000';
        return row.map(cell => {
            if (typeof cell === 'object') {
                return {
                    text: cell.text,
                    options: {
                        fontFace: ORANGE_FONTS.body,
                        fontSize: cell.fontSize || fontSize,
                        color: cell.color || ORANGE_COLORS.primary.white,
                        fill: { color: cell.fill || bg },
                        bold: cell.bold || false,
                        align: cell.align || 'left',
                        valign: 'middle'
                    }
                };
            }
            return {
                text: cell,
                options: {
                    fontFace: ORANGE_FONTS.body,
                    fontSize: fontSize,
                    color: ORANGE_COLORS.primary.white,
                    fill: { color: bg },
                    align: 'left',
                    valign: 'middle'
                }
            };
        });
    });

    slide.addTable([headerRow, ...dataRows], {
        x: opts.x || POS.body.x,
        y: opts.y || POS.body.y,
        w: opts.w || 9.312,
        colW: opts.colW || headers.map(() => 9.312 / headers.length),
        rowH: opts.rowH || 0.4,
        border: { type: 'solid', pt: 0.5, color: '595959' },
        autoPage: false
    });
}

function ColBullets(slide, title, items, x, y, w) {
    slide.addText(title, {
        x, y, w, h: 0.4,
        fontFace: ORANGE_FONTS.title,
        fontSize: 14,
        bold: true,
        color: ORANGE_COLORS.primary.orange,
        shrinkText: true,
        bullet: false
    });

    const bulletItems = items.map(text => ({
        text: text,
        options: {
            fontFace: ORANGE_FONTS.body,
            fontSize: 12,
            bold: true,
            color: ORANGE_COLORS.primary.white,
            bullet: false,
            paraSpaceAfter: 6
        }
    }));

    slide.addText(bulletItems, {
        x, y: y + 0.45, w, h: 2.8,
        valign: 'top',
        shrinkText: true
    });
}

// ============================================
// GENERATION — 18 SLIDES
// ============================================

async function generate() {
    const { pres } = createOrangePres('Verbascope DEF — Presentation Juridique', 'noir');
    slideCounter = 0;

    // ==========================================
    // SLIDE 1 — TITRE
    // ==========================================
    slideCounter++;
    const s1 = pres.addSlide();
    s1.background = { color: THEME.bg };

    s1.addText('Verbascope\nBARO_DEF', {
        x: POS.titleBig.x, y: POS.titleBig.y,
        w: POS.titleBig.w, h: POS.titleBig.h,
        fontFace: ORANGE_FONTS.title,
        fontSize: 55,
        bold: true,
        color: ORANGE_COLORS.primary.white,
        lineSpacingPercent: 85,
        align: 'left', valign: 'top',
        shrinkText: true, bullet: false
    });

    s1.addText("Dispositif d'IA hybride pour la classification\nautomatisee des verbatims clients", {
        x: POS.subtitle.x, y: POS.subtitle.y,
        w: POS.subtitle.w, h: POS.subtitle.h,
        fontFace: ORANGE_FONTS.body,
        fontSize: 18,
        bold: true,
        color: ORANGE_COLORS.primary.orange,
        align: 'left', valign: 'top',
        shrinkText: true, bullet: false
    });

    s1.addText('Direction Entreprises France (DEF)\nEquipe Voix du Client\nFevrier 2026\n\nPresentation pour le juridique', {
        x: POS.sideText.x, y: POS.sideText.y,
        w: POS.sideText.w, h: POS.sideText.h,
        fontFace: ORANGE_FONTS.body,
        fontSize: 14,
        bold: true,
        color: ORANGE_COLORS.primary.grayMedium,
        align: 'left', valign: 'top',
        shrinkText: true, bullet: false
    });

    addOrangeLogo(s1);

    // ==========================================
    // SLIDE 2 — RESUME EXECUTIF
    // ==========================================
    const s2 = S(pres);
    H(s2, "Resume executif : l'industrialisation de l'ecoute client");

    const cols = [
        { title: '01. Le defi', items: [
            'Volume massif de verbatims (transactionnels, barometres Entreprises/ProPME)',
            'Traitements manuels lents et heterogenes',
            "Dependance a un prestataire externe (ERDIL) : boite noire, couts recurrents, rigidite"
        ], x: POS.body.x },
        { title: '02. La solution', items: [
            'Dispositif hybride : IA Generative (GPT-4o) + Deep Learning (CamemBERT)',
            'Synergie GP/DEF : framework Grand Public adapte aux specificites Entreprises',
            'Souverainete : hebergement GCP et Azure Europe exclusivement'
        ], x: 3.55 },
        { title: "03. L'impact", items: [
            'Maitrise : controle total de la taxonomie metier',
            'Vitesse : analyse en quasi temps reel via API',
            'Cout : reduction drastique vs. prestataire et Full LLM (~10x moins cher en run)'
        ], x: 6.55 }
    ];

    cols.forEach(col => {
        const colW = 2.8;
        slide_addColBox(s2, col.title, col.items, col.x, POS.body.y, colW);
    });

    Callout(s2, "Remplacement d'ERDIL : passage d'un service externe opaque a un processus interne transparent et maitrise", { y: 4.1 });

    // ==========================================
    // SLIDE 3 — SECTION 01
    // ==========================================
    slideCounter++;
    addSectionSlide(pres, 'Mutualisation\nGrand Public / DEF', 1, THEME);

    // ==========================================
    // SLIDE 4 — GP / DEF
    // ==========================================
    const s4 = S(pres);
    H(s4, "De l'isolation a la mutualisation strategique");

    // Boite GP
    s4.addShape('rect', { x: POS.body.x, y: POS.body.y, w: 4.2, h: 2.6, fill: { color: '2D2D2D' }, rectRadius: 0.05 });
    s4.addText('Grand Public (GP)', {
        x: POS.body.x + 0.2, y: POS.body.y + 0.1, w: 3.8, h: 0.35,
        fontFace: ORANGE_FONTS.title, fontSize: 14, bold: true,
        color: ORANGE_COLORS.primary.orange, shrinkText: true, bullet: false
    });
    s4.addText('Proprietaire du framework', {
        x: POS.body.x + 0.2, y: POS.body.y + 0.45, w: 3.8, h: 0.25,
        fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
        color: ORANGE_COLORS.primary.grayMedium, shrinkText: true, bullet: false
    });
    const gpItems = [
        'Infrastructure GCP (BigQuery, Cloud Storage)',
        'Librairies py-verbascope / py-verbacore',
        'Modelisation Deep Learning (CamemBERT)',
        'Deploiement API (FastAPI, Cloud Run)'
    ].map(t => ({ text: t, options: {
        fontFace: ORANGE_FONTS.body, fontSize: 11, bold: true,
        color: ORANGE_COLORS.primary.white,
        bullet: { type: 'bullet', characterCode: '2013', color: ORANGE_COLORS.primary.grayMedium },
        paraSpaceAfter: 5
    }}));
    s4.addText(gpItems, { x: POS.body.x + 0.2, y: POS.body.y + 0.75, w: 3.8, h: 1.6, valign: 'top', shrinkText: true });

    // Boite DEF
    const defX = 5.15;
    s4.addShape('rect', { x: defX, y: POS.body.y, w: 4.2, h: 2.6, fill: { color: '2D2D2D' }, rectRadius: 0.05 });
    s4.addText('DEF (Entreprises)', {
        x: defX + 0.2, y: POS.body.y + 0.1, w: 3.8, h: 0.35,
        fontFace: ORANGE_FONTS.title, fontSize: 14, bold: true,
        color: ORANGE_COLORS.primary.orange, shrinkText: true, bullet: false
    });
    s4.addText('Utilisateur Data Science', {
        x: defX + 0.2, y: POS.body.y + 0.45, w: 3.8, h: 0.25,
        fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
        color: ORANGE_COLORS.primary.grayMedium, shrinkText: true, bullet: false
    });
    const defItems = [
        'Logique metier et taxonomie VoC',
        'Phase IAG (extraction / classification)',
        'Definition de la nomenclature',
        'Validation et controle qualite'
    ].map(t => ({ text: t, options: {
        fontFace: ORANGE_FONTS.body, fontSize: 11, bold: true,
        color: ORANGE_COLORS.primary.white,
        bullet: { type: 'bullet', characterCode: '2013', color: ORANGE_COLORS.primary.grayMedium },
        paraSpaceAfter: 5
    }}));
    s4.addText(defItems, { x: defX + 0.2, y: POS.body.y + 0.75, w: 3.8, h: 1.6, valign: 'top', shrinkText: true });

    // Plateforme commune (au-dessus zone logo)
    Box(s4, 'Qualtrics (plateforme commune)', 3.5, 3.95, 3, 0.4, ORANGE_COLORS.primary.orange, ORANGE_COLORS.primary.white);
    ArrowDown(s4, 4.0, 3.78, 0.17);
    ArrowDown(s4, 6.0, 3.78, 0.17);

    // Texte integre sous la plateforme (pas de callout separe pour eviter debordement)
    s4.addText("GP fournit le framework technique, DEF apporte l'expertise metier et la gouvernance des nomenclatures", {
        x: POS.body.x, y: 4.38, w: 8.3, h: 0.2,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.primary.grayMedium,
        shrinkText: true, bullet: false
    });

    // ==========================================
    // SLIDE 5 — ARCHITECTURE HYBRIDE
    // ==========================================
    const s5 = S(pres);
    H(s5, "L'architecture hybride : le meilleur des deux mondes");

    // Phase 1
    const p1X = POS.body.x;
    s5.addShape('rect', { x: p1X, y: POS.body.y, w: 4.2, h: 2.8, fill: { color: '1A2A3A' }, rectRadius: 0.05 });
    s5.addText('Phase 1 : Intelligence', {
        x: p1X + 0.15, y: POS.body.y + 0.1, w: 3.9, h: 0.35,
        fontFace: ORANGE_FONTS.title, fontSize: 14, bold: true,
        color: ORANGE_COLORS.secondary.blue, shrinkText: true, bullet: false
    });
    s5.addText('Flux batch / offline', {
        x: p1X + 0.15, y: POS.body.y + 0.45, w: 3.9, h: 0.2,
        fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
        color: ORANGE_COLORS.primary.grayMedium, shrinkText: true, bullet: false
    });
    const ph1Items = [
        'Technologie : IA Generative (GPT-4o via Azure OpenAI)',
        "Role : comprendre le texte, gerer les ambiguites, creer le Gold Standard",
        "Haute capacite cognitive, utilisee uniquement pour creer le jeu d'entrainement"
    ].map(t => ({ text: t, options: {
        fontFace: ORANGE_FONTS.body, fontSize: 11, bold: true,
        color: ORANGE_COLORS.primary.white,
        bullet: { type: 'bullet', characterCode: '2013', color: ORANGE_COLORS.secondary.blue },
        paraSpaceAfter: 5
    }}));
    s5.addText(ph1Items, { x: p1X + 0.15, y: POS.body.y + 0.7, w: 3.9, h: 1.5, valign: 'top', shrinkText: true });
    Box(s5, "Le LLM enseigne au modele", p1X + 0.3, 3.65, 3.6, 0.3, ORANGE_COLORS.secondary.blue, ORANGE_COLORS.primary.white);

    // Phase 2
    const p2X = 5.15;
    s5.addShape('rect', { x: p2X, y: POS.body.y, w: 4.2, h: 2.8, fill: { color: '1A2D1A' }, rectRadius: 0.05 });
    s5.addText('Phase 2 : Industrialisation', {
        x: p2X + 0.15, y: POS.body.y + 0.1, w: 3.9, h: 0.35,
        fontFace: ORANGE_FONTS.title, fontSize: 14, bold: true,
        color: ORANGE_COLORS.secondary.green, shrinkText: true, bullet: false
    });
    s5.addText('Flux online / temps reel', {
        x: p2X + 0.15, y: POS.body.y + 0.45, w: 3.9, h: 0.2,
        fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
        color: ORANGE_COLORS.primary.grayMedium, shrinkText: true, bullet: false
    });
    const ph2Items = [
        'Technologie : Deep Learning (CamemBERT fine-tune)',
        'Role : predire les labels a grande echelle en production',
        'Vitesse extreme (ms), cout marginal faible, stabilite, souverainete'
    ].map(t => ({ text: t, options: {
        fontFace: ORANGE_FONTS.body, fontSize: 11, bold: true,
        color: ORANGE_COLORS.primary.white,
        bullet: { type: 'bullet', characterCode: '2013', color: ORANGE_COLORS.secondary.green },
        paraSpaceAfter: 5
    }}));
    s5.addText(ph2Items, { x: p2X + 0.15, y: POS.body.y + 0.7, w: 3.9, h: 1.5, valign: 'top', shrinkText: true });
    Box(s5, "Le modele sert le metier", p2X + 0.3, 3.65, 3.6, 0.3, ORANGE_COLORS.secondary.green, ORANGE_COLORS.primary.white);

    // Fleche entre phases
    Arrow(s5, p1X + 4.2, 2.7, 0.95);

    Callout(s5, "L'IAG n'est utilisee qu'en parametrage (batch) pour creer le jeu d'entrainement. En production, seul CamemBERT tourne.", { y: 4.1 });

    // ==========================================
    // SLIDE 6 — ARCHITECTURE TECHNIQUE
    // ==========================================
    const s6 = S(pres);
    H(s6, 'Architecture technique de bout en bout');

    const bw = 1.5;
    const gap = 0.2;
    const r1 = [
        { label: 'Qualtrics', x: 0.3, fill: '3D3D3D' },
        { label: 'BigQuery', x: 2.0, fill: '3D3D3D' },
        { label: 'Azure OpenAI\n(GPT-4o)', x: 3.7, fill: '1A2A3A' },
        { label: 'Validation\nhumaine', x: 5.4, fill: ORANGE_COLORS.primary.orange },
        { label: 'GCS Dataset\n(labellise)', x: 7.1, fill: '1A2D1A' },
    ];
    r1.forEach(b => Box(s6, b.label, b.x, POS.body.y, bw, 0.8, b.fill, ORANGE_COLORS.primary.white));

    Arrow(s6, 0.3 + bw, POS.body.y + 0.4, gap);
    Arrow(s6, 2.0 + bw, POS.body.y + 0.4, gap);
    Arrow(s6, 3.7 + bw, POS.body.y + 0.4, gap);
    Arrow(s6, 5.4 + bw, POS.body.y + 0.4, gap);

    s6.addText('Phase IAG (batch)', {
        x: 2.0, y: POS.body.y + 0.9, w: 5.0, h: 0.25,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.secondary.blue, shrinkText: true, bullet: false
    });

    const r2 = [
        { label: 'GPU Compute\n(CamemBERT)', x: 3.7, fill: '1A2A3A' },
        { label: 'API FastAPI\n(Cloud Run)', x: 5.4, fill: '1A2D1A' },
        { label: 'Dashboards BI\n(VoC)', x: 7.1, fill: ORANGE_COLORS.secondary.green },
    ];
    r2.forEach(b => Box(s6, b.label, b.x, 3.0, bw, 0.8, b.fill, ORANGE_COLORS.primary.white));

    Arrow(s6, 3.7 + bw, 3.4, gap);
    Arrow(s6, 5.4 + bw, 3.4, gap);
    ArrowDown(s6, 4.45, POS.body.y + 0.8, 1.4);

    s6.addText('Phase training + inference', {
        x: 3.7, y: 3.9, w: 5.0, h: 0.25,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.secondary.green, shrinkText: true, bullet: false
    });

    const tools = [
        { label: 'Orchestration\nLangChain, LiteLLM', x: POS.body.x },
        { label: 'Observabilite\nLangfuse (audit)', x: 3.55 },
        { label: 'Stockage\nCloud Storage', x: 6.55 },
    ];
    tools.forEach(t => {
        Box(s6, t.label, t.x, 3.85, 2.5, 0.4, '2D2D2D', ORANGE_COLORS.primary.grayLight);
    });

    // ==========================================
    // SLIDE 7 — SECTION 02
    // ==========================================
    slideCounter++;
    addSectionSlide(pres, 'Le processus\net nos controles', 2, THEME);

    // ==========================================
    // SLIDE 8 — WORKFLOW IAG (4 etapes)
    // ==========================================
    const s8 = S(pres);
    H(s8, 'Workflow IAG : les 4 etapes (responsabilite DEF)');

    const stepW = 2.1;
    const stepGap = 0.2;
    const stepSpacing = stepW + stepGap;
    const steps = [
        { num: '1', title: 'Extraction', desc: 'Requetes SQL sur BigQuery\n(ID Client, Date, Verbatim,\nNote SAT)', color: '3D3D3D' },
        { num: '2', title: 'Themes (GPT-4o)', desc: 'Extraction de 3-4 themes\ncausaux par verbatim\n(temperature = 0)', color: '1A2A3A' },
        { num: '3', title: 'Validation', desc: 'Controle humain sur\n50-200 echantillons\n(boucle iterative)', color: ORANGE_COLORS.primary.orange },
        { num: '4', title: 'Classification', desc: 'Mapping vers nomenclature\nmetier (Cat1 > Cat2 >\nCat3 > Label)', color: '1A2D1A' },
    ];

    steps.forEach((st, i) => {
        const x = 0.4 + i * stepSpacing;
        const numY = POS.body.y;
        const boxY = POS.body.y + 0.7;
        const boxH = 1.4;

        // Numero
        s8.addShape('rect', { x, y: numY, w: 0.45, h: 0.45, fill: { color: ORANGE_COLORS.primary.orange }, rectRadius: 0.22 });
        s8.addText(st.num, {
            x, y: numY, w: 0.45, h: 0.45,
            fontFace: ORANGE_FONTS.title, fontSize: 16, bold: true,
            color: ORANGE_COLORS.primary.white, align: 'center', valign: 'middle',
            shrinkText: true, bullet: false
        });

        // Titre
        s8.addText(st.title, {
            x: x + 0.5, y: numY, w: 1.5, h: 0.45,
            fontFace: ORANGE_FONTS.title, fontSize: 12, bold: true,
            color: ORANGE_COLORS.primary.white, valign: 'middle',
            shrinkText: true, bullet: false
        });

        // Boite contenu
        s8.addShape('rect', { x, y: boxY, w: stepW, h: boxH, fill: { color: st.color }, rectRadius: 0.05 });
        s8.addText(st.desc, {
            x: x + 0.1, y: boxY + 0.1, w: stepW - 0.2, h: boxH - 0.2,
            fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
            color: ORANGE_COLORS.primary.white,
            valign: 'top', shrinkText: true, bullet: false
        });
    });

    // Fleches entre boites
    const arrowY = POS.body.y + 0.7 + 0.7;
    for (let i = 0; i < 3; i++) {
        Arrow(s8, 0.4 + stepW + i * stepSpacing, arrowY, stepGap);
    }

    // Exemple concret (au-dessus zone logo)
    const exY = 3.45;
    s8.addShape('rect', { x: 0.4, y: exY, w: 8.3, h: 0.9, fill: { color: '2D2D2D' }, rectRadius: 0.05 });

    s8.addText('Exemple concret', {
        x: 0.6, y: exY + 0.05, w: 3, h: 0.2,
        fontFace: ORANGE_FONTS.title, fontSize: 10, bold: true,
        color: ORANGE_COLORS.primary.orange, shrinkText: true, bullet: false
    });

    s8.addText("Verbatim :", {
        x: 0.6, y: exY + 0.28, w: 0.9, h: 0.18,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.primary.grayLight, shrinkText: true, bullet: false
    });
    s8.addText("\"Ca fait 2 mois que rien n'est installe ! Mon TPE est toujours en panne.\"", {
        x: 1.5, y: exY + 0.28, w: 3.5, h: 0.18,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.primary.white, shrinkText: true, bullet: false
    });

    s8.addText("Themes extraits :", {
        x: 0.6, y: exY + 0.5, w: 1.4, h: 0.18,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.primary.grayLight, shrinkText: true, bullet: false
    });
    s8.addText("Retard d'installation | Panne du TPE", {
        x: 2.0, y: exY + 0.5, w: 2.5, h: 0.18,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.primary.white, shrinkText: true, bullet: false
    });

    s8.addText("Labels metier :", {
        x: 5.2, y: exY + 0.28, w: 1.4, h: 0.18,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.secondary.green, shrinkText: true, bullet: false
    });
    s8.addText("Parcours > Installation > Retard\nProduit > TPE > Panne", {
        x: 5.2, y: exY + 0.5, w: 3.4, h: 0.35,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.secondary.green, shrinkText: true, bullet: false
    });

    // ==========================================
    // SLIDE 9 — GOUVERNANCE NOMENCLATURE
    // ==========================================
    const s9 = S(pres);
    H(s9, 'Gouvernance de la nomenclature et qualite');

    ColBullets(s9, 'Cycle de gouvernance', [
        'Revue metier trimestrielle ou semestrielle',
        'Versioning obligatoire (fichiers horodates)',
        'Archivage des versions precedentes pour audit',
        'Definitions claires pour chaque label'
    ], POS.body.x, POS.body.y, 4.2);

    ColBullets(s9, 'Controle qualite', [
        'Coherence verifiee sur echantillon temoin (50-200 verbatims)',
        'Traces Langfuse disponibles pour chaque run',
        'Archivage systematique pour audit',
        'Boucle iterative si resultats insatisfaisants'
    ], 5.15, POS.body.y, 4.2);

    // Separateur vertical
    s9.addShape('line', { x: 4.75, y: POS.body.y + 0.1, w: 0, h: 2.5, line: { color: '595959', width: 1 } });

    // KPI Autre (au-dessus zone logo)
    s9.addShape('rect', { x: POS.body.x, y: 3.55, w: 8.3, h: 0.8, fill: { color: '2D2D2D' }, rectRadius: 0.05 });
    s9.addShape('rect', { x: POS.body.x, y: 3.55, w: 0.06, h: 0.8, fill: { color: ORANGE_COLORS.primary.orange } });
    s9.addText("KPI critique : le taux \"Autre\"", {
        x: POS.body.x + 0.2, y: 3.58, w: 4, h: 0.22,
        fontFace: ORANGE_FONTS.title, fontSize: 11, bold: true,
        color: ORANGE_COLORS.primary.orange, shrinkText: true, bullet: false
    });
    s9.addText("Le label \"Autre\" est un signal d'alarme. Si son taux augmente, action requise : enrichir la nomenclature ou ajuster les few-shots. Ce KPI est suivi a chaque run.", {
        x: POS.body.x + 0.2, y: 3.82, w: 7.9, h: 0.45,
        fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
        color: ORANGE_COLORS.primary.white, shrinkText: true, bullet: false
    });

    // ==========================================
    // SLIDE 10 — SECTION 03
    // ==========================================
    slideCounter++;
    addSectionSlide(pres, 'Securite, souverainete\net conformite', 3, THEME);

    // ==========================================
    // SLIDE 11 — SECURITE (4 quadrants)
    // ==========================================
    const s11 = S(pres);
    H(s11, 'Securite, souverainete et observabilite');

    const quads = [
        { title: 'Residence des donnees', items: ["Utilisation exclusive d'Azure OpenAI Europe", 'Les donnees ne transitent pas par les US', 'Infrastructure GCP region Europe'], x: POS.body.x, y: POS.body.y },
        { title: 'Confidentialite', items: ['Pas de fine-tuning du modele GPT-4o', 'Usage en mode inference seule', 'GPT-4o stateless (aucune donnee conservee)'], x: 5.15, y: POS.body.y },
        { title: 'Tracabilite (Langfuse)', items: ['Log de chaque prompt et reponse', 'Suivi de la consommation de tokens (couts)', 'Audit de conformite et debug'], x: POS.body.x, y: 3.05 },
        { title: 'Gestion des acces', items: ['Habilitations strictes via GCP IAM', 'Principe du moindre privilege', 'Acces nominatifs, revision trimestrielle'], x: 5.15, y: 3.05 },
    ];

    quads.forEach(q => {
        s11.addShape('rect', { x: q.x, y: q.y, w: 4.2, h: 1.35, fill: { color: '2D2D2D' }, rectRadius: 0.05 });
        s11.addText(q.title, {
            x: q.x + 0.15, y: q.y + 0.08, w: 3.9, h: 0.25,
            fontFace: ORANGE_FONTS.title, fontSize: 11, bold: true,
            color: ORANGE_COLORS.primary.orange, shrinkText: true, bullet: false
        });
        const items = q.items.map(t => ({ text: t, options: {
            fontFace: ORANGE_FONTS.body, fontSize: 10, bold: true,
            color: ORANGE_COLORS.primary.white,
            bullet: { type: 'bullet', characterCode: '2013', color: ORANGE_COLORS.primary.grayMedium },
            paraSpaceAfter: 3
        }}));
        s11.addText(items, {
            x: q.x + 0.15, y: q.y + 0.35, w: 3.9, h: 0.9,
            valign: 'top', shrinkText: true
        });
    });

    // ==========================================
    // SLIDE 12 — TRACABILITE AUDIT
    // ==========================================
    const s12 = S(pres);
    H(s12, "Tracabilite detaillee et capacite d'audit");

    Table(s12,
        ['Composant', 'Mecanisme de tracabilite', 'Retention'],
        [
            ['Requetes GPT-4o', 'Langfuse (logs complets prompts + reponses)', '90 jours'],
            ['Validations humaines', 'BigQuery tables versionnees', 'Permanent'],
            ['Entrainements modele', 'MLflow / Vertex AI logs', '1 an'],
            ['Inferences production', 'Cloud Run logs + BigQuery', '90 jours'],
            ['Acces donnees', 'GCP IAM audit logs', '1 an'],
            ['Nomenclatures', 'GCS versioning (horodate)', 'Permanent']
        ],
        { y: POS.body.y, colW: [2.2, 4.8, 2.3], rowH: 0.37, fontSize: 11 }
    );

    Callout(s12, 'Tous les traitements sont auditables. Capacite de reproduire toute extraction ou classification a posteriori.', { bgColor: '1A2A3A', y: 3.95 });

    // ==========================================
    // SLIDE 13 — ANALYSE COMPARATIVE
    // ==========================================
    const s13 = S(pres);
    H(s13, 'Analyse comparative et benefices');

    const OK = { text: 'Elevee', color: ORANGE_COLORS.secondary.green, align: 'center' };
    const CTRL = { text: 'Maitrise', color: ORANGE_COLORS.secondary.green, align: 'center' };
    const TOT = { text: 'Totale', color: ORANGE_COLORS.secondary.green, align: 'center' };
    const GAR = { text: 'Garantie', color: ORANGE_COLORS.secondary.green, align: 'center' };

    Table(s13,
        ['Critere', 'Humain', 'ERDIL', 'Full LLM', 'Verbascope'],
        [
            [{ text: 'Scalabilite', bold: true }, { text: 'Faible', color: 'FF6347', align: 'center' }, { text: 'Moyenne', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, OK, OK],
            [{ text: 'Cout de run', bold: true }, { text: 'Tres eleve', color: 'FF6347', align: 'center' }, { text: 'Eleve', color: 'FF6347', align: 'center' }, { text: 'Eleve', color: 'FF6347', align: 'center' }, CTRL],
            [{ text: 'Flexibilite', bold: true }, { text: 'Moyenne', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, { text: 'Faible', color: 'FF6347', align: 'center' }, TOT, TOT],
            [{ text: 'Souverainete', bold: true }, { text: 'Oui', color: ORANGE_COLORS.secondary.green, align: 'center' }, { text: 'Variable', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, { text: 'Variable', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, GAR],
            [{ text: 'Transparence', bold: true }, { text: 'Oui', color: ORANGE_COLORS.secondary.green, align: 'center' }, { text: 'Non', color: 'FF6347', align: 'center' }, { text: 'Partielle', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, TOT],
            [{ text: 'Tracabilite', bold: true }, { text: 'Oui', color: ORANGE_COLORS.secondary.green, align: 'center' }, { text: 'Limitee', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, { text: 'Limitee', color: ORANGE_COLORS.secondary.yellow, align: 'center' }, TOT]
        ],
        { y: POS.body.y, colW: [1.8, 1.5, 1.5, 1.5, 3.0], rowH: 0.37, fontSize: 11 }
    );

    Callout(s13, "L'approche hybride est environ 10x moins couteuse en run que l'approche Full LLM, avec une latence plus faible et une souverainete garantie.", { y: 3.95 });

    // ==========================================
    // SLIDE 14 — SECTION 04
    // ==========================================
    slideCounter++;
    addSectionSlide(pres, 'Gouvernance\njuridique', 4, THEME);

    // ==========================================
    // SLIDE 15 — RACI
    // ==========================================
    const s15 = S(pres);
    H(s15, 'Matrice de responsabilites (RACI)');

    const R = { text: 'R', bold: true, color: ORANGE_COLORS.primary.orange, align: 'center' };
    const A = { text: 'A', bold: true, color: ORANGE_COLORS.secondary.green, align: 'center' };
    const Cc = { text: 'C', color: ORANGE_COLORS.primary.grayMedium, align: 'center' };
    const Ii = { text: 'I', color: ORANGE_COLORS.primary.grayLight, align: 'center' };
    const D = { text: '-', color: '595959', align: 'center' };

    Table(s15,
        ['Activite', 'GP', 'DEF (VoC)', 'DSI', 'Juridique'],
        [
            [{ text: 'Extraction themes (GPT-4o)', bold: true }, R, A, Cc, Ii],
            [{ text: 'Validation humaine', bold: true },         R, Cc, D, Ii],
            [{ text: 'Classification nomenclature', bold: true },Cc, R, D, Ii],
            [{ text: 'Entrainement CamemBERT', bold: true },     R, Cc, A, Ii],
            [{ text: 'Deploiement API production', bold: true },  R, Cc, A, Ii],
            [{ text: 'Dashboards BI', bold: true },              Cc, R, Cc, Ii],
            [{ text: 'Audits conformite', bold: true },          Cc, Cc, Cc, R],
            [{ text: 'Gouvernance nomenclature', bold: true },   Cc, R, D, Ii]
        ],
        { y: POS.body.y, colW: [3.3, 1.2, 1.5, 1.1, 1.2], rowH: 0.33, fontSize: 10 }
    );

    s15.addText('R = Responsable (realise)  |  A = Accountable (decide)  |  C = Consulte  |  I = Informe', {
        x: POS.body.x, y: 4.25, w: 8.3, h: 0.2,
        fontFace: ORANGE_FONTS.body, fontSize: 9, bold: true,
        color: ORANGE_COLORS.primary.grayMedium,
        shrinkText: true, bullet: false
    });

    // ==========================================
    // SLIDE 16 — POINTS D'ATTENTION JURIDIQUES
    // ==========================================
    const s16 = S(pres);
    H(s16, "Points d'attention pour le juridique");

    Bullets(s16, [
        "Contrat Azure OpenAI : verifier le DPA (Data Processing Agreement) pour la residence UE et la non-utilisation pour le fine-tuning",
        "Propriete intellectuelle : librairies py-verbascope et py-verbacore sont propriete GP — clarifier les droits d'usage DEF",
        "RGPD : les verbatims clients constituent des donnees personnelles potentielles — documenter la base legale du traitement",
        "Sous-traitance : Microsoft Azure est sous-traitant au sens RGPD — verifier les clauses contractuelles types",
        "Retention des logs : 90 jours pour Langfuse — est-ce suffisant pour vos besoins d'investigation ?",
        "Droit d'acces et d'effacement : definir la procedure pour les demandes RGPD des clients (ex: effacer un verbatim)"
    ], { y: POS.body.y, h: 2.6, fontSize: 12, paraSpaceAfter: 6 });

    Callout(s16, 'Revue juridique recommandee sur ces 6 points avant passage en production elargie', { y: 4.0 });

    // ==========================================
    // SLIDE 17 — PROCHAINES ETAPES
    // ==========================================
    const s17 = S(pres);
    H(s17, 'Prochaines etapes');

    const nextItems = [
        'Revue contractuelle Azure OpenAI (DPA, residence UE, clauses de non-reutilisation)',
        'Documentation de la base legale RGPD pour le traitement des verbatims',
        'Clarification de la propriete intellectuelle sur les librairies GP',
        'Validation des durees de retention des logs (90 jours suffisants ?)',
        'Procedure pour les demandes RGPD clients (acces, effacement)',
        'Go / No-Go juridique pour la mise en production elargie'
    ].map(t => ({ text: t, options: {
        fontFace: ORANGE_FONTS.body, fontSize: 14, bold: true,
        color: ORANGE_COLORS.primary.white,
        bullet: { type: 'bullet', characterCode: '2610', color: ORANGE_COLORS.primary.orange },
        paraSpaceAfter: 10
    }}));
    s17.addText(nextItems, {
        x: POS.body.x, y: POS.body.y, w: 9.312, h: 2.6,
        valign: 'top', shrinkText: true
    });

    Callout(s17, 'Contacts : DEF pour le cadrage metier et IAG  |  GP pour le framework et le modeling  |  Equipe VoC pour la nomenclature', { bgColor: '595959', y: 4.0 });

    // ==========================================
    // SLIDE 18 — QUESTIONS
    // ==========================================
    slideCounter++;
    addEndSlide(pres, 'Questions ?', THEME);

    // ==========================================
    // EXPORT
    // ==========================================
    const outputPath = 'C:\\Users\\PGNK2128\\Downloads\\Verbascope_DEF_Juridique_v6.pptx';
    await pres.writeFile({ fileName: outputPath });
    console.log(`Presentation generee : ${outputPath}`);
    console.log('18 slides — ISO template officiel Orange (fond noir)');
}

// Helper pour colonnes du resume executif
function slide_addColBox(slide, title, items, x, y, w) {
    slide.addShape('rect', { x, y, w, h: 2.7, fill: { color: '2D2D2D' }, rectRadius: 0.05 });
    slide.addText(title, {
        x: x + 0.15, y: y + 0.1, w: w - 0.3, h: 0.35,
        fontFace: ORANGE_FONTS.title, fontSize: 13, bold: true,
        color: ORANGE_COLORS.primary.orange,
        shrinkText: true, bullet: false
    });
    const bulletItems = items.map(t => ({ text: t, options: {
        fontFace: ORANGE_FONTS.body, fontSize: 11, bold: true,
        color: ORANGE_COLORS.primary.white,
        bullet: { type: 'bullet', characterCode: '2013', color: ORANGE_COLORS.primary.grayMedium },
        paraSpaceAfter: 5
    }}));
    slide.addText(bulletItems, {
        x: x + 0.15, y: y + 0.5, w: w - 0.3, h: 2.1,
        valign: 'top', shrinkText: true
    });
}

generate().catch(err => {
    console.error('Erreur lors de la generation :', err);
    process.exit(1);
});
