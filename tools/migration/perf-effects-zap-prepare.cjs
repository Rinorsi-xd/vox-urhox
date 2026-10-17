const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const directory = path.join(root, '.tmp/perf-effects-zap-native-1017');
if (fs.existsSync(directory)) throw new Error('Preserve prior fixture; target exists');
const frozen = path.join(root, '.tmp/outgame-cached-1792196884433');
const candidate = path.join(root, '.tmp/perf-effects-zap-path-1017/CombatEffects-candidate.lua');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const before = path.join(frozen, 'scripts/render/CombatEffects.lua');
if (sha(before) !== '57899721a52eff5e42a255bd3f7c9effcfe7daa27fb1f153582f6a33c18060f3') throw new Error('Frozen CombatEffects drift');
const identity = { sourceManifest: '17ca8a04', beforeSha256: sha(before), candidateSha256: sha(candidate), snapshots: {} };
for (const variant of ['A', 'B']) {
  const snapshot = path.join(directory, variant);
  fs.mkdirSync(snapshot, { recursive: true });
  fs.cpSync(path.join(frozen, 'scripts'), path.join(snapshot, 'scripts'), { recursive: true });
  fs.cpSync(path.join(root, '.tmp/perf-spawn-f1f7d033-b/.project'), path.join(snapshot, '.project'), { recursive: true });
  fs.symlinkSync(path.join(frozen, 'assets'), path.join(snapshot, 'assets'), 'junction');
  if (variant === 'B') fs.copyFileSync(candidate, path.join(snapshot, 'scripts/render/CombatEffects.lua'));
  fs.copyFileSync(path.join(root, 'tools/migration/perf-effects-zap-native.lua'), path.join(snapshot, 'scripts/perf-effects-zap-native.lua'));
  const hashes = {};
  function scan(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const file = path.join(dir, entry.name);
      if (entry.isDirectory()) scan(file);
      else if (entry.name.endsWith('.lua')) hashes[path.relative(snapshot, file).replaceAll('\\', '/')] = sha(file);
    }
  }
  scan(path.join(snapshot, 'scripts'));
  if (Object.keys(hashes).length !== 549) throw new Error('Expected 548 frozen modules + one probe');
  identity.snapshots[variant] = { snapshot, hashes };
}
const changed = Object.keys(identity.snapshots.A.hashes).filter(key => identity.snapshots.A.hashes[key] !== identity.snapshots.B.hashes[key]);
if (changed.length !== 1 || changed[0] !== 'scripts/render/CombatEffects.lua') throw new Error('Unexpected A/B source difference');
fs.writeFileSync(path.join(directory, 'identity.json'), JSON.stringify(identity, null, 2));
console.log(JSON.stringify({ status: 'READY_NOT_RUN', directory, changed, probeSha256: identity.snapshots.A.hashes['scripts/perf-effects-zap-native.lua'] }));
