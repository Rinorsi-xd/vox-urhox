// Public workshop/T/Esc/course/W route. F8 observes; no gameplay state writes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const copy = value => value === undefined ? null : structuredClone(value);
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

async function main() {
  assert(process.env.VOX_QA_PORT, 'Supply the immutable QA package port explicitly');
  assert(process.env.VOX_EXPECT_MANIFEST, 'Supply the immutable QA manifest explicitly');
  const base = 'http://127.0.0.1:' + Number(process.env.VOX_QA_PORT);
  async function identity() {
    const response = await fetch(base + '/identity.json', {signal: AbortSignal.timeout(15000)});
    assert(response.ok, 'QA identity HTTP ' + response.status);
    return response.json();
  }
  const initialIdentity = await identity();
  assert(initialIdentity.qa, 'QA observer package is required');
  assert.equal(initialIdentity.servedManifest, process.env.VOX_EXPECT_MANIFEST, 'Pinned immutable package');
  const workshopFile = path.join(root, 'assets/UI/Workshop.json');
  const trackFile = path.join(root, 'assets/Track/Manifest.json');
  const workshop = JSON.parse(fs.readFileSync(workshopFile));
  const vehicle = workshop.prefabs.find(item => item.id === 'scorpion');
  assert(vehicle && vehicle.kind.includes('节足'), 'Actual source arthropod workshop vehicle');
  const teleports = JSON.parse(fs.readFileSync(trackFile)).layout.teleports;
  const courses = [
    {button: '练习：山坡', target: '节足山坡'},
    {button: '练习：抓墙 / 跳跃', target: '节足抓墙'},
  ].map(course => {
    const spot = teleports.find(spot => spot.name === course.target);
    assert(spot, 'Actual source course target ' + course.target);
    return {...course, spot};
  });
  const out = path.join(root, 'docs/migration/evidence/practice-course-web-' +
    initialIdentity.servedManifest.replace('.json', '') + '-' + new Date().toISOString().replace(/[:.]/g, '-'));
  fs.mkdirSync(out, {recursive: true});
  const report = {
    result: 'FAIL', functionalResult: 'FAIL', visualResult: 'PENDING_REVIEW',
    identity: initialIdentity, startedAt: new Date().toISOString(),
    testSha256: sha(__filename),
    source: {workshopSha256: sha(workshopFile), trackSha256: sha(trackFile), vehicle, stats: workshop.stats[vehicle.id]},
    route: 'Public workshop scorpion -> T -> trial -> Esc/course/W twice -> T -> hangar',
    boundary: 'One desktop Chrome instance. Only public mouse/keyboard commands; F8 is the read-only observer. No extra playfield click after either course. Exact rendered hint needs review of the two screenshots because the existing observer exposes no toast text; CPU evidence separately checks exact source text and 6000ms. No wall-jump, long-run, mobile or performance acceptance.',
    checks: [], inputs: [], states: [], screenshots: [], courses: [], errors: [], probeErrors: [], networkErrors: [], skippedBootstrapPackages: [],
  };
  let browser, page, state, revision = 0, phase = 'boot', holdingW = false;
  const check = (name, pass, detail) => {
    report.checks.push({name, pass: !!pass, detail});
    assert(pass, name + (detail ? ': ' + JSON.stringify(detail) : ''));
  };
  async function key(name) {
    report.inputs.push({at: Date.now(), phase, key: name});
    await page.keyboard.press(name, {delay: 100});
  }
  async function wait(predicate, label, timeout = 300000) {
    const start = Date.now(); let nextDump = 0;
    while (!state || !predicate(state)) {
      if (report.errors.length) throw Error(report.errors.join('\n'));
      if (state?.loadingFlow?.failed) throw Error('Loading failed: ' + state.loadingFlow.error);
      if (Date.now() - start > timeout) throw Error('Timeout: ' + label);
      if (Date.now() >= nextDump) { nextDump = Date.now() + 700; await key('F8'); }
      await sleep(50);
    }
    return state;
  }
  async function dump(label) {
    const before = revision;
    await key('F8');
    await wait(() => revision > before, 'fresh observer ' + label, 15000);
    report.states.push({at: Date.now(), phase, label, state: copy(state)});
    return state;
  }
  async function click(text) {
    await dump('before click ' + text);
    const widget = state.widgets.find(widget => widget.text === text && !widget.disabled);
    assert(widget, 'Visible command ' + text);
    const canvas = await page.locator('canvas').boundingBox();
    assert(canvas, 'Rendered game canvas');
    const [x, y, width, height] = widget.rect;
    const point = {x: canvas.x + (x + width / 2) / state.width * canvas.width,
      y: canvas.y + (y + height / 2) / state.height * canvas.height};
    assert(point.x >= canvas.x && point.x <= canvas.x + canvas.width &&
      point.y >= canvas.y && point.y <= canvas.y + canvas.height, 'Visible command is inside canvas');
    report.inputs.push({at: Date.now(), phase, click: text, point, rect: widget.rect});
    await page.mouse.click(point.x, point.y);
  }
  async function shot(name) {
    const file = name + '.png';
    await page.screenshot({path: path.join(out, file), timeout: 15000});
    report.screenshots.push({name, file, at: Date.now()});
    return file;
  }
  try {
    const {chromium} = require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
    browser = await chromium.launch({headless: true, channel: 'chrome', args: ['--use-angle=d3d11']});
    page = await browser.newPage({viewport: {width: 1920, height: 1080}, deviceScaleFactor: 1});
    page.on('console', message => {
      const line = message.text(); fs.appendFileSync(path.join(out, 'console.log'), line + '\n');
      const marker = line.indexOf('OUTGAME_STATE ');
      if (marker >= 0) {
        try { state = JSON.parse(line.slice(marker + 14)); revision++; }
        catch (error) { report.probeErrors.push({at: Date.now(), phase, error: error.message, line}); }
      }
      const skipped = line.match(/No package for (engine-res|urhox-libs), skipping/);
      if (skipped) report.skippedBootstrapPackages.push(skipped[1]);
      if (line.includes('[Bootstrap/DownloadInitialPackage] Completed successfully')) report.bootstrapCompleted = true;
      if (/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line)) report.errors.push(line);
    });
    page.on('pageerror', error => report.errors.push(String(error)));
    page.on('crash', () => report.errors.push('Browser page crashed'));
    page.on('requestfailed', request => report.networkErrors.push({url: request.url(), error: request.failure()?.errorText}));
    page.on('response', response => { if (response.status() >= 400) report.networkErrors.push({url: response.url(), status: response.status()}); });
    await page.goto(base + '/outgame.html?-game_url=' + base + '/game-dist/&-log=info&cached=1');
    await wait(s => s.tab === 'hangar' && !s.loadingFlow?.active, 'actionable hangar');
    phase = 'workshop';
    await click('创意工坊'); await wait(s => s.tab === 'workshop', 'public workshop');
    await click(vehicle.name); await wait(s => s.workshop?.selected === vehicle.id, 'actual scorpion selection');
    if (state.workshop.view !== 'detail') await key('Enter');
    await wait(s => s.workshop?.view === 'detail' && s.preview?.complete, 'actual scorpion preview');
    await shot('workshop-scorpion'); await key('Enter');
    await wait(s => s.tab === 'hangar' && s.blueprint === vehicle.name &&
      !s.loadingFlow?.active && !s.vehicleLoading?.busy, 'public scorpion installation');
    await dump('installed scorpion');
    check('Source arthropod installed through public workshop', state.blueprint === vehicle.name);
    phase = 'training-entry'; await key('t');
    await wait(s => s.mode === 'trial' && !s.loadingFlow?.active, 'public T training entry');
    await dump('training ready');
    check('T enters the original trial map', state.map === 'trial', {map: state.map});
    check('Actual practice player is live and registered once', state.practice?.alive && state.practice.life > 0 && state.practice.parts > 0 && state.practice.playerCount === 1, state.practice);
    check('Both real leg-course buttons exist', courses.every(course => state.widgets.some(widget => widget.text === course.button && !widget.disabled)));
    if (!state.pointer?.captured) {
      const canvas = await page.locator('canvas').boundingBox();
      assert(canvas, 'Initial rendered playfield');
      const point = {x: canvas.x + canvas.width * .5, y: canvas.y + canvas.height * .45};
      report.inputs.push({at: Date.now(), phase, click: 'initial playfield capture', point});
      await page.mouse.click(point.x, point.y);
    }
    await wait(s => s.pointer?.captured && s.pointer?.ready, 'initial public playfield capture', 15000);
    check('Initial public click establishes actual browser lock', await page.evaluate(() => !!document.pointerLockElement));
    for (const [index, course] of courses.entries()) {
      phase = 'course-' + (index + 1);
      // Esc is tested from the captured state; otherwise it opens settings.
      await key('Escape');
      await wait(s => s.mode === 'trial' && !s.pointer?.captured && !s.pointer?.pending, 'Esc release', 15000);
      await dump('unlocked before ' + course.target);
      check(course.target + ' starts with browser pointer unlocked', !(await page.evaluate(() => !!document.pointerLockElement)));
      check(course.target + ' Esc leaves no settings modal', !state.pauseMenu, state.pauseMenu);
      // Chromium requires a cooldown after Escape before another lock request.
      await sleep(1300);
      await click(course.button);
      const clickedAt = Date.now();
      await dump('immediately after ' + course.target);
      check(course.target + ' remains on trial map', state.mode === 'trial' && state.map === 'trial');
      const actual = copy(state.vehicle?.position);
      check(course.target + ' reaches its source XZ target', Array.isArray(actual) &&
        Math.hypot(actual[0] - course.spot.pos[0], actual[2] - course.spot.pos[2]) < 3, {actual, spot: course.spot});
      const screenshot = await shot('course-' + (index + 1) + '-hint');
      const courseResult = {target: course.target, sourceSpot: course.spot, actual, clickedAt,
        hint: {result: 'PENDING_VISUAL_REVIEW', expectedText: course.target + '：W 前进 / 贴墙自动抓附，空格蹬开，长按收腿', expectedDurationMs: 6000, screenshot, capturedAfterClickMs: Date.now() - clickedAt}};
      report.courses.push(courseResult);
      await wait(s => s.pointer?.captured && s.pointer?.ready, 'course automatic capture without another click', 15000);
      check(course.target + ' actually locks the browser pointer', await page.evaluate(() => !!document.pointerLockElement));
      await dump('captured before W ' + course.target);
      const before = copy(state.vehicle.position);
      report.inputs.push({at: Date.now(), phase, heldKey: 'w', durationMs: 2000});
      await page.keyboard.down('w'); holdingW = true; await sleep(2000);
      await dump('W held ' + course.target);
      await page.keyboard.up('w'); holdingW = false;
      const after = copy(state.vehicle.position);
      const distance = Math.hypot(after[0] - before[0], after[2] - before[2]);
      courseResult.movement = {before, after, distance, speed: state.vehicle.speed};
      check(course.target + ' W moves the actual vehicle without a second click', distance > 1, courseResult.movement);
      check(course.target + ' preserves live singleton player', state.practice?.alive && state.practice.playerCount === 1, state.practice);
      await shot('course-' + (index + 1) + '-moved');
    }
    phase = 'return'; await key('t');
    await wait(s => s.tab === 'hangar' && !s.loadingFlow?.active && !s.vehicleLoading?.busy, 'public T returns to hangar');
    await dump('returned hangar'); await shot('returned-hangar');
    check('Return releases browser pointer lock', !(await page.evaluate(() => !!document.pointerLockElement)));
    const retired = state.performance?.lifecycle?.trial;
    check('Observer reports retired trial released or collected', retired === false ||
      retired?.disposed && !retired.scene && !retired.world && !retired.effects && !retired.view && !retired.hud, retired);
    const optional = [], unresolved = [];
    for (const error of report.networkErrors) {
      const match = new URL(error.url).pathname.match(/^\/cached-engine-source\/src\/(engine-res|urhox-libs)\/(?:[^/]+\/)?assets@windows\.7z$/);
      (report.bootstrapCompleted && error.status === 404 && match && report.skippedBootstrapPackages.includes(match[1]) ? optional : unresolved).push(error);
    }
    report.network = {optionalBootstrapFallbacks: optional, unresolved};
    check('No unresolved HTTP or resource failures', unresolved.length === 0, unresolved);
    check('No Lua, shader or browser errors', report.errors.length === 0, report.errors);
    report.functionalResult = 'PASS';
  } catch (error) {
    report.errors.push(error.stack || String(error));
    if (page) try { await shot('failure'); } catch {}
  } finally {
    if (holdingW && page) try { await page.keyboard.up('w'); } catch {}
    if (browser) await browser.close();
    try {
      report.finalIdentity = await identity();
      check('Complete route used the same immutable package', report.finalIdentity.qa &&
        report.finalIdentity.servedManifest === initialIdentity.servedManifest, report.finalIdentity);
    } catch (error) { report.errors.push(error.stack || String(error)); report.functionalResult = 'FAIL'; }
    report.finalState = copy(state); report.finishedAt = new Date().toISOString();
    report.result = report.functionalResult === 'PASS' && report.errors.length === 0 ? 'FUNCTIONAL_PASS_VISUAL_PENDING' : 'FAIL';
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({result: report.result, checks: report.checks.length, output: out}, null, 2));
    if (report.result === 'FAIL') process.exitCode = 1;
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
