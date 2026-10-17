const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const fixture = path.join(root, '.tmp/perf-damage-flush-c935-1017');
const label = process.argv[2] || 'damage-profile-2';
assert.match(label, /^[A-Za-z0-9_-]+$/);
const output = path.join(fixture, label + '.independent-acceptance.json');
assert(!fs.existsSync(output), 'Preserve prior independent evidence');
const inputs = {};
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = name => {
  const file = path.join(fixture, name);
  inputs[name] = sha(file);
  return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
};
const result = read(label + '.json');
const processRecord = read(label + '.process.json');
const validation = read(label + '.validation.json');
const launch = read(label + '.launch.json');
const identity = read('source-identity.json');
const roster = read('damage-roster.json');
assert.equal(processRecord.completedWithinDeadline, true);
assert.equal(processRecord.handleRetained, true);
assert.equal(processRecord.exitCode, 0);
assert.equal(validation.valid, true);
assert.equal(validation.nativeErrors.length, 0);
const errors = [];
for (const suffix of ['stdout.log', 'stderr.log']) {
  const name = label + '.' + suffix;
  inputs[name] = sha(path.join(fixture, name));
  for (const line of fs.readFileSync(path.join(fixture, name), 'utf8').split(/\r?\n/)) {
    if (/\bERROR:/.test(line)) errors.push(line);
  }
}
assert.equal(errors.length, 0, 'Raw logs contain native errors');
assert.equal(result.status, 'PASS');
assert.equal(result.cleanup, true);
assert.equal(result.collectorRunning, true);
assert.equal(result.metadata.length, 8);
assert.equal(result.steps.length, 24);
assert.deepEqual(result.fixture, identity.identity);
assert.deepEqual(roster.identity, identity.identity);
assert.deepEqual(launch.fixture, identity.identity);
assert.deepEqual(launch.sourceHashes, identity.sourceHashes);
assert.deepEqual(launch.resourceInputs, identity.resourceInputs);
assert.equal(launch.args.includes('-graphicsheadless'), false);
for (const [name, expected] of Object.entries(identity.sourceHashes)) assert.equal(sha(path.join(fixture, name)), expected, `Frozen script/roster drift ${name}`);
for (const [name, expected] of Object.entries(identity.resourceInputs)) assert.equal(sha(path.join(identity.resources, name)), expected, `Resource drift ${name}`);
for (const [name, expected] of Object.entries(identity.runtimeInputs)) assert.equal(sha(path.join(identity.runtimeDirectory, name)), expected, `Runtime drift ${name}`);
assert.equal(sha(launch.runtime), launch.runtimeSha256);
const capture = path.join(root, 'docs/migration/evidence/monitor-combat-c935-complete-k/capture.json');
assert.equal(sha(capture), identity.identity.captureSha256);
const captured = JSON.parse(fs.readFileSync(capture, 'utf8'));
assert.deepEqual(roster.roster.map(r => r.source), captured.before.roster.map(r => r.source));
const sums = {};
for (let unit = 1; unit <= 8; unit++) {
  const steps = result.steps.filter(s => s.unit === unit);
  assert.deepEqual(steps.map(s => s.step), [1, 2, 3]);
  assert.equal(result.metadata[unit - 1].name, roster.roster[unit - 1].name);
  let previous = result.metadata[unit - 1].parts;
  for (const step of steps) {
    assert.equal(step.behaviorChecks, true);
    assert.equal(step.alive, true);
    assert.equal(step.partsBefore, previous);
    assert.equal(step.partsAfter, previous - 1);
    previous = step.partsAfter;
    assert.equal(step.partType, 'cube');
    assert.equal(step.debris, 0);
    assert.deepEqual(step.events, [{ type: 'partRemoved', id: step.target, reason: 'damage' }, { type: 'unitRebuilt', id: false, reason: false }]);
    for (const name of ['unit.Destroy', 'unit.Flush', 'bp.Graph', 'bp.Connectivity', 'spec.Build', 'turretRange.For', 'unit.Build', 'vehicle.New', 'vehicle.init', 'vehicle.Dispose', 'visual.Bind', 'visual.Consume']) {
      assert.equal(step.stats[name].calls, 1, `${unit}/${step.step}/${name}`);
    }
    for (const [name, row] of Object.entries(step.stats)) {
      for (const [key, value] of Object.entries(row)) assert(Number.isFinite(value) && value >= 0, `${name}.${key}`);
      const samples = step.samples.filter(s => s.label === name);
      assert.equal(samples.length, row.calls);
      for (const key of ['wallMs', 'cpuMs', 'selfWallMs', 'selfCpuMs']) {
        assert(Math.abs(samples.reduce((n, s) => n + s[key], 0) - row[key]) < 1e-7, `Sample/stats mismatch ${name}.${key}`);
      }
      const sum = sums[name] ||= { name, calls: 0, wallMs: 0, selfWallMs: 0, cpuMs: 0, selfCpuMs: 0, maxWallMs: 0 };
      for (const key of ['calls', 'wallMs', 'selfWallMs', 'cpuMs', 'selfCpuMs']) sum[key] += row[key];
      sum.maxWallMs = Math.max(sum.maxWallMs, row.maxWallMs);
    }
  }
}
const rounded = value => Math.round(value * 1000) / 1000;
const summary = Object.values(sums).sort((a, b) => b.selfWallMs - a.selfWallMs).map(row => Object.fromEntries(Object.entries(row).map(([k, v]) => [k, typeof v === 'number' ? rounded(v) : v])));
const accepted = {
  status: 'INDEPENDENT_NATIVE_PROBE_ACCEPTED', label, inputs,
  launcherBoundary: 'Root reported the launcher returned exit 1 in its final ConvertFrom-Json due to Windows PowerShell default ANSI decoding of BOM-less UTF-8 Chinese. Original output/log/process/validation retained unchanged. This independent UTF-8 analysis accepts the Runtime result, not the original launcher postprocessing.',
  checks: { runtimeExitCode: 0, nativeErrors: 0, steps: 24, units: 8, behaviorAssertRows: 24, partsRemoved: 24, nativeRebuilds: 24, visualRebinds: 24, sourceInputsChecked: Object.keys(identity.sourceHashes).length, resourceInputsChecked: Object.keys(identity.resourceInputs).length, runtimeInputsChecked: Object.keys(identity.runtimeInputs).length, captureMatches: true, cleanup: true, automaticCollectorRunning: true },
  summary, perVehicle: result.metadata.map((r, i) => ({ name: r.name, parts: r.parts, flushWallMs: result.steps.filter(s => s.unit === i + 1).map(s => s.flush.wallMs), turretWallMs: result.steps.filter(s => s.unit === i + 1).map(s => s.stats['turretRange.For'].wallMs) })),
  boundary: result.boundary + ' No before/after comparison; this run did not reproduce Web Flush 50-98 ms spikes. TurretRange.For remains an inclusive local clearance scope; its cache-hit, Prepare, Evaluate and automatic-GC contributions are not yet separated. Behavior assertions were executed by the hashed real Native probe; raw per-part p/q/lv/av snapshots were not exported for an independent state replay.'
};
fs.writeFileSync(output, JSON.stringify(accepted, null, 2));
console.log(JSON.stringify({ status: accepted.status, output, checks: accepted.checks, topSelf: summary.slice(0, 5), flush: sums['unit.Flush'], spec: sums['spec.Build'] }));
