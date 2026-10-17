const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const snapshot = path.join(root, '.tmp/outgame-cached-1792213080660');
const destination = path.resolve(root, process.argv[2] || '.tmp/g4-boss-missile-native-loose-c074-1017-b');
assert.ok(destination.startsWith(path.join(root, '.tmp') + path.sep), 'Keep isolated Native entry inside workspace .tmp');
assert.ok(!fs.existsSync(destination), 'Preserve previous entry roots and evidence');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const identity = JSON.parse(fs.readFileSync(path.join(snapshot, 'identity.json'), 'utf8'));
assert.equal(identity.ok, true);
for (const [file, expected] of Object.entries(identity.identity.scripts)) {
  assert.equal(hash(path.join(snapshot, 'scripts', file)), expected, 'Frozen source drift: ' + file);
}
assert.equal(identity.identity.scripts['combat/StoryBoss.lua'], '25e4a402d6a8bf7dc577553437ca17cecc27ce5d47d272aad54564166ba5102a');
fs.mkdirSync(destination, {recursive: true});
for (const name of ['scripts', 'assets']) fs.symlinkSync(path.join(snapshot, name), path.join(destination, name), 'junction');
fs.cpSync(path.join(snapshot, '.project'), path.join(destination, '.project'), {recursive: true});
fs.copyFileSync(path.join(snapshot, 'identity.json'), path.join(destination, 'identity.json'));
assert.equal(fs.existsSync(path.join(destination, 'dist')), false);
for (const name of ['scripts', 'assets']) assert.equal(fs.realpathSync(path.join(destination, name)), fs.realpathSync(path.join(snapshot, name)));
const result = {status: 'PREPARED_NOT_RUN', snapshot, destination, sourceCommit: identity.identity.sourceCommit,
  sourceFilesVerified: Object.keys(identity.identity.scripts).length, junctions: {scripts: path.join(snapshot, 'scripts'), assets: path.join(snapshot, 'assets')},
  omitted: ['dist', '.build'],
  reason: 'beta40 detects dist/latest.json and selects Manifest Bootstrap; the cached Web manifest has no usable Native engine-startup source. A new directory without dist selects the already observed loose scripts/assets startup path.',
  boundary: 'Same exact frozen Lua and assets. Only the isolated Native startup directory differs; no production, frozen payload, runtime or previous test tool edits, no Runtime launched.'};
fs.writeFileSync(path.join(destination, 'native-entry-identity.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
