/**
 * Generateur Word (.docx) ISO template officiel Orange — v1
 *
 * Miroir de create_orange_ppt.js pour documents Word.
 * Utilise le package `docx` (v9.x).
 *
 * Composants:
 *   - Page de garde avec logo Orange
 *   - Table des matieres (Sommaire)
 *   - Historique des versions (tableau)
 *   - Sections numerotees avec placeholders
 *   - Tableaux avec en-tetes Orange
 *   - Header/Footer avec logo + pagination
 *
 * Usage: const { createOrangeDoc } = require('./create_orange_docx');
 */

const {
    Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
    Header, Footer, PageNumber, TableOfContents,
    HeadingLevel, AlignmentType, WidthType, ShadingType, BorderStyle,
    VerticalAlign, TabStopType, NumberFormat, PageBreak,
    convertInchesToTwip
} = require('docx');
const path = require('path');
const fs = require('fs');

// Import Orange constants from PPT generator (single source of truth)
const { ORANGE_COLORS, ORANGE_FONTS } = require('./create_orange_ppt');

// ============================================
// LOGO PATH (same as PPT generator)
// ============================================
const SMALL_LOGO_PATH = path.join(
    process.env.USERPROFILE || '',
    'OneDrive - orange.com', 'Bureau', 'Agents', 'Data',
    'orange_brand_assets', 'mastermedia1', 'small_logo',
    'ORANGE_Small Logo', 'Small_Logo_Digital', 'Small_Logo_RGB.png'
);

// ============================================
// PAGE DIMENSIONS (A4)
// ============================================
const PAGE = {
    size: {
        width: 11906,    // A4 width in twips (210mm)
        height: 16838    // A4 height in twips (297mm)
    },
    margin: {
        top: 1440,       // 1 inch
        right: 1134,     // ~2cm
        bottom: 1440,
        left: 1134
    }
};

// ============================================
// FONT (Arial = safe fallback for Helvetica 75 Bold)
// ============================================
const FONT = ORANGE_FONTS.fallback; // 'Arial'

// ============================================
// CUSTOM STYLES
// ============================================
const DOCX_STYLES = {
    default: {
        document: {
            run: {
                font: FONT,
                size: 22,   // 11pt (half-points)
                color: ORANGE_COLORS.primary.black
            },
            paragraph: {
                spacing: { after: 120, line: 276 }  // 1.15 line spacing
            }
        }
    },
    paragraphStyles: [
        {
            id: 'Heading1',
            name: 'Heading 1',
            basedOn: 'Normal',
            next: 'Normal',
            quickFormat: true,
            run: {
                font: FONT,
                size: 32,   // 16pt
                bold: true,
                color: ORANGE_COLORS.primary.orange
            },
            paragraph: {
                spacing: { before: 360, after: 200 },
                outlineLevel: 0
            }
        },
        {
            id: 'Heading2',
            name: 'Heading 2',
            basedOn: 'Normal',
            next: 'Normal',
            quickFormat: true,
            run: {
                font: FONT,
                size: 28,   // 14pt
                bold: true,
                color: ORANGE_COLORS.primary.black
            },
            paragraph: {
                spacing: { before: 240, after: 120 },
                outlineLevel: 1
            }
        },
        {
            id: 'Heading3',
            name: 'Heading 3',
            basedOn: 'Normal',
            next: 'Normal',
            quickFormat: true,
            run: {
                font: FONT,
                size: 24,   // 12pt
                bold: true,
                color: ORANGE_COLORS.primary.grayDark
            },
            paragraph: {
                spacing: { before: 200, after: 100 },
                outlineLevel: 2
            }
        }
    ]
};

// ============================================
// TABLE BORDER DEFAULT
// ============================================
const TABLE_BORDER = {
    style: BorderStyle.SINGLE,
    size: 1,
    color: ORANGE_COLORS.primary.grayLight
};

const ALL_BORDERS = {
    top: TABLE_BORDER,
    bottom: TABLE_BORDER,
    left: TABLE_BORDER,
    right: TABLE_BORDER
};

// ============================================
// HELPER: Read logo data (cached)
// ============================================
let _logoCache = null;
function getLogoData() {
    if (_logoCache !== null) return _logoCache;
    _logoCache = fs.existsSync(SMALL_LOGO_PATH)
        ? fs.readFileSync(SMALL_LOGO_PATH)
        : false;
    return _logoCache;
}

