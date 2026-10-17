const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = 'http://127.0.0.1:' + Number(process.env.VOX_QA_PORT || 4508);
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function protocol(report) {
    const chunks = new Map();
    const result = {state: undefined, fixture: undefined, sequence: 0};
    result.feed = line => {
        const prefixes = ['OUTGAME_STATE ', 'QA_AIM_ENGINE_CHUNK '];
        for (const prefix of prefixes) {
            const at = line.indexOf(prefix); if (at < 0) continue;
            const body = line.slice(at + prefix.length);
            let value;
            try {value = JSON.parse(body);} catch (error) {
                if (prefix === 'OUTGAME_STATE ') {
                    report.truncatedStateMessages++;
                    if (report.truncatedStateSamples.length < 5) report.truncatedStateSamples.push({length: body.length, tail: body.slice(-100)});
                } else report.errors.push('Aim chunk JSON: ' + error.message);
                continue;
            }
            if (prefix === 'OUTGAME_STATE ') {result.state = value; result.sequence++; continue;}
            try {
                assert.equal(typeof value.runId, 'string');
                assert.ok(value.runId.length > 0 && value.runId.length < 100);
                assert.ok(Number.isInteger(value.index) && Number.isInteger(value.total));
                assert.ok(value.index >= 1 && value.index <= value.total && value.total <= 64);
                assert.ok(typeof value.text === 'string' && value.text.length <= 1800);
                let message = chunks.get(value.runId);
                if (!message) {message = {total: value.total, parts: new Map()}; chunks.set(value.runId, message);}
                assert.equal(message.total, value.total, 'Aim chunk count changed');
                if (message.parts.has(value.index)) assert.equal(message.parts.get(value.index), value.text, 'Conflicting duplicate aim chunk');
                message.parts.set(value.index, value.text);
                if (message.parts.size === message.total) {
                    const fixture = JSON.parse(Array.from({length: message.total}, (_, i) => message.parts.get(i + 1)).join(''));
                    assert.equal(fixture.runId, value.runId, 'Aim report/chunk run mismatch');
                    result.fixture = fixture;
                }
            } catch (error) {report.errors.push(error.message);}
        }
    };
    return result;
}
function protocolTest() {
    const make = () => {const report = {errors: [], truncatedStateMessages: 0, truncatedStateSamples: []}; return {report, reader: protocol(report)};};
    const {reader, report} = make();
    reader.feed('engine OUTGAME_STATE {"mode":"hangar"}');
    assert.equal(reader.state.mode, 'hangar');
    reader.feed('engine OUTGAME_STATE {"nested":{}');
    assert.equal(report.truncatedStateMessages, 1); assert.equal(reader.sequence, 1); assert.equal(report.errors.length, 0);
    const fixture = {runId: 'test-aim', result: 'PASS', checks: Array.from({length: 100}, (_, i) => ({name: 'check-' + i, ok: true}))};
    const text = JSON.stringify(fixture), records = [];
    const total = Math.ceil(text.length / 1800);
    for (let i = 0; i < total; i++) records.push({runId: fixture.runId, index: i + 1, total, text: text.slice(i * 1800, (i + 1) * 1800)});
    reader.feed('QA_AIM_ENGINE_CHUNK ' + JSON.stringify(records.at(-1)));
    assert.equal(reader.fixture, undefined, 'Partial report cannot pass');
    for (const record of records.slice(0, -1).reverse()) reader.feed('QA_AIM_ENGINE_CHUNK ' + JSON.stringify(record));
    assert.deepEqual(reader.fixture, fixture); assert.equal(report.errors.length, 0);
    reader.feed('QA_AIM_ENGINE_CHUNK ' + JSON.stringify(records[0]));
    assert.equal(report.errors.length, 0, 'Exact transport retry is safe');
    reader.feed('QA_AIM_ENGINE_CHUNK ' + JSON.stringify({...records[0], text: 'different'}));
    assert.match(report.errors.at(-1), /Conflicting duplicate/);
    const invalid = make(); invalid.reader.feed('QA_AIM_ENGINE_CHUNK {');
    assert.equal(invalid.report.errors.length, 1, 'Broken aim chunk cannot be ignored');
    invalid.reader.feed('QA_AIM_ENGINE_CHUNK ' + JSON.stringify({...records[0], total: 65}));
    assert.equal(invalid.report.errors.length, 2, 'Unbounded chunk count refused');
    console.log('PASS: state truncation, exact long report, missing/reordered/retried/conflicting chunks, malformed records and count limits');
}
async function run() {
    const identity = await fetch(base + '/identity.json').then(r => r.json());
    assert.equal(identity.qa, true, 'QA server required');
    assert.equal(identity.qaAimEngine, true, '--qa-aim-engine server required');
    const out = path.resolve('docs/migration/evidence/aim-engine-' + Date.now());
    fs.mkdirSync(out, {recursive: true});
    const report = {result: 'RUNNING', identity, checks: [], errors: [], httpErrors: [], truncatedStateMessages: 0, truncatedStateSamples: [],
        boundary: 'Desktop Chrome loads frozen game; CDP F16 runs an explicit private unrendered real-engine fixture. This is not natural gameplay, visual acceptance, FPS or mobile testing.'};
    const reader = protocol(report);
    let browser, page;
    try {
        browser = await chromium.launch({headless: false, channel: 'chrome', args: ['--use-angle=d3d11']});
        page = await browser.newPage({viewport: {width: 1600, height: 900}, deviceScaleFactor: 1});
        page.on('console', msg => {
            const line = msg.text(); fs.appendFileSync(path.join(out, 'runtime.log'), line + '\n');
            reader.feed(line);
            if (/Execute Lua|stack traceback|Aborted\(|Shader compilation failed|ERROR:/.test(line)) report.errors.push(line);
        });
        page.on('pageerror', error => report.errors.push(error.message));
        page.on('response', response => {if (response.status() >= 400) report.httpErrors.push({status: response.status(), url: response.url()});});
        await page.goto(base + '/outgame.html?-game_url=' + base + '/game-dist/&-log=info&cached=1');
        await page.bringToFront();
        const hallDeadline = Date.now() + 240000;
        while (!reader.state || reader.state.mode !== 'hangar' || reader.state.loadingFlow?.active) {
            assert.equal(report.errors.length, 0, report.errors.join('\n'));
            assert.ok(Date.now() < hallDeadline, 'Timeout waiting for hall');
            const before = reader.sequence; await page.keyboard.press('F8');
            const deadline = Date.now() + 1500; while (reader.sequence === before && Date.now() < deadline) await delay(60);
            await delay(150);
        }
        await page.screenshot({path: path.join(out, 'before.png')});
        const input = await page.context().newCDPSession(page);
        try {
            const event = {key: 'F16', code: 'F16', windowsVirtualKeyCode: 127, nativeVirtualKeyCode: 127};
            await input.send('Input.dispatchKeyEvent', {type: 'rawKeyDown', ...event});
            await delay(40);
            await input.send('Input.dispatchKeyEvent', {type: 'keyUp', ...event});
        } finally {await input.detach();}
        const deadline = Date.now() + 60000;
        while (!reader.fixture) {
            assert.equal(report.errors.length, 0, report.errors.join('\n'));
            assert.ok(Date.now() < deadline, 'Timeout waiting for real-engine aim fixture'); await delay(100);
        }
        const fixture = reader.fixture; report.fixture = fixture;
        assert.equal(fixture.result, 'PASS', fixture.failure);
        assert.equal(fixture.cleanup, true, fixture.cleanupFailure);
        assert.ok(fixture.checks.every(check => check.ok === true), 'All engine checks passed');
        for (const name of ['actual Resolve selects reachable same enemy surface', 'actual laser Fire damages real enemy',
            'actual direct reticle hit keeps exact surface and skips recovery', 'actual Fire cannot damage through native wall',
            'actual recovery refuses camera-occluded reachable surface', 'actual limited aim cannot fire through camera wall',
            'Clear releases callback retained owners']) assert.ok(fixture.checks.some(check => check.name === name), name);
        assert.equal(report.errors.length, 0, report.errors.join('\n'));
        assert.equal(report.httpErrors.length, 0, JSON.stringify(report.httpErrors));
        const endIdentity = await fetch(base + '/identity.json').then(r => r.json());
        assert.equal(endIdentity.probeSha256, identity.probeSha256, 'QA fixture changed while running');
        assert.equal(endIdentity.servedManifest, identity.servedManifest, 'Frozen game changed while running');
        await page.screenshot({path: path.join(out, 'after.png')});
        report.result = 'PASS';
    } catch (error) {
        report.result = 'FAIL'; report.failure = error.stack; report.fixture = reader.fixture;
        process.exitCode = 1;
        if (page) await page.screenshot({path: path.join(out, 'failure.png')}).catch(() => {});
    } finally {
        if (browser) await browser.close();
        report.browser = 'CLOSED';
        fs.writeFileSync(path.join(out, 'result.json'), JSON.stringify(report, null, 2));
        console.log(JSON.stringify({result: report.result, out, failure: report.failure, checks: report.fixture?.checks}));
    }
}
if (process.argv.includes('--protocol-test')) protocolTest();
else if (require.main === module) run().catch(error => {console.error(error); process.exitCode = 1;});
module.exports = {protocol};
