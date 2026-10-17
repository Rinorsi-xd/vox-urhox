const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const DEFAULT = 'docs/migration/evidence/salvage-natural-manifest-6f9297a9-2026-10-16T21-44-02-714Z';
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function flatten(value, prefix = '', out = {}) {
  if (typeof value === 'number' && Number.isFinite(value)) out[prefix] = value;
  else if (value && typeof value === 'object' && !Array.isArray(value))
    for (const [key, item] of Object.entries(value)) flatten(item, prefix ? prefix + '.' + key : key, out);
  return out;
}
function summary(rows, name) {
  const found = rows.filter(row => typeof row.metrics[name] === 'number');
  if (!found.length) return {samples: 0};
  const first = found[0], last = found.at(-1);
  let min = first, max = first, decreases = 0, changes = 0;
  for (let i = 0; i < found.length; i++) {
    const row = found[i];
    if (row.metrics[name] < min.metrics[name]) min = row;
    if (row.metrics[name] > max.metrics[name]) max = row;
    if (i && row.metrics[name] < found[i - 1].metrics[name]) decreases++;
    if (i && row.metrics[name] !== found[i - 1].metrics[name]) changes++;
  }
  const point = row => ({line: row.line, time: row.time, value: row.metrics[name]});
  return {samples: found.length, first: point(first), last: point(last), min: point(min), max: point(max),
    delta: last.metrics[name] - first.metrics[name], decreases, changes};
}
function inspectWasm(file, stack) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.subarray(0, 8).toString('hex'), '0061736d01000000');
  function reader(start, end) {
    let pos = start;
    return {get pos() { return pos; }, byte() { assert.ok(pos < end); return bytes[pos++]; },
      u32() { let value = 0; for (let i = 0; i < 5; i++) { const b = this.byte(); value += (b & 127) * 2 ** (7 * i); if (!(b & 128)) return value; } throw Error('Invalid LEB'); },
      name() { const n = this.u32(); assert.ok(pos + n <= end); const value = bytes.subarray(pos, pos + n).toString('utf8'); pos += n; return value; },
      skip(n) { assert.ok(n >= 0 && pos + n <= end); pos += n; }};
  }
  const sections = []; let pos = 8;
  while (pos < bytes.length) { const r = reader(pos, bytes.length), id = r.byte(), n = r.u32(), start = r.pos; assert.ok(start + n <= bytes.length); sections.push({id, start, end: start + n}); pos = start + n; }
  const unique = id => { const list = sections.filter(s => s.id === id); assert.equal(list.length, 1); return reader(list[0].start, list[0].end); };
  const custom = [], names = new Map();
  for (const section of sections.filter(s => s.id === 0)) {
    const r = reader(section.start, section.end), name = r.name(); custom.push({name, bytes: section.end - section.start});
    if (name === 'name') while (r.pos < section.end) {
      const subsection = r.byte(), n = r.u32(), end = r.pos + n; assert.ok(end <= section.end);
      if (subsection === 1) { const nr = reader(r.pos, end); for (let count = nr.u32(); count > 0; count--) names.set(nr.u32(), nr.name()); }
      r.skip(n);
    }
  }
  const types = [], tr = unique(1);
  for (let count = tr.u32(); count > 0; count--) { assert.equal(tr.byte(), 0x60); const params = [], results = []; for (let n = tr.u32(); n > 0; n--) params.push(tr.byte()); for (let n = tr.u32(); n > 0; n--) results.push(tr.byte()); types.push({params, results}); }
  const ir = unique(2), imports = [];
  const limits = r => { const flags = r.u32(); assert.ok(!(flags & 4)); r.u32(); if (flags & 1) r.u32(); };
  for (let n = ir.u32(); n > 0; n--) { const module = ir.name(), name = ir.name(), kind = ir.byte();
    if (kind === 0) imports.push({module, name, type: ir.u32()});
    else if (kind === 1) { ir.byte(); limits(ir); } else if (kind === 2) limits(ir);
    else if (kind === 3) { ir.byte(); ir.byte(); } else if (kind === 4) { ir.byte(); ir.u32(); } else throw Error('Unknown import');
  }
  const functionTypes = [], fr = unique(3); for (let n = fr.u32(); n > 0; n--) functionTypes.push(fr.u32());
  const exports = [], er = unique(7); for (let n = er.u32(); n > 0; n--) exports.push({name: er.name(), kind: er.byte(), index: er.u32()});
  const cr = unique(10), bodies = []; assert.equal(cr.u32(), functionTypes.length);
  for (let i = 0; i < functionTypes.length; i++) { const size = cr.u32(), start = cr.pos; bodies.push({index: i + imports.length, start, end: start + size}); cr.skip(size); }
  const frames = stack.map(frame => { const body = bodies[frame.index - imports.length];
    assert.ok(body && frame.offset >= body.start && frame.offset < body.end, 'Fatal offset inside captured function body');
    return {...frame, offsetHex: '0x' + frame.offset.toString(16), body, type: types[functionTypes[frame.index - imports.length]],
      debugName: names.get(frame.index) || null, exports: exports.filter(e => e.kind === 0 && e.index === frame.index).map(e => e.name), owner: 'unknown'};
  });
  return {path: path.resolve(file), sha256: hash(bytes), bytes: bytes.length, importedFunctions: imports.length,
    definedFunctions: functionTypes.length, customSections: custom, functionDebugNames: names.size, stack: frames,
    boundary: 'Metadata only; function type, export alias and byte containment are not allocator ownership or demangled native names.'};
}
function analyze(directory) {
  const logPath = path.join(directory, 'salvage-natural-web.log'), jsonPath = path.join(directory, 'salvage-natural-web.json');
  const logBytes = fs.readFileSync(logPath), resultBytes = fs.readFileSync(jsonPath), run = JSON.parse(resultBytes);
  const lines = logBytes.toString('utf8').split(/\r?\n/), states = [], parseErrors = [], fatals = [], perf = [];
  for (let i = 0; i < lines.length; i++) {
    if (/^Aborted\(OOM\)/.test(lines[i])) fatals.push({line: i + 1, message: lines[i]});
    if (lines[i].includes('VOX_PERF ')) perf.push(i + 1);
    const at = lines[i].indexOf('OUTGAME_STATE '); if (at < 0) continue;
    try { const data = JSON.parse(lines[i].slice(at + 14)), prefix = lines[i].slice(0, at), matched = prefix.match(/^\[([^\]]+)\]\[(\d+)\]/);
      states.push({line: i + 1, timestamp: matched?.[1] || null, frame: matched ? +matched[2] : null, data});
    } catch (error) { parseErrors.push({line: i + 1, error: error.message}); }
  }
  assert.equal(parseErrors.length, 0); assert.equal(fatals.length, 1); assert.equal(run.identity.monitorDisabled, true);
  const salvage = states.filter(row => row.data.salvageRun);
  function project(row) {
    const d = row.data, p = d.performance, r = d.salvageRun || {};
    const metrics = flatten({cache: Object.fromEntries(['resourceBytes', 'modelBytes', 'soundBytes', 'materialBytes', 'texture2DBytes', 'arrayBytes', 'imageBytes', 'jsonBytes', 'xmlBytes'].map(k => [k, p[k]])),
      luaKiB: p.luaKiB, render: {batches: p.batches, primitives: p.primitives, postPasses: p.postPasses}, effects: p.effects,
      objects: p.battleObjects, salvage: {enemies: r.enemies, opened: r.opened, used: r.used, value: r.value},
      weaponAudio: d.weaponAudio, feedbackAudio: d.feedbackAudio, drivingAudio: d.drivingAudio, salvageAudio: r.audio,
      playerMotion: d.wing?.telemetry, destruction: d.destruction, weapons: d.weapons,
      cameraModels: d.camera?.playerModels, background: {resources: p.assetRelease?.backgroundLoadResources, retiredTargets: p.retiredTargets}, hp: d.reticle?.hp});
    return {line: row.line, frame: row.frame, timestamp: row.timestamp, time: r.time ?? null, mode: d.mode, map: d.map, metrics};
  }
  const rows = salvage.map(project), names = [...new Set(rows.flatMap(row => Object.keys(row.metrics)))].sort();
  const metrics = Object.fromEntries(names.map(name => [name, summary(rows, name)]));
  const allRows = states.filter(row => row.data.performance).map(project), allNames = [...new Set(allRows.flatMap(row => Object.keys(row.metrics)))].sort();
  const allModeMetrics = Object.fromEntries(allNames.map(name => [name, summary(allRows, name)]));
  const timeline = [0, 20, 40, 60, 80, 100, 120, 140, 160].map(t => rows.reduce((best, row) => Math.abs(row.time - t) < Math.abs(best.time - t) ? row : best, rows[0])); timeline.push(rows.at(-1));
  const counts = new Map(); for (const row of salvage) { const obj = row.data.performance.battleObjects; if (obj) counts.set(obj.at + ':' + obj.frame, {line: row.line, observedTime: row.data.salvageRun.time, objectAt: obj.at, objectFrame: obj.frame, ...obj}); }
  const live = salvage.find(row => row.data.salvageRun.time > 0 && !row.data.salvageRun.cine?.blocking) || salvage[0];
  const last = salvage.at(-1), timing = [];
  for (const [name, end] of Object.entries(last.data.performance.updateTiming || {})) { const start = live.data.performance.updateTiming?.[name]; if (!start) continue;
    const calls = end.calls - start.calls, totalMs = end.totalMs - start.totalMs;
    timing.push({name, firstLine: live.line, lastLine: last.line, calls, totalMs, meanMsPerCall: calls ? totalMs / calls : null, maxMsSinceLaunch: end.maxMs,
      boundary: 'Inclusive QA wrapper integer-ms wall duration; parent and child cannot be summed; startup maximum can predate this window.'});
  }
  const frameMap = new Map(), duplicateFrames = [], wallErrors = [];
  for (const row of salvage) { const window = row.data.framesWall; if (!window?.samplesMs) continue; let clock = window.firstClockMs;
    for (const ms of window.samplesMs) { clock += ms; if (frameMap.has(clock)) { if (frameMap.get(clock).ms !== ms) wallErrors.push({line: row.line, clock, previous: frameMap.get(clock).ms, ms}); duplicateFrames.push(clock); }
      else frameMap.set(clock, {clock, ms, line: row.line, time: row.data.salvageRun.time});
    }
  }
  const intervals = [...frameMap.values()].map(row => row.ms).sort((a, b) => a - b), quantile = p => intervals[Math.ceil(intervals.length * p) - 1];
  const rawStack = (run.errors || []).join('\n'), stack = [...rawStack.matchAll(/wasm-function\[(\d+)\]:0x([\da-f]+)/g)].map(m => ({index: +m[1], offset: parseInt(m[2], 16)}));
  const wasm = inspectWasm('.tmp/web-engine/UrhoXRuntime.wasm', stack);
  const jsFile = '.tmp/web-engine/UrhoXRuntime.js', jsBytes = fs.readFileSync(jsFile), js = jsBytes.toString('utf8');
  const bindings = [];
  for (const match of js.matchAll(/([A-Za-z_$][\w$]*)=(?:Module\["[^"\n]+"\]=)?wasmExports\["([^"\n]+)"\]/g))
    bindings.push({javascriptName: match[1], exportAlias: match[2], offset: match.index, text: match[0]});
  for (const frame of wasm.stack) frame.javascriptBindings = bindings.filter(binding => frame.exports.includes(binding.exportAlias));
  const resizeAt = js.indexOf('_emscripten_resize_heap='), abortAt = js.indexOf('abortOnCannotGrowMemory='), initialAt = js.indexOf('INITIAL_MEMORY=');
  assert.ok(resizeAt >= 0 && abortAt >= 0 && initialAt >= 0);
  const sidecars = ['UrhoXRuntime.js.map', 'UrhoXRuntime.wasm.map', 'UrhoXRuntime.wasm.symbols', 'UrhoXRuntime.symbols', 'UrhoXRuntime.debug.wasm'].map(file => ({path: path.resolve('.tmp/web-engine', file), exists: fs.existsSync(path.join('.tmp/web-engine', file))}));
  const changes = {}; for (const name of ['cache.resourceBytes', 'cache.modelBytes', 'cache.soundBytes']) {
    changes[name] = rows.filter((row, i) => i === 0 || row.metrics[name] !== rows[i - 1].metrics[name]).map(row => ({line: row.line, time: row.time, value: row.metrics[name]}));
  }
  const olderPath = path.resolve('docs/migration/evidence/salvage-natural-manifest-8d107d95-2026-10-16T15-36-48-056Z/salvage-natural-web.json');
  const olderBytes = fs.readFileSync(olderPath), older = JSON.parse(olderBytes);
  const olderStack = [...(older.errors || []).join('\n').matchAll(/wasm-function\[(\d+)\]:0x([\da-f]+)/g)].map(m => ({index: +m[1], offset: parseInt(m[2], 16)}));
  return {result: 'ANALYZED_OBSERVED_OOM', input: {logPath: path.resolve(logPath), logBytes: logBytes.length, logSha256: hash(logBytes), resultPath: path.resolve(jsonPath), resultSha256: hash(resultBytes)},
    identity: {manifest: run.identity.servedManifest, sourceDirectory: run.identity.source_directory, scriptFingerprint: run.identity.identity.scriptFingerprint,
      sourceCommit: run.identity.identity.sourceCommit, targetCommit: run.identity.identity.targetCommit, port: run.identity.port, monitorDisabled: run.identity.monitorDisabled, perfMonitor: run.identity.perfMonitor, probeSha256: run.identity.probeSha256},
    stateRows: states.length, salvageRows: rows.length, parseErrors, fatal: fatals[0], monitorRecordLines: perf,
    route: {checks: run.checks, target: run.target, exit: run.exit, approachPassed: run.approachPassed?.length, roadPassed: run.roadPassed?.length, finalCargo: last.data.salvageRun.cargo, result: run.result, fatalRuntime: run.fatalRuntime, shutdown: run.shutdownDetails, probeErrors: run.probeErrors},
    firstHall: states.find(row => row.data.mode === 'hangar')?.data.performance, timeline, metrics, allModeMetrics, allStateMeasurements: allRows,
    changes, objectSamples: [...counts.values()], allSalvageRows: rows,
    last: {line: last.line, timestamp: last.timestamp, frame: last.frame, run: last.data.salvageRun, performance: last.data.performance, weapons: last.data.weapons, reticle: last.data.reticle},
    timing, wallFrames: {count: intervals.length, duplicateSamples: duplicateFrames.length, inconsistentSamples: wallErrors, meanMs: intervals.reduce((a, b) => a + b, 0) / intervals.length,
      p50Ms: quantile(.5), p95Ms: quantile(.95), maxMs: intervals.at(-1), above80: intervals.filter(ms => ms > 80).length,
      boundary: 'Deduplicated QA Update-entry wall intervals; includes rendering, waits and observers. Not CPU sections, present timing, old/new comparison or isolated benchmark.'},
    olderComparison: {path: olderPath, sha256: hash(olderBytes), storedResult: older.result,
      sameCapturedWasmStack: JSON.stringify(stack) === JSON.stringify(olderStack), olderStack,
      boundary: 'Identical captured allocation call path does not identify allocation owner, prove identical heap state or establish same root cause.'},
    wasm, javascript: {path: path.resolve(jsFile), sha256: hash(jsBytes), bytes: jsBytes.length, sourceMapDirectives: js.match(/sourceMappingURL=[^\s]+/g) || [],
      resize: {offset: resizeAt, text: js.slice(resizeAt, resizeAt + 180)}, abort: {offset: abortAt, text: js.slice(abortAt, abortAt + 65)},
      initialMemory: {offset: initialAt, text: js.slice(initialAt, initialAt + 180)}}, sidecars,
    boundary: 'Offline parsing only; no runtime, hardware, live heap access or production mutation. Cache, Lua and allocator counters overlap and are never summed. Resource zero is an API result, not proof of zero native/GPU usage. Stack owner and failing allocation size remain unknown; local runtime binary metadata identity must be matched against run identity before symbol claims.'};
}
if (require.main === module) {
  const directory = path.resolve(process.argv[2] || DEFAULT), result = analyze(directory), out = path.join(directory, 'salvage-6f-oom-offline-analysis.json');
  fs.writeFileSync(out, JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify({result: result.result, out, states: result.stateRows, salvageRows: result.salvageRows, fatal: result.fatal, lastTime: result.last.run.time,
    wallFrames: result.wallFrames, metrics: Object.fromEntries(['cache.resourceBytes', 'cache.modelBytes', 'cache.soundBytes', 'luaKiB', 'salvage.enemies'].map(k => [k, result.metrics[k]])),
    wasm: {sha256: result.wasm.sha256, customSections: result.wasm.customSections, stack: result.wasm.stack}, sidecars: result.sidecars}, null, 2));
}
module.exports = {analyze, inspectWasm, summary};
