'use strict';
/**
 * create_orange_ppt.js — Module PPT Orange ISO Template v2.0
 * Reconstruit depuis orange-ppt SKILL.md + api-reference.md (2026-03-31)
 * Layout : 10" x 5.625" (ORANGE_SLIDE custom)
 */

const pptxgen = require('C:/Users/PGNK2128/Godot-MCP/node_modules/pptxgenjs');
const path    = require('path');
const fs      = require('fs');

// ── CONSTANTES ──────────────────────────────────────────────────────────────

const ORANGE_COLORS = {
    primary:   { orange:'FF7900', black:'000000', white:'FFFFFF', grayDark:'595959', grayMedium:'8F8F8F', grayLight:'D6D6D6' },
    secondary: { blue:'4BB4E6', green:'50BE87', pink:'FFB4E6', yellow:'FFD200', purple:'A885D8' },
    light:     { blue:'B5E8F7', green:'B8EBD6', pink:'FFE8F7', purple:'D9C2F0', yellow:'FFF6B6' },
    dark:      { blue:'085EBD', green:'0A6E31', pink:'FF8AD4', yellow:'FFB400', purple:'492191' },
    bg:        { card:'F5F5F5' }
};

const ORANGE_FONTS = { title:'Helvetica 75 Bold', fallback:'Arial' };
const FONT = ORANGE_FONTS.title;

const POS = {
    title:    { x:0.344, y:0.294, w:9.315, h:0.811 },
    body:     { x:0.344, y:1.292, w:9.312, h:3.686 },
    titleBig: { x:0.344, y:0.293, w:5.282, h:2.52  },
    subtitle: { x:0.344, y:3.25,  w:5.282, h:0.85  },
    sideText: { x:6.343, y:0.292, w:3.313, h:3.723 },
    section:  { x:0.343, y:0.294, w:6.668, h:4.686 },
    logo:     { x:0.343, y:4.63,  w:0.67,  h:0.67  },
    slideNum: { x:9.35,  y:4.96,  w:0.301, h:0.366 },
    colLeft:  { x:0.343, y:1.292, w:4.34,  h:3.686 },
    colRight: { x:5.321, y:1.292, w:4.336, h:3.686 }
};

const VISUAL = { cardRadius:0.04, swatchRadius:0.08, stripe:0.06, cardPadding:0.15, gap:0.15 };
const LOGO_SAFE_Y = 4.45;

const STYLES = {
    contentTitle: { fontFace:FONT, fontSize:20, bold:true,  shrinkText:true, bullet:false, lineSpacingPercent:90  },
    bigTitle:     { fontFace:FONT, fontSize:55, bold:true,  shrinkText:true, bullet:false, lineSpacingPercent:85  },
    body:         { fontFace:FONT, fontSize:13, bold:false, shrinkText:true, bullet:false, lineSpacingPercent:115 },
    slideNum:     { fontFace:FONT, fontSize:8,  bold:false, shrinkText:true, bullet:false, align:'right' },
    cardTitle:    { fontFace:FONT, fontSize:13, bold:true,  shrinkText:true, bullet:false },
    cardBody:     { fontFace:FONT, fontSize:11, bold:false, shrinkText:true, bullet:false, lineSpacingPercent:115 },
    badge:        { fontFace:FONT, fontSize:12, bold:true,  shrinkText:true, bullet:false },
    swatchLabel:  { fontFace:FONT, fontSize:8,  bold:false, shrinkText:true, bullet:false }
};

// ── UTILITAIRES ─────────────────────────────────────────────────────────────

function getTheme(mode) {
    if (mode === 'noir') return { mode:'noir', bg:'000000', title:'FFFFFF', body:'FFFFFF', slideNum:'FFFFFF', sectionTitle:'FFFFFF', sideText:'8F8F8F' };
    return { mode:'blanc', bg:'FFFFFF', title:'FF7900', body:'000000', slideNum:'000000', sectionTitle:'FF7900', sideText:'595959' };
}

function formatBullet(text) { return '\u2013  ' + text; }

function createOrangePres(title, mode) {
    const pres = new pptxgen();
    pres.defineLayout({ name:'ORANGE_SLIDE', width:10, height:5.625 });
    pres.layout  = 'ORANGE_SLIDE';
    pres.author  = 'VOC Data - Orange';
    pres.subject = title;
    pres.title   = title;
    return { pres, theme: getTheme(mode) };
}

const LOGO_PATH = path.join(__dirname, 'assets/Small_Logo_RGB.png');

