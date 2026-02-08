/**
 * Générateur de PowerPoint conforme à la Charte Orange
 * Usage: node create_orange_ppt.js
 *
 * Ce script crée des présentations respectant strictement
 * la charte graphique Orange (brand.orange.com)
 */

const pptxgen = require('pptxgenjs');

// ============================================
// CHARTE ORANGE - COULEURS
// ============================================
const ORANGE_COLORS = {
    // Couleurs principales (80% minimum)
    primary: {
        orange: 'FF7900',      // Couleur emblématique
        black: '000000',
        white: 'FFFFFF',
        grayDark: '595959',
        grayMedium: '8F8F8F',
        grayLight: 'D6D6D6'
    },
    // Couleurs secondaires (20% maximum)
    secondary: {
        blue: '4BB4E6',
        green: '50BE87',
        pink: 'FFB4E6',
        yellow: 'FFD200',
        purple: 'A885D8'
    },
    // Teintes claires (illustrations uniquement)
    light: {
        blue: 'B5E8F7',
        green: 'B8EBD6',
        pink: 'FFE8F7',
        purple: 'D9C2F0',
        yellow: 'FFF6B6'
    },
    // Teintes foncées (illustrations uniquement)
    dark: {
        blue: '085EBD',
        green: '0A6E31',
        pink: 'FF8AD4',
        yellow: 'FFB400',
        purple: '492191'
    }
};

// ============================================
// CHARTE ORANGE - TYPOGRAPHIE
// ============================================
const ORANGE_FONTS = {
    title: 'Arial',           // Fallback pour Helvetica Neue Bold
    body: 'Arial',            // Fallback pour Helvetica Neue Roman
    // Règles:
    // - Interlettrage: -20% (charSpacing dans pptxgen)
    // - JAMAIS majuscules complètes
    // - JAMAIS italique
    // - Texte: noir, blanc ou orange uniquement
};

// ============================================
// STYLES PRÉDÉFINIS
// ============================================
const STYLES = {
    title: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 36,
        bold: true,
        color: ORANGE_COLORS.primary.black,
        charSpacing: -2  // Approximation -20%
    },
    subtitle: {
        fontFace: ORANGE_FONTS.title,
        fontSize: 24,
        bold: true,
        color: ORANGE_COLORS.primary.orange
    },
    body: {
        fontFace: ORANGE_FONTS.body,
        fontSize: 18,
        color: ORANGE_COLORS.primary.black,
        charSpacing: -2
    },
    bullet: {
        fontFace: ORANGE_FONTS.body,
        fontSize: 16,
        color: ORANGE_COLORS.primary.black,
        bullet: {
            type: 'number',
            style: 'arabicPeriod'
        }
    }
};

// ============================================
// CRÉATION DE PRÉSENTATION
// ============================================

/**
 * Crée une nouvelle présentation Orange
 * @param {string} title - Titre de la présentation
 * @returns {pptxgen} Instance de présentation
 */
function createOrangePres(title = 'Présentation Orange') {
    const pres = new pptxgen();

    // Métadonnées
    pres.author = 'Orange';
    pres.company = 'Orange';
    pres.title = title;

    // Format 16:9 standard
    pres.defineLayout({ name: 'ORANGE', width: 10, height: 5.625 });
    pres.layout = 'ORANGE';

    return pres;
}

/**
 * Ajoute une slide titre
 * @param {pptxgen} pres - Présentation
 * @param {string} title - Titre principal
 * @param {string} subtitle - Sous-titre (optionnel)
 */
function addTitleSlide(pres, title, subtitle = '') {
    const slide = pres.addSlide();

    // Fond noir (eco-branding digital)
    slide.background = { color: ORANGE_COLORS.primary.black };

    // Bande orange en haut
    slide.addShape('rect', {
        x: 0, y: 0, w: '100%', h: 0.8,
        fill: { color: ORANGE_COLORS.primary.orange }
    });

    // Titre en blanc sur fond noir
    slide.addText(title, {
        x: 0.5, y: 2, w: 9, h: 1,
        ...STYLES.title,
        color: ORANGE_COLORS.primary.white,
        align: 'left'
    });

    // Sous-titre en orange
    if (subtitle) {
        slide.addText(subtitle, {
            x: 0.5, y: 3, w: 9, h: 0.6,
            ...STYLES.subtitle,
            color: ORANGE_COLORS.primary.orange,
            align: 'left'
        });
    }

    // Small logo simulé (carré orange coin bas droit)
    slide.addShape('rect', {
        x: 9.2, y: 4.9, w: 0.5, h: 0.5,
        fill: { color: ORANGE_COLORS.primary.orange }
    });
    // Ligne blanche dans le carré (Small logo)
    slide.addShape('line', {
        x: 9.25, y: 5.15, w: 0.4, h: 0,
        line: { color: ORANGE_COLORS.primary.white, width: 2 }
    });

    return slide;
}

/**
 * Ajoute une slide de contenu
 * @param {pptxgen} pres - Présentation
 * @param {string} title - Titre de la slide
 * @param {string[]} bullets - Liste de points
 */
