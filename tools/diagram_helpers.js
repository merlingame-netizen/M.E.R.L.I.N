'use strict';

/**
 * diagram_helpers.js — Diagrammes vectoriels via pptxgenjs shapes
 *
 * Thème Orange ISO, langage simple/pédagogique.
 * Fonctions exportées :
 *   drawGitWorkflow(slide)      — Slide : workflow feature branch (labels FR simples)
 *   drawDocStructure(slide)     — Slide : arbre documentation
 *   drawDbeaverArch(slide)      — Slide : accès aux données (EDH / BigQuery / Test)
 *   drawAnalysisSequence(slide) — Slide : démarche d'analyse type
 */

const C = {
    orange:  'FF7900',
    black:   '000000',
    white:   'FFFFFF',
    dark:    '595959',
    medium:  '8F8F8F',
    light:   'D6D6D6',
    bg:      'F5F5F5',
    green:   '50BE87',
    greenBg: 'B8EBD6',
    greenDk: '0A6E31',
    yellow:  'FFD200',
    yellowBg:'FFF6B6',
    blue:    '4BB4E6',
    blueBg:  'B5E8F7',
    blueDk:  '085EBD',
    red:     'CC3300',
    redBg:   'FFE8E8'
};
const F = 'Arial';

// ─── Primitives ───────────────────────────────────────────────────────────────

function box(slide, x, y, w, h, text, opts = {}) {
    const {
        fill = C.bg, stroke = C.orange, strokeW = 1.5,
        color = C.black, size = 10, bold = true, radius = 0.05,
        align = 'center', valign = 'middle'
    } = opts;
    slide.addShape('roundRect', {
        x, y, w, h,
        fill: { color: fill },
        line: { color: stroke, width: strokeW },
        rectRadius: radius
    });
    if (text) {
        slide.addText(text, {
            x: x + 0.05, y, w: w - 0.1, h,
            fontFace: F, fontSize: size, bold, color,
            align, valign, shrinkText: true, bullet: false, lineSpacingPercent: 90
        });
    }
}

function dot(slide, cx, cy, r, opts = {}) {
    const { fill = C.orange, stroke = C.orange } = opts;
    slide.addShape('ellipse', {
        x: cx - r, y: cy - r, w: r * 2, h: r * 2,
        fill: { color: fill }, line: { color: stroke, width: 1 }
    });
}

function arrow(slide, x, y, w, h, opts = {}) {
    const { color = C.dark, width = 1.5 } = opts;
    // Normalize: cx/cy must be >= 0 in OOXML spec
    const flipH = w < 0;
    const flipV = h < 0;
    const shapeOpts = {
        x: flipH ? x + w : x,
        y: flipV ? y + h : y,
        w: Math.abs(w),
        h: Math.abs(h),
        line: { color, width, endArrowType: 'triangle', beginArrowType: 'none' }
    };
    if (flipH) shapeOpts.flipH = true;
    if (flipV) shapeOpts.flipV = true;
    slide.addShape('line', shapeOpts);
}

function ln(slide, x, y, w, h, opts = {}) {
    const { color = C.medium, width = 2.0, dash = 'solid' } = opts;
    // Normalize: cx/cy must be >= 0 in OOXML spec
    const flipH = w < 0;
    const flipV = h < 0;
    const shapeOpts = {
        x: flipH ? x + w : x,
        y: flipV ? y + h : y,
        w: Math.abs(w),
        h: Math.abs(h),
        line: { color, width, dashType: dash }
    };
    if (flipH) shapeOpts.flipH = true;
    if (flipV) shapeOpts.flipV = true;
    slide.addShape('line', shapeOpts);
}

function lbl(slide, x, y, w, text, opts = {}) {
    const { color = C.dark, size = 9, align = 'center', bold = true, h = 0.28 } = opts;
    slide.addText(text, {
        x, y, w, h,
        fontFace: F, fontSize: size, bold, color,
        align, valign: 'top', shrinkText: true, bullet: false
    });
}

function pill(slide, x, y, w, h, text, opts = {}) {
    const { fill = C.orange, color = C.white, size = 9 } = opts;
    slide.addShape('roundRect', {
        x, y, w, h,
        fill: { color: fill }, line: { type: 'none' }, rectRadius: h / 2
    });
    slide.addText(text, {
        x, y, w, h,
        fontFace: F, fontSize: size, bold: true, color,
        align: 'center', valign: 'middle', shrinkText: true, bullet: false
    });
}

