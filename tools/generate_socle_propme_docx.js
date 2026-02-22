/**
 * Generateur: Template Socle de Donnees Sondage ProPME (GCP)
 *
 * Genere un document Word (.docx) charte Orange avec la structure complete
 * du document de specification du socle BigQuery ProPME.
 * Toutes les sections contiennent des placeholders [A remplir].
 *
 * Usage: node generate_socle_propme_docx.js
 * Output: ~/Downloads/Template_Socle_Sondage_ProPME.docx
 */

const path = require('path');
const { createOrangeDoc, saveOrangeDoc, createOrangeTable } = require('./create_orange_docx');

// ============================================
// DOCUMENT STRUCTURE (13 sections)
// ============================================
const SECTIONS = [
    {
        title: 'Contexte & Objectifs',
        subsections: [
            { title: 'Contexte du projet' },
            { title: 'Objectifs du socle de donnees' },
            { title: 'Perimetre fonctionnel' },
            { title: 'Hors perimetre' }
        ]
    },
    {
        title: 'Parties Prenantes',
        subsections: [
            {
                title: 'Equipe projet',
                table: {
                    headers: ['Role', 'Nom', 'Direction', 'R/A/C/I'],
                    rows: [
                        ['Chef de projet', '[A remplir]', '[A remplir]', 'R'],
                        ['Product Owner', '[A remplir]', '[A remplir]', 'A'],
                        ['Data Engineer', '[A remplir]', '[A remplir]', 'R'],
                        ['Data Analyst', '[A remplir]', '[A remplir]', 'C'],
                        ['Architecte GCP', '[A remplir]', '[A remplir]', 'C'],
                        ['RSSI / DPO', '[A remplir]', '[A remplir]', 'I']
                    ]
                }
            },
            { title: 'Comitologie' },
            { title: 'Contacts cles' }
        ]
    },
    {
        title: 'Architecture Technique',
        subsections: [
            { title: 'Vue d\'ensemble GCP' },
            {
                title: 'Projet GCP & Datasets BigQuery',
                table: {
                    headers: ['Element', 'Valeur'],
                    rows: [
                        ['Projet GCP', '[A remplir]'],
                        ['Region', '[A remplir]'],
                        ['Nombre de datasets', '[A remplir]'],
                        ['Methode d\'authentification', '[A remplir]'],
                        ['Outils d\'acces', '[A remplir]']
                    ]
                }
            },
            { title: 'Composants de la plateforme' },
            {
                title: 'Schema d\'architecture',
                body: '[Inserer le diagramme d\'architecture ici]'
            },
            {
                title: 'Environnements',
                table: {
                    headers: ['Environnement', 'Projet GCP', 'Usage', 'Acces'],
                    rows: [
                        ['DEV', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['PREPROD', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['PROD', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            }
        ]
    },
    {
        title: 'Modele de Donnees',
        subsections: [
            { title: 'Vue logique des datasets' },
            {
                title: 'Tables principales',
                table: {
                    headers: ['Dataset', 'Table', 'Description', 'Nb colonnes', 'Volume estime'],
                    rows: [
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            {
                title: 'Dictionnaire de donnees',
                table: {
                    headers: ['Table', 'Colonne', 'Type', 'Nullable', 'Description', 'Exemple'],
                    rows: [
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            {
                title: 'Relations entre tables',
                body: '[Inserer le diagramme de relations ici]'
            },
            { title: 'Conventions de nommage' }
        ]
    },
    {
        title: 'Sources de Donnees',
        subsections: [
            {
                title: 'Inventaire des sources',
                table: {
                    headers: ['Source', 'Type', 'Frequence', 'Volume', 'Format', 'Responsable'],
                    rows: [
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            { title: 'Protocoles d\'extraction' },
            { title: 'Mapping source-cible' }
        ]
    },
    {
        title: 'Flux de Donnees & Pipeline',
        subsections: [
            {
                title: 'Architecture d\'ingestion',
                body: '[Inserer le diagramme de flux ici]'
            },
            { title: 'Transformations & regles metier' },
            { title: 'Orchestration (scheduler, DAGs)' },
            { title: 'Gestion des erreurs & rejets' },
            { title: 'Monitoring & alerting' }
        ]
    },
    {
        title: 'KPIs & Metriques',
        subsections: [
            {
                title: 'KPIs cibles',
                table: {
                    headers: ['KPI', 'Definition', 'Formule de calcul', 'Seuil / Objectif', 'Frequence'],
                    rows: [
                        ['NPS', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['CSAT', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['CES', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Taux de detracteurs', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Volume sondages', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            {
                title: 'Dimensions de segmentation',
                table: {
                    headers: ['Dimension', 'Description', 'Valeurs possibles', 'Source'],
                    rows: [
                        ['Region', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Segment client', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Type d\'offre', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['BU', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            { title: 'Regles de calcul' },
            { title: 'Restitution & dashboards' }
        ]
    },
    {
        title: 'Securite & Conformite',
        subsections: [
            {
                title: 'Authentification & gestion des acces (IAM)',
                table: {
                    headers: ['Role IAM', 'Perimetre', 'Profils concernes', 'Justification'],
                    rows: [
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            { title: 'RGPD & donnees personnelles' },
            { title: 'Chiffrement (at rest / in transit)' },
            { title: 'Audit trail & logs' }
        ]
    },
    {
        title: 'Gouvernance des Donnees',
        subsections: [
            { title: 'Roles et responsabilites data' },
            { title: 'Politique de qualite des donnees' },
            { title: 'Politique de retention & archivage' },
            { title: 'Lineage & tracabilite' }
        ]
    },
    {
        title: 'Performance & Scalabilite',
        subsections: [
            {
                title: 'Volumetrie cible',
                table: {
                    headers: ['Metrique', 'Valeur actuelle', 'Cible a 1 an', 'Cible a 3 ans'],
                    rows: [
                        ['Nb reponses / trimestre', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Taille totale stockage', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Nb tables', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Nb utilisateurs simultanes', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            { title: 'SLA & temps de reponse' },
            { title: 'Optimisations BigQuery (partitioning, clustering)' },
            { title: 'Controle des couts GCP' }
        ]
    },
    {
        title: 'Tests & Recette',
        subsections: [
            { title: 'Strategie de test' },
            { title: 'Jeux de donnees de test' },
            {
                title: 'Criteres d\'acceptation',
                table: {
                    headers: ['Critere', 'Description', 'Methode de verification', 'Statut'],
                    rows: [
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            {
                title: 'PV de recette',
                body: '[Inserer le proces-verbal de recette ici]'
            }
        ]
    },
    {
        title: 'Planning & Roadmap',
        subsections: [
            {
                title: 'Phases du projet',
                table: {
                    headers: ['Phase', 'Livrable', 'Date debut', 'Date fin', 'Statut'],
                    rows: [
                        ['Cadrage', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Specification', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Developpement', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Recette', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]'],
                        ['Mise en production', '[A remplir]', '[A remplir]', '[A remplir]', '[A remplir]']
                    ]
                }
            },
            { title: 'Jalons cles' },
            { title: 'Dependances & risques' }
        ]
    },
    {
        title: 'Annexes',
        subsections: [
            {
                title: 'Glossaire',
                table: {
                    headers: ['Terme', 'Definition'],
                    rows: [
                        ['GCP', 'Google Cloud Platform'],
                        ['BigQuery', 'Entrepot de donnees analytique serverless de Google'],
                        ['NPS', 'Net Promoter Score'],
                        ['CSAT', 'Customer Satisfaction Score'],
                        ['CES', 'Customer Effort Score'],
                        ['ProPME', '[A remplir]'],
                        ['IAM', 'Identity and Access Management'],
                        ['ADC', 'Application Default Credentials']
                    ]
                }
            },
            { title: 'Documents de reference' },
            { title: 'Changelog technique' }
        ]
    }
];

// ============================================
// GENERATE
// ============================================
async function main() {
    const outputPath = path.join(
        process.env.USERPROFILE || '',
        'Downloads',
        'Template_Socle_Sondage_ProPME.docx'
    );

    const doc = createOrangeDoc({
        title: 'Socle de Donnees Sondage ProPME',
        subtitle: 'Specification du socle BigQuery sous GCP',
        author: '[A remplir]',
        version: '0.1',
        status: 'Brouillon',
        project: 'Socle Sondage ProPME',
        direction: '[A remplir]',
        sections: SECTIONS
    });

    await saveOrangeDoc(doc, outputPath);
}

main().catch(err => {
    console.error('Erreur:', err);
    process.exit(1);
});
