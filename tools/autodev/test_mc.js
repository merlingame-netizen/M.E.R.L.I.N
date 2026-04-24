// Mission Control Smoke Test — Playwright
const { chromium } = require('playwright');
const fs = require('fs');

const SCREENSHOTS_DIR = '/home/user/M.E.R.L.I.N/tools/autodev/captures';
fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  console.log('[TEST] Opening Mission Control...');
  await page.goto('http://localhost:4200', { waitUntil: 'networkidle', timeout: 15000 });
  await page.waitForTimeout(2000);

  // Screenshot: Game tab (default)
  await page.screenshot({ path: `${SCREENSHOTS_DIR}/mc_game_tab.png`, fullPage: false });
  console.log('[TEST] Game tab screenshot captured');

  // Check header
  const logo = await page.textContent('.app__logo');
  console.log(`[TEST] Logo text: "${logo}"`);
  const status = await page.textContent('.app__status');
  console.log(`[TEST] Status: "${status}"`);

  // Check Game tab content
  const launchBtn = await page.$('.game-launch__btn');
  if (launchBtn) {
    const btnText = await launchBtn.textContent();
    console.log(`[TEST] Launch button: "${btnText}" ✓`);
  } else {
    console.log('[TEST] ✗ Launch button NOT FOUND');
  }

  // Check KPI strip
  const kpis = await page.$$('.kpi');
  console.log(`[TEST] KPI cards: ${kpis.length}`);

  // Navigate to Agents tab
  const tabs = await page.$$('.nav-tab');
  console.log(`[TEST] Nav tabs: ${tabs.length}`);
  if (tabs.length >= 2) {
    await tabs[1].click();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/mc_agents_tab.png`, fullPage: false });
    console.log('[TEST] Agents tab screenshot captured');

    // Check if agents loaded
    const agentCategories = await page.$$('button');
    const catButtons = [];
    for (const btn of agentCategories) {
      const text = await btn.textContent();
      if (text.includes('▶') || text.includes('▼')) catButtons.push(text.trim());
    }
    console.log(`[TEST] Agent categories: ${catButtons.length}`);
    if (catButtons.length > 0) console.log(`[TEST]   First: ${catButtons[0]}`);
  }

  // Navigate to Tasks tab
  if (tabs.length >= 3) {
    await tabs[2].click();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/mc_tasks_tab.png`, fullPage: false });
    console.log('[TEST] Tasks tab screenshot captured');

    const featureRows = await page.$$('.feature-row');
    console.log(`[TEST] Feature queue rows: ${featureRows.length}`);
  }

  // Navigate to Alerts tab
  if (tabs.length >= 4) {
    await tabs[3].click();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/mc_alerts_tab.png`, fullPage: false });
    console.log('[TEST] Alerts tab screenshot captured');
  }

  // Navigate to Director tab
  if (tabs.length >= 5) {
    await tabs[4].click();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/mc_director_tab.png`, fullPage: false });
    console.log('[TEST] Director tab screenshot captured');

    const feedbackCards = await page.$$('.feedback-card');
    console.log(`[TEST] Feedback cards: ${feedbackCards.length}`);
  }

  // Back to Game tab — test copy button
  if (tabs.length >= 1) {
    await tabs[0].click();
    await page.waitForTimeout(500);
    if (launchBtn) {
      await launchBtn.click();
      await page.waitForTimeout(500);
      const btnTextAfter = await page.$eval('.game-launch__btn', el => el.textContent);
      console.log(`[TEST] After click: "${btnTextAfter}"`);
    }
  }

  console.log('\n[RESULT] Mission Control smoke test complete');
  await browser.close();
})().catch(e => {
  console.error('[ERROR]', e.message);
  process.exit(1);
});
