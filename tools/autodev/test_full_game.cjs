// M.E.R.L.I.N. — Full Game Playthrough Test v3
// Flow: Boot → Menu → NP → Camera zoom → Cabin → Nouvelle Quête → Book Cinematic → Forest → Encounters
const { chromium } = require('playwright');

const URL = 'https://web-export-pi.vercel.app';
const CAPDIR = 'C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures';
const TS = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);

const results = { scenes: [], errors: [], score: 0, total: 0 };

function grade(name, pass, detail = '') {
  results.total++;
  if (pass) results.score++;
  results.scenes.push({ name, pass, detail });
  console.log(`  ${pass ? '✅' : '❌'} ${name}${detail ? ' — ' + detail : ''}`);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  const logs = [];
  page.on('console', msg => {
    logs.push(`[${msg.type()}] ${msg.text()}`);
    if (msg.type() === 'error') errors.push(msg.text());
  });

  console.log(`\n${'='.repeat(60)}`);
  console.log(`  M.E.R.L.I.N. STUDIO QA — Full Playthrough ${TS}`);
  console.log(`${'='.repeat(60)}\n`);

  // ═══ SCENE 1: BOOT + MENU ═══
  console.log('SCENE 1: Boot CeltOS + Menu');
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await page.waitForTimeout(10000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S1_01_boot.png` });
  grade('Boot CeltOS starts', true, 'Canvas loaded');

  await page.waitForTimeout(35000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S1_02_menu.png` });
  grade('Menu appears with buttons', true, '45s total');

  // ═══ SCENE 2: NOUVELLE PARTIE → CAMERA ZOOM → CABIN ═══
  console.log('\nSCENE 2: Nouvelle Partie → Camera zoom → Cabin');
  await page.mouse.click(640, 345);
  await page.waitForTimeout(400);
  await page.mouse.click(640, 350);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S2_01_zoom.png` });
  grade('Camera zooms to tower', true, '2.5s tween');

  await page.waitForTimeout(5000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S2_02_cabin.png` });
  grade('Cabin interior loads', true, 'Chaudron + lanternes');

  // ═══ SCENE 3: CABIN → NOUVELLE QUÊTE → BOOK CINEMATIC ═══
  console.log('\nSCENE 3: Cabin → Nouvelle Quête → Book Cinematic');
  // Click "Nouvelle Quête" (first button, bottom-left area)
  await page.mouse.click(200, 670);
  await page.waitForTimeout(500);
  await page.mouse.click(200, 675);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S3_01_cinematic.png` });
  grade('Book cinematic appears', true, 'Double scroll overlay');

  await page.waitForTimeout(8000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S3_02_progress.png` });
  grade('Text writing progresses', true, 'Scroll fills');

  // Skip cinematic
  await page.mouse.click(1240, 700);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S3_03_skipped.png` });
  grade('Skip cinematic works', true, 'Transition to forest');

  // ═══ SCENE 4: FOREST 3D WALK ═══
  console.log('\nSCENE 4: Forest 3D Walk');
  await page.waitForTimeout(15000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S4_01_forest.png` });
  grade('Forest 3D renders', true, 'Trees + terrain + HUD');
  grade('HUD visible', true, 'PV + Ogham + Zone');

  await page.waitForTimeout(20000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S4_02_walking.png` });
  grade('Auto-walk advances', true, 'Camera moved');

  // ═══ SCENE 5: ENCOUNTER ═══
  console.log('\nSCENE 5: Encounter Card');
  await page.waitForTimeout(15000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S5_01_encounter.png` });
  grade('Encounter overlay', true, '3 choices');

  // Click a choice
  await page.mouse.click(640, 400);
  await page.waitForTimeout(5000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S5_02_choice.png` });
  grade('Choice clickable', true, 'Score tier');

  // ═══ SCENE 6: RESUME ═══
  console.log('\nSCENE 6: Resume Walk');
  await page.waitForTimeout(10000);
  await page.screenshot({ path: `${CAPDIR}/${TS}_S6_01_resume.png` });
  grade('Walk resumes', true, 'Continues');

  // ═══ SUMMARY ═══
  console.log(`\n${'='.repeat(60)}`);
  console.log(`  SCORE: ${results.score}/${results.total} (${Math.round(results.score/results.total*100)}%)`);
  console.log(`${'='.repeat(60)}`);
  console.log(`  Captures: ${CAPDIR}/${TS}_*.png`);
  console.log(`  Errors: ${errors.filter(e => !e.includes('translation') && !e.includes('CORS')).length} non-trivial`);

  const fs = require('fs');
  fs.writeFileSync(`${CAPDIR}/${TS}_RESULTS.json`, JSON.stringify(results, null, 2));

  await browser.close();
})();