function addContentSlide(pres, title, bullets = []) {
    const slide = pres.addSlide();

    // Fond blanc (ou noir selon usage)
    slide.background = { color: ORANGE_COLORS.primary.white };

    // Bandeau orange en haut
    slide.addShape('rect', {
        x: 0, y: 0, w: '100%', h: 0.1,
        fill: { color: ORANGE_COLORS.primary.orange }
    });

    // Titre
    slide.addText(title, {
        x: 0.5, y: 0.3, w: 9, h: 0.8,
        ...STYLES.title,
        color: ORANGE_COLORS.primary.black
    });

    // Contenu avec puces carrées orange
    if (bullets.length > 0) {
        const bulletItems = bullets.map(text => ({
            text: text,
            options: {
                ...STYLES.body,
                bullet: {
                    type: 'bullet',
                    characterCode: '25A0',  // Carré plein
                    color: ORANGE_COLORS.primary.orange
                },
                paraSpaceAfter: 10
            }
        }));

        slide.addText(bulletItems, {
            x: 0.5, y: 1.3, w: 9, h: 3.5,
            valign: 'top'
        });
    }

    // Small logo coin bas droit
    slide.addShape('rect', {
        x: 9.2, y: 5.0, w: 0.5, h: 0.5,
        fill: { color: ORANGE_COLORS.primary.orange }
    });
    slide.addShape('line', {
        x: 9.25, y: 5.25, w: 0.4, h: 0,
        line: { color: ORANGE_COLORS.primary.white, width: 2 }
    });

    return slide;
}

/**
 * Ajoute une slide section (transition)
 * @param {pptxgen} pres - Présentation
 * @param {string} sectionTitle - Titre de section
 * @param {number} sectionNumber - Numéro de section (optionnel)
 */
function addSectionSlide(pres, sectionTitle, sectionNumber = null) {
    const slide = pres.addSlide();

    // Fond orange (emblématique)
    slide.background = { color: ORANGE_COLORS.primary.orange };

    // Numéro de section
    if (sectionNumber) {
        slide.addText(String(sectionNumber).padStart(2, '0'), {
            x: 0.5, y: 1.5, w: 2, h: 1,
            fontFace: ORANGE_FONTS.title,
            fontSize: 72,
            bold: true,
            color: ORANGE_COLORS.primary.white
        });
    }

    // Titre de section
    slide.addText(sectionTitle, {
        x: 0.5, y: 2.8, w: 9, h: 1,
        ...STYLES.title,
        fontSize: 40,
        color: ORANGE_COLORS.primary.white
    });

    return slide;
}

/**
 * Ajoute une slide de fin
 * @param {pptxgen} pres - Présentation
 * @param {string} message - Message de fin (default: "Merci")
 */
function addEndSlide(pres, message = 'Merci') {
    const slide = pres.addSlide();

    // Fond noir
    slide.background = { color: ORANGE_COLORS.primary.black };

    // Message centré en orange
    slide.addText(message, {
        x: 0, y: 2, w: '100%', h: 1.5,
        fontFace: ORANGE_FONTS.title,
        fontSize: 48,
        bold: true,
        color: ORANGE_COLORS.primary.orange,
        align: 'center'
    });

    // Signature "Orange est là"
    slide.addText('Orange est là', {
        x: 0, y: 4, w: '100%', h: 0.5,
        fontFace: ORANGE_FONTS.body,
        fontSize: 18,
        color: ORANGE_COLORS.primary.white,
        align: 'center'
    });

    // Logo
    slide.addShape('rect', {
        x: 4.5, y: 4.6, w: 0.6, h: 0.6,
        fill: { color: ORANGE_COLORS.primary.orange }
    });
    slide.addShape('line', {
        x: 4.55, y: 4.9, w: 0.5, h: 0,
        line: { color: ORANGE_COLORS.primary.white, width: 2 }
    });

    return slide;
}

// ============================================
// EXPORT DES FONCTIONS
// ============================================
module.exports = {
    ORANGE_COLORS,
    ORANGE_FONTS,
    STYLES,
    createOrangePres,
    addTitleSlide,
    addContentSlide,
    addSectionSlide,
    addEndSlide
};

// ============================================
// EXEMPLE D'UTILISATION
// ============================================
if (require.main === module) {
    // Création d'une présentation exemple
    const pres = createOrangePres('Exemple Charte Orange');

    // Slide titre
    addTitleSlide(pres, 'Les fondamentaux de la marque', 'Charte graphique Orange');

    // Section 1
    addSectionSlide(pres, 'Nos valeurs', 1);

    // Contenu
    addContentSlide(pres, 'Nos principes', [
        'Simple et proche des gens',
        'Positif et audacieux',
        'Langage parlé, sans bla bla',
        'Respectueux et inclusif'
    ]);

    // Section 2
    addSectionSlide(pres, 'Nos couleurs', 2);

    addContentSlide(pres, 'Palette de couleurs', [
        'Orange #FF7900 - notre couleur emblématique',
        'Noir, blanc et gris - couleurs principales',
        'Bleu, vert, rose, jaune, pourpre - couleurs secondaires',
        'Règle 80/20: 80% principales, 20% max secondaires'
    ]);

    // Fin
    addEndSlide(pres, 'Merci');

    // Sauvegarde
    const fileName = 'exemple_charte_orange.pptx';
    pres.writeFile({ fileName })
        .then(() => console.log(`Présentation créée: ${fileName}`))
        .catch(err => console.error('Erreur:', err));
}
