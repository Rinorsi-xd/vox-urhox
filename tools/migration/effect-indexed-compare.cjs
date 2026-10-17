const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const [fixture, outputLabel, strictLabel, eqALabel, eqBLabel, ...timingLabels] = process.argv.slice(2);
for (const label of [fixture, outputLabel, strictLabel, eqALabel, eqBLabel, ...timingLabels]) {
  if (!label || !/^[A-Za-z0-9_-]+$/.test(label)) throw new Error('Use simple, nonempty labels');
}
if (timingLabels.length !== 8) throw new Error('Require two complete A B B A timing cycles (8 labels)');
const root = path.resolve(__dirname, '../..', '.tmp', `effect-indexed-candidate-${fixture}`);
const identity = JSON.parse(fs.readFileSync(path.join(root, 'identity.json'), 'utf8'));
const read = name => JSON.parse(fs.readFileSync(path.join(root, `${name}.json`), 'utf8').replace(/^\uFEFF/, ''));
function checked(label) {
  const result = read(label);
  const process = read(`${label}.process`);
  const validation = read(`${label}.validation`);
  const runIdentity = read(`${label}.identity`);
  assert.equal(process.completedWithinDeadline, true, `${label} completion`);
  // PowerShell's Start-Process ExitCode may be null after WaitForExit. Preserve
  // that boundary rather than converting a missing code into a claimed zero.
  assert.ok(process.exitCode === 0 || process.exitCode === null, `${label} exit`);
  assert.equal(validation.valid, true, `${label} native errors`);
  assert.equal(validation.nativeErrors.length, 0, `${label} native errors count`);
  assert.deepEqual(runIdentity.sourceHashes, identity.hashes, `${label} source hashes`);
  assert.deepEqual(runIdentity.runtimeInputs, identity.runtimeInputs, `${label} Runtime`);
  assert.deepEqual(runIdentity.resourceInputs, identity.resourceInputs, `${label} resources`);
  return { label, result, process };
}
const strict = checked(strictLabel);
assert.equal(strict.result.status, 'STRICT_PASS');
assert.ok(strict.result.checks > 0 && strict.result.deindexedVertices > 0);
const a = checked(eqALabel), b = checked(eqBLabel);
for (const [run, variant] of [[a, 'A'], [b, 'B']]) {
  assert.equal(run.result.status, 'PASS');assert.equal(run.result.mode, 'equivalence');
  assert.equal(run.result.variant, variant);assert.equal(run.result.frames, 180);
  assert.equal(run.result.warmup, 60);assert.equal(run.result.seed, 17102026);
  assert.equal(run.result.collectorRunning, true);
  assert.ok(run.result.deindexedVertices > 0);
  assert.notEqual(run.result.geometryDigest, 'cbf29ce484222325');
  assert.notEqual(run.result.stateDigest, 'cbf29ce484222325');
}
for (const key of ['geometryDigest', 'stateDigest', 'deindexedVertices', 'batchTotals', 'peakBatches', 'groundCalls', 'randomTail']) {
  assert.deepEqual(a.result[key], b.result[key], `native mixed equivalence ${key}`);
}
const timings = timingLabels.map(checked);
for (let i = 0; i < timings.length; i++) {
  const r = timings[i].result, variant = ['A', 'B', 'B', 'A'][i % 4];
  assert.equal(r.status, 'PASS');assert.equal(r.mode, 'timing');assert.equal(r.variant, variant);
  assert.equal(r.frames, 480);assert.equal(r.warmup, 60);assert.equal(r.seed, 17102026);
  assert.equal(r.collectorRunning, true);assert.equal(r.deindexedVertices, 0);
  assert.ok(Number.isFinite(r.totalMs) && r.totalMs > 0);
  assert.equal(r.perFrameMs, r.totalMs / 480);
  for (const key of ['batchTotals', 'peakBatches', 'groundCalls', 'randomTail']) {
    assert.deepEqual(r[key], timings[0].result[key], `timing workload ${key}`);
  }
}
const cycles = [];
for (let start = 0; start < 8; start += 4) {
  const runs = timings.slice(start, start + 4);
  const baseline = [runs[0].result.totalMs, runs[3].result.totalMs];
  const candidate = [runs[1].result.totalMs, runs[2].result.totalMs];
  const mean = xs => xs.reduce((x, y) => x + y, 0) / xs.length;
  const aMean = mean(baseline), bMean = mean(candidate);
  const benefit = (aMean - bMean) / aMean;
  const baselineDrift = Math.abs(baseline[1] - baseline[0]) / aMean;
  const candidateDrift = Math.abs(candidate[1] - candidate[0]) / bMean;
  cycles.push({ runs: runs.map(r => ({ label: r.label, variant: r.result.variant, totalMs: r.result.totalMs, perFrameMs: r.result.perFrameMs })),
    baselineMeanMsPerUpdate: aMean / 480, candidateMeanMsPerUpdate: bMean / 480,
    arithmeticReductionPercent: benefit * 100, baselineDriftPercent: baselineDrift * 100,
    candidateDriftPercent: candidateDrift * 100,
    reductionExceedsObservedDrift: benefit > Math.max(baselineDrift, candidateDrift) });
}
const supported = cycles.every(c => c.reductionExceedsObservedDrift);
const result = { status: supported ? 'SCOPED_CPU_BENEFIT_SUPPORTED_PENDING_REVIEW' : 'REJECT_BENEFIT_WITHIN_VARIATION_OR_REGRESSION',
  strict: { label: strict.label, checks: strict.result.checks, vertices: strict.result.deindexedVertices },
  mixedEquivalence: { labels: [a.label, b.label], geometryDigest: a.result.geometryDigest, stateDigest: a.result.stateDigest, vertices: a.result.deindexedVertices },
  cycles, missingProcessExitCodes: [strict, a, b, ...timings].filter(r => r.process.exitCode === null).map(r => r.label),
  boundary: 'Two isolated Native CombatEffects mixed ABBA cycles, normal GC and exact native deindex/state/RNG gate. Timing is integer-ms wall time for Effects.Update, no viewport. Observed drift is not a statistical confidence interval. Missing native ExitCode remains explicit. Does not prove full battle, Web, TapTap or Snapdragon 845 sustained FPS; root must review all logs and dynamic culling/pixel gates before integration.' };
fs.writeFileSync(path.join(root, `${outputLabel}.json`), JSON.stringify(result, null, 2), { flag: 'wx' });
console.log(JSON.stringify(result, null, 2));