function addOrangeLogo(slide) {
    const { x, y, w, h } = POS.logo;
    if (fs.existsSync(LOGO_PATH)) {
        slide.addImage({ path: LOGO_PATH, x, y, w, h });
    } else {
        slide.addShape('rect', { x, y, w, h, fill:{ color:ORANGE_COLORS.primary.orange }, line:{ color:ORANGE_COLORS.primary.orange } });
        slide.addText('orange', { x, y, w, h, fontFace:FONT, fontSize:9, color:ORANGE_COLORS.primary.white, bold:true, align:'center', valign:'middle', shrinkText:true, bullet:false });
    }
}

function addSlideNumber(slide, num, theme) {
    if (num == null) return;
    const { x, y, w, h } = POS.slideNum;
    slide.addText(String(num), { x, y, w, h, fontFace:FONT, fontSize:8, color:theme.slideNum, align:'right', shrinkText:true, bullet:false });
}

// ── COMPOSANTS UNITAIRES ────────────────────────────────────────────────────

function addCard(slide, pos, opts = {}) {
    const { x, y, w, h } = pos;
    slide.addShape('roundRect', { x, y, w, h, fill:{ color:opts.bgColor || ORANGE_COLORS.bg.card }, line:{ color:ORANGE_COLORS.primary.grayLight, width:1 }, rectRadius:VISUAL.cardRadius });
    if (opts.topStripe !== false) {
        slide.addShape('roundRect', { x, y, w, h:VISUAL.stripe, fill:{ color:ORANGE_COLORS.primary.orange }, line:{ color:ORANGE_COLORS.primary.orange }, rectRadius:VISUAL.cardRadius });
    }
    if (opts.title) {
        slide.addText(opts.title, { x:x+VISUAL.cardPadding, y:y+VISUAL.stripe+0.06, w:w-2*VISUAL.cardPadding, h:0.35, fontFace:FONT, fontSize:13, bold:true, color:opts.titleColor||ORANGE_COLORS.primary.black, align:'left', valign:'middle', shrinkText:true, bullet:false });
    }
    if (opts.body) {
        const bodyY = y + VISUAL.stripe + 0.06 + (opts.title ? 0.37 : 0);
        const bodyH = h - VISUAL.stripe - 0.06 - (opts.title ? 0.37 : 0) - 0.1;
        slide.addText(opts.body, { x:x+VISUAL.cardPadding, y:bodyY, w:w-2*VISUAL.cardPadding, h:bodyH, fontFace:FONT, fontSize:11, bold:false, color:opts.bodyColor||ORANGE_COLORS.primary.grayDark, align:'left', valign:'top', lineSpacingPercent:115, shrinkText:true, bullet:false });
    }
}

function addInfoBox(slide, pos, text, opts = {}) {
    const { x, y, w, h } = pos;
    slide.addShape('rect', { x, y, w, h, fill:{ color:opts.bgColor||ORANGE_COLORS.bg.card }, line:{ color:opts.bgColor||ORANGE_COLORS.bg.card } });
    slide.addShape('rect', { x, y, w:VISUAL.stripe, h, fill:{ color:opts.borderColor||ORANGE_COLORS.primary.orange }, line:{ color:opts.borderColor||ORANGE_COLORS.primary.orange } });
    slide.addText(text, { x:x+VISUAL.stripe+VISUAL.cardPadding, y, w:w-VISUAL.stripe-VISUAL.cardPadding, h, fontFace:FONT, fontSize:opts.fontSize||11, bold:false, color:opts.textColor||ORANGE_COLORS.primary.grayDark, align:'left', valign:'middle', lineSpacingPercent:115, shrinkText:true, bullet:false });
}

function addBadge(slide, pos, text, opts = {}) {
    const { x, y, w, h } = pos;
    slide.addShape('roundRect', { x, y, w, h, fill:{ color:opts.bgColor||ORANGE_COLORS.primary.orange }, line:{ color:opts.bgColor||ORANGE_COLORS.primary.orange }, rectRadius:h/2 });
    slide.addText(text, { x, y, w, h, fontFace:FONT, fontSize:opts.fontSize||12, bold:true, color:opts.textColor||ORANGE_COLORS.primary.white, align:'center', valign:'middle', shrinkText:true, bullet:false });
}

function addColorSwatch(slide, pos, color, label, opts = {}) {
    const { x, y, size = 0.5 } = pos;
    slide.addShape('roundRect', { x, y, w:size, h:size, fill:{ color }, line:{ color:ORANGE_COLORS.primary.grayLight, width:0.5 }, rectRadius:VISUAL.swatchRadius });
    if (label) slide.addText(label, { x, y:y+size+0.05, w:size, h:0.2, fontFace:FONT, fontSize:8, bold:false, color:opts.labelColor||ORANGE_COLORS.primary.grayDark, align:'center', valign:'top', shrinkText:true, bullet:false });
}

