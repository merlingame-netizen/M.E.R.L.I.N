/**
 * Presentation Orange — Reorganisation Partage VOC/Data
 * Fond blanc, ~8 slides
 * Usage: node create_rangement_voc_ppt.js
 */

const path = require('path');
const {
    ORANGE_COLORS, ORANGE_FONTS, STYLES, POS, VISUAL, LOGO_SAFE_Y,
    createOrangePres, addTitleSlide, addContentSlide, addSectionSlide,
    addTwoColumnSlide, addEndSlide, addComparisonSlide, addCardGridSlide,
    addBadgeSlide, addCard, addInfoBox, addBadge, addOrangeLogo, addSlideNumber,
    formatBullet, getTheme
} = require('./create_orange_ppt.js');

const MODE = 'blanc';
const OUTPUT_DIR = path.join(process.env.USERPROFILE || '', 'Downloads');

async function generate() {
    const { pres, theme } = createOrangePres('Reorganisation Partage VOC/Data', MODE);

    // ========== SLIDE 1 — TITRE ==========
    addTitleSlide(pres, 'Reorganisation\nPartage VOC', 'Proposition de rangement ordonne', theme, {
        sideText: 'Fevrier 2026\nEquipe VoC Data'
    });

    // ========== SLIDE 2 — CONSTAT ==========
    const s2 = pres.addSlide();
    s2.background = { color: theme.bg };

    s2.addText('Constat : un dossier qui a grandi organiquement', {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    // Chiffres cles en badges
    const badges = [
        { x: 0.4, y: 1.3, w: 1.4, label: '15' },
        { x: 0.4, y: 1.8, w: 1.4, label: '7' },
        { x: 0.4, y: 2.3, w: 1.4, label: '0' }
    ];
    const badgeDescs = [
        'dossiers racine sans logique commune',
        'problemes identifies (nommage, doublons, archives)',
        'README pour guider les nouveaux arrivants'
    ];

    badges.forEach((b, i) => {
        addBadge(s2, { x: b.x, y: b.y, w: b.w, h: 0.35 }, b.label);
        s2.addText(badgeDescs[i], {
            x: b.x + b.w + 0.25, y: b.y,
            w: 7.5, h: 0.35,
            fontFace: ORANGE_FONTS.title, fontSize: 13, bold: true,
            color: ORANGE_COLORS.primary.black,
            align: 'left', valign: 'middle',
            shrinkText: true, bullet: false
        });
    });

    // Info box avec les problemes
    addInfoBox(s2, { x: 0.4, y: 3.0, w: 9.2, h: 1.3 },
        'Nommage incoherent (espaces, CAPS, accents)  |  Doublons Grilles IPSOS  |  Archives melees au contenu actif  |  Dossier vide (Dataiku)  |  Pas d\'index global  |  EDH multi-projets sans tri  |  Outils transversaux mal identifies'
    );

    addOrangeLogo(s2);
    addSlideNumber(s2, 2, theme);

    // ========== SLIDE 3 — PRINCIPES ==========
    addCardGridSlide(pres, '5 conventions de nommage', [
        {
            title: 'Prefixe numerique',
            body: '01_ECOUTE_CLIENT/\n02_ECOUTE_SALARIE/\n\u2192 Ordre visuel garanti'
        },
        {
            title: 'CAPS = categories',
            body: 'Racine en MAJUSCULES\nSous-dossiers en snake_case\n\u2192 Hierarchie lisible'
        },
        {
            title: 'Pas d\'espaces ni accents',
            body: 'Prevention_Detraction\n(pas "Prevention detraction")\n\u2192 Compatibilite scripts'
        },
        {
            title: '_archive en bas',
            body: 'Prefixe _ pour tri en fin\nSeparation actif / archive\n\u2192 Focus sur le courant'
        }
    ], theme, { slideNum: 3, cols: 4 });

    // ========== SLIDE 4 — AVANT / APRES ==========
    addComparisonSlide(pres, 'Avant / Apres',
        {
            title: 'Aujourd\'hui (15 dossiers)',
            body: '__PPT_Orange/\nBusiness Wan - Churn/\nCalcul NPS_MNPS/\nDASHBOARD PROPME/\nEcoute Client - LLM/\nEcoute Salarie - LLM/\nEDH/\nGCP/\nIA GEN/\nPrevention detraction/\nProjet dataiku.../\nQualtrics/\nTravaux cible IPSOS/\nVerbatim - Pistes.../\n\u2192 Noms heterogenes, pas d\'ordre',
            bodyColor: ORANGE_COLORS.primary.grayDark
        },
        {
            title: 'Demain (8 categories)',
            body: '00_OUTILS/\n01_ECOUTE_CLIENT/\n02_ECOUTE_SALARIE/\n03_CIBLAGE_IPSOS/\n04_SCORING_CHURN/\n05_DASHBOARDS/\n06_EDH/\n07_GCP/\n_archive/\nREADME.md\n\u2192 Numerote, lisible, coherent',
            bodyColor: ORANGE_COLORS.primary.black
        },
        theme,
        { slideNum: 4, infoBox: 'Principe : regrouper par domaine metier, separer archives, README a chaque niveau' }
    );

    // ========== SLIDE 5 — STRUCTURE CIBLE DETAILLEE ==========
    const s5 = pres.addSlide();
    s5.background = { color: theme.bg };

    s5.addText('Structure cible detaillee', {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    // 2 colonnes manuelles pour la structure
    const treeLeft = [
        { cat: '00_OUTILS/', items: 'PPT_Orange, Calcul_NPS, Qualtrics' },
        { cat: '01_ECOUTE_CLIENT/', items: 'Grilles_LLM, Verbascope, VOC_DEF' },
        { cat: '02_ECOUTE_SALARIE/', items: 'Grilles_LLM (salaries)' },
        { cat: '03_CIBLAGE_IPSOS/', items: 'App_Cible_v2, Notebooks, _archive' }
    ];
    const treeRight = [
        { cat: '04_SCORING_CHURN/', items: 'Business_Wan, Prevention_Detraction' },
        { cat: '05_DASHBOARDS/', items: 'ProPME (PowerBI)' },
        { cat: '06_EDH/', items: 'BCV, Reclamation, SAV, Ingestion' },
        { cat: '07_GCP/', items: 'Docs, presentations GCP' }
    ];

    const colStartY = 1.35;
    const rowH = 0.75;

    treeLeft.forEach((item, i) => {
        addBadge(s5, { x: 0.35, y: colStartY + i * rowH, w: 2.4, h: 0.28 }, item.cat, { fontSize: 9 });
        s5.addText(item.items, {
            x: 2.9, y: colStartY + i * rowH,
            w: 1.95, h: 0.6,
            fontFace: ORANGE_FONTS.title, fontSize: 10, bold: true,
            color: ORANGE_COLORS.primary.grayDark,
            align: 'left', valign: 'top',
            shrinkText: true, bullet: false,
            lineSpacingPercent: 90
        });
    });

    treeRight.forEach((item, i) => {
        addBadge(s5, { x: 5.2, y: colStartY + i * rowH, w: 2.4, h: 0.28 }, item.cat, { fontSize: 9 });
        s5.addText(item.items, {
            x: 7.75, y: colStartY + i * rowH,
            w: 1.85, h: 0.6,
            fontFace: ORANGE_FONTS.title, fontSize: 10, bold: true,
            color: ORANGE_COLORS.primary.grayDark,
            align: 'left', valign: 'top',
            shrinkText: true, bullet: false,
            lineSpacingPercent: 90
        });
    });

    // _archive en bas
    addInfoBox(s5, { x: 0.35, y: colStartY + 4 * rowH + 0.1, w: 9.3, h: 0.4 },
        '_archive/  +  README.md a chaque niveau  =  navigation intuitive et onboarding facilite'
    );

    addOrangeLogo(s5);
    addSlideNumber(s5, 5, theme);

    // ========== SLIDE 6 — BENEFICES ==========
    addCardGridSlide(pres, 'Benefices attendus', [
        {
            title: 'Navigation rapide',
            body: 'Tri numerique = ordre garanti\nMax 2 clics pour trouver\nun projet'
        },
        {
            title: 'Onboarding',
            body: 'README a chaque niveau\nUn nouvel arrivant comprend\nla structure en 5 min'
        },
        {
            title: 'Coherence',
            body: 'Convention unique :\nsnake_case, sans accents,\nsans espaces'
        },
        {
            title: 'Archivage clair',
            body: '_archive/ en bas de liste\nSeparation actif/historique\nPas de confusion'
        }
    ], theme, { slideNum: 6, cols: 4 });

    // ========== SLIDE 7 — PLAN D'ACTION ==========
    const s7 = pres.addSlide();
    s7.background = { color: theme.bg };

    s7.addText('Plan d\'action en 5 etapes', {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    const actions = [
        { num: '1', text: 'Creer les 8 dossiers numerotes + _archive/' },
        { num: '2', text: 'Deplacer les contenus vers la nouvelle structure' },
        { num: '3', text: 'Renommer fichiers/dossiers (snake_case, sans accents)' },
        { num: '4', text: 'Ajouter un README.md dans chaque dossier racine' },
        { num: '5', text: 'Supprimer les dossiers vides + doublons confirmes' }
    ];

    actions.forEach((a, i) => {
        const y = 1.35 + i * 0.62;
        // Numero en badge
        addBadge(s7, { x: 0.5, y, w: 0.5, h: 0.35 }, a.num);
        // Description
        s7.addText(a.text, {
            x: 1.2, y,
            w: 8.3, h: 0.35,
            fontFace: ORANGE_FONTS.title, fontSize: 14, bold: true,
            color: ORANGE_COLORS.primary.black,
            align: 'left', valign: 'middle',
            shrinkText: true, bullet: false
        });
    });

    addInfoBox(s7, { x: 0.5, y: 4.5, w: 9.0, h: 0.35 },
        'Impact : 0 perte de donnees \u2013 renommage/deplacement uniquement'
    );

    addOrangeLogo(s7);
    addSlideNumber(s7, 7, theme);

    // ========== SLIDE 8 — FIN ==========
    addEndSlide(pres, 'Merci', theme);

    // ========== ECRITURE ==========
    const fileName = path.join(OUTPUT_DIR, 'Reorganisation_Partage_VOC.pptx');
    await pres.writeFile({ fileName });
    console.log(`OK: ${fileName}`);
}

generate().catch(err => { console.error('Erreur:', err); process.exit(1); });
