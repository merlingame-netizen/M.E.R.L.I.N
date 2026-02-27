'use strict';

/**
 * mermaid_helper.js — Génération PNG depuis code Mermaid avec thème Orange
 *
 * Usage :
 *   const { generateDiagram, cleanupDiagrams } = require('./mermaid_helper.js');
 *   const pngPath = await generateDiagram(code, 'output.png', { width: 1400 });
 *
 * Dépendance : @mermaid-js/mermaid-cli (mmdc dans node_modules/.bin/)
 */

const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const path = require('path');
const os = require('os');

const execFileAsync = promisify(execFile);

// Chemin vers mmdc local
const MMDC_PATH = path.join(__dirname, 'node_modules', '.bin', 'mmdc');
const MMDC_FALLBACK = path.join(__dirname, '..', 'node_modules', '.bin', 'mmdc');
const CONFIG_PATH = path.join(__dirname, 'mermaid_config_orange.json');

// Répertoire temporaire pour les fichiers .mmd et .png
const TMP_DIR = path.join(os.tmpdir(), 'mermaid_orange');

/**
 * Trouve le chemin mmdc disponible
 * @returns {string} chemin absolu vers mmdc
 */
function getMmdcPath() {
    if (fs.existsSync(MMDC_PATH + '.cmd')) return MMDC_PATH + '.cmd';
    if (fs.existsSync(MMDC_PATH))         return MMDC_PATH;
    if (fs.existsSync(MMDC_FALLBACK + '.cmd')) return MMDC_FALLBACK + '.cmd';
    if (fs.existsSync(MMDC_FALLBACK))     return MMDC_FALLBACK;
    return 'mmdc'; // fallback global
}

/**
 * Génère un PNG depuis du code Mermaid
 *
 * @param {string} mermaidCode  - Code Mermaid (ex: "graph TB\n  A --> B")
 * @param {string} outputPath   - Chemin absolu du PNG de sortie
 * @param {object} [opts]       - Options optionnelles
 * @param {number} [opts.width=1400]     - Largeur en pixels
 * @param {number} [opts.height=900]     - Hauteur en pixels (0 = auto)
 * @param {string} [opts.background='white'] - Couleur de fond
 * @param {string} [opts.configPath]     - Chemin vers config JSON (défaut: orange)
 * @returns {Promise<string>} Chemin absolu du PNG généré
 */
async function generateDiagram(mermaidCode, outputPath, opts = {}) {
    const {
        width = 1400,
        background = 'white',
        configPath = CONFIG_PATH
    } = opts;

    // Créer le dossier tmp si nécessaire
    if (!fs.existsSync(TMP_DIR)) {
        fs.mkdirSync(TMP_DIR, { recursive: true });
    }

    // Fichier .mmd temporaire
    const tmpId = Date.now() + '_' + Math.random().toString(36).slice(2, 8);
    const mmdFile = path.join(TMP_DIR, `diagram_${tmpId}.mmd`);

    try {
        // Écrire le code Mermaid
        fs.writeFileSync(mmdFile, mermaidCode, 'utf8');

        // Préparer les arguments mmdc
        const args = [
            '-i', mmdFile,
            '-o', outputPath,
            '-b', background,
            '-w', String(width),
            '--quiet'
        ];

        // Ajouter la config Orange si elle existe
        if (fs.existsSync(configPath)) {
            args.push('-c', configPath);
        }

        const mmdcPath = getMmdcPath();
        console.log(`  [mermaid] Generating: ${path.basename(outputPath)} (${width}px)`);

        await execFileAsync(mmdcPath, args, {
            timeout: 30000,
            windowsHide: true,
            shell: true   // Requis sur Windows pour exécuter les fichiers .cmd
        });

        if (!fs.existsSync(outputPath)) {
            throw new Error(`mmdc n'a pas généré le fichier: ${outputPath}`);
        }

        const size = fs.statSync(outputPath).size;
        console.log(`  [mermaid] OK: ${path.basename(outputPath)} (${Math.round(size / 1024)}KB)`);

        return outputPath;

    } finally {
        // Nettoyage du fichier .mmd temporaire
        if (fs.existsSync(mmdFile)) {
            fs.unlinkSync(mmdFile);
        }
    }
}

/**
 * Génère plusieurs diagrammes en parallèle
 *
 * @param {Array<{code: string, path: string, opts?: object}>} diagrams
 * @returns {Promise<string[]>} Chemins des PNG générés
 */
async function generateDiagrams(diagrams) {
    return Promise.all(
        diagrams.map(({ code, path: outputPath, opts }) =>
            generateDiagram(code, outputPath, opts)
        )
    );
}

/**
 * Supprime une liste de fichiers PNG temporaires
 * @param {string[]} paths - Chemins des PNG à supprimer
 */
function cleanupDiagrams(paths) {
    paths.forEach(p => {
        if (p && fs.existsSync(p)) {
            fs.unlinkSync(p);
        }
    });
}

/**
 * Retourne un chemin PNG temporaire unique
 * @param {string} name - Nom descriptif (ex: "git_workflow")
 * @returns {string} Chemin absolu unique
 */
function tmpPngPath(name) {
    if (!fs.existsSync(TMP_DIR)) {
        fs.mkdirSync(TMP_DIR, { recursive: true });
    }
    return path.join(TMP_DIR, `${name}_${Date.now()}.png`);
}

module.exports = {
    generateDiagram,
    generateDiagrams,
    cleanupDiagrams,
    tmpPngPath,
    TMP_DIR
};