// ============================================
// COMPONENT: Header (logo + title + orange rule)
// ============================================
function createHeader(docTitle) {
    const logoData = getLogoData();
    const children = [];

    if (logoData) {
        children.push(new ImageRun({
            type: 'png',
            data: logoData,
            transformation: { width: 50, height: 50 },
            altText: { title: 'Orange', description: 'Logo Orange', name: 'logo' }
        }));
    }

    children.push(new TextRun({ text: '\t' }));
    children.push(new TextRun({
        text: docTitle,
        font: FONT,
        size: 16,   // 8pt
        color: ORANGE_COLORS.primary.grayDark
    }));

    return new Header({
        children: [
            new Paragraph({
                children,
                tabStops: [{
                    type: TabStopType.RIGHT,
                    position: convertInchesToTwip(6.5)
                }],
                border: {
                    bottom: {
                        style: BorderStyle.SINGLE,
                        size: 6,
                        color: ORANGE_COLORS.primary.orange,
                        space: 4
                    }
                },
                spacing: { after: 200 }
            })
        ]
    });
}

// ============================================
// COMPONENT: Footer (confidential + page X/Y)
// ============================================
function createFooter() {
    return new Footer({
        children: [
            new Paragraph({
                children: [
                    new TextRun({
                        text: 'Confidentiel Orange',
                        font: FONT,
                        size: 14,   // 7pt
                        color: ORANGE_COLORS.primary.grayMedium,
                        italics: false
                    }),
                    new TextRun({ text: '\t' }),
                    new TextRun({
                        text: 'Page ',
                        font: FONT,
                        size: 14,
                        color: ORANGE_COLORS.primary.grayDark
                    }),
                    new TextRun({
                        children: [PageNumber.CURRENT],
                        font: FONT,
                        size: 14,
                        color: ORANGE_COLORS.primary.grayDark
                    }),
                    new TextRun({
                        text: ' / ',
                        font: FONT,
                        size: 14,
                        color: ORANGE_COLORS.primary.grayDark
                    }),
                    new TextRun({
                        children: [PageNumber.TOTAL_PAGES],
                        font: FONT,
                        size: 14,
                        color: ORANGE_COLORS.primary.grayDark
                    })
                ],
                tabStops: [{
                    type: TabStopType.RIGHT,
                    position: convertInchesToTwip(6.5)
                }],
                border: {
                    top: {
                        style: BorderStyle.SINGLE,
                        size: 2,
                        color: ORANGE_COLORS.primary.grayLight,
                        space: 4
                    }
                }
            })
        ]
    });
}

// ============================================
// COMPONENT: Orange Table (headers orange, alternating rows)
// ============================================
function createOrangeTable(headers, rows) {
    const colCount = headers.length;
    const tableWidth = 9360;
    const colWidth = Math.floor(tableWidth / colCount);

    const headerRow = new TableRow({
        tableHeader: true,
        children: headers.map(text => new TableCell({
            width: { size: colWidth, type: WidthType.DXA },
            shading: {
                fill: ORANGE_COLORS.primary.orange,
                type: ShadingType.CLEAR
            },
            borders: ALL_BORDERS,
            margins: { top: 60, bottom: 60, left: 100, right: 100 },
            verticalAlign: VerticalAlign.CENTER,
            children: [new Paragraph({
                children: [new TextRun({
                    text,
                    font: FONT,
                    bold: true,
                    size: 20,
                    color: ORANGE_COLORS.primary.white
                })],
                alignment: AlignmentType.LEFT
            })]
        }))
    });

    const dataRows = rows.map((row, idx) => new TableRow({
        children: row.map(cellText => new TableCell({
            width: { size: colWidth, type: WidthType.DXA },
            shading: {
                fill: idx % 2 === 1 ? 'F5F5F5' : 'FFFFFF',
                type: ShadingType.CLEAR
            },
            borders: ALL_BORDERS,
            margins: { top: 40, bottom: 40, left: 100, right: 100 },
            children: [new Paragraph({
                children: [new TextRun({
                    text: cellText,
                    font: FONT,
                    size: 20,
                    color: ORANGE_COLORS.primary.black
                })]
            })]
        }))
    }));

    return new Table({
        width: { size: tableWidth, type: WidthType.DXA },
        columnWidths: Array(colCount).fill(colWidth),
        rows: [headerRow, ...dataRows]
    });
}

