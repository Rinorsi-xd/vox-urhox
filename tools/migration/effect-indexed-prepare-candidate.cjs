const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const label = process.argv[2];
if (!label || !/^[a-zA-Z0-9_-]+$/.test(label)) throw new Error('Supply unique fixture label');
const directory = path.join(root, '.tmp', `effect-indexed-candidate-${label}`);
if (fs.existsSync(directory)) throw new Error('Preserve prior fixture');
const frozen = path.join(root, '.tmp/outgame-cached-1792198527902');
if (fs.existsSync(path.join(frozen, 'scripts/dev/IndexedEffectCandidate.lua'))) throw new Error('Baseline must exclude experimental candidate');
const shared = JSON.parse(fs.readFileSync(path.join(root, '.tmp/perf-effects-zap-native-1017-v2/identity.json'), 'utf8'));
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
fs.mkdirSync(directory, { recursive: true });
fs.cpSync(path.join(frozen, 'scripts'), path.join(directory, 'scripts'), { recursive: true });
fs.cpSync(path.join(frozen, '.project'), path.join(directory, '.project'), { recursive: true });
fs.symlinkSync(path.join(frozen, 'assets'), path.join(directory, 'assets'), 'junction');
fs.mkdirSync(path.join(directory, 'scripts/dev'), { recursive: true });
fs.copyFileSync(path.join(__dirname, 'IndexedEffectCandidate.lua'), path.join(directory, 'scripts/dev/IndexedEffectCandidate.lua'));
for (const name of ['effect-indexed-mixed.lua', 'effect-indexed-strict.lua']) fs.copyFileSync(path.join(__dirname, name), path.join(directory, 'scripts', name));
const hashes = {};
function walk(base, relative = '') {
  for (const entry of fs.readdirSync(base, { withFileTypes: true })) {
    const name = path.posix.join(relative, entry.name);
    if (entry.isDirectory()) walk(path.join(base, entry.name), name);
    else if (entry.isFile()) hashes[name] = hash(path.join(base, entry.name));
  }
}
walk(path.join(directory, 'scripts'), 'scripts');walk(path.join(directory, '.project'), '.project');
const identity = { status: 'PREPARED_NOT_RUN', directory, frozen, hashes,
  resources: shared.resources, resourceInputs: shared.resourceInputs,
  runtimeDirectory: shared.runtimeDirectory, runtimeInputs: shared.runtimeInputs,
  boundary: 'One frozen source snapshot; A uses production Batch constructor, B selects isolated candidate. Same Effects/state/event code. Dynamic bounds route pending native gate. No Native execution.' };
fs.writeFileSync(path.join(directory, 'identity.json'), JSON.stringify(identity, null, 2));
console.log(JSON.stringify({ status: identity.status, directory, files: Object.keys(hashes).length }));
