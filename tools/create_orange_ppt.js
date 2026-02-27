/**
 * Generateur PowerPoint ISO template officiel Orange — v1 + Rich Components
 *
 * Style v1 (fidele au Guide_Template_Orange_VoC_DEF_v2.pptx):
 *   - Helvetica 75 Bold partout (Arial Bold fallback)
 *   - Bullets en-dash U+2013 inline
 *   - lineSpacingPercent 85-90%
 *   - Pas de kerning force, pas de getLineHeight()
 *
 * Composants riches (extraits du guide PPT XML):
 *   - Cards avec coins arrondis + bande orange optionnelle
 *   - Info box avec bordure gauche orange
 *   - Badges/pilules orange avec texte blanc
 *   - Color swatches (grille de couleurs)
 *   - Slide comparaison (2 panneaux cote a cote)
 *   - Slide grille de cards (4 cards avec bande haute)
 *
 * Usage: node create_orange_ppt.js [noir|blanc]
 */

const pptxgen = require('pptxgenjs');
const path = require('path');
const fs = require('fs');

// ============================================
// CHARTE ORANGE - COULEURS
// ============================================
const ORANGE_COLORS = {
    primary: {
        orange: 'FF7900',
        black: '000000',
        white: 'FFFFFF',
        grayDark: '595959',
        grayMedium: '8F8F8F',
        grayLight: 'D6D6D6'
    },
    secondary: {
        blue: '4BB4E6',
        green: '50BE87',
        pink: 'FFB4E6',
        yellow: 'FFD200',
        purple: 'A885D8'
    },
    light: {
        blue: 'B5E8F7',
        green: 'B8EBD6',
        pink: 'FFE8F7',
        purple: 'D9C2F0',
        yellow: 'FFF6B6'
    },
    dark: {
        blue: '085EBD',
        green: '0A6E31',
        pink: 'FF8AD4',
        yellow: 'FFB400',
        purple: '492191'
    },
    bg: {
        card: 'F5F5F5'      // Fond gris clair pour cards/info boxes (du guide PPT)
    }
};

// ============================================
// CHARTE ORANGE - TYPOGRAPHIE (v1 = 75 Bold partout)
// ============================================
const ORANGE_FONTS = {
    title: 'Helvetica 75 Bold',     // Partout (v1 style)
    fallback: 'Arial'
};

// ============================================
// POSITIONS OFFICIELLES (EMU -> inches, du guide PPT)
// ============================================
const POS = {
    title:    { x: 0.344, y: 0.294, w: 9.315, h: 0.811 },
    body:     { x: 0.344, y: 1.292, w: 9.312, h: 3.158 },
    titleBig: { x: 0.344, y: 0.293, w: 5.282, h: 2.52 },
    subtitle: { x: 0.344, y: 3.25,  w: 5.282, h: 0.85 },
    sideText: { x: 6.343, y: 0.292, w: 3.313, h: 3.723 },
    section:  { x: 0.343, y: 0.294, w: 6.668, h: 4.686 },
    logo:     { x: 0.343, y: 4.63,  w: 0.67,  h: 0.67 },
    slideNum: { x: 9.15,  y: 4.96,  w: 0.5,   h: 0.366 },
    colLeft:  { x: 0.343, y: 1.292, w: 4.34,  h: 3.158 },
    colRight: { x: 5.321, y: 1.292, w: 4.336, h: 3.158 }
};

// Zone de securite: aucun element ne doit depasser ce Y
const LOGO_SAFE_Y = 4.45;

// ============================================
// CONSTANTES VISUELLES (extraites du guide PPT XML)
// ============================================
const VISUAL = {
    cardRadius: 0.04,        // Coins arrondis cards (adj val 2000 EMU)
    swatchRadius: 0.08,      // Coins arrondis swatches (adj val 6000 EMU)
    stripe: 0.06,            // Epaisseur bande orange (54864 EMU)
    cardPadding: 0.15,       // Padding interne des cards
    gap: 0.15                // Espacement entre elements
};

