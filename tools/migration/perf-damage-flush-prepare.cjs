const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const target = path.join(root, '.tmp/perf-damage-flush-c935-1017');
const frozen = path.join(root, '.tmp/outgame-cached-1792198527902');
const native = path.join(root, '.tmp/perf-effects-zap-native-1017-v2');
const capture = path.join(root, 'docs/migration/evidence/monitor-combat-c935-complete-k/capture.json');
if (fs.existsSync(target)) throw new Error('Preserve existing fixture; choose a new explicit target');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const originalIdentity = JSON.parse(fs.readFileSync(path.join(frozen, 'identity.json'), 'utf8'));
for (const [name, sha] of Object.entries(originalIdentity.identity.scripts)) {
  if (hash(path.join(frozen, 'scripts', name)) !== sha) throw new Error(`Frozen source drift: ${name}`);
}
const data = JSON.parse(fs.readFileSync(capture, 'utf8'));
if (data.before.roster.length !== 8) throw new Error('Actual K roster must contain eight sources');
const resourceIdentity = JSON.parse(fs.readFileSync(path.join(native, 'identity.json'), 'utf8'));
for (const [name, sha] of Object.entries(resourceIdentity.resourceInputs)) {
  if (hash(path.join(resourceIdentity.resources, name)) !== sha) throw new Error(`Native resource drift: ${name}`);
}
fs.mkdirSync(target, { recursive: true });
fs.cpSync(path.join(frozen, 'scripts'), path.join(target, 'scripts'), { recursive: true });
fs.cpSync(path.join(native, 'A/.project'), path.join(target, '.project'), { recursive: true });
fs.symlinkSync(path.join(frozen, 'assets'), path.join(target, 'assets'), 'junction');
fs.copyFileSync(path.join(root, 'tools/migration/perf-damage-flush-native.lua'), path.join(target, 'scripts/perf-damage-flush-native.lua'));
const sourceHashes = {};
function scan(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) scan(file);
    else sourceHashes[path.relative(target, file).replaceAll('\\', '/')] = hash(file);
  }
}
scan(path.join(target, 'scripts'));
const identity = { manifest: 'c9350245', targetCommit: originalIdentity.identity.targetCommit, captureSha256: hash(capture), frozenIdentitySha256: hash(path.join(frozen, 'identity.json')) };
fs.writeFileSync(path.join(target, 'damage-roster.json'), JSON.stringify({ identity, roster: data.before.roster.map(r => ({ name: r.name, role: r.role, team: r.team, source: r.source })) }));
sourceHashes['damage-roster.json'] = hash(path.join(target, 'damage-roster.json'));
fs.writeFileSync(path.join(target, 'source-identity.json'), JSON.stringify({ identity, sourceHashes, resources: resourceIdentity.resources, resourceInputs: resourceIdentity.resourceInputs, runtimeDirectory: resourceIdentity.runtimeDirectory, runtimeInputs: resourceIdentity.runtimeInputs }, null, 2));
console.log(JSON.stringify({ status: 'READY_NOT_RUN', target, identity, files: Object.keys(sourceHashes).length }));
