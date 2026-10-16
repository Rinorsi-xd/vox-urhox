// Real public-input destruction route. F8 observes state; it never applies damage.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const wrap = degrees => ((degrees + 180) % 360 + 360) % 360 - 180;
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

function aimDelta(camera, target, height = 0) {
  // Probe target positions use source coordinates; native camera X is mirrored.
  const dx = -target.pos[0] - camera.position[0];
  const dy = target.pos[1] + 1 + height - camera.position[1];
  const dz = target.pos[2] - camera.position[2];
  const yaw = Math.atan2(dx, dz) * 180 / Math.PI;
  const pitch = -Math.atan2(dy, Math.hypot(dx, dz)) * 180 / Math.PI;
  return {
    yaw: wrap(yaw - camera.yaw), pitch: pitch - camera.pitch,
    mouseX: clamp(wrap(yaw - camera.yaw) / (.0024 * 180 / Math.PI), -160, 160),
    mouseY: clamp((pitch - camera.pitch) / (.002 * 180 / Math.PI), -100, 100),
  };
}

function frameStats(frames) {
  const sorted = frames.map(frame => frame.ms).sort((a, b) => a - b);
  const percentile = q => sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * q))] : null;
  return {
    count: sorted.length, medianMs: percentile(.5), p95Ms: percentile(.95), p99Ms: percentile(.99),
    maxMs: sorted.length ? sorted.at(-1) : null,
    over100ms: frames.filter(frame => frame.ms > 100).length,
  };
}

function classifyNetwork(errors, skippedPackages, bootstrapCompleted) {
  const optional = [], unresolved = [];
  for (const error of errors) {
    const url = new URL(error.url);
    const match = url.pathname.match(/^\/cached-engine-source\/src\/(engine-res|urhox-libs)\/(?:[^/]+\/)?assets@windows\.7z$/);
    (bootstrapCompleted && error.status === 404 && match && skippedPackages.includes(match[1]) ? optional : unresolved).push(error);
  }
  return {optionalBootstrapPackageFallbacks: optional, unresolved};
}