// ============================================
// COMPONENT: Metadata table (key-value pairs, no orange header)
// ============================================
function createMetadataTable(pairs) {
    const keyWidth = 2400;
    const valWidth = 6960;

    const rows = pairs.map(([key, val]) => new TableRow({
        children: [
            new TableCell({
                width: { size: keyWidth, type: WidthType.DXA },
                shading: { fill: 'F5F5F5', type: ShadingType.CLEAR },
                borders: ALL_BORDERS,
                margins: { top: 40, bottom: 40, left: 100, right: 100 },
                children: [new Paragraph({
                    children: [new TextRun({
                        text: key,
                        font: FONT,
                        bold: true,
                        size: 20,
                        color: ORANGE_COLORS.primary.black
                    })]
                })]
            }),
            new TableCell({
                width: { size: valWidth, type: WidthType.DXA },
                borders: ALL_BORDERS,
                margins: { top: 40, bottom: 40, left: 100, right: 100 },
                children: [new Paragraph({
                    children: [new TextRun({
                        text: val,
                        font: FONT,
                        size: 20,
                        color: ORANGE_COLORS.primary.grayDark
                    })]
                })]
            })
        ]
    }));

    return new Table({
        width: { size: keyWidth + valWidth, type: WidthType.DXA },
        columnWidths: [keyWidth, valWidth],
        rows
    });
}

// ============================================
// SECTION: Cover Page
// ============================================
function createCoverSection(opts) {
    const logoData = getLogoData();
    const children = [];

    // Logo at top
    if (logoData) {
        children.push(new Paragraph({
            children: [
                new ImageRun({
                    type: 'png',
                    data: logoData,
                    transformation: { width: 120, height: 120 },
                    altText: { title: 'Orange', description: 'Logo Orange', name: 'logo' }
                })
            ],
            spacing: { after: 600 }
        }));
    }

    // Vertical space
    children.push(new Paragraph({ spacing: { before: 1600 } }));

    // Title
    children.push(new Paragraph({
        children: [new TextRun({
            text: opts.title || 'Document Orange',
            font: FONT,
            size: 56,   // 28pt
            bold: true,
            color: ORANGE_COLORS.primary.orange
        })],
        spacing: { after: 200 }
    }));

    // Subtitle
    if (opts.subtitle) {
        children.push(new Paragraph({
            children: [new TextRun({
                text: opts.subtitle,
                font: FONT,
                size: 32,   // 16pt
                color: ORANGE_COLORS.primary.grayDark
            })],
            spacing: { after: 400 }
        }));
    }

    // Orange horizontal rule
    children.push(new Paragraph({
        border: {
            bottom: {
                style: BorderStyle.SINGLE,
                size: 12,
                color: ORANGE_COLORS.primary.orange,
                space: 8
            }
        },
        spacing: { after: 400 }
    }));

    // Metadata table
    children.push(createMetadataTable([
        ['Auteur', opts.author || '[À remplir]'],
        ['Date', opts.date || new Date().toLocaleDateString('fr-FR')],
        ['Version', opts.version || '0.1'],
        ['Statut', opts.status || 'Brouillon'],
        ['Projet', opts.project || '[À remplir]'],
        ['Direction', opts.direction || '[À remplir]']
    ]));

    return {
        properties: {
            page: { size: PAGE.size, margin: PAGE.margin }
            // No header/footer on cover page
        },
        children
    };
}

// ============================================
// SECTION: Table of Contents
// ============================================
function createTocSection(docTitle) {
    return {
        properties: {
            page: { size: PAGE.size, margin: PAGE.margin },
            pageNumbers: { start: 1, formatType: NumberFormat.DECIMAL }
        },
        headers: { default: createHeader(docTitle) },
        footers: { default: createFooter() },
        children: [
            new Paragraph({
                heading: HeadingLevel.HEADING_1,
                children: [new TextRun({ text: 'Sommaire' })]
            }),
            new TableOfContents('Sommaire', {
                hyperlink: true,
                headingStyleRange: '1-3'
            })
        ]
    };
}

// ============================================
// SECTION: Version History
// ============================================
function createVersionHistorySection(docTitle, versions) {
    const defaultVersions = versions || [
        ['0.1', new Date().toLocaleDateString('fr-FR'), '[Auteur]', 'Creation initiale'],
        ['0.2', '[Date]', '[Auteur]', '[À remplir]'],
        ['1.0', '[Date]', '[Auteur]', '[À remplir]']
    ];

    return {
        properties: {
            page: { size: PAGE.size, margin: PAGE.margin }
        },
        headers: { default: createHeader(docTitle) },
        footers: { default: createFooter() },
        children: [
            new Paragraph({
                heading: HeadingLevel.HEADING_1,
                children: [new TextRun({ text: 'Historique des versions' })],
                pageBreakBefore: true
            }),
            new Paragraph({ spacing: { after: 120 } }),
            createOrangeTable(
                ['Version', 'Date', 'Auteur', 'Description des modifications'],
                defaultVersions
            )
        ]
    };
}