function infoBar(slide, y, text, opts = {}) {
    const { fill = C.bg, stroke = C.light, leftColor = C.orange, size = 9 } = opts;
    slide.addShape('rect', {
        x: 0.34, y, w: 9.3, h: 0.42,
        fill: { color: fill }, line: { color: stroke, width: 1 }
    });
    slide.addShape('rect', { x: 0.34, y, w: 0.05, h: 0.42, fill: { color: leftColor }, line: { type: 'none' } });
    lbl(slide, 0.5, y + 0.06, 9.0, text, { color: C.dark, size, align: 'left' });
}

// ─────────────────────────────────────────────────────────────────────────────
// DIAGRAM 1 — Git Workflow (labels simples, pédagogiques)
// ─────────────────────────────────────────────────────────────────────────────

function drawGitWorkflow(slide) {
    const mainY  = 2.05;
    const featY  = 3.30;
    const r      = 0.14;
    const cMain  = [1.0, 8.4, 9.2];
    const cFeat  = [2.4, 4.0, 5.6, 7.2];

    // ── Labels de branche (repositionnés — zéro superposition) ───────────────
    // "branche principale" : au-dessus, avant le 1er nœud, Y bien séparé des commits
    lbl(slide, 0.10, 1.28, 1.9, 'branche principale (main)',
        { color: C.orange, size: 10, align: 'left', h: 0.34 });
    // bottom = 1.62 ; commits main à y=1.70 → gap 0.08" ✓

    // "feature branch" : au-dessus de la ligne feature, APRÈS le connecteur diagonal
    // (connecteur se termine à x=2.40 → label commence à x=2.55, aucun croisement)
    lbl(slide, 2.55, featY - 0.40, 2.3, 'votre espace de travail\nisolé (feature branch)',
        { color: C.dark, size: 8.5, align: 'left', h: 0.37 });
    // bottom = 2.97 ; commits feature à y=3.52 → gap 0.55" ✓

    // Lignes
    ln(slide, 0.5,      mainY, 9.0, 0,              { color: C.orange, width: 2.5 });
    ln(slide, cFeat[0], featY, cFeat[3] - cFeat[0], 0, { color: C.medium, width: 2 });
    ln(slide, cMain[0], mainY, cFeat[0] - cMain[0], featY - mainY, { color: C.medium, width: 1.5 });
    ln(slide, cFeat[3], featY, cMain[1] - cFeat[3], mainY - featY, { color: C.medium, width: 1.5 });

    // Cercles main
    dot(slide, cMain[0], mainY, r, { fill: C.orange });
    dot(slide, cMain[1], mainY, r, { fill: C.orange });
    dot(slide, cMain[2], mainY, r + 0.02, { fill: C.black });

    // Cercles feature
    cFeat.forEach(cx => dot(slide, cx, featY, r, { fill: C.medium }));

    // Labels commits main — Y unique = mainY-0.35 = 1.70 (séparé de "branche principale" bottom=1.62)
    lbl(slide, cMain[0] - 0.40, mainY - 0.35, 0.80, 'départ',    { color: C.orange, size: 9 });
    lbl(slide, cMain[1] - 0.50, mainY - 0.35, 1.00, 'fusion ✓',  { color: C.orange, size: 9 });
    lbl(slide, cMain[2] - 0.50, mainY - 0.35, 1.00, 'livraison', { color: C.black,  size: 9 });
    // "livraison" bottom = 1.98 ; badge v1.0 top = 2.31 → gap 0.33" ✓

    // Labels commits feature — légèrement plus bas pour respirer
    const featLbls = ['ajout :\nnouvel indicateur', 'correction :\nbug sur les dates', 'documentation :\nmise à jour README', ''];
    cFeat.forEach((cx, i) => {
        if (featLbls[i]) {
            lbl(slide, cx - 0.6, featY + 0.22, 1.2, featLbls[i],
                { color: C.dark, size: 8, align: 'center' });
        }
    });

    // Badge livraison — sous le dot noir (pas à côté du texte "livraison")
    // dot bottom = mainY+0.16=2.21 ; pill top = mainY+0.26=2.31 → gap 0.10" ✓
    pill(slide, cMain[2] - 0.22, mainY + 0.26, 0.80, 0.26, 'v1.0', { fill: C.black, size: 8 });

    // Barre de rappel format commit
    infoBar(slide, 3.95,
        'Format de commit :   feat: nouvelle fonctionnalité   ·   fix: correction   ·   docs: documentation   ·   chore: maintenance');
}

// ─────────────────────────────────────────────────────────────────────────────
// DIAGRAM 2 — Documentation Structure
// ─────────────────────────────────────────────────────────────────────────────

