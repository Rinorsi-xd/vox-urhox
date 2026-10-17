const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const directory = path.join(root, '.tmp/perf-effects-zap-native-1017-v2');
if (fs.existsSync(directory)) throw new Error('Preserve prior v2 fixture; target exists');
const original = path.join(root, '.tmp/perf-effects-zap-native-1017');
const previous = JSON.parse(fs.readFileSync(path.join(original, 'identity.json'), 'utf8'));
const runtimeDirectory = path.join(root, '.tmp/perf-effects-runtime-beta40');
const matchingCube = 'D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/Res/Cube/Day/DaySpecularHDR.dds';
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const identity = { ...previous, snapshots: {}, resourceInputs: {}, runtimeInputs: {}, resourceProvenance: {} };
for (const variant of ['A', 'B']) {
  const snapshot = path.join(directory, variant);
  const old = previous.snapshots[variant];
  for (const [name, hash] of Object.entries(old.hashes)) {
    if (sha(path.join(old.snapshot, name)) !== hash) throw new Error(`Original source drift: ${variant}/${name}`);
  }
  fs.mkdirSync(snapshot, { recursive: true });
  fs.cpSync(path.join(old.snapshot, 'scripts'), path.join(snapshot, 'scripts'), { recursive: true });
  fs.cpSync(path.join(old.snapshot, '.project'), path.join(snapshot, '.project'), { recursive: true });
  fs.symlinkSync(path.join(root, '.tmp/outgame-cached-1792196884433/assets'), path.join(snapshot, 'assets'), 'junction');
  identity.snapshots[variant] = { snapshot, hashes: old.hashes };
}
const resources = path.join(directory, 'resources');
fs.mkdirSync(path.join(resources, 'Autoload'), { recursive: true });
fs.mkdirSync(path.join(resources, 'ResCache'), { recursive: true });
fs.mkdirSync(path.join(resources, 'Res/Cube/Day'), { recursive: true });
for (const name of ['CoreData.pak', 'Data.pak', 'Res.pak']) {
  const relative = `Autoload/${name}`;
  const source = path.join(root, '.cli', relative);
  const destination = path.join(resources, relative);
  fs.copyFileSync(source, destination);
  identity.resourceInputs[relative] = sha(destination);
  identity.resourceProvenance[relative] = source;
}
const cubeRelative = 'Res/Cube/Day/DaySpecularHDR.dds';
fs.copyFileSync(matchingCube, path.join(resources, cubeRelative));
identity.resourceInputs[cubeRelative] = sha(path.join(resources, cubeRelative));
identity.resourceProvenance[cubeRelative] = matchingCube;
for (const name of ['UrhoXRuntime.exe', 'AgentSDK.dll', 'd3dcompiler_47.dll', 'shaderc.dll', 'themis_x64.dll', 'OfflineShaderCompiler.exe']) {
  identity.runtimeInputs[name] = sha(path.join(runtimeDirectory, name));
}
identity.resources = resources;
identity.runtimeDirectory = runtimeDirectory;
identity.environmentBoundary = 'Same original three CLI resource packages, plus exact beta40 default DDS missing from original prefix. Frozen shared resource inputs for both A/B. Generated ResCache and Runtime shader caches are mutable outputs, not hashed inputs. No production/CLI/installed Runtime files changed. No native execution performed during preparation.';
fs.writeFileSync(path.join(directory, 'identity.json'), JSON.stringify(identity, null, 2));
console.log(JSON.stringify({ status: 'READY_NOT_RUN', directory, resources, resourceInputs: identity.resourceInputs }));
