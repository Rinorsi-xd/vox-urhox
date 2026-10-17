const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const directory = path.join(root, '.tmp/perf-damage-flush-deletion-c935-1017');
const labels = process.argv.slice(2);
if (!labels.length) labels.push('deletion-A1', 'deletion-B1', 'deletion-B2', 'deletion-A2');
assert.equal(labels.length, 4, 'Provide one ABBA set');
for (const label of labels) assert.match(label, /^[A-Za-z0-9_-]+$/);
const output = path.join(directory, labels.join('-') + '.independent-abba.json');
assert(!fs.existsSync(output), 'Preserve previous analysis');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const inputs = {};
const read = name => {
  const file = path.join(directory, name);
  inputs[name] = sha(file);
  return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
};
const tolerance = { float32Ulps: 2, absoluteComponent: 1e-4, positionEuclideanMetres: 1e-4, slack: 1e-12 };
const nativeChecks = { states: 0, components: 0, maxComponentDelta: 0, maxPositionDriftMetres: 0 };
const floatUlp = value => value === 0 ? 2 ** -149 : Math.max(2 ** -149, 2 ** (Math.floor(Math.log2(Math.abs(value))) - 23));
function nativeSame(a, b, label) {
  let squared = 0;
  const { p: ap, q: aq, lv: alv, av: aav, ...pureA } = a;
  const { p: bp, q: bq, lv: blv, av: bav, ...pureB } = b;
  assert.deepEqual(pureA, pureB, `${label} pure state mismatch`);
  for (const key of ['p', 'q', 'lv', 'av']) {
    const components = key === 'q' ? ['x', 'y', 'z', 'w'] : ['x', 'y', 'z'];
    assert.deepEqual(Object.keys(a[key]).sort(), components.toSorted());
    assert.deepEqual(Object.keys(b[key]).sort(), components.toSorted());
    for (const i of components) {
      const x = a[key][i], y = b[key][i];
      assert(Number.isFinite(x) && Number.isFinite(y), `${label} nonfinite native state`);
      const delta = Math.abs(x - y);
      assert(delta <= tolerance.absoluteComponent && delta <= tolerance.float32Ulps * Math.max(floatUlp(x), floatUlp(y)) + tolerance.slack, `${label} native drift ${key}[${i}] ${x} -> ${y}`);
      nativeChecks.components++;
      nativeChecks.maxComponentDelta = Math.max(nativeChecks.maxComponentDelta, delta);
      if (key === 'p') squared += delta * delta;
    }
  }
  const drift = Math.sqrt(squared);
  assert(drift <= tolerance.positionEuclideanMetres, `${label} native position Euclidean drift ${drift}`);
  nativeChecks.maxPositionDriftMetres = Math.max(nativeChecks.maxPositionDriftMetres, drift);
  nativeChecks.states++;
}
function duration(row, label) {
  for (const key of ['wallMs', 'cpuMs']) assert(Number.isFinite(row[key]) && row[key] >= 0, `${label} invalid ${key}`);
}
const sum = (rows, getter) => rows.reduce((n, row) => n + getter(row), 0);
function analyze() {
  const identity = read('identity.json');
  assert.deepEqual(identity.nativeTolerance, tolerance, 'Predeclared identity native tolerance mismatch');
  const baseline = identity.variants.A.hashes, candidate = identity.variants.B.hashes;
  assert.deepEqual(Object.keys(baseline), Object.keys(candidate));
  assert.deepEqual(Object.keys(baseline).filter(k => baseline[k] !== candidate[k]), ['scripts/construction/TurretRange.lua']);
  for (const variant of ['A', 'B']) for (const [name, hash] of Object.entries(identity.variants[variant].hashes)) assert.equal(sha(path.join(identity.variants[variant].directory, name)), hash, `${variant} input drift ${name}`);
  for (const [name, hash] of Object.entries(identity.resourceInputs)) assert.equal(sha(path.join(identity.resources, name)), hash, `Resource drift ${name}`);
  for (const [name, hash] of Object.entries(identity.runtimeInputs)) assert.equal(sha(path.join(identity.runtimeDirectory, name)), hash, `Runtime drift ${name}`);
  const passes = [];
  let reference;
  for (const [index, label] of labels.entries()) {
    const variant = ['A', 'B', 'B', 'A'][index];
    const launch = read(label + '.launch.json'), processRecord = read(label + '.process.json');
    const validation = read(label + '.validation.json'), result = read(label + '.json');
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
      const name = label + '.' + suffix, file = path.join(directory, name);
      inputs[name] = sha(file);
      assert(!/\bERROR:/.test(fs.readFileSync(file, 'utf8')), `Raw native errors ${name}`);
    }
    assert.equal(result.status, 'PASS');
    assert.equal(result.cleanup, true);assert.equal(result.collectorRunning, true);
    assert.equal(result.batches, 8);assert.equal(result.steps.length, 192);
    assert.equal(result.metadata.length, 64);assert.equal(result.loading.length, 64);
    assert.equal(result.setup.length, 8);
    assert.deepEqual(result.fixture, identity.fixture);
    assert.deepEqual(result.nativeTolerance, tolerance);
    assert.deepEqual(result.batchCleanup, Array(8).fill(true));
    const behavior = [], metadata = [], sums = {};
    for (let batch = 1; batch <= 8; batch++) for (let unit = 1; unit <= 8; unit++) {
      const rowIndex = (batch - 1) * 8 + unit - 1;
      const load = result.loading[rowIndex], meta = result.metadata[rowIndex];
      assert.equal(load.batch, batch);assert.equal(load.unit, unit);assert.equal(meta.batch, batch);
      assert.equal(load.hits, unit);assert.equal(load.misses, 0);
      assert(Number.isInteger(load.prepared) && load.prepared >= 1 && load.prepared <= unit);
      assert(Number.isInteger(load.checkpoints) && load.checkpoints > 0);
      assert.equal(load.clearanceWarm, false);
      assert.equal(load.primeCheckpoints, 0);
      assert(Number.isInteger(load.primeCheckpoints) && load.primeCheckpoints >= 0 && load.primeCheckpoints <= load.checkpoints);
      duration(load.prepare, `${label} prepare`);duration(load.spawn, `${label} spawn`);
      assert.match(meta.signature, /^[a-f0-9]{16}$/);assert(meta.signatureBytes > 0);
      const { state, ...pureMeta } = meta;
      metadata.push(pureMeta);
      const steps = result.steps.filter(s => s.batch === batch && s.unit === unit);
      assert.deepEqual(steps.map(s => s.step), [1, 2, 3]);
      let previousParts = meta.parts, previousState = state;
      for (const step of steps) {
        assert.equal(step.behaviorChecks, true);assert.equal(step.alive, true);
        assert.equal(step.partsBefore, previousParts);assert.equal(step.partsAfter, previousParts - 1);previousParts = step.partsAfter;
        assert.equal(step.debris, 0);assert.equal(step.partType, 'cube');
        nativeSame(previousState, step.stateBefore, `${label} ${batch}/${unit}/${step.step} before`);
        nativeSame(step.stateBefore, step.stateAfter, `${label} ${batch}/${unit}/${step.step} roundtrip`);
        previousState = step.stateAfter;
        assert.match(step.signature, /^[a-f0-9]{16}$/);assert(step.signatureBytes > 0);
        assert.deepEqual(step.events, [{ type: 'partRemoved', id: step.target, reason: 'damage' }, { type: 'unitRebuilt', id: false, reason: false }]);
        for (const name of ['unit.Destroy', 'unit.Flush', 'bp.Graph', 'bp.Connectivity', 'spec.Build', 'turretRange.For', 'unit.Build', 'vehicle.New', 'vehicle.init', 'vehicle.Dispose', 'visual.Bind', 'visual.Consume']) assert.equal(step.stats[name].calls, 1);
        behavior.push({ batch, unit, step: step.step, target: step.target, partsBefore: step.partsBefore, partsAfter: step.partsAfter, events: step.events, signature: step.signature, signatureBytes: step.signatureBytes });
        for (const [name, row] of Object.entries(step.stats)) {
          for (const value of Object.values(row)) assert(Number.isFinite(value) && value >= 0);
          const total = sums[name] ||= { calls: 0, wallMs: 0, selfWallMs: 0, cpuMs: 0, selfCpuMs: 0, maxWallMs: 0 };
          for (const key of ['calls', 'wallMs', 'selfWallMs', 'cpuMs', 'selfCpuMs']) total[key] += row[key];
          total.maxWallMs = Math.max(total.maxWallMs, row.maxWallMs);
        }
      }
    }
    if (!reference) reference = { behavior, metadata, raw: result };
    else {
      assert.deepEqual(behavior, reference.behavior, `ABBA exact pure blueprint/spec/HP/events mismatch ${label}`);
      assert.deepEqual(metadata, reference.metadata, `ABBA exact pure metadata mismatch ${label}`);
      for (let i = 0; i < result.metadata.length; i++) nativeSame(reference.raw.metadata[i].state, result.metadata[i].state, `${label} initial ${i}`);
      for (let i = 0; i < result.steps.length; i++) for (const key of ['stateBefore', 'stateAfter']) nativeSame(reference.raw.steps[i][key], result.steps[i][key], `${label} ${key} ${i}`);
    }
    const loading = {};
    for (const key of ['prepare', 'spawn']) loading[key] = { wallMs: sum(result.loading, x => x[key].wallMs), cpuMs: sum(result.loading, x => x[key].cpuMs) };
    for (const row of result.setup) duration(row, `${label} setup`);
    loading.total = { wallMs: loading.prepare.wallMs + loading.spawn.wallMs, cpuMs: loading.prepare.cpuMs + loading.spawn.cpuMs };
    const rounds = [1, 2, 3].map(step => {
      const rows = result.steps.filter(row => row.step === step);
      return { step, calls: rows.length, flushWallMs: sum(rows, x => x.stats['unit.Flush'].wallMs), flushCpuMs: sum(rows, x => x.stats['unit.Flush'].cpuMs), turretWallMs: sum(rows, x => x.stats['turretRange.For'].wallMs), turretCpuMs: sum(rows, x => x.stats['turretRange.For'].cpuMs) };
    });
    passes.push({ label, variant, steps: 192, behaviorMatches: true, sums, loading, rounds, totalLoadingAndFlush: { wallMs: loading.total.wallMs + sums['unit.Flush'].wallMs, cpuMs: loading.total.cpuMs + sums['unit.Flush'].cpuMs }, totalSetupAndFlush: { wallMs: sum(result.setup, x => x.wallMs) + sums['unit.Flush'].wallMs, cpuMs: sum(result.setup, x => x.cpuMs) + sums['unit.Flush'].cpuMs }, perBatch: Array.from({ length: 8 }, (_, i) => ({ batch: i + 1, flushWallMs: sum(result.steps.filter(s => s.batch === i + 1), x => x.flush.wallMs), turretWallMs: sum(result.steps.filter(s => s.batch === i + 1), x => x.stats['turretRange.For'].wallMs) })) });
  }
  const mean = (variant, getter) => sum(passes.filter(p => p.variant === variant), getter) / 2;
  const compare = getter => {
    const a = mean('A', getter), b = mean('B', getter);
    return { baselineMeanMs: a, candidateMeanMs: b, changePercent: a === 0 ? null : (b / a - 1) * 100 };
  };
  const comparisons = {};
  for (const scope of ['unit.Flush', 'turretRange.For', 'spec.Build', 'vehicle.init', 'visual.Bind']) comparisons[scope] = { wall: compare(p => p.sums[scope].wallMs), cpu: compare(p => p.sums[scope].cpuMs) };
  for (const scope of ['prepare', 'spawn', 'total']) comparisons['loading.' + scope] = { wall: compare(p => p.loading[scope].wallMs), cpu: compare(p => p.loading[scope].cpuMs) };
  for (const scope of ['totalLoadingAndFlush', 'totalSetupAndFlush']) comparisons[scope] = { wall: compare(p => p[scope].wallMs), cpu: compare(p => p[scope].cpuMs) };
  for (let step = 1; step <= 3; step++) comparisons['round.' + step] = { flushWall: compare(p => p.rounds[step - 1].flushWallMs), flushCpu: compare(p => p.rounds[step - 1].flushCpuMs), turretWall: compare(p => p.rounds[step - 1].turretWallMs), turretCpu: compare(p => p.rounds[step - 1].turretCpuMs) };
  return { status: 'NATIVE_ABBA_VERIFIED', inputs, sourceDifference: identity.differences, nativeTolerance: tolerance, nativeChecks, assertions: { behaviorRows: 768, metadataRows: 256, loadingRows: 256, pureSignaturesExact: true, normalAutomaticGc: true, fullCleanup: true, nativeErrors: 0, runtimeExitCodes: [0, 0, 0, 0] }, passes, comparisons, boundary: identity.boundary + ' Isolated finite CPU attribution with normal automatic GC and method observers. Load costs reported separately and together with Flush; inclusive parent/child times overlap. Native raw states remain in original files with recorded hashes. No complete combat/Web/mobile/sustained FPS acceptance.' };
}
try {
  const report = analyze();
  fs.writeFileSync(output, JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ status: report.status, output, comparisons: report.comparisons, nativeChecks }));
} catch (error) {
  const report = { status: 'ANALYSIS_FAILED', inputs, nativeTolerance: tolerance, nativeChecks, error: String(error.stack || error) };
  fs.writeFileSync(output, JSON.stringify(report, null, 2));
  console.error(JSON.stringify({ status: report.status, output, error: String(error.message || error) }));
  process.exitCode = 1;
}