async function main() {
  assert(process.env.VOX_QA_PORT, 'Supply the immutable QA package port explicitly');
  const base = 'http://127.0.0.1:' + Number(process.env.VOX_QA_PORT);
  const response = await fetch(base + '/identity.json');
  assert(response.ok, 'QA identity HTTP ' + response.status);
  const identity = await response.json();
  assert(identity.qa, 'This test requires a QA observer package');
  if (process.env.VOX_QA_MANIFEST) assert.equal(identity.servedManifest, process.env.VOX_QA_MANIFEST, 'Immutable QA manifest');
  const out = path.join(root, 'docs/migration/evidence/destruction-web-' + new Date().toISOString().replace(/[:.]/g, '-'));
  fs.mkdirSync(out, {recursive: true});
  const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json')));
  const report = {
    identity, baseline: {branch: baseline.branch, commit: baseline.commit, snapshot: baseline.snapshot},
    testSha256: crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),
    startedAt: new Date().toISOString(), route: 'Public workshop raceCar -> trial -> N nine times -> mouse aim/fire',
    boundary: 'One desktop Chrome instance; public keyboard/mouse only. QA reads actual state and times actual Flush. No injected damage, placement, HP or deaths. No mobile or audible-quality acceptance.',
    errors: [], probeErrors: [], networkErrors: [], skippedBootstrapPackages: [], inputs: [], states: [], damageEvents: [], checks: [], screenshots: [],
  };
  const manifest = JSON.parse(fs.readFileSync(identity.manifest_path));
  const flashResource = manifest.files.find(file => file.fs_path === 'Shaders/BLGL/RestoreFlash.shader');
  assert(flashResource, 'Actual shell shader is packaged');
  report.flashShader = {resource: flashResource, loads: []};
  const flashShaderKey = flashResource.uuid.replaceAll('-', '_') + '_' + flashResource.hash + '_';
  const {chromium} = require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  const browser = await chromium.launch({headless: true, channel: 'chrome', args: ['--use-angle=d3d11']});
  const page = await browser.newPage({viewport: {width: 1920, height: 1080}, deviceScaleFactor: 1});
  let state, revision = 0, phase = 'boot', firing = false, closing = false;
  let pointer = {x: 960, y: 540};
  const snapshot = value => value === undefined ? null : JSON.parse(JSON.stringify(value));
  const check = (name, condition, detail) => {
    report.checks.push({name, pass: !!condition, detail});
    assert(condition, name + (detail ? ': ' + JSON.stringify(detail) : ''));
  };
  page.on('console', message => {
    const line = message.text();
    fs.appendFileSync(path.join(out, 'console.log'), line + '\n');
    if (line.includes('Shader::BeginLoad:') && line.includes(flashShaderKey)) {
      report.flashShader.loads.push({at: Date.now(), phase, line});
    }
    const skipped = line.match(/No package for (engine-res|urhox-libs), skipping/);
    if (skipped) report.skippedBootstrapPackages.push(skipped[1]);
    if (line.includes('[Bootstrap/DownloadInitialPackage] Completed successfully')) report.bootstrapPackagesCompleted = true;
    const marker = line.indexOf('OUTGAME_STATE ');
    if (marker >= 0) {
      try { state = JSON.parse(line.slice(marker + 14)); revision++; }
      catch (error) {
        // Shader compilation logs can interrupt a console state line during
        // boot. Preserve it, then request a complete read-only snapshot again.
        report.probeErrors.push({at: Date.now(), phase, error: error.message, line});
      }
    }
    const damage = line.indexOf('DAMAGE_REBUILD ');
    if (damage >= 0) {
      try { report.damageEvents.push({arrivedAt: Date.now(), phase, ...JSON.parse(line.slice(damage + 15))}); }
      catch (error) { report.errors.push('Malformed destruction event: ' + error.message); }
    }
    if (/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line)) report.errors.push(line);
  });
  page.on('pageerror', error => report.errors.push(String(error)));
  page.on('crash', () => report.errors.push('Browser page crashed'));
  page.on('requestfailed', request => report.networkErrors.push({url: request.url(),error: request.failure()?.errorText}));
  page.on('response', response => { if (response.status() >= 400) report.networkErrors.push({url: response.url(), status: response.status()}); });
  browser.on('disconnected', () => { if (!closing) report.errors.push('Browser disconnected unexpectedly'); });
  await page.addInitScript(() => {
    window.__destructionFrames = {timeOrigin: performance.timeOrigin, phase: 'boot', frames: []};
    let previous = performance.now(), previousPhase = 'boot';
    function tick(now) {
      const data = window.__destructionFrames;
      data.frames.push({at: now, wallAt: data.timeOrigin + now, ms: now - previous, phase: data.phase, previousPhase});
      previous = now; previousPhase = data.phase; requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  });
  async function mark(name) {
    phase = name;
    await page.evaluate(name => { window.__destructionFrames.phase = name; }, name);
    console.log(name);
  }
  async function key(name) {
    report.inputs.push({at: Date.now(), phase, key: name});
    await page.keyboard.press(name, {delay: 150});
  }
  async function wait(predicate, label, timeout = 300000) {
    const started = Date.now(); let nextDump = 0;
    while (!state || !predicate(state)) {
      if (report.errors.length) throw Error(report.errors.join('\n'));
      if (state?.loadingFlow?.failed) throw Error('Loading failed: ' + state.loadingFlow.error);
      if (Date.now() - started > timeout) throw Error('Timeout: ' + label);
      if (Date.now() >= nextDump) { nextDump = Date.now() + 1000; await key('F8'); }
      await sleep(100);
    }
    return state;
  }
  async function dump(label) {
    const before = revision;
    await key('F8');
    await wait(() => revision > before, 'fresh observer ' + label, 15000);
    report.states.push({at: Date.now(), phase, label, state: snapshot(state)});
    return state;
  }
  async function click(text) {
    await dump('click ' + text);
    const widget = state.widgets.find(widget => widget.text === text && !widget.disabled);
    assert(widget, 'Visible command ' + text);
    const canvas = await page.locator('canvas').boundingBox();
    assert(canvas, 'Rendered game canvas');
    const [x, y, width, height] = widget.rect;
    pointer = {x: canvas.x + (x + width / 2) / state.width * canvas.width, y: canvas.y + (y + height / 2) / state.height * canvas.height};
    report.inputs.push({at: Date.now(), phase, click: text, ...pointer});
    await page.mouse.click(pointer.x, pointer.y);
    await sleep(250);
  }
  async function shot(name) {
    const previous = phase;
    await mark('proof-' + name);
    const file = name + '.png';
    await page.screenshot({path: path.join(out, file)});
    report.screenshots.push({at: Date.now(), name, file});
    await sleep(500);
    await mark(previous);
  }
  const targetName = '赤焰 GT';
  const target = () => state.aimTargets?.find(target => target.name === targetName);
  async function aim(height = 0, attempts = 14) {
    for (let attempt = 0; attempt < attempts; attempt++) {
      await dump('aim ' + attempt);
      const current = target();
      if (!current) return false;
      const delta = aimDelta(state.camera, current, height);
      if (Math.abs(delta.yaw) < .55 && Math.abs(delta.pitch) < .55) return true;
      // Playwright sends real native pointer movement, including while locked.
      pointer.x += delta.mouseX; pointer.y += delta.mouseY;
      report.inputs.push({at: Date.now(), phase, move: snapshot(pointer), delta, height});
      await page.mouse.move(pointer.x, pointer.y, {steps: 2});
      await sleep(180);
    }
    return false;
  }
  try {
    await page.goto(base + '/outgame.html?-game_url=' + base + '/game-dist/&-log=info&cached=1');
    await wait(state => state.tab === 'hangar' && !state.loadingFlow?.active, 'actionable hangar');
    await mark('select-armed-car');
    await click('创意工坊');
    await wait(state => state.tab === 'workshop', 'workshop');
    await click('赤焰 GT');
    await wait(state => state.workshop?.selected === 'raceCar', 'raceCar selected');
    if (state.workshop.view !== 'detail') await key('Enter');
    await wait(state => state.workshop?.view === 'detail' && state.preview?.complete, 'raceCar detail ready');
    await key('Enter');
    await wait(state => state.tab === 'hangar' && state.blueprint === targetName && !state.loadingFlow?.active && !state.vehicleLoading?.busy, 'raceCar installed through public workshop');
    await click('出战'); await wait(state => state.tab === 'battle', 'mode page');
    await click('试车场'); await mark('trial-load'); await click('开始试车');
    await wait(state => state.mode === 'trial' && state.map === 'trial' && !state.loadingFlow?.active, 'trial world');
    await dump('trial ready');
    check('Actual shell shader first loads under loading page',
      report.flashShader.loads.some(load => load.phase === 'trial-load'), report.flashShader.loads);
    check('Read-only destruction observer available', !!state.destruction && Array.isArray(state.aimTargets));
    check('Real practice player and weapon groups', state.practice?.alive && state.reticle?.groups >= 2);
    await mark('target-area');
    // N is the shipped trial-area cycle, not a hidden QA teleport.
    for (let index = 0; index < 9; index++) { await key('n'); await sleep(180); }
    await dump('public N target area');
    const spot = JSON.parse(fs.readFileSync(path.join(root, 'assets/Track/Manifest.json'))).layout.teleports.find(spot => spot.name === '靶车');
    const actual = state.vehicle.position;
    check('Nine public N presses reach target area', Math.hypot(actual[0] - spot.pos[0], actual[2] - spot.pos[2]) < 3, {actual, sourceSpot: spot});
    check('Fixed parked target exists', !!target(), state.aimTargets);
    const initialParts = target().parts;
    report.initialTarget = snapshot(target());
    check('Actual feedback and weapon audio counters available', !!state.feedbackAudio?.counts && !!state.weaponAudio?.counts);
    report.initialAudio = {feedback: snapshot(state.feedbackAudio), weapon: snapshot(state.weaponAudio)};
    report.initialHitFlash = snapshot(state.partHitFlash);
    report.initialWeapons = snapshot(state.weapons);
    pointer = {x: 960, y: 540}; await page.mouse.click(pointer.x, pointer.y);
    await wait(state => state.pointer?.captured && state.pointer?.ready, 'actual pointer capture');
    check('Browser pointer lock acquired', await page.evaluate(() => !!document.pointerLockElement));
    await key('1'); await dump('primary weapon selected');
    check('Public weapon selection is ranged', ['mg', 'sniper', 'cannon', 'gatling', 'shotgun'].includes(state.drill?.kind), state.drill);
    await mark('aim');
    check('Native mouse converges on target', await aim());
    await shot('target-before');
    let minParts = initialParts, broken = false, kill = false, breakShot = false, hitShot = false;
    const started = Date.now();
    await mark('fire');
    report.fireStartedAt = Date.now();
    await page.mouse.down(); firing = true;
    while (Date.now() - started < 120000) {
      await sleep(650); await dump('real held fire');
      const current = target();
      if (current) minParts = Math.min(minParts, current.parts);
      const events = report.damageEvents.filter(event => event.name === targetName && event.arrivedAt >= report.fireStartedAt);
      // The installed player and this parked target share the same name. Flush
      // logs alone cannot identify which actor broke; cross-check live targets.
      broken = minParts < initialParts;
      kill = !current && state.weapons.kills > report.initialWeapons.kills && events.some(event => event.killed === true);
      if (!hitShot && state.partHitFlash?.active > 0 && state.partHitFlash.total > (report.initialHitFlash?.total || 0)) {
        await shot('target-hit-flash'); hitShot = true;
      }
      if (broken && !breakShot) { await page.mouse.up(); firing = false; await shot('target-broken'); breakShot = true; }
      if (kill) break;
      if (!current) throw Error('Target vanished without observed real Flush kill');
      if (!firing) { await page.mouse.down(); firing = true; }
      const elapsed = Date.now() - started;
      // Sweep actual aim through armor/core heights, then try the normal second group.
      const heights = [0, -.5, -1, .5];
      const height = heights[Math.floor(elapsed / 6000) % heights.length];
      await aim(height, 3);
      if (elapsed > 45000 && state.reticle.selected === 1) {
        await page.mouse.up(); firing = false; await key('2'); await dump('secondary ranged group');
      }
      if (state.weapons.energy < 5) { await page.mouse.up(); firing = false; await sleep(1800); }
    }
    await page.mouse.up(); firing = false;
    report.fireFinishedAt = Date.now();
    await mark('after-kill'); await sleep(750); await dump('destruction and delayed audio settled');
    report.targetResult = {initialParts, minParts, broken, kill};
    report.targetEventBoundary = 'Name-only Flush logs include the identically named player; target part loss is verified from aimTargets, and kill from target disappearance plus world kills and Flush event.';
    report.finalAudio = {feedback: snapshot(state.feedbackAudio), weapon: snapshot(state.weaponAudio)};
    report.finalHitFlash = snapshot(state.partHitFlash);
    check('Shell shader is not first loaded by live firing',
      report.flashShader.loads.every(load => load.at < report.fireStartedAt), report.flashShader.loads);
    check('Actual firing creates projectiles', state.weapons.shots > report.initialWeapons.shots, state.weapons);
    check('Actual target parts are destroyed', broken, report.targetResult);
    check('Actual enemy part-hit flash consumed', state.partHitFlash?.supported &&
      state.partHitFlash.total > (report.initialHitFlash?.total || 0), state.partHitFlash);
    check('Actual active part-hit flash captured', hitShot);
    check('Actual target Flush kill observed', kill, report.damageEvents);
    check('Actual target rebuild timing observed', report.damageEvents.some(event => event.name === targetName));
    check('Kill creates original score reward', state.combatFeedback?.scoreTarget >= 300, state.combatFeedback);
    check('Kill confirmation sound actually played',
      (state.feedbackAudio?.counts.kill_confirm || 0) > (report.initialAudio.feedback.counts.kill_confirm || 0), state.feedbackAudio);
    await wait(s => s.combatFeedback?.score >= 300 && (s.feedbackAudio?.counts.score_tick || 0) >
      (report.initialAudio.feedback.counts.score_tick || 0), 'score cubes arrive and play score ticks', 15000);
    check('Real score collection completes', state.combatFeedback.score >= 300, state.combatFeedback);
    await shot('target-killed');
    check('No runtime errors', report.errors.length === 0, report.errors);
    report.networkClassification = classifyNetwork(report.networkErrors, report.skippedBootstrapPackages, report.bootstrapPackagesCompleted);
    check('No unresolved failed resource requests', report.networkClassification.unresolved.length === 0, report.networkClassification);
    report.functionalResult = 'PASS';
  } catch (error) {
    report.functionalResult = 'FAIL'; report.failure = error.stack;
    if (firing) await page.mouse.up().catch(() => {});
    await shot('failure').catch(() => {});
  } finally {
    const measured = await page.evaluate(() => window.__destructionFrames).catch(() => ({frames: []}));
    fs.writeFileSync(path.join(out, 'frames.json'), JSON.stringify(measured));
    fs.writeFileSync(path.join(out, 'damage-events.json'), JSON.stringify(report.damageEvents, null, 2));
    report.frameSummary = {};
    for (const label of new Set(measured.frames.map(frame => frame.phase))) {
      report.frameSummary[label] = frameStats(measured.frames.filter(frame => frame.phase === label && frame.previousPhase === label));
    }
    report.damageWindows = report.damageEvents.map(event => ({event, timingBoundary: 'Console arrival time is approximate; engine timestamp retained separately.',
      frames: measured.frames.filter(frame => frame.wallAt >= event.arrivedAt - 500 && frame.wallAt <= event.arrivedAt + 500)}));
    const live = measured.frames.filter(frame => frame.phase === 'fire' && frame.previousPhase === 'fire');
    report.liveFrames = frameStats(live);
    // Keep screenshot/probe overhead in a second inclusive result, never silently
    // discard a stall whose completed rAF crosses a phase boundary.
    const inclusive = measured.frames.filter(frame => report.fireStartedAt && frame.wallAt >= report.fireStartedAt &&
      frame.wallAt - frame.ms <= (report.fireFinishedAt || Date.now()));
    report.inclusiveFireFrames = frameStats(inclusive);
    const slowFlushes = report.damageEvents.filter(event => event.ms > 100);
    report.performanceResult = live.length > 0 && report.inclusiveFireFrames.over100ms === 0 && slowFlushes.length === 0 ? 'PASS' : 'FAIL';
    report.slowFlushes = slowFlushes;
    report.performanceThresholdMs = 100;
    report.result = report.functionalResult === 'PASS' && report.performanceResult === 'PASS' ? 'PASS' : 'FAIL';
    report.final = state; report.finishedAt = new Date().toISOString();
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
    closing = true; await browser.close(); console.log(out);
  }
  if (report.result !== 'PASS') process.exitCode = 1;
}

module.exports = {aimDelta, frameStats, wrap, classifyNetwork};
if (require.main === module) main().catch(error => { console.error(error); process.exitCode = 1; });