// ============================================
// STYLES v1 (fideles au guide PPT)
// ============================================
const STYLES = {
    contentTitle: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 20,
        bold: true,
        color: ORANGE_COLORS.primary.orange,
        lineSpacingPercent: 90,
        shrinkText: true,
        bullet: false
    },
    bigTitle: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 55,
        bold: true,
        lineSpacingPercent: 85,
        shrinkText: true,
        bullet: false
    },
    body: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 14,
        bold: true,
        lineSpacingPercent: 90,
        shrinkText: true,
        bullet: false,
        paraSpaceBefore: 4,
        paraSpaceAfter: 4
    },
    slideNum: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 8,
        bold: true,
        shrinkText: true,
        bullet: false,
        valign: 'bottom'
    },
    // Styles pour composants riches
    cardTitle: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 14,
        bold: true,
        color: ORANGE_COLORS.primary.orange,
        lineSpacingPercent: 90,
        shrinkText: true,
        bullet: false
    },
    cardBody: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 11,
        bold: true,
        color: ORANGE_COLORS.primary.grayDark,
        lineSpacingPercent: 90,
        shrinkText: true,
        bullet: false
    },
    badge: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 11,
        bold: true,
        color: ORANGE_COLORS.primary.white,
        align: 'center',
        valign: 'middle',
        shrinkText: true,
        bullet: false
    },
    swatchLabel: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 8,
        bold: true,
        color: ORANGE_COLORS.primary.grayDark,
        align: 'center',
        shrinkText: true,
        bullet: false
    }
};

// ============================================
// BULLET HELPER (v1 = en-dash inline)
// ============================================

/**
 * Formate un item bullet avec en-dash U+2013 (style guide PPT v1)
 * @param {string} text - Texte du bullet
 * @param {string} color - Couleur du texte (hex sans #)
 * @param {number} [fontSize=14] - Taille de police
 * @returns {string} Texte formate avec en-dash
 */
function formatBullet(text, color, fontSize) {
    return '\u2013  ' + text;
}

// ============================================
// THEMES : FOND NOIR vs FOND BLANC
// ============================================
function getTheme(mode) {
    if (mode === 'blanc') {
        return {
            mode: 'blanc',
            bg: 'FFFFFF',
            title: 'FF7900',
            body: '000000',
            slideNum: '000000',
            sectionTitle: 'FF7900',
            sideText: '595959'
        };
    }
    return {
        mode: 'noir',
        bg: '000000',
        title: 'FFFFFF',
        body: 'FFFFFF',
        slideNum: 'FFFFFF',
        sectionTitle: 'FFFFFF',
        sideText: '8F8F8F'
    };
}

// ============================================
// LOGO (small logo PNG ou simulation)
// ============================================
const SMALL_LOGO_PATH = path.join(
    process.env.USERPROFILE || '',
    'OneDrive - orange.com', 'Bureau', 'Agents', 'Data',
    'orange_brand_assets', 'mastermedia1', 'small_logo',
    'ORANGE_Small Logo', 'Small_Logo_Digital', 'Small_Logo_RGB.png'
);

function addOrangeLogo(slide) {
    if (fs.existsSync(SMALL_LOGO_PATH)) {
        slide.addImage({
            path: SMALL_LOGO_PATH,
            x: POS.logo.x, y: POS.logo.y,
            w: POS.logo.w, h: POS.logo.h
        });
    } else {
        // Fallback: carre orange + ligne blanche
        slide.addShape('rect', {
            x: POS.logo.x, y: POS.logo.y, w: POS.logo.w, h: POS.logo.h,
            fill: { color: ORANGE_COLORS.primary.orange },
            line: { type: 'none' }
        });
        slide.addShape('line', {
            x: POS.logo.x + 0.08, y: POS.logo.y + 0.38,
            w: POS.logo.w - 0.16, h: 0,
            line: { color: ORANGE_COLORS.primary.white, width: 2 }
        });
    }
}