// ============================================
// RICH BODY RENDERER — multi-line, bold, bullets
// ============================================

/**
 * Parse **bold** markers in a line and return TextRun[].
 */
function parseRichText(line, baseColor) {
    const runs = [];
    const regex = /\*\*(.+?)\*\*/g;
    let lastIndex = 0;
    let match;
    while ((match = regex.exec(line)) !== null) {
        if (match.index > lastIndex) {
            runs.push(new TextRun({
                text: line.slice(lastIndex, match.index),
                font: FONT, size: 22, color: baseColor
            }));
        }
        runs.push(new TextRun({
            text: match[1],
            font: FONT, size: 22, color: baseColor, bold: true
        }));
        lastIndex = regex.lastIndex;
    }
    if (lastIndex < line.length) {
        runs.push(new TextRun({
            text: line.slice(lastIndex),
            font: FONT, size: 22, color: baseColor
        }));
    }
    if (runs.length === 0) {
        runs.push(new TextRun({ text: ' ', font: FONT, size: 22, color: baseColor }));
    }
    return runs;
}

/**
 * Render body text into Paragraph[].
 * Supports: multi-line (\n), bullets (- ), bold (**text**), empty line spacers.
 */
function renderBody(text, isPlaceholder) {
    if (isPlaceholder) {
        return [new Paragraph({
            children: [new TextRun({
                text: text,
                font: FONT, size: 22,
                color: ORANGE_COLORS.primary.grayMedium
            })],
            spacing: { after: 120 }
        })];
    }

    const paragraphs = [];
    const color = ORANGE_COLORS.primary.black;
    const lines = text.split('\n');

    for (const line of lines) {
        if (line.trim() === '') {
            paragraphs.push(new Paragraph({ spacing: { after: 60 } }));
        } else if (line.startsWith('- ')) {
            // Bullet point
            paragraphs.push(new Paragraph({
                children: parseRichText('\u2013 ' + line.slice(2), color),
                indent: { left: 720 },
                spacing: { after: 40 }
            }));
        } else {
            paragraphs.push(new Paragraph({
                children: parseRichText(line, color),
                spacing: { after: 80 }
            }));
        }
    }

    if (paragraphs.length > 0) {
        // Extra spacing after last paragraph
        paragraphs.push(new Paragraph({ spacing: { after: 40 } }));
    }

    return paragraphs;
}

/**
 * Render code/diagram block in monospace (Courier New, grey background).
 */
function renderCodeBlock(codeText) {
    const lines = codeText.split('\n');
    const paragraphs = lines.map(line => new Paragraph({
        children: [new TextRun({
            text: line || ' ',
            font: 'Courier New',
            size: 16,       // 8pt
            color: '333333'
        })],
        spacing: { after: 0, line: 240 },
        shading: { fill: 'F5F5F5', type: ShadingType.CLEAR }
    }));
    return paragraphs;
}

// ============================================
// BUILDER: Content section with subsections
// ============================================
function buildContentChildren(sectionNum, sectionTitle, subsections) {
    const children = [
        new Paragraph({
            heading: HeadingLevel.HEADING_1,
            children: [new TextRun({ text: `${sectionNum}. ${sectionTitle}` })],
            pageBreakBefore: true
        })
    ];

    if (subsections && subsections.length > 0) {
        for (let i = 0; i < subsections.length; i++) {
            const sub = subsections[i];

            // H2 subsection
            children.push(new Paragraph({
                heading: HeadingLevel.HEADING_2,
                children: [new TextRun({
                    text: `${sectionNum}.${i + 1} ${sub.title}`
                })]
            }));

            // Body text (multi-line, bold, bullets)
            const bodyText = sub.body || '[À remplir]';
            children.push(...renderBody(bodyText, !sub.body));

            // Code/diagram block (monospace)
            if (sub.code) {
                children.push(...renderCodeBlock(sub.code));
                children.push(new Paragraph({ spacing: { after: 120 } }));
            }

            // Optional table
            if (sub.table) {
                children.push(new Paragraph({ spacing: { after: 80 } }));
                children.push(createOrangeTable(sub.table.headers, sub.table.rows));
                children.push(new Paragraph({ spacing: { after: 120 } }));
            }

            // Optional H3 sub-subsections
            if (sub.subsections) {
                for (let j = 0; j < sub.subsections.length; j++) {
                    const sub3 = sub.subsections[j];
                    children.push(new Paragraph({
                        heading: HeadingLevel.HEADING_3,
                        children: [new TextRun({
                            text: `${sectionNum}.${i + 1}.${j + 1} ${sub3.title}`
                        })]
                    }));

                    // H3 body (multi-line, bold, bullets)
                    const body3 = sub3.body || '[À remplir]';
                    children.push(...renderBody(body3, !sub3.body));

                    // H3 code block
                    if (sub3.code) {
                        children.push(...renderCodeBlock(sub3.code));
                        children.push(new Paragraph({ spacing: { after: 120 } }));
                    }

                    // H3 table
                    if (sub3.table) {
                        children.push(new Paragraph({ spacing: { after: 80 } }));
                        children.push(createOrangeTable(sub3.table.headers, sub3.table.rows));
                        children.push(new Paragraph({ spacing: { after: 120 } }));
                    }
                }
            }
        }
    } else {
        children.push(new Paragraph({
            children: [new TextRun({
                text: '[À remplir]',
                color: ORANGE_COLORS.primary.grayMedium
            })]
        }));
    }

    return children;
}

