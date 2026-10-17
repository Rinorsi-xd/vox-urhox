const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const source = path.join(root, '.tmp/perf-damage-flush-priming-c935-1017-v2');
const target = path.join(root, 'docs/migration/evidence/native-damage-priming-2026-10-17');
assert(!fs.existsSync(target), 'Preserve existing archive');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const analysisName = 'priming-A1-priming-B1-priming-B2-priming-A2.independent-abba.json';
const analysis = JSON.parse(fs.readFileSync(path.join(source, analysisName), 'utf8'));
assert.equal(analysis.status, 'NATIVE_ABBA_VERIFIED');
for (const [name, hash] of Object.entries(analysis.inputs)) assert.equal(sha(path.join(source, name)), hash, 'Raw evidence drift ' + name);
const identity = JSON.parse(fs.readFileSync(path.join(source, 'identity.json'), 'utf8'));
const entries = [];
function copy(file, name) {
  const destination = path.join(target, name);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(file, destination);
  assert.equal(sha(file), sha(destination));
  entries.push({ source: path.relative(root, file).replaceAll('\\', '/'), archive: name, sha256: sha(file), bytes: fs.statSync(file).size });
}
for (const entry of fs.readdirSync(source, { withFileTypes: true })) if (entry.isFile()) copy(path.join(source, entry.name), 'originals/' + entry.name);
for (const variant of ['A', 'B']) {
  for (const name of ['scripts/combat/CarUnit.lua', 'scripts/construction/TurretRange.lua', 'scripts/perf-damage-flush-priming-native.lua', 'damage-roster.json']) {
    const file = path.join(identity.variants[variant].directory, name);
    assert.equal(sha(file), identity.variants[variant].hashes[name], 'Variant evidence drift ' + variant + '/' + name);
    copy(file, variant + '/' + name);
  }
}
for (const name of ['perf-damage-flush-priming-native.lua', 'perf-damage-flush-priming-prepare.cjs', 'perf-damage-flush-priming-run.ps1', 'perf-damage-flush-priming-analyze.cjs', 'check-carunit-clearance-priming.lua', 'check-carunit-clearance-priming.py', 'archive-damage-priming.cjs']) copy(path.join(root, 'tools/migration', name), 'tools/' + name);
copy(path.join(root, 'tools/migration/candidates/CarUnitClearancePriming.lua'), 'candidate/CarUnitClearancePriming.lua');
copy(path.join(root, 'docs/migration/evidence/carunit-clearance-priming-offline-2026-10-17.json'), 'offline-correctness.json');
const labels = ['priming-A1', 'priming-B1', 'priming-B2', 'priming-A2'];
const quantile = (values, p) => values.toSorted((a, b) => a - b)[Math.ceil(values.length * p) - 1];
const stats = values => ({ count: values.length, mean: values.reduce((a, b) => a + b, 0) / values.length, p50: quantile(values, .5), p95: quantile(values, .95), max: Math.max(...values), over80: values.filter(value => value > 80).length });
const distributions = labels.map(label => {
  const run = JSON.parse(fs.readFileSync(path.join(source, label + '.json'), 'utf8'));
  return { label, flush: stats(run.steps.map(s => s.flush.wallMs)), turret: stats(run.steps.map(s => s.stats['turretRange.For'].wallMs)), rounds: [1, 2, 3].map(step => ({ step, flush: stats(run.steps.filter(s => s.step === step).map(s => s.flush.wallMs)), turret: stats(run.steps.filter(s => s.step === step).map(s => s.stats['turretRange.For'].wallMs)) })), loading: { prepare: stats(run.loading.map(s => s.prepare.wallMs)), spawn: stats(run.loading.map(s => s.spawn.wallMs)) } };
});
fs.writeFileSync(path.join(target, 'distributions.json'), JSON.stringify({ status: 'DERIVED_FROM_PRESERVED_RAW', quantile: 'nearest rank ceil(n*p), no interpolation', distributions }, null, 2));
fs.writeFileSync(path.join(target, 'archive-sha256.json'), JSON.stringify({ status: 'ORIGINAL_BYTES_VERIFIED', entries, derived: ['distributions.json'], boundary: 'Original raw files and tool/source snapshots preserved with SHA-256; full asset/runtime binaries and all unrelated frozen source modules are identified by identity hashes, not duplicated. This archive is evidence, not a standalone runnable game package.' }, null, 2));
console.log(JSON.stringify({ status: 'ORIGINAL_BYTES_VERIFIED', target, files: entries.length, distributions }));