// ── SLIDES DE BASE ──────────────────────────────────────────────────────────

function addTitleSlide(pres, title, subtitle, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(title, { ...POS.titleBig, fontFace:FONT, fontSize:55, bold:true, color:theme.body, align:'left', valign:'top', lineSpacingPercent:85, shrinkText:true, bullet:false });
    if (subtitle) s.addText(subtitle, { ...POS.subtitle, fontFace:FONT, fontSize:18, bold:false, color:theme.sideText, align:'left', valign:'top', lineSpacingPercent:115, shrinkText:true, bullet:false });
    if (opts.sideText) s.addText(opts.sideText, { ...POS.sideText, fontFace:FONT, fontSize:14, bold:false, color:theme.sideText, align:'right', valign:'top', lineSpacingPercent:115, shrinkText:true, bullet:false });
    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

function addSectionSlide(pres, sectionTitle, sectionNumber, theme) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(String(sectionNumber).padStart(2,'0') + '\n' + sectionTitle, { ...POS.section, fontFace:FONT, fontSize:55, bold:true, color:theme.sectionTitle, align:'left', valign:'top', lineSpacingPercent:85, shrinkText:true, bullet:false });
    addOrangeLogo(s);
    return s;
}

function addContentSlide(pres, title, bullets, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(title, { ...POS.title, fontFace:FONT, fontSize:20, bold:true, color:ORANGE_COLORS.primary.orange, align:'left', valign:'middle', lineSpacingPercent:90, shrinkText:true, bullet:false });
    s.addText(bullets.map(b => formatBullet(b)).join('\n'), { ...POS.body, fontFace:FONT, fontSize:13, bold:false, color:theme.body, align:'left', valign:'top', lineSpacingPercent:115, shrinkText:true, bullet:false });
    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

function addTwoColumnSlide(pres, title, leftBullets, rightBullets, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(title, { ...POS.title, fontFace:FONT, fontSize:20, bold:true, color:ORANGE_COLORS.primary.orange, align:'left', valign:'middle', lineSpacingPercent:90, shrinkText:true, bullet:false });
    s.addText(leftBullets.map(b => formatBullet(b)).join('\n'),  { ...POS.colLeft,  fontFace:FONT, fontSize:13, bold:false, color:theme.body, align:'left', valign:'top', lineSpacingPercent:115, shrinkText:true, bullet:false });
    s.addText(rightBullets.map(b => formatBullet(b)).join('\n'), { ...POS.colRight, fontFace:FONT, fontSize:13, bold:false, color:theme.body, align:'left', valign:'top', lineSpacingPercent:115, shrinkText:true, bullet:false });
    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

function addEndSlide(pres, message, theme) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(message || 'Merci', { x:0, y:1.5, w:10, h:2.625, fontFace:FONT, fontSize:55, bold:true, color:theme.sectionTitle, align:'center', valign:'middle', lineSpacingPercent:85, shrinkText:true, bullet:false });
    addOrangeLogo(s);
    return s;
}

// ── SLIDES RICHES ───────────────────────────────────────────────────────────

function addComparisonSlide(pres, title, left, right, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(title, { ...POS.title, fontFace:FONT, fontSize:20, bold:true, color:ORANGE_COLORS.primary.orange, align:'left', valign:'middle', shrinkText:true, bullet:false });
    const cardY = 1.1, cardH = 3.1;
    [[left, POS.colLeft], [right, POS.colRight]].forEach(([card, col]) => {
        s.addShape('roundRect', { x:col.x, y:cardY, w:col.w, h:cardH, fill:{ color:card.bgColor||ORANGE_COLORS.bg.card }, line:{ color:ORANGE_COLORS.primary.grayLight, width:1 }, rectRadius:VISUAL.cardRadius });
        s.addText(card.title, { x:col.x+VISUAL.cardPadding, y:cardY+0.12, w:col.w-2*VISUAL.cardPadding, h:0.4, fontFace:FONT, fontSize:14, bold:true, color:card.titleColor||theme.title, align:'left', valign:'middle', shrinkText:true, bullet:false });
        s.addText(card.body,  { x:col.x+VISUAL.cardPadding, y:cardY+0.6,  w:col.w-2*VISUAL.cardPadding, h:cardH-0.75, fontFace:FONT, fontSize:12, bold:false, color:card.bodyColor||theme.body, align:'left', valign:'top', lineSpacingPercent:120, shrinkText:true, bullet:false });
    });
    if (opts.infoBox) addInfoBox(s, { x:POS.colLeft.x, y:cardY+cardH+0.1, w:9.315, h:0.4 }, opts.infoBox, { textColor:theme.body });
    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

function addCardGridSlide(pres, title, cards, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    const cols  = opts.cols  || 2;
    const cardH = opts.cardH || 1.5;

    // Titre + stripe orange
    s.addText(title, { ...POS.title, fontFace:FONT, fontSize:20, bold:true, color:ORANGE_COLORS.primary.orange, align:'left', valign:'middle', lineSpacingPercent:90, shrinkText:true, bullet:false });
    s.addShape('rect', { x:POS.title.x, y:POS.title.y+POS.title.h, w:POS.title.w, h:VISUAL.stripe, fill:{ color:ORANGE_COLORS.primary.orange }, line:{ color:ORANGE_COLORS.primary.orange } });

    const startY = POS.title.y + POS.title.h + VISUAL.stripe + VISUAL.gap;
    const cardW  = (POS.title.w - (cols-1)*VISUAL.gap) / cols;

    cards.forEach((card, i) => {
        const col = i % cols;
        const row = Math.floor(i / cols);
        addCard(s,
            { x:POS.title.x + col*(cardW+VISUAL.gap), y:startY + row*(cardH+VISUAL.gap), w:cardW, h:cardH },
            { title:card.title, body:card.body, topStripe:true, titleColor:card.titleColor||theme.body, bodyColor:card.bodyColor||ORANGE_COLORS.primary.grayDark }
        );
    });

    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

function addBadgeSlide(pres, title, badges, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(title, { ...POS.title, fontFace:FONT, fontSize:20, bold:true, color:ORANGE_COLORS.primary.orange, align:'left', valign:'middle', lineSpacingPercent:90, shrinkText:true, bullet:false });

    const startY = 1.2;
    const rowH   = (LOGO_SAFE_Y - startY) / badges.length;
    const badgeW = 2.2, badgeH = 0.38;

    badges.forEach((badge, i) => {
        const by = startY + i*rowH + (rowH-badgeH)/2;
        addBadge(s, { x:POS.title.x, y:by, w:badgeW, h:badgeH }, badge.label);
        s.addText(badge.description || badge.body || '', {
            x:POS.title.x+badgeW+0.3, y:startY+i*rowH, w:POS.title.w-badgeW-0.3, h:rowH,
            fontFace:FONT, fontSize:12, bold:false, color:theme.body, align:'left', valign:'middle',
            lineSpacingPercent:120, shrinkText:true, bullet:false
        });
        if (i < badges.length-1) s.addShape('line', { x:POS.title.x, y:startY+(i+1)*rowH-VISUAL.gap/2, w:POS.title.w, h:0, line:{ color:ORANGE_COLORS.primary.grayLight, width:0.5 } });
    });

    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

function addColorPaletteSlide(pres, title, swatches, theme, opts = {}) {
    const s = pres.addSlide();
    s.background = { color:theme.bg };
    s.addText(title, { ...POS.title, fontFace:FONT, fontSize:20, bold:true, color:ORANGE_COLORS.primary.orange, align:'left', valign:'middle', shrinkText:true, bullet:false });
    const size = opts.swatchSize || 0.7;
    const cols = opts.cols || 6;
    swatches.forEach((sw, i) => {
        const col = i % cols, row = Math.floor(i / cols);
        addColorSwatch(s, { x:POS.title.x+col*(size+0.15), y:1.3+row*(size+0.35), size }, sw.color, sw.label);
    });
    if (opts.rulesPanel) addInfoBox(s, { x:7.0, y:1.2, w:2.65, h:3.0 }, opts.rulesPanel);
    addOrangeLogo(s);
    addSlideNumber(s, opts.slideNum, theme);
    return s;
}

// ── EXPORTS ─────────────────────────────────────────────────────────────────

module.exports = {
    ORANGE_COLORS, ORANGE_FONTS, POS, VISUAL, LOGO_SAFE_Y, STYLES,
    getTheme, formatBullet, createOrangePres,
    addOrangeLogo, addSlideNumber,
    addTitleSlide, addContentSlide, addSectionSlide, addTwoColumnSlide, addEndSlide,
    addComparisonSlide, addCardGridSlide, addBadgeSlide, addColorPaletteSlide,
    addCard, addInfoBox, addBadge, addColorSwatch,
};
