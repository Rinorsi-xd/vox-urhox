const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const fixture = path.resolve(root, process.argv[2] || '.tmp/intro-sfx-native-20261017-font5');
const snapshot = path.resolve(root, process.argv[3] || '.tmp/outgame-cached-1792189057538');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const identity = read(path.join(fixture, 'identity.json'));
const result = read(path.join(fixture, 'native-5.json'));
const closed = read(path.join(fixture, 'native-5.process.json'));
const checked = {};
for (const [file, expected] of Object.entries(identity.sourceHashes)) {
  assert.equal(hash(fs.readFileSync(path.join(fixture, file))), expected, 'Frozen source/resource drift: ' + file);
  assert.equal(hash(fs.readFileSync(path.join(root, file))), expected, 'Current source/resource drift: ' + file);
  checked[file] = expected;
}
assert.equal(hash(fs.readFileSync(path.join(fixture, 'scripts/intro-sfx-native.lua'))), identity.probeSha256);
for (const [file, expected] of Object.entries({...identity.runtimeFiles, ...identity.bootstrapResources}))
  assert.equal(hash(fs.readFileSync(path.join(identity.runtimeRoot, file))), expected, 'Native resource drift: ' + file);
for (const [link, target] of Object.entries(identity.resourceJunctions)) assert.equal(fs.realpathSync(link), fs.realpathSync(target));
assert.equal(result.status, 'PASS'); assert.equal(result.checks.length, 46);
assert.ok(result.checks.every(check => check.pass === true));
assert.equal(result.nativeFadeFlag, 'OBSERVED_AND_PROTECTED');
const observations = Object.fromEntries(result.observations.map(row => [row.label, row.data]));
assert.equal(observations.concurrentMixer.retained, 13);
assert.equal(observations.concurrentMixer.timePositionsAdvanced, 13);
assert.equal(observations.preDispose.count, 17); assert.equal(observations.postDispose.count, 0);
assert.equal(closed.status, 'CLOSED'); assert.equal(closed.runtimeSha256, identity.runtimeFiles['UrhoXRuntime.exe']);
assert.equal(path.resolve(closed.runtime), path.resolve(identity.runtimeRoot, 'UrhoXRuntime.exe'));
let pidAbsent = false;
try { process.kill(closed.pid, 0); } catch (error) { if (error.code === 'ESRCH') pidAbsent = true; else throw error; }
assert.ok(pidAbsent, 'Recorded Native PID must no longer exist');
const stderr = fs.readFileSync(path.join(fixture, 'native-5.stderr.log'), 'utf8');
const stdout = fs.readFileSync(path.join(fixture, 'native-5.stdout.log'), 'utf8');
assert.equal((stderr.match(/\bERROR:/g) || []).length, 0);
assert.equal((stdout.match(/\bERROR:/g) || []).length, 0);
const luaDirectory = path.join(identity.runtimeRoot, 'logs/lua');
const luaLogs = fs.readdirSync(luaDirectory).filter(name => name.endsWith('.log')).map(name => fs.readFileSync(path.join(luaDirectory, name), 'utf8')).join('\n');
assert.ok(luaLogs.includes('INTRO_SFX_NATIVE_RESULT') && luaLogs.includes('PASS'), 'Real Runtime Lua final log missing');
const prepared = read(path.join(snapshot, 'identity.json')), scripts = prepared.identity.scripts;
assert.equal(Object.keys(scripts).length, 547);
for (const [name, expected] of Object.entries(scripts)) {
  assert.equal(hash(fs.readFileSync(path.join(snapshot, 'scripts', name))), expected, 'Packed source drift: ' + name);
  assert.equal(hash(fs.readFileSync(path.join(root, 'scripts', name))), expected, 'Production drift: ' + name);
}
assert.equal(hash(JSON.stringify(Object.entries(scripts).sort())), prepared.identity.scriptFingerprint);
assert.equal(scripts['audio/IntroAudio.lua'], checked['scripts/audio/IntroAudio.lua']);
const verification = {
  result: 'PASS', fixture, snapshot, checks: 46, nativeErrorCount: 0, elapsedMs: result.elapsedMs,
  sourceHashes: checked, probeSha256: identity.probeSha256, runtimeSha256: closed.runtimeSha256,
  registeredSources: {baseline: observations.baselineSources.count, beforeDispose: 17, afterDispose: 0},
  concurrentSources: 13, sourcesWithPositionProgress: 13, nativeFadeFlag: result.nativeFadeFlag,
  closure: {status: closed.status, pid: closed.pid, pidAbsent, archivedExitCode: closed.exitCode,
    boundary: 'The archived process file records null exitCode. This audit confirms CLOSED and absent PID; it does not independently recover an OS exit code.'},
  package: {manifest: path.basename(prepared.manifest_path), scripts: 547, scriptFingerprint: prepared.identity.scriptFingerprint,
    introAudioMatchesNativeAndProduction: true},
  evidenceHashes: Object.fromEntries(['identity.json', 'native-5.json', 'native-5.process.json', 'native-5.stderr.log', 'native-5.stdout.log'].map(name => [name, hash(fs.readFileSync(path.join(fixture, name)))])),
  boundary: 'Read-only evidence/hash/process-existence audit; no Runtime or browser launched. Verifies real Native source/mixer progress and explicit lifecycle, plus current and packaged source identity. No PCM/listening, full rendered opening, Web frame-time benefit, OOM allocation attribution or Snapdragon845 sustained performance acceptance.'
};
const output = path.join(root, 'docs/migration/evidence/intro-sfx-native-final-verification.json');
fs.writeFileSync(output, JSON.stringify(verification, null, 2) + '\n');
console.log(JSON.stringify(verification, null, 2));
