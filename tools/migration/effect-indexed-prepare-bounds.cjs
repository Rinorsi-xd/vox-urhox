const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const label = process.argv[2];
if (!label || !/^[a-zA-Z0-9_-]+$/.test(label)) throw new Error('Supply a unique fixture label');
const directory = path.join(root, '.tmp', `effect-indexed-bounds-${label}`);
if (fs.existsSync(directory)) throw new Error('Preserve prior fixture; choose another label');
const frozen = path.join(root, '.tmp/outgame-cached-1792198527902');
if (fs.existsSync(path.join(frozen, 'scripts/dev/IndexedEffectCandidate.lua'))) throw new Error('Baseline must exclude experimental candidate');
const shared = JSON.parse(fs.readFileSync(path.join(root, '.tmp/perf-effects-zap-native-1017-v2/identity.json'), 'utf8'));
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
fs.mkdirSync(directory, { recursive: true });
fs.cpSync(path.join(frozen, 'scripts'), path.join(directory, 'scripts'), { recursive: true });
fs.cpSync(path.join(frozen, '.project'), path.join(directory, '.project'), { recursive: true });
fs.symlinkSync(path.join(frozen, 'assets'), path.join(directory, 'assets'), 'junction');
fs.copyFileSync(path.join(__dirname, 'effect-indexed-bounds.lua'), path.join(directory, 'scripts/effect-indexed-bounds.lua'));
const hashes = {};
function walk(base, relative = '') {
  for (const entry of fs.readdirSync(base, { withFileTypes: true })) {
    const name = path.posix.join(relative, entry.name);
    if (entry.isDirectory()) walk(path.join(base, entry.name), name);
    else if (entry.isFile()) hashes[name] = hash(path.join(base, entry.name));
  }
}
walk(path.join(directory, 'scripts'), 'scripts');
walk(path.join(directory, '.project'), '.project');
for (const [name, expected] of Object.entries(shared.resourceInputs)) {
  if (hash(path.join(shared.resources, name)) !== expected) throw new Error(`Shared resource drift: ${name}`);
}
for (const [name, expected] of Object.entries(shared.runtimeInputs)) {
  if (hash(path.join(shared.runtimeDirectory, name)) !== expected) throw new Error(`Runtime drift: ${name}`);
}
const identity = { status: 'PREPARED_NOT_RUN', directory, frozen, hashes,
  resources: shared.resources, resourceInputs: shared.resourceInputs,
  runtimeDirectory: shared.runtimeDirectory, runtimeInputs: shared.runtimeInputs,
  boundary: 'Frozen copied scripts and settings; frozen assets junction. No production code edits or Native execution.' };
fs.writeFileSync(path.join(directory, 'identity.json'), JSON.stringify(identity, null, 2));
console.log(JSON.stringify({ status: identity.status, directory, files: Object.keys(hashes).length }));