function drawDocStructure(slide) {
    const rootX = 3.3, rootY = 1.38, rootW = 3.0, rootH = 0.5;
    const rootCX = rootX + rootW / 2;
    const rootBY = rootY + rootH;

    box(slide, rootX, rootY, rootW, rootH, 'Projet DATA', {
        fill: C.orange, stroke: C.orange, color: C.white, size: 13, radius: 0.06
    });

    // Branche MD
    const mdX = 0.34, mdY = 2.22, mdW = 3.6, mdH = 0.48, mdCX = mdX + mdW / 2;
    ln(slide, rootCX, rootBY, mdCX - rootCX, mdY - rootBY, { color: C.medium, width: 1.5 });
    box(slide, mdX, mdY, mdW, mdH, 'Fichiers de suivi (.md)', {
        fill: C.bg, stroke: C.orange, color: C.orange, size: 11
    });

    const mdFiles = [
        { x: 0.34, text: 'README.md\n"Vue d\'ensemble"' },
        { x: 1.34, text: 'CHANGELOG\n"Historique"' },
        { x: 2.34, text: 'Suivi tâches\n"Avancement"' },
        { x: 3.34, text: 'Découvertes\n"Notes analyse"' }
    ];
    const leafY = 3.18, leafW = 0.9, leafH = 0.75, mdBY = mdY + mdH;
    mdFiles.forEach(f => {
        const lCX = f.x + leafW / 2;
        ln(slide, mdCX, mdBY, lCX - mdCX, leafY - mdBY, { color: C.light, width: 1 });
        box(slide, f.x, leafY, leafW, leafH, f.text, {
            fill: C.bg, stroke: C.light, color: C.dark, size: 8, radius: 0.04
        });
    });

    // Branche DOCX
    const docX = 5.3, docY = 2.22, docW = 4.0, docH = 0.48, docCX = docX + docW / 2;
    ln(slide, rootCX, rootBY, docCX - rootCX, docY - rootBY, { color: C.medium, width: 1.5 });
    box(slide, docX, docY, docW, docH, 'Fiche technique projet (.docx)', {
        fill: C.bg, stroke: C.orange, color: C.orange, size: 11
    });

    const secs = [
        'Contexte\ndu projet', 'Architecture\ntechnique', 'Sources\nde données', 'Indicateurs',
        'Sécurité\n& RGPD', 'Pipeline\nde données', 'Tests\n& Recette', '+ 6 autres\nrubriques'
    ];
    const sW = 0.95, sH = 0.58, sGap = 0.05, docBY = docY + docH;
    secs.forEach((s, i) => {
        const col = i % 4, row = Math.floor(i / 4);
        const sx = docX + col * (sW + sGap);
        const sy = docBY + 0.12 + row * (sH + 0.08);
        const lCX = sx + sW / 2;
        if (row === 0) ln(slide, docCX, docBY, lCX - docCX, sy - docBY, { color: C.light, width: 1 });
        box(slide, sx, sy, sW, sH, s, {
            fill: i === secs.length - 1 ? C.light : C.bg,
            stroke: C.light, color: C.dark, size: 7.5, radius: 0.03
        });
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// DIAGRAM 3 — Accès aux données (sans jargon technique)
// ─────────────────────────────────────────────────────────────────────────────

function drawDbeaverArch(slide) {
    // DBeaver
    const dbW = 4.2, dbH = 0.62, dbX = (9.66 - dbW) / 2, dbY = 1.38;
    box(slide, dbX, dbY, dbW, dbH, 'DBeaver  —  Outil d\'exploration de données', {
        fill: C.orange, stroke: C.orange, color: C.white, size: 13, radius: 0.06
    });
    const dbCX = dbX + dbW / 2, dbBY = dbY + dbH;

    const cols = [
        {
            cx: 1.65, bW: 2.8,
            fill: C.yellowBg, stroke: C.yellow,
            title: 'Données Orange\ninterne (EDH)',
            badge: 'Clients · Réclamations · Sollicitations',
            badgeColor: 'FFB400',
            sub: 'Historique commercial\n117 tables disponibles'
        },
        {
            cx: 5.0, bW: 2.8,
            fill: C.blueBg, stroke: C.blue,
            title: 'Données Cloud\nprojet (BigQuery)',
            badge: 'Sondages ProPME · KPIs · NPS / CSAT',
            badgeColor: C.blueDk,
            sub: 'Entrepôt Google Cloud\n111 jeux de données'
        },
        {
            cx: 8.35, bW: 1.9,
            fill: C.bg, stroke: C.light,
            title: 'Base de test\n(local)',
            badge: 'Dev & Tests uniquement',
            badgeColor: C.dark,
            sub: 'Pour tester\nsans risque'
        }
    ];

    // subY/subH ajustés : sub-box bottom = 3.53+0.38 = 3.91 (infoBar à 3.95 → gap 0.04" ✓)
    const boxY = 2.4, boxH = 0.75, subY = boxY + boxH + 0.38, subH = 0.38;

    cols.forEach(col => {
        const bX = col.cx - col.bW / 2;
        arrow(slide, dbCX, dbBY, col.cx - dbCX, boxY - dbBY, { color: C.dark, width: 1.5 });
        box(slide, bX, boxY, col.bW, boxH, col.title, {
            fill: col.fill, stroke: col.stroke, color: C.black, size: 10, radius: 0.06
        });
        const badgeW = Math.min(col.bW - 0.2, 2.5);
        pill(slide, bX + (col.bW - badgeW) / 2, boxY + boxH + 0.06, badgeW, 0.26, col.badge,
            { fill: col.badgeColor, size: 7.5 });
        box(slide, bX, subY, col.bW, subH, col.sub, {
            fill: col.fill, stroke: col.stroke, color: C.dark, size: 9, radius: 0.04
        });
    });

    infoBar(slide, 3.95,
        'Toujours commencer par explorer la structure des tables avant d\'écrire une requête  |  Ne jamais modifier les données en production');
}

// ─────────────────────────────────────────────────────────────────────────────
// DIAGRAM 4 — Démarche d'analyse type (remplace séquence EDH technique)
// ─────────────────────────────────────────────────────────────────────────────

function drawAnalysisSequence(slide) {
    const steps = [
        { num: '①', text: 'Je me connecte à la base de données',        sub: 'DBeaver → sélectionner la connexion',       fill: C.bg,      stroke: C.orange },
        { num: '②', text: 'Je cherche ma table de données',             sub: 'Explorer les tables disponibles',           fill: C.bg,      stroke: C.orange },
        { num: '③', text: 'Je lis la structure (colonnes)',              sub: 'Comprendre ce que contient la table',       fill: C.bg,      stroke: C.orange },
        { num: '④', text: 'Je fais un test sur 10 à 50 lignes',        sub: 'Vérifier que les données sont correctes',   fill: C.yellowBg,stroke: C.yellow },
        { num: '⑤', text: 'J\'analyse dans Python ou Excel',            sub: 'Calculs, comptages, graphiques, export',    fill: C.greenBg, stroke: C.green }
    ];

    const sX = 0.34, sW = 5.4, sH = 0.5, sGap = 0.1;
    const startY = 1.32;

    steps.forEach((s, i) => {
        const sy = startY + i * (sH + sGap);
        const isLast = i === steps.length - 1;

        pill(slide, sX, sy + 0.08, 0.36, 0.34, s.num,
            { fill: isLast ? C.green : C.orange, size: 9 });

        box(slide, sX + 0.44, sy, sW - 0.44, sH,
            s.text + '\n' + s.sub, {
                fill: s.fill, stroke: s.stroke,
                color: C.black, strokeW: isLast ? 2 : 1.5,
                size: 9, radius: 0.04
            });

        if (i < steps.length - 1) {
            const arrowX = sX + 0.18;
            arrow(slide, arrowX, sy + sH, 0, sGap, { color: C.orange, width: 1.5 });
        }
    });

    // Panneau droit — bonnes pratiques
    const pX = 5.95, pY = 1.32, pW = 3.7;

    box(slide, pX, pY, pW, 0.42, 'Règles d\'or', {
        fill: C.orange, stroke: C.orange, color: C.white, size: 11, radius: 0.05
    });

    const tips = [
        { isOk: true,  text: 'Tester avec peu de lignes avant l\'analyse' },
        { isOk: true,  text: 'Documenter ses requêtes (findings.md)' },
        { isOk: true,  text: 'Faire les calculs dans Python ou Excel' },
        { isOk: false, text: 'Modifier ou supprimer des données en prod' },
        { isOk: false, text: 'Lancer une requête sans lire la structure' }
    ];

    tips.forEach((t, i) => {
        const ay = pY + 0.5 + i * 0.4;
        const prefix = t.isOk ? 'OK : ' : 'Non : ';
        box(slide, pX, ay, pW, 0.36, prefix + t.text, {
            fill: t.isOk ? C.greenBg : C.redBg,
            stroke: t.isOk ? C.green : C.red,
            color: C.dark, size: 8.5, radius: 0.03, align: 'left', valign: 'middle'
        });
    });
}

module.exports = {
    drawGitWorkflow,
    drawDocStructure,
    drawDbeaverArch,
    drawAnalysisSequence
};
