const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const original = path.join(root, '.tmp/perf-damage-flush-c935-1017');
const target = path.join(root, '.tmp/perf-damage-flush-scalar-c935-1017');
assert(!fs.existsSync(target), 'Preserve prior frozen A/B fixture');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const old = JSON.parse(fs.readFileSync(path.join(original, 'source-identity.json'), 'utf8'));
for (const [name, hash] of Object.entries(old.sourceHashes)) assert.equal(sha(path.join(original, name)), hash, `Original source drift ${name}`);
const candidate = path.join(root, 'tools/migration/candidates/TurretRangePrepareScalar.lua');
const check = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/evidence/turret-prepare-scalar-offline-2026-10-17.json'), 'utf8'));
assert.equal(check.status, 'PASS');
assert.equal(check.baselineSha256, old.sourceHashes['scripts/construction/TurretRange.lua']);
assert.equal(check.candidateSha256, sha(candidate));
const variants = {};
for (const variant of ['A', 'B']) {
  const directory = path.join(target, variant);
  fs.mkdirSync(directory, { recursive: true });
  fs.cpSync(path.join(original, 'scripts'), path.join(directory, 'scripts'), { recursive: true });
  fs.cpSync(path.join(original, '.project'), path.join(directory, '.project'), { recursive: true });
  fs.symlinkSync(path.join(root, '.tmp/outgame-cached-1792198527902/assets'), path.join(directory, 'assets'), 'junction');
  fs.copyFileSync(path.join(original, 'damage-roster.json'), path.join(directory, 'damage-roster.json'));
  fs.copyFileSync(path.join(root, 'tools/migration/perf-damage-flush-scalar-native.lua'), path.join(directory, 'scripts/perf-damage-flush-scalar-native.lua'));
  if (variant === 'B') fs.copyFileSync(candidate, path.join(directory, 'scripts/construction/TurretRange.lua'));
  const hashes = {};
  function scan(folder) {
    for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
      const file = path.join(folder, entry.name);
      if (entry.isDirectory()) scan(file);
      else hashes[path.relative(directory, file).replaceAll('\\', '/')] = sha(file);
    }
  }
  scan(path.join(directory, 'scripts'));
  hashes['damage-roster.json'] = sha(path.join(directory, 'damage-roster.json'));
  variants[variant] = { directory, hashes };
}
assert.deepEqual(Object.keys(variants.A.hashes), Object.keys(variants.B.hashes));
const differences = Object.keys(variants.A.hashes).filter(name => variants.A.hashes[name] !== variants.B.hashes[name]);
assert.deepEqual(differences, ['scripts/construction/TurretRange.lua']);
const identity = { fixture: old.identity, variants, resources: old.resources, resourceInputs: old.resourceInputs, runtimeDirectory: old.runtimeDirectory, runtimeInputs: old.runtimeInputs,
  candidateSha256: sha(candidate), correctnessSha256: sha(path.join(root, 'docs/migration/evidence/turret-prepare-scalar-offline-2026-10-17.json')), differences,
  expectedBatches: 8, expectedSteps: 192, boundary: 'Only A/B source difference is two temporary tables replaced by scalar same-order sqrt in Prepare; same real Native workload. Normal GC. Direct initial Spawn warms each bp clearance cache. No cached-spec cold-spawn, map/AI/fire/render/audio or Web/device performance acceptance.' };
fs.writeFileSync(path.join(target, 'identity.json'), JSON.stringify(identity, null, 2));
console.log(JSON.stringify({ status: 'READY_NOT_RUN', target, differences, expectedBatches: 8, expectedSteps: 192 }));
