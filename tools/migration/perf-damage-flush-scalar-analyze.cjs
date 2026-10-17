const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const directory = path.join(root, '.tmp/perf-damage-flush-scalar-c935-1017');
const labels = process.argv.slice(2);
if (!labels.length) labels.push('scalar-A1', 'scalar-B1', 'scalar-B2', 'scalar-A2');
assert.equal(labels.length, 4, 'Provide one ABBA set');
for (const label of labels) assert.match(label, /^[A-Za-z0-9_-]+$/);
const output = path.join(directory, labels.join('-') + '.independent-abba.json');
assert(!fs.existsSync(output), 'Preserve previous analysis');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const inputs = {};
const read = name => { const file = path.join(directory, name); inputs[name] = sha(file); return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); };
const identity = read('identity.json');
const baseline = identity.variants.A.hashes;
const candidate = identity.variants.B.hashes;
assert.deepEqual(Object.keys(baseline), Object.keys(candidate));
assert.deepEqual(Object.keys(baseline).filter(k => baseline[k] !== candidate[k]), ['scripts/construction/TurretRange.lua']);
for (const variant of ['A', 'B']) for (const [name, hash] of Object.entries(identity.variants[variant].hashes)) assert.equal(sha(path.join(identity.variants[variant].directory, name)), hash, `${variant} input drift ${name}`);
for (const [name, hash] of Object.entries(identity.resourceInputs)) assert.equal(sha(path.join(identity.resources, name)), hash, `Resource drift ${name}`);
for (const [name, hash] of Object.entries(identity.runtimeInputs)) assert.equal(sha(path.join(identity.runtimeDirectory, name)), hash, `Runtime drift ${name}`);
const passes = [];
let reference;
let totalAssertions = 0;
for (const [index, label] of labels.entries()) {
  const variant = ['A', 'B', 'B', 'A'][index];
  const launch = read(label + '.launch.json');
  const processRecord = read(label + '.process.json');
  const validation = read(label + '.validation.json');
  const result = read(label + '.json');
  assert.equal(launch.variant, variant);
  assert.deepEqual(launch.sourceHashes, identity.variants[variant].hashes);
  assert.deepEqual(launch.fixture, identity.fixture);
  assert.equal(launch.args.includes('-graphicsheadless'), false);
  assert.equal(processRecord.exitCode, 0);
  assert.equal(processRecord.completedWithinDeadline, true);
  assert.equal(processRecord.handleRetained, true);
  assert.equal(validation.valid, true);
  assert.equal(validation.nativeErrors.length, 0);
  for (const suffix of ['stdout.log', 'stderr.log']) {
    const name = label + '.' + suffix; inputs[name] = sha(path.join(directory, name));
    assert(!/\bERROR:/.test(fs.readFileSync(path.join(directory, name), 'utf8')), `Raw native errors ${name}`);
  }
  assert.equal(result.status, 'PASS');assert.equal(result.cleanup, true);assert.equal(result.collectorRunning, true);
  assert.equal(result.batches, 8);assert.equal(result.steps.length, 192);assert.equal(result.metadata.length, 64);
  assert.deepEqual(result.fixture, identity.fixture);
  assert.deepEqual(result.batchCleanup, Array(8).fill(true));
  const behavior = [];
  const sums = {};
  for (let batch = 1; batch <= 8; batch++) for (let unit = 1; unit <= 8; unit++) {
    const steps = result.steps.filter(s => s.batch === batch && s.unit === unit);
    assert.deepEqual(steps.map(s => s.step), [1, 2, 3]);
    let previous = result.metadata[(batch - 1) * 8 + unit - 1].parts;
    for (const step of steps) {
      assert.equal(step.behaviorChecks, true);assert.equal(step.alive, true);assert.equal(step.partsBefore, previous);assert.equal(step.partsAfter, previous - 1);previous = step.partsAfter;
      assert.equal(step.debris, 0);assert.equal(step.partType, 'cube');assert.deepEqual(step.stateBefore, step.stateAfter);
      assert.match(step.signature, /^[a-f0-9]{16}$/);assert(step.signatureBytes > 0);
      assert.deepEqual(step.events, [{ type: 'partRemoved', id: step.target, reason: 'damage' }, { type: 'unitRebuilt', id: false, reason: false }]);
      for (const name of ['unit.Destroy', 'unit.Flush', 'bp.Graph', 'bp.Connectivity', 'spec.Build', 'turretRange.For', 'unit.Build', 'vehicle.New', 'vehicle.init', 'vehicle.Dispose', 'visual.Bind', 'visual.Consume']) assert.equal(step.stats[name].calls, 1);
      behavior.push({ batch, unit, step: step.step, target: step.target, partsBefore: step.partsBefore, partsAfter: step.partsAfter, stateBefore: step.stateBefore, stateAfter: step.stateAfter, events: step.events, signature: step.signature, signatureBytes: step.signatureBytes });
      totalAssertions++;
      for (const [name, row] of Object.entries(step.stats)) {
        for (const value of Object.values(row)) assert(Number.isFinite(value) && value >= 0);
        const sum = sums[name] ||= { calls: 0, wallMs: 0, selfWallMs: 0, cpuMs: 0, selfCpuMs: 0, maxWallMs: 0 };
        for (const key of ['calls', 'wallMs', 'selfWallMs', 'cpuMs', 'selfCpuMs']) sum[key] += row[key];
        sum.maxWallMs = Math.max(sum.maxWallMs, row.maxWallMs);
      }
    }
  }
  if (!reference) reference = behavior;
  else assert.deepEqual(behavior, reference, 'ABBA real state/event/spec+bp+hp signature mismatch ' + label);
  passes.push({ label, variant, steps: 192, behaviorMatches: true, sums, perBatch: Array.from({ length: 8 }, (_, i) => ({ batch: i + 1, flushWallMs: result.steps.filter(s => s.batch === i + 1).reduce((n, s) => n + s.flush.wallMs, 0), turretWallMs: result.steps.filter(s => s.batch === i + 1).reduce((n, s) => n + s.stats['turretRange.For'].wallMs, 0) })) });
}
const average = (variant, scope, key) => passes.filter(p => p.variant === variant).reduce((n, p) => n + p.sums[scope][key], 0) / 2;
const comparisons = {};
for (const scope of ['unit.Flush', 'turretRange.For', 'spec.Build', 'vehicle.init', 'visual.Bind']) {
  const a = average('A', scope, 'wallMs'); const b = average('B', scope, 'wallMs');
  comparisons[scope] = { baselineMeanTotalWallMs: a, candidateMeanTotalWallMs: b, baselineMeanWallPerCallMs: a / 192, candidateMeanWallPerCallMs: b / 192, changePercent: (b / a - 1) * 100, baselineMeanCpuMs: average('A', scope, 'cpuMs'), candidateMeanCpuMs: average('B', scope, 'cpuMs') };
}
const report = { status: 'NATIVE_ABBA_VERIFIED', inputs, sourceDifference: identity.differences, assertions: { behaviorRows: totalAssertions, signatureAlgorithm: 'FNV-1a 64-bit plus encoded byte length, over canonical doubles/bp/spec/hp/shields/hull/state/events; raw state/event records also compared', normalAutomaticGc: true, fullCleanup: true, nativeErrors: 0, runtimeExitCodes: [0, 0, 0, 0] }, passes, comparisons, boundary: identity.boundary + ' This is an isolated finite CPU attribution experiment with normal automatic GC and method observers. Per-call integer-clock values are coarse; inclusive parent/child times overlap. No sustained combat FPS claim or proof that Web 50-98 ms Flush spikes are fixed.' };
fs.writeFileSync(output, JSON.stringify(report, null, 2));
console.log(JSON.stringify({ status: report.status, output, comparisons, behaviorRows: totalAssertions }));
