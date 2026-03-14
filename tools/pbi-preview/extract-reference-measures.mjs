/**
 * Extract measure values from the reference cockpit_sat_v4.html
 * and save as measures_reference.json for preview comparison.
 */
import { readFileSync, writeFileSync } from 'fs';

const htmlPath = process.argv[2] || 'C:/Users/PGNK2128/Downloads/cockpit_sat_v4.html';
const outPath = process.argv[3] || 'C:/Users/PGNK2128/Downloads/measures_reference.json';

const html = readFileSync(htmlPath, 'utf8');

// Extract GD object from <script>const GD = {...};</script>
const match = html.match(/const GD\s*=\s*(\{[\s\S]*?\});/);
if (!match) {
  console.error('GD data object not found in HTML');
  process.exit(1);
}
const GD = JSON.parse(match[1]);

// Default view: Mois, Mars 2026
const d = GD.mois?.['Mars 2026'] || {};
console.log(`Found ${Object.keys(d).length} indicators in Mars 2026 mois`);

const measures = {};

// Map reference indicator names → our measure names
const mapping = {
  '3901 A2P DeltaSAT':                        { nps: 'NPS_3901_A2P',       rep: 'NbRep_3901_A2P' },
  '3901 S/Trait. DeltaSAT':                    { nps: 'NPS_3901_STrait',    rep: 'NbRep_3901_STrait' },
  '706 AC DeltaSAT':                           { nps: 'NPS_706_AC',        rep: 'NbRep_706_AC' },
  'Nomade/CDC DeltaSAT':                       { nps: 'NPS_Nomade',        rep: 'NbRep_Nomade' },
  'DVI DeltaSAT':                              { nps: 'NPS_DVI',           rep: 'NbRep_DVI' },
  'Boutique AD DeltaSAT':                      { nps: 'NPS_Boutique_AD',   rep: 'NbRep_Boutique_AD' },
  'Boutique OS DeltaSAT':                      { nps: 'NPS_Boutique_OS',   rep: 'NbRep_Boutique_OS' },
  'PAP DeltaSAT':                              { nps: 'NPS_PAP',           rep: 'NbRep_PAP' },
  'Offre Mobile E DeltaSAT':                   { nps: 'NPS_Mobile_Achat',  rep: 'NbRep_Mobile_Achat' },
  'Offre BB ProPME DeltaSat':                  { nps: 'NPS_Offre_BB',      rep: 'NbRep_Offre_BB' },
  'DeltaSAT DME E':                            { nps: 'NPS_Prod_BB',       rep: 'NbRep_Prod_BB' },
  'SAV offres BB E DeltaSAT':                  { nps: 'NPS_SAV_BB',        rep: 'NbRep_SAV_BB' },
  '3901 AT DeltaSAT':                          { nps: 'NPS_3901_AT',       rep: 'NbRep_3901_AT' },
  '706 AT DeltaSAT':                           { nps: 'NPS_706_AT',        rep: 'NbRep_706_AT' },
  'Global DeltaSAT':                           { nps: 'NPS_Recla_Global',  rep: 'NbRep_Recla_Global' },
  'Front (N1) DeltaSAT':                       { nps: 'NPS_Recla_Front',   rep: 'NbRep_Recla_Front' },
  'Back (N2) DeltaSAT':                        { nps: 'NPS_Recla_Back',    rep: 'NbRep_Recla_Back' },
  // Sub-measures (nps only)
  '3901 A2P Commerce':                         { nps: 'Commerce_Interne' },
  '3901 A2P Suivi Cde':                        { nps: 'SuiviCde_Interne' },
  '3901 A2P Reco':                             { nps: 'Reco_Interne' },
  '3901 S/Trait. Commerce':                    { nps: 'Commerce_Externe' },
  '3901 S/Trait. Suivi Cde':                   { nps: 'SuiviCde_Externe' },
  '3901 S/Trait. Reco':                        { nps: 'Reco_Externe' },
  'Boutique AD Commerce':                      { nps: 'Boutique_AD_Commerce' },
  'Boutique AD Service':                       { nps: 'Boutique_AD_Service' },
  'Boutique OS Commerce':                      { nps: 'Boutique_OS_Commerce' },
  'Boutique OS Service':                       { nps: 'Boutique_OS_Service' },
  'Boutique AD DeltaSAT GP':                   { nps: 'NPS_Boutique_AD_GP' },
  'Boutique OS DeltaSAT GP':                   { nps: 'NPS_Boutique_OS_GP' },
  'PAP DeltaSAT GP':                           { nps: 'NPS_PAP_GP' },
  // T1C measures
  '3901 A2P Traité au 1er contact':            { nps: 'T1C_3901_A2P' },
  '3901 S/Trait. Traité au 1er contact':       { nps: 'T1C_3901_STrait' },
  '706 AC Traité au 1er contact':              { nps: 'T1C_706_AC' },
  '706 AT Traité au 1er contact':              { nps: 'T1C_706_AT' },
  'Global Traité au 1er contact':              { nps: 'T1C_Recla_Global' },
  'Offre BB ProPME Traité au 1er contact':     { nps: 'T1C_Offre_BB' },
  'Traité au 1er contact DME':                 { nps: 'T1C_DME' },
  // Sub-BB measures
  'Offre BB ProPME Fibre':                     { nps: 'Offre_BB_Fibre' },
  'Offre BB ProPME Cuivre':                    { nps: 'Offre_BB_Cuivre' },
  'Offre BB ProPME Monoligne':                 { nps: 'Offre_BB_Mono' },
  'Offre BB ProPME Multiligne':                { nps: 'Offre_BB_Multi' },
};

for (const [indicator, measureMap] of Object.entries(mapping)) {
  const row = d[indicator];
  if (!row) {
    console.warn(`  Missing indicator: "${indicator}"`);
    continue;
  }
  if (measureMap.nps) measures[measureMap.nps] = row.nps;
  if (measureMap.rep) measures[measureMap.rep] = row.rep;
}

// Baro NPS (trimestre view, T4 2025)
const baroData = GD.trim?.['T4 2025'];
if (baroData) {
  // Find the "NPS Baro Global" or similar key
  for (const [k, v] of Object.entries(baroData)) {
    if (k.toLowerCase().includes('baro') || k.toLowerCase().includes('global')) {
      measures['NPS_Baro_Global'] = v.nps;
      measures['NbRep_Baro_Global'] = v.rep;
      console.log(`  Baro: ${k} → NPS=${v.nps}, Rep=${v.rep}`);
      break;
    }
  }
}

const filled = Object.values(measures).filter(v => v !== null && v !== undefined).length;
console.log(`\nExtracted ${filled}/${Object.keys(measures).length} measure values`);

writeFileSync(outPath, JSON.stringify(measures, null, 2), 'utf8');
console.log(`Saved to: ${outPath}`);
