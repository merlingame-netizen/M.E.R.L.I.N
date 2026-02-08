import fs from 'fs';
import { getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs';

async function extractPDF(filePath, outputName) {
    try {
        const data = new Uint8Array(fs.readFileSync(filePath));
        const doc = await getDocument({ data }).promise;

        let fullText = `# ${outputName}\n\nPages: ${doc.numPages}\n\n`;

        for (let i = 1; i <= doc.numPages; i++) {
            const page = await doc.getPage(i);
            const textContent = await page.getTextContent();
            const text = textContent.items.map(item => item.str).join(' ');
            fullText += `## Page ${i}\n\n${text}\n\n`;
        }

        return fullText;
    } catch (error) {
        return `Error extracting ${outputName}: ${error.message}`;
    }
}

async function main() {
    const pdfs = [
        { path: 'C:/Users/PGNK2128/Downloads/Charte---Style-Photo---FR-012026.pdf', name: 'Charte Style Photo' },
        { path: 'C:/Users/PGNK2128/Downloads/Charte---Langage-de-Marque---FR-13012026.pdf', name: 'Charte Langage de Marque' },
        { path: 'C:/Users/PGNK2128/Downloads/Bonnes-pratiques---Eco-branding---FR.pdf', name: 'Bonnes Pratiques Eco-branding' },
        { path: 'C:/Users/PGNK2128/Godot-MCP/resources/orange_brand_assets/mastermedia2/307992-Guidelines - Illustration - EN-Guidelines - Illustration - EN.pdf', name: 'Guidelines Illustration' }
    ];

    let allContent = '';

    for (const pdf of pdfs) {
        console.log(`Extracting: ${pdf.name}...`);
        const content = await extractPDF(pdf.path, pdf.name);
        allContent += content + '\n---\n\n';
    }

    fs.writeFileSync('c:/Users/PGNK2128/Godot-MCP/resources/charte_pdfs_extraits.md', allContent);
    console.log('Done! Output saved to charte_pdfs_extraits.md');
}

main().catch(console.error);