function addSlideNumber(slide, num, theme) {
    if (num == null) return;
    slide.addText(String(num), {
        x: POS.slideNum.x, y: POS.slideNum.y,
        w: POS.slideNum.w, h: POS.slideNum.h,
        ...STYLES.slideNum,
        color: theme.slideNum,
        align: 'right'
    });
}

// ============================================
// COMPOSANTS RICHES — CARDS
// ============================================

/**
 * Ajoute une card avec fond gris et coins arrondis
 * Option: bande orange en haut (topStripe)
 *
 * @param {object} slide - Slide pptxgenjs
 * @param {object} pos - { x, y, w, h }
 * @param {object} opts - { title, body, bgColor, topStripe, titleColor, bodyColor }
 */
function addCard(slide, pos, opts = {}) {
    const bgColor = opts.bgColor || ORANGE_COLORS.bg.card;

    // Fond de la card (rounded rect)
    slide.addShape('roundRect', {
        x: pos.x, y: pos.y, w: pos.w, h: pos.h,
        fill: { color: bgColor },
        line: { type: 'none' },
        rectRadius: VISUAL.cardRadius
    });

    // Bande orange en haut (optionnel)
    if (opts.topStripe) {
        slide.addShape('rect', {
            x: pos.x, y: pos.y,
            w: pos.w, h: VISUAL.stripe,
            fill: { color: ORANGE_COLORS.primary.orange },
            line: { type: 'none' }
        });
    }

    // Titre de la card
    const textY = opts.topStripe
        ? pos.y + VISUAL.stripe + VISUAL.cardPadding * 0.5
        : pos.y + VISUAL.cardPadding;

    if (opts.title) {
        slide.addText(opts.title, {
            x: pos.x + VISUAL.cardPadding,
            y: textY,
            w: pos.w - VISUAL.cardPadding * 2,
            h: 0.35,
            ...STYLES.cardTitle,
            color: opts.titleColor || ORANGE_COLORS.primary.orange
        });
    }

    // Body de la card
    if (opts.body) {
        const bodyY = opts.title ? textY + 0.35 : textY;
        slide.addText(opts.body, {
            x: pos.x + VISUAL.cardPadding,
            y: bodyY,
            w: pos.w - VISUAL.cardPadding * 2,
            h: pos.h - (bodyY - pos.y) - VISUAL.cardPadding,
            ...STYLES.cardBody,
            color: opts.bodyColor || ORANGE_COLORS.primary.grayDark
        });
    }
}

// ============================================
// COMPOSANTS RICHES — INFO BOX
// ============================================

/**
 * Ajoute une info box avec bordure gauche orange (du guide PPT slide 3)
 *
 * @param {object} slide - Slide pptxgenjs
 * @param {object} pos - { x, y, w, h }
 * @param {string} text - Texte de l'info box
 * @param {object} [opts] - { bgColor, borderColor, textColor, fontSize }
 */
function addInfoBox(slide, pos, text, opts = {}) {
    const bgColor = opts.bgColor || ORANGE_COLORS.bg.card;
    const borderColor = opts.borderColor || ORANGE_COLORS.primary.orange;

    // Fond gris
    slide.addShape('rect', {
        x: pos.x, y: pos.y, w: pos.w, h: pos.h,
        fill: { color: bgColor },
        line: { type: 'none' }
    });

    // Bande orange a gauche
    slide.addShape('rect', {
        x: pos.x, y: pos.y,
        w: VISUAL.stripe, h: pos.h,
        fill: { color: borderColor },
        line: { type: 'none' }
    });

    // Texte
    slide.addText(text, {
        x: pos.x + VISUAL.stripe + VISUAL.cardPadding,
        y: pos.y + VISUAL.cardPadding * 0.5,
        w: pos.w - VISUAL.stripe - VISUAL.cardPadding * 2,
        h: pos.h - VISUAL.cardPadding,
        fontFace: ORANGE_FONTS.title,
        fontSize: opts.fontSize || 11,
        bold: true,
        color: opts.textColor || ORANGE_COLORS.primary.grayDark,
        lineSpacingPercent: 90,
        valign: 'top',
        shrinkText: true,
        bullet: false
    });
}

