const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const destination = path.resolve(root, process.argv[2] || '.tmp/intro-sfx-native-20261017');
assert.ok(destination.startsWith(path.join(root, '.tmp') + path.sep), 'Fixture must remain under workspace .tmp');
assert.ok(!fs.existsSync(destination), 'Preserve existing fixture and evidence; use a new destination');
const files = ['scripts/audio/IntroAudio.lua', 'scripts/audio/IntroAudioTail.lua', 'scripts/audio/AudioLevels.lua',
  'assets/Intro/Audio/sfx_alarm.mp3', 'assets/Intro/Audio/sfx_blip.mp3', 'assets/Intro/Audio/sfx_scribble.mp3', 'assets/Intro/Audio/sfx_tv_cut.mp3', '.project/settings.json'];
const identity = {status: 'PREPARED_NOT_RUN', destination, sourceHashes: {}, preparedAt: new Date().toISOString(),
  boundary: 'Exact current production modules and four real audio resources copied to isolated directory. No runtime, browser, mixer, native process or existing immutable package is touched.'};
for (const file of files) { const bytes = fs.readFileSync(path.join(root, file)), to = path.join(destination, file); fs.mkdirSync(path.dirname(to), {recursive: true}); fs.writeFileSync(to, bytes); identity.sourceHashes[file] = hash(bytes); }
const probe = fs.readFileSync(path.join(__dirname, 'intro-sfx-native.lua'));
fs.writeFileSync(path.join(destination, 'scripts/intro-sfx-native.lua'), probe); identity.probeSha256 = hash(probe);
// Native1-3 log only executable-adjacent ResCache/Res, ignoring added CLI roots.
// Place exact original resources at those observed paths in a new isolated copy.
const runtimeOrigin = path.join(root, '.tmp/perf-effects-runtime-beta40');
identity.runtimeRoot = path.join(destination, 'runtime');
identity.runtimeFiles = {}; identity.resourceJunctions = {}; identity.bootstrapResources = {};
fs.mkdirSync(identity.runtimeRoot, {recursive: true});
const runtimeIdentity = JSON.parse(fs.readFileSync(path.join(runtimeOrigin, 'copy-identity.json'), 'utf8').replace(/^\uFEFF/, ''));
for (const name of Object.keys(runtimeIdentity.files)) {
  const bytes = fs.readFileSync(path.join(runtimeOrigin, name));
  assert.equal(hash(bytes), runtimeIdentity.files[name].sha256, 'Original Runtime identity drift: ' + name);
  fs.writeFileSync(path.join(identity.runtimeRoot, name), bytes); identity.runtimeFiles[name] = hash(bytes);
}
const originalRes = fs.realpathSync(path.join(runtimeOrigin, 'Res'));
const resLink = path.join(identity.runtimeRoot, 'Res'); fs.symlinkSync(originalRes, resLink, 'junction');
identity.resourceJunctions[resLink] = originalRes;
for (const [directory, resource] of [['CoreData', 'Techniques/NoTexture.xml'], ['CoreData', 'Techniques/DiffUnlit.xml'],
  ['Data', 'Strings/Bootstrap.json'], ['Data', 'Textures/spinner.png'], ['Data', 'Fonts/Anonymous Pro.ttf'],
  ['Data', 'Fonts/Default.xml'], ['Data', 'Fonts/Anonymous Pro.xml'], ['Res', 'Fonts/Twemoji.Mozilla.ttf']]) {
  const bytes = fs.readFileSync(path.join(runtimeOrigin, directory, resource));
  const relative = path.posix.join('ResCache', resource), target = path.join(identity.runtimeRoot, relative);
  fs.mkdirSync(path.dirname(target), {recursive: true}); fs.writeFileSync(target, bytes);
  identity.bootstrapResources[relative] = hash(bytes);
}
fs.writeFileSync(path.join(destination, 'identity.json'), JSON.stringify(identity, null, 2) + '\n');
console.log(JSON.stringify(identity, null, 2));
