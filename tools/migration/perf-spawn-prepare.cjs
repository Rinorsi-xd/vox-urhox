const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const target = path.join(root, '.tmp/perf-spawn-f1f7d033-b');
if (fs.existsSync(target)) throw new Error('Preserve prior evidence: fixture already exists');
const frozen = path.join(root, '.tmp/outgame-cached-1792193222299');
const native = path.join(root, '.tmp/perf-vehicle-allocation-20261017-b');
const capture = path.join(root, 'docs/migration/evidence/monitor-combat-f1f7d033-j/capture.json');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
fs.mkdirSync(target, { recursive: true });
fs.cpSync(path.join(frozen, 'scripts'), path.join(target, 'scripts'), { recursive: true });
fs.cpSync(path.join(native, '.project'), path.join(target, '.project'), { recursive: true });
// Resource files are read-only inputs; no copying or mutation of current assets.
fs.symlinkSync(path.join(native, 'assets'), path.join(target, 'assets'), 'junction');
const sourceHashes = {};
function scan(dir) {
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, item.name);
    if (item.isDirectory()) scan(file);
    else sourceHashes[path.relative(target, file).replaceAll('\\', '/')] = hash(fs.readFileSync(file));
  }
}
scan(path.join(target, 'scripts'));
const data = JSON.parse(fs.readFileSync(capture, 'utf8'));
const identity = { manifest: 'f1f7d033', captureSha256: hash(fs.readFileSync(capture)), sourceCount: Object.keys(sourceHashes).filter(name => name.endsWith('.lua')).length };
if (identity.sourceCount !== 548 || data.before.roster.length !== 8) throw new Error('Frozen fixture mismatch');
fs.writeFileSync(path.join(target, 'spawn-roster.json'), JSON.stringify({ identity, roster: data.before.roster.map(r => ({ name: r.name, role: r.role, team: r.team, source: r.source })) }));
fs.copyFileSync(path.join(root, 'tools/migration/perf-spawn-native.lua'), path.join(target, 'scripts/perf-spawn-native.lua'));
fs.writeFileSync(path.join(target, 'source-identity.json'), JSON.stringify({ identity, sourceHashes }, null, 2));
console.log(JSON.stringify({ status: 'READY_NOT_RUN', target, identity }));