// ============================================
// COMPOSANTS RICHES — BADGE / PILULE
// ============================================

/**
 * Ajoute un badge/pilule orange avec texte blanc (du guide PPT slide 5)
 *
 * @param {object} slide - Slide pptxgenjs
 * @param {object} pos - { x, y, w, h }
 * @param {string} text - Texte du badge
 * @param {object} [opts] - { bgColor, textColor, fontSize }
 */
function addBadge(slide, pos, text, opts = {}) {
    const bgColor = opts.bgColor || ORANGE_COLORS.primary.orange;

    slide.addShape('roundRect', {
        x: pos.x, y: pos.y, w: pos.w, h: pos.h,
        fill: { color: bgColor },
        line: { type: 'none' },
        rectRadius: pos.h / 2    // Pilule = rayon = moitie hauteur
    });

    slide.addText(text, {
        x: pos.x, y: pos.y, w: pos.w, h: pos.h,
        ...STYLES.badge,
        fontSize: opts.fontSize || 11,
        color: opts.textColor || ORANGE_COLORS.primary.white
    });
}

// ============================================
// COMPOSANTS RICHES — COLOR SWATCH
// ============================================

/**
 * Ajoute un swatch de couleur (carre arrondi + label en dessous)
 *
 * @param {object} slide - Slide pptxgenjs
 * @param {object} pos - { x, y, size } (size = cote du carre)
 * @param {string} color - Couleur hex (sans #)
 * @param {string} label - Label sous le swatch (#FF7900)
 * @param {object} [opts] - { labelColor }
 */
function addColorSwatch(slide, pos, color, label, opts = {}) {
    const size = pos.size || 0.5;

    slide.addShape('roundRect', {
        x: pos.x, y: pos.y, w: size, h: size,
        fill: { color: color },
        line: { type: 'none' },
        rectRadius: VISUAL.swatchRadius
    });

    if (label) {
        slide.addText(label, {
            x: pos.x - 0.05, y: pos.y + size + 0.04,
            w: size + 0.1, h: 0.2,
            ...STYLES.swatchLabel,
            color: opts.labelColor || ORANGE_COLORS.primary.grayDark
        });
    }
}

// ============================================
// CREATION DE PRESENTATION
// ============================================

function createOrangePres(title = 'Presentation Orange', mode = 'noir') {
    const pres = new pptxgen();
    pres.author = 'Orange';
    pres.company = 'Orange';
    pres.title = title;
    pres.defineLayout({ name: 'ORANGE_16x9', width: 10, height: 5.625 });
    pres.layout = 'ORANGE_16x9';

    const theme = getTheme(mode);
    return { pres, theme };
}

// ============================================
// SLIDE TITRE (Layout 2 — 55pt, couverture)
// ============================================

