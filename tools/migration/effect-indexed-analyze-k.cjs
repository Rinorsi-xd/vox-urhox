// Offline-only independent analysis; never runs a Runtime or changes capture.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const directory = process.argv[3] ? path.resolve(process.argv[3]) : path.resolve(__dirname, '../../docs/migration/evidence/monitor-combat-c935-complete-k');
const output = process.argv[2] || 'independent-attribution.json';
assert.match(output, /^[A-Za-z0-9_-]+\.json$/);
assert.ok(process.argv[4] === undefined || process.argv[4] === '--include-frames');
const rawCapture = fs.readFileSync(path.join(directory, 'capture.json'));
const rawPerf = fs.readFileSync(path.join(directory, 'production-perf.jsonl'));
const capture = JSON.parse(rawCapture);
const records = rawPerf.toString('utf8').trim().split(/\r?\n/).map(JSON.parse);
const samples = new Map(), slow = new Map();
for (const record of records) {
  if (record.type === 'slow_frame') slow.set(record.frame, record);
  for (const row of record.frameSamples || []) {
    assert.equal(row.stageTimes.length % 5, 0);
    const stages = [];
    for (let index = 0; index < row.stageTimes.length; index += 5) {
      const [id, ms, selfMs, calls, maxMs] = row.stageTimes.slice(index, index + 5);
      const name = record.stageNames[id - 1];assert.equal(typeof name, 'string');
      stages.push({ name, ms, selfMs, calls, maxMs });
    }
    assert.ok(!samples.has(row.frame), 'No duplicate compact production frame');
    samples.set(row.frame, { ...row, stages });
  }
}
const n = capture.frameIds.length;
for (const key of ['wallMs', 'parts', 'shots', 'hits', 'damage', 'kills']) assert.equal(capture[key].length, n);
assert.equal(capture.rows.length, n * 9);
for (let i = 1; i < n; i++) assert.equal(capture.frameIds[i], capture.frameIds[i - 1] + 1);
const indices = Array.from({ length: n - 2 }, (_, i) => i + 1);
const alignments = [];
for (let offset = -2000; offset <= 0; offset++) {
  let matched = 0, exact = 0, error = 0, maxError = 0;
  for (const index of indices) {
    const row = samples.get(capture.frameIds[index] + offset);
    if (!row) continue;
    matched++;const diff = Math.abs(row.frameMs - capture.wallMs[index + 1]);
    if (diff === 0) exact++;error += diff;maxError = Math.max(maxError, diff);
  }
  if (matched === indices.length) alignments.push({ offset, matched, exact, totalAbsoluteErrorMs: error, maxAbsoluteErrorMs: maxError });
}
alignments.sort((a, b) => b.exact - a.exact || a.totalAbsoluteErrorMs - b.totalAbsoluteErrorMs);
const alignment = alignments[0];assert.ok(alignment.exact / indices.length > .98);assert.ok(alignment.exact > alignments[1].exact * 5);
assert.ok(alignment.maxAbsoluteErrorMs <= 1, 'No arbitrary frame realignment or missing-frame interpolation');
const sum = xs => xs.reduce((a, b) => a + b, 0);
const mean = xs => sum(xs) / xs.length;
const quantile = (xs, p) => [...xs].sort((a, b) => a - b)[Math.ceil(xs.length * p) - 1];
const totals = new Map();
const frames = indices.map(index => {
  const row = samples.get(capture.frameIds[index] + alignment.offset);
  const observation = { engineFrame: capture.frameIds[index], monitorFrame: row.frame,
    intervalMs: capture.wallMs[index + 1], monitorIntervalMs: row.frameMs, updateToEndFrameMs: row.wallMs,
    scriptMs: row.scriptMs, steps: row.steps, luaKiB: row.luaKiB,
    parts: capture.parts[index], shots: capture.shots[index], hits: capture.hits[index], damage: capture.damage[index],
    finalizeMs: capture.rows[index * 9], emitMs: capture.rows[index * 9 + 3], contextMs: capture.rows[index * 9 + 6],
    stages: row.stages };
  for (const stage of row.stages) {
    if (!totals.has(stage.name)) totals.set(stage.name, { name: stage.name, inclusiveMs: 0, selfMs: 0, calls: 0, maxCallMs: 0 });
    const total = totals.get(stage.name);total.inclusiveMs += stage.ms;total.selfMs += stage.selfMs;
    total.calls += stage.calls;total.maxCallMs = Math.max(total.maxCallMs, stage.maxMs);
  }
  return observation;
});
const stageTotals = [...totals.values()].map(row => ({ ...row, inclusiveMeanMsPerFrame: row.inclusiveMs / frames.length,
  selfMeanMsPerFrame: row.selfMs / frames.length, callsPerFrame: row.calls / frames.length })).sort((a, b) => b.selfMs - a.selfMs);