// ============================================
// FACTORY: Create complete Orange document
// ============================================
function createOrangeDoc(opts) {
    const docTitle = opts.title || 'Document Orange';
    const sections = [];

    // Section 1: Cover page
    sections.push(createCoverSection({
        title: docTitle,
        subtitle: opts.subtitle,
        author: opts.author,
        date: opts.date,
        version: opts.version,
        status: opts.status,
        project: opts.project,
        direction: opts.direction
    }));

    // Section 2: TOC
    sections.push(createTocSection(docTitle));

    // Section 3: Version history
    sections.push(createVersionHistorySection(docTitle, opts.versions));

    // Section 4+: Content sections
    const contentSections = opts.sections || [];
    const contentChildren = [];

    for (let i = 0; i < contentSections.length; i++) {
        const sec = contentSections[i];
        const secChildren = buildContentChildren(i + 1, sec.title, sec.subsections);
        contentChildren.push(...secChildren);
    }

    if (contentChildren.length > 0) {
        sections.push({
            properties: {
                page: { size: PAGE.size, margin: PAGE.margin }
            },
            headers: { default: createHeader(docTitle) },
            footers: { default: createFooter() },
            children: contentChildren
        });
    }

    return new Document({
        creator: opts.author || 'Orange',
        title: docTitle,
        description: opts.subtitle || '',
        features: { updateFields: true },
        styles: DOCX_STYLES,
        sections
    });
}

// ============================================
// HELPER: Save document to file
// ============================================
async function saveOrangeDoc(doc, outputPath) {
    const buffer = await Packer.toBuffer(doc);
    fs.writeFileSync(outputPath, buffer);
    console.log('OK: ' + outputPath);
    return outputPath;
}

// ============================================
// EXPORTS
// ============================================
module.exports = {
    ORANGE_COLORS,
    ORANGE_FONTS,
    FONT,
    PAGE,
    DOCX_STYLES,
    TABLE_BORDER,
    SMALL_LOGO_PATH,
    createOrangeDoc,
    saveOrangeDoc,
    createCoverSection,
    createTocSection,
    createVersionHistorySection,
    buildContentChildren,
    renderBody,
    renderCodeBlock,
    createOrangeTable,
    createMetadataTable,
    createHeader,
    createFooter
};

// ============================================
// STANDALONE DEMO
// ============================================
if (require.main === module) {
    const outputPath = path.join(
        process.env.USERPROFILE || '',
        'Downloads',
        'Template_Orange_Document.docx'
    );

    const doc = createOrangeDoc({
        title: 'Document Template Orange',
        subtitle: 'Modele de document conforme a la charte Orange',
        author: 'Orange',
        version: '1.0',
        status: 'Template',
        sections: [
            {
                title: 'Introduction',
                subsections: [
                    { title: 'Contexte' },
                    { title: 'Objectifs' },
                    { title: 'Perimetre' }
                ]
            },
            {
                title: 'Analyse',
                subsections: [
                    { title: 'Etat des lieux' },
                    { title: 'Constats' }
                ]
            },
            {
                title: 'Annexes',
                subsections: [
                    { title: 'Glossaire' },
                    { title: 'References' }
                ]
            }
        ]
    });

    saveOrangeDoc(doc, outputPath).catch(err => {
        console.error('Erreur:', err);
        process.exit(1);
    });
}