function addTitleSlide(pres, title, subtitle, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre 55pt
    slide.addText(title, {
        x: POS.titleBig.x, y: POS.titleBig.y,
        w: POS.titleBig.w, h: POS.titleBig.h,
        ...STYLES.bigTitle,
        color: theme.mode === 'noir' ? ORANGE_COLORS.primary.white : ORANGE_COLORS.primary.orange,
        align: 'left', valign: 'top'
    });

    // Sous-titre 18pt
    if (subtitle) {
        slide.addText(subtitle, {
            x: POS.subtitle.x, y: POS.subtitle.y,
            w: POS.subtitle.w, h: POS.subtitle.h,
            fontFace: ORANGE_FONTS.title,
            fontSize: 18,
            bold: true,
            color: theme.mode === 'noir' ? ORANGE_COLORS.primary.white : ORANGE_COLORS.primary.black,
            align: 'left', valign: 'top',
            lineSpacingPercent: 90,
            shrinkText: true, bullet: false
        });
    }

    // Texte lateral
    if (opts.sideText) {
        slide.addText(opts.sideText, {
            x: POS.sideText.x, y: POS.sideText.y,
            w: POS.sideText.w, h: POS.sideText.h,
            fontFace: ORANGE_FONTS.title,
            fontSize: 14,
            bold: true,
            color: theme.sideText,
            align: 'left', valign: 'top',
            lineSpacingPercent: 90,
            shrinkText: true, bullet: false
        });
    }

    addOrangeLogo(slide);
    if (opts.slideNum != null) addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE CONTENU (Layout 1 — 20pt titre + bullets en-dash)
// ============================================

function addContentSlide(pres, title, bullets, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre 20pt orange
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    // Bullets avec en-dash (v1 style)
    if (bullets && bullets.length > 0) {
        const bulletText = bullets.map(b => formatBullet(b)).join('\n');
        slide.addText(bulletText, {
            x: POS.body.x, y: POS.body.y,
            w: POS.body.w, h: POS.body.h,
            ...STYLES.body,
            color: theme.body,
            valign: 'top'
        });
    }

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE SECTION (Layout 4 — 55pt)
// ============================================

function addSectionSlide(pres, sectionTitle, sectionNumber, theme) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    let text = '';
    if (sectionNumber != null) {
        text = String(sectionNumber).padStart(2, '0') + '\n';
    }
    text += sectionTitle;

    slide.addText(text, {
        x: POS.section.x, y: POS.section.y,
        w: POS.section.w, h: POS.section.h,
        ...STYLES.bigTitle,
        color: theme.sectionTitle,
        align: 'left', valign: 'top'
    });

    addOrangeLogo(slide);
    return slide;
}

// ============================================
// SLIDE DEUX COLONNES (Layout 5)
// ============================================

function addTwoColumnSlide(pres, title, leftBullets, rightBullets, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    // Colonne gauche
    if (leftBullets && leftBullets.length > 0) {
        const text = leftBullets.map(b => formatBullet(b)).join('\n');
        slide.addText(text, {
            x: POS.colLeft.x, y: POS.colLeft.y,
            w: POS.colLeft.w, h: POS.colLeft.h,
            ...STYLES.body, color: theme.body, valign: 'top'
        });
    }

    // Colonne droite
    if (rightBullets && rightBullets.length > 0) {
        const text = rightBullets.map(b => formatBullet(b)).join('\n');
        slide.addText(text, {
            x: POS.colRight.x, y: POS.colRight.y,
            w: POS.colRight.w, h: POS.colRight.h,
            ...STYLES.body, color: theme.body, valign: 'top'
        });
    }

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE COMPARAISON (2 cards cote a cote, du guide PPT slide 3)
// ============================================

/**
 * @param {pptxgen} pres
 * @param {string} title - Titre de la slide
 * @param {object} left - { title, body, bgColor, titleColor, bodyColor }
 * @param {object} right - { title, body, bgColor, titleColor, bodyColor }
 * @param {object} theme
 * @param {object} [opts] - { slideNum, infoBox }
 */
function addComparisonSlide(pres, title, left, right, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    const cardW = 4.34;
    const cardH = 2.5;
    const cardY = 1.3;

    // Card gauche
    addCard(slide, { x: 0.343, y: cardY, w: cardW, h: cardH }, {
        title: left.title,
        body: left.body,
        bgColor: left.bgColor || ORANGE_COLORS.bg.card,
        titleColor: left.titleColor,
        bodyColor: left.bodyColor
    });

    // Card droite
    addCard(slide, { x: 5.321, y: cardY, w: cardW, h: cardH }, {
        title: right.title,
        body: right.body,
        bgColor: right.bgColor || ORANGE_COLORS.bg.card,
        titleColor: right.titleColor,
        bodyColor: right.bodyColor
    });

    // Info box en bas (optionnel)
    if (opts.infoBox) {
        addInfoBox(slide, {
            x: 0.343, y: cardY + cardH + VISUAL.gap,
            w: 9.315, h: 0.6
        }, opts.infoBox);
    }

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE CARD GRID (grille de cards avec bande haute, du guide PPT slide 7)
// ============================================

/**
 * @param {pptxgen} pres
 * @param {string} title - Titre de la slide
 * @param {Array<{title: string, body: string}>} cards - 2 a 4 cards
 * @param {object} theme
 * @param {object} [opts] - { slideNum, cols }
 */
function addCardGridSlide(pres, title, cards, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    const cols = opts.cols || Math.min(cards.length, 4);
    const totalW = 9.315;
    const startX = 0.343;
    const startY = 1.3;
    const gap = VISUAL.gap;
    const cardW = (totalW - gap * (cols - 1)) / cols;
    const cardH = opts.cardH || 2.8;

    cards.forEach((card, i) => {
        const col = i % cols;
        const row = Math.floor(i / cols);
        const x = startX + col * (cardW + gap);
        const y = startY + row * (cardH + gap);

        addCard(slide, { x, y, w: cardW, h: cardH }, {
            title: card.title,
            body: card.body,
            topStripe: true,
            titleColor: card.titleColor,
            bodyColor: card.bodyColor
        });
    });

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE BADGES (pilules orange, du guide PPT slide 5)
// ============================================

/**
 * @param {pptxgen} pres
 * @param {string} title - Titre de la slide
 * @param {Array<{label: string, description: string}>} badges - Liste de badges
 * @param {object} theme
 * @param {object} [opts] - { slideNum }
 */
function addBadgeSlide(pres, title, badges, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    const startY = 1.4;
    const badgeW = 2.2;
    const badgeH = 0.35;
    const rowH = 0.9;

    badges.forEach((b, i) => {
        const y = startY + i * rowH;

        // Badge pilule
        addBadge(slide, { x: 0.5, y, w: badgeW, h: badgeH }, b.label);

        // Description a droite
        if (b.description) {
            slide.addText(b.description, {
                x: 0.5 + badgeW + 0.3, y,
                w: 6.5, h: badgeH + 0.15,
                fontFace: ORANGE_FONTS.title,
                fontSize: 12,
                bold: true,
                color: theme.body,
                align: 'left', valign: 'middle',
                lineSpacingPercent: 90,
                shrinkText: true, bullet: false
            });
        }
    });

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE COLOR PALETTE (grille de couleurs, du guide PPT slide 4)
// ============================================

/**
 * @param {pptxgen} pres
 * @param {string} title - Titre de la slide
 * @param {Array<{color: string, label: string}>} swatches - Couleurs a afficher
 * @param {object} theme
 * @param {object} [opts] - { slideNum, rulesPanel, swatchSize, cols }
 */
function addColorPaletteSlide(pres, title, swatches, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    const size = opts.swatchSize || 0.55;
    const cols = opts.cols || 6;
    const gap = 0.2;
    const startX = 0.5;
    const startY = 1.4;

    swatches.forEach((s, i) => {
        const col = i % cols;
        const row = Math.floor(i / cols);
        const x = startX + col * (size + gap);
        const y = startY + row * (size + 0.35);

        addColorSwatch(slide, { x, y, size }, s.color, s.label);
    });

    // Panneau de regles a droite (optionnel, comme slide 4 du guide)
    if (opts.rulesPanel) {
        const panelX = startX + cols * (size + gap) + 0.3;
        const panelW = 10 - panelX - 0.35;
        addInfoBox(slide, {
            x: panelX, y: startY,
            w: panelW, h: 3.2
        }, opts.rulesPanel);
    }

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// SLIDE FIN
// ============================================

function addEndSlide(pres, message, theme) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    const textColor = theme.mode === 'noir'
        ? ORANGE_COLORS.primary.white
        : ORANGE_COLORS.primary.orange;

    slide.addText(message || 'Merci', {
        x: 0, y: 1.5, w: 10, h: 2,
        fontFace: ORANGE_FONTS.title,
        fontSize: 55,
        bold: true,
        color: textColor,
        align: 'center', valign: 'middle',
        lineSpacingPercent: 85,
        shrinkText: true, bullet: false
    });

    addOrangeLogo(slide);
    return slide;
}

// ============================================
// SLIDE IMAGE / DIAGRAMME (pour intégration Mermaid PNG ou toute image)
// ============================================

/**
 * Slide avec titre + image pleine largeur (pour diagrammes Mermaid générés en PNG)
 *
 * @param {object} pres        - Présentation pptxgenjs
 * @param {string} title       - Titre de la slide (20pt orange)
 * @param {string} imagePath   - Chemin absolu vers le PNG
 * @param {object} theme       - Thème Orange (noir/blanc)
 * @param {object} [opts]      - Options optionnelles
 * @param {string} [opts.caption]   - Légende sous l'image (11pt gris)
 * @param {number} [opts.slideNum]  - Numéro de slide
 * @param {number} [opts.imgY]      - Offset Y de l'image (défaut: 1.1)
 * @param {number} [opts.imgH]      - Hauteur image (défaut: 3.3 — LOGO_SAFE_Y respecté)
 */
function addImageSlide(pres, title, imagePath, theme, opts = {}) {
    const slide = pres.addSlide();
    slide.background = { color: theme.bg };

    // Titre 20pt orange
    slide.addText(title, {
        x: POS.title.x, y: POS.title.y,
        w: POS.title.w, h: POS.title.h,
        ...STYLES.contentTitle,
        color: ORANGE_COLORS.primary.orange
    });

    // Image centrée sous le titre
    const imgY = opts.imgY != null ? opts.imgY : 1.1;
    const imgH = opts.imgH != null ? opts.imgH : 3.3;     // Max safe: 4.4 - 1.1 = 3.3

    slide.addImage({
        path: imagePath,
        x: POS.body.x,
        y: imgY,
        w: POS.body.w,
        h: imgH,
        sizing: { type: 'contain', w: POS.body.w, h: imgH }
    });

    // Légende optionnelle (juste au-dessus du logo, dans la safe zone)
    if (opts.caption) {
        slide.addText(opts.caption, {
            x: POS.body.x,
            y: imgY + imgH + 0.02,
            w: POS.body.w,
            h: 0.25,
            fontFace: ORANGE_FONTS.title,
            fontSize: 9,
            bold: true,
            color: ORANGE_COLORS.primary.grayMedium,
            align: 'center',
            shrinkText: true,
            bullet: false
        });
    }

    addOrangeLogo(slide);
    addSlideNumber(slide, opts.slideNum, theme);
    return slide;
}

// ============================================
// EXPORT
// ============================================
module.exports = {
    ORANGE_COLORS,
    ORANGE_FONTS,
    STYLES,
    POS,
    VISUAL,
    LOGO_SAFE_Y,
    getTheme,
    formatBullet,
    createOrangePres,
    addOrangeLogo,
    addSlideNumber,
    // Slides de base
    addTitleSlide,
    addContentSlide,
    addSectionSlide,
    addTwoColumnSlide,
    addEndSlide,
    // Slides riches (du guide PPT)
    addComparisonSlide,
    addCardGridSlide,
    addBadgeSlide,
    addColorPaletteSlide,
    // Slide image / diagramme (Mermaid PNG)
    addImageSlide,
    // Composants unitaires
    addCard,
    addInfoBox,
    addBadge,
    addColorSwatch
};

// ============================================
// EXEMPLE (si lance directement)
// ============================================
if (require.main === module) {
    const mode = process.argv[2] || 'noir';
    const { pres, theme } = createOrangePres('Exemple Charte Orange v1 + Rich', mode);

    addTitleSlide(pres, 'Les fondamentaux\nde la marque', 'Charte graphique Orange', theme, {
        sideText: 'Fevrier 2026\nOrange Brand'
    });

    addSectionSlide(pres, 'Nos valeurs', 1, theme);

    addContentSlide(pres, 'Nos principes', [
        'Simple et proche des gens',
        'Positif et audacieux',
        'Langage parle, sans bla bla',
        'Respectueux et inclusif'
    ], theme, { slideNum: 3 });

    addEndSlide(pres, 'Merci', theme);

    const fileName = `exemple_charte_orange_${mode}.pptx`;
    pres.writeFile({ fileName })
        .then(() => console.log(`OK: ${fileName} (mode ${mode})`))
        .catch(err => console.error('Erreur:', err));
}