const spikes = frames.filter(row => row.intervalMs > 80).map(row => {
  const record = slow.get(row.monitorFrame);assert.ok(record, 'Each spike has original slow_frame record');
  assert.equal(record.frameMs, row.monitorIntervalMs);assert.equal(record.scriptMs, row.scriptMs);
  const index = frames.indexOf(row), previous = frames[Math.max(0, index - 1)];
  return { ...row, stages: [...row.stages].sort((a, b) => b.selfMs - a.selfMs), context: record.context,
    unattributedMs: record.unattributedMs, outsideEndFrameMs: record.outsideEndFrameMs,
    longSpans: record.longSpans, previous: { engineFrame: previous.engineFrame, intervalMs: previous.intervalMs,
      luaKiB: previous.luaKiB, parts: previous.parts, hits: previous.hits, damage: previous.damage },
    partDelta: row.parts - previous.parts, hitDelta: row.hits - previous.hits, damageDelta: row.damage - previous.damage };
});
const retained = ['hangarRetained', 'buildRetained', 'mapPreviewRetained', 'openingActive', 'backgroundResources'];
const contextRecords = records.filter(r => r.context && r.frame >= frames[0].monitorFrame && r.frame <= frames.at(-1).monitorFrame);
const retention = Object.fromEntries(retained.map(key => [key, { presentRecords: contextRecords.filter(r => Object.hasOwn(r.context, key)).length,
  truthyRecords: contextRecords.filter(r => Boolean(r.context[key])).length }]));
const elapsed = frames.map(r => r.intervalMs);
const result = { status: 'INDEPENDENT_ATTRIBUTION_PASS',
  sourceHashes: { 'capture.json': crypto.createHash('sha256').update(rawCapture).digest('hex'),
    'production-perf.jsonl': crypto.createHash('sha256').update(rawPerf).digest('hex') },
  alignment: { ...alignment, formula: 'monitorFrame = engineFrame + offset; capture.wallMs[index+1] encloses engineFrame[index]',
    runnerUp: alignments[1], excludedPartialFrames: [capture.frameIds[0], capture.frameIds.at(-1)] },
  summary: { frames: frames.length, elapsedMs: sum(elapsed), meanIntervalMs: mean(elapsed), meanRateFps: 1000 / mean(elapsed),
    p50Ms: quantile(elapsed, .5), p95Ms: quantile(elapsed, .95), p99Ms: quantile(elapsed, .99), maxMs: Math.max(...elapsed), over80: spikes.length,
    meanScriptMs: mean(frames.map(r => r.scriptMs)), meanUpdateToEndFrameMs: mean(frames.map(r => r.updateToEndFrameMs)),
    meanFinalizeMs: mean(frames.map(r => r.finalizeMs)), meanEmitNestedWithinFinalizeMs: mean(frames.map(r => r.emitMs)),
    meanContextMs: mean(frames.map(r => r.contextMs)), meanSteps: mean(frames.map(r => r.steps)),
    stepsDistribution: frames.reduce((a, r) => (a[r.steps] = (a[r.steps] || 0) + 1, a), {}) },
  workload: { roster: capture.before.roster.length, realAiDrivers: capture.before.roster.filter(r => r.driver).length,
    shots: capture.after.world.shots - capture.before.world.shots, hits: capture.after.world.hits - capture.before.world.hits,
    playerDamage: capture.after.playerDamage - capture.before.playerDamage, minParts: Math.min(...frames.map(r => r.parts)) },
  retention, stageTotals, spikes,
  boundary: 'Read-only independent reconstruction of one controlled eight-car Web combat capture, production monitoring enabled. Integer wall time, inclusive scopes nest and self only subtracts instrumented children. Scoped samples can include native calls, allocation, GC or scheduling pauses. Residual is not measured GPU time. This is attribution, not optimization A/B or Snapdragon 845/TapTap FPS acceptance.' };
if (process.argv[4] === '--include-frames') result.frames = frames;
fs.writeFileSync(path.join(directory, output), JSON.stringify(result, null, 2), { flag: 'wx' });
console.log(JSON.stringify({ status: result.status, summary: result.summary, alignment: result.alignment,
  topSelf: stageTotals.slice(0, 12), spikes: spikes.map(r => ({ engineFrame: r.engineFrame, monitorFrame: r.monitorFrame,
    intervalMs: r.intervalMs, scriptMs: r.scriptMs, steps: r.steps, top: r.stages.slice(0, 3), partDelta: r.partDelta })) }, null, 2));
