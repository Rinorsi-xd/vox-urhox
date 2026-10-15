// Apply only the reviewed b276 car-data delta, preserving unrelated asset bytes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {pathToFileURL} = require('node:url');
const root = path.resolve(__dirname, '../..');
const commit = 'b276064942ae09c0227ec28d4cfda1d5ff006455';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const ids = ['mtBack', 'mtHead', 'mtWingL', 'mtWingR', 'mtTail1', 'mtTail2', 'mtTail3',
  'rtBack', 'rtHead', 'rtFlankL', 'rtFlankR', 'rtTail1', 'rtTail2', 'rtTail3',
  'roHead', 'roTail', 'roElytraL', 'roElytraR', 'roSideL', 'roSideR'];
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}
const same = (a, b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
function list(directory) {
  return fs.readdirSync(directory, {recursive: true, withFileTypes: true})
    .filter(entry => entry.isFile()).map(entry => path.join(entry.parentPath, entry.name));
}
function literal(source, name, end) {
  const start = source.indexOf('const ' + name + ' = ');
  assert(start >= 0, 'Actual source declaration ' + name);
  const expression = source.slice(start + ('const ' + name + ' = ').length);
  const last = expression.indexOf(end);
  assert(last >= 0, 'Actual source declaration terminator ' + name);
  // Use the JavaScript parser for the source's object literals, not JSON regex replacements.
  return JSON.parse(JSON.stringify(vm.runInNewContext('(' + expression.slice(0, last + end.length - 1) + ')', {}, {timeout: 1000})));
}
async function main() {
  const stageArg = process.argv.find(arg => arg.startsWith('--stage='));
  assert(stageArg, 'Supply the already reviewed --stage= directory');
  const stage = path.resolve(stageArg.slice('--stage='.length));
  assert(stage.startsWith(path.join(root, '.tmp') + path.sep), 'Stage stays inside project .tmp');
  const apply = process.argv.includes('--apply');
  const baseline = read(path.join(root, 'docs/migration/baselines', commit + '.json'));
  assert.equal(baseline.commit, commit);
  const source = path.resolve(baseline.snapshot);
  const manifest = read(path.join(stage, 'manifest.json'));
  assert.equal(path.resolve(manifest.source), source, 'Reviewed immutable source snapshot');
  for (const [file, expected] of Object.entries(manifest.sourceHashes)) {
    assert.equal(sha(fs.readFileSync(path.join(source, file))), expected, 'Export input unchanged ' + file);
    assert.equal(baseline.files[file]?.sha256, expected, 'Export input belongs to candidate ' + file);
  }
  for (const [file, record] of Object.entries(manifest.files)) assert.equal(sha(fs.readFileSync(path.join(stage, file))), record.sha256, 'Stage hash ' + file);
  const currentCatalog = read(path.join(root, 'assets/Parts/Catalog.json'));
  const nextCatalog = read(path.join(stage, 'Catalog.json'));
  assert.equal(currentCatalog.parts.length, 311, 'Apply once against reviewed 311-part input');
  assert.equal(nextCatalog.parts.length, 331);
  assert.deepEqual(nextCatalog.parts.filter(part => !currentCatalog.parts.some(old => old.id === part.id)).map(part => part.id), ids);
  for (const part of currentCatalog.parts) assert(same(part, nextCatalog.parts.find(next => next.id === part.id)), 'Old definition unchanged ' + part.id);
  const changedPresets = Object.keys(currentCatalog.presets).filter(key => !same(currentCatalog.presets[key], nextCatalog.presets[key]));
  assert.deepEqual(changedPresets, ['buildFox']);
  assert.deepEqual(Object.keys(nextCatalog.presets).filter(key => !currentCatalog.presets[key]), ['buildManta', 'buildRat', 'buildRoach']);
  for (const key of Object.keys(currentCatalog).filter(key => !['parts', 'presets'].includes(key))) assert(same(currentCatalog[key], nextCatalog[key]), 'Catalog field unchanged ' + key);
  const foxChanges = currentCatalog.presets.buildFox.parts.flatMap((part, index) => same(part, nextCatalog.presets.buildFox.parts[index]) ? [] : [{old: part, next: nextCatalog.presets.buildFox.parts[index]}]);
  assert.equal(foxChanges.length, 1);
  assert.equal(foxChanges[0].old.type, 'sniper5'); assert.equal(foxChanges[0].next.type, 'missile5');
  assert(same({...foxChanges[0].old, type: 'missile5'}, foxChanges[0].next), 'Fox changes only weapon type');
  const changed = Object.entries(manifest.files).filter(([name, record]) => !fs.existsSync(path.join(root, 'assets/Parts', name)) || sha(fs.readFileSync(path.join(root, 'assets/Parts', name))) !== record.sha256).map(([name]) => name);
  const rigNames = ids.map(id => 'Rigs/' + id + '.json');
  const models = new Set();
  function collect(value) {
    if (!value || typeof value !== 'object') return;
    if (typeof value.model === 'string') models.add(value.model.replace(/^Parts\//, ''));
    for (const child of Object.values(value)) collect(child);
  }
  for (const rig of rigNames) collect(read(path.join(stage, rig)));
  assert.equal(models.size, 20, 'Twenty content-addressed decor models');
  const allowedParts = new Set(['Catalog.json', ...rigNames, ...models]);
  const skipped = [];
  for (const file of changed) {
    if (allowedParts.has(file)) continue;
    assert.equal(file, 'BuildRules.json', 'No unreviewed part change');
    assert(same(read(path.join(root, 'assets/Parts', file)), read(path.join(stage, file))), 'Skip serialization-only BuildRules delta');
    skipped.push(file);
  }
  for (const file of [...rigNames, ...models]) assert(!fs.existsSync(path.join(root, 'assets/Parts', file)), 'New asset does not overwrite unknown file ' + file);
  assert(same(read(path.join(root, 'assets/Drive/Geometry.json')), read(path.join(stage, 'DriveGeometry.json'))), 'Drive geometry remains unchanged');
  const workshopFile = 'assets/UI/Workshop.json';
  const currentWorkshop = read(path.join(root, workshopFile));
  const workshopSource = fs.readFileSync(path.join(source, 'shared/ui/workshop.js'), 'utf8');
  const prefabs = literal(workshopSource, 'PREFABS', '\n];');
  const featured = literal(workshopSource, 'FEATURED', '];');
  const {PREFAB_STATS: stats} = await import(pathToFileURL(path.join(source, 'shared/ui/prefabStats.js')).href);
  assert.equal(prefabs.length, 19);
  assert(same(featured, currentWorkshop.featured), 'Featured carousel unchanged');
  assert.deepEqual(prefabs.filter(prefab => !currentWorkshop.prefabs.some(old => old.id === prefab.id)).map(prefab => prefab.id), ['manta', 'rat', 'roach']);
  for (const old of currentWorkshop.prefabs.filter(prefab => prefab.id !== 'fox')) assert(same(old, prefabs.find(next => next.id === old.id)), 'Old workshop entry unchanged ' + old.id);
  const nextWorkshop = {...currentWorkshop, prefabs, stats};
  const nextDependencies = read(path.join(root, 'assets/Parts/Dependencies.json'));
  for (const rig of rigNames) {
    const names = new Set(['Parts/' + rig]);
    function gather(value) {
      if (!value || typeof value !== 'object') return;
      if (typeof value.model === 'string') names.add(value.model);
      for (const child of Object.values(value)) gather(child);
    }
    gather(read(path.join(stage, rig)));
    nextDependencies[path.basename(rig, '.json')] = [...names].sort();
  }
  const beforeFiles = Object.fromEntries(list(path.join(root, 'assets/Parts')).map(file => [path.relative(root, file).replaceAll('\\', '/'), sha(fs.readFileSync(file))]));
  const report = {sourceCommit: commit, source, staging: stage, applied: apply, startedAt: new Date().toISOString(),
    sourceHashes: manifest.sourceHashes, intendedParts: changed.filter(file => allowedParts.has(file)), skippedSerializationOnly: skipped,
    oldCatalogParts: 311, newCatalogParts: 331, oldPrefabCount: 16, newPrefabCount: 19, newPartIds: ids,
    unchangedParts: beforeFiles, writes: [], pending: ['Real Web/native car and weapon checks', 'Source CSS-filter images', 'Twenty source part thumbnails']};
  const evidence = path.join(root, 'docs/migration/evidence/baseline-cars-' + new Date().toISOString().replace(/[:.]/g, '-'));
  fs.mkdirSync(evidence, {recursive: true});
  const backup = path.join(evidence, 'before');
  function write(relative, bytes, reason) {
    const file = path.join(root, relative);
    const old = fs.existsSync(file) ? fs.readFileSync(file) : null;
    if (old && old.equals(bytes)) return;
    const record = {file: relative, beforeSha256: old ? sha(old) : null, afterSha256: sha(bytes), bytes: bytes.length, reason};
    report.writes.push(record);
    if (!apply) return;
    if (old) { const copy = path.join(backup, relative); fs.mkdirSync(path.dirname(copy), {recursive: true}); fs.writeFileSync(copy, old); }
    fs.mkdirSync(path.dirname(file), {recursive: true}); fs.writeFileSync(file, bytes);
  }
  function meta(relative, identity) {
    if (!fs.existsSync(path.join(root, relative + '.meta'))) write(relative + '.meta', Buffer.from(JSON.stringify({uuid: crypto.createHash('sha256').update(identity).digest().subarray(0, 18).toString('base64url')})), 'New deterministic resource identity');
  }
  for (const file of report.intendedParts) { const relative = 'assets/Parts/' + file; write(relative, fs.readFileSync(path.join(stage, file)), 'Reviewed new-source part delta'); meta(relative, 'Vox:Parts:' + file); }
  write('assets/Parts/Dependencies.json', Buffer.from(JSON.stringify(nextDependencies)), 'Append only twenty decor dependencies');
  write(workshopFile, Buffer.from(JSON.stringify(nextWorkshop)), 'Exact new source workshop and display stats');
  for (const id of ['manta', 'rat', 'roach', 'fox']) {
    const sourceName = 'shared/assets/ui/prefabs/' + id + '.jpg';
    const bytes = fs.readFileSync(path.join(source, sourceName));
    assert.equal(sha(bytes), baseline.files[sourceName].sha256);
    const relative = 'assets/UI/Prefabs/' + id + '.jpg';
    write(relative, bytes, 'Exact source artwork ' + sourceName); meta(relative, 'Vox:Prefab:' + id + '.jpg');
    const xml = 'assets/UI/Prefabs/' + id + '.xml';
    if (!fs.existsSync(path.join(root, xml))) write(xml, fs.readFileSync(path.join(root, 'assets/UI/Prefabs/fox.xml')), 'Existing cross-platform compression settings');
    meta(xml, 'Vox:Prefab:' + id + '.xml');
  }
  const actualManifest = {...manifest, sourceCommit: commit, candidateBaseline: 'docs/migration/baselines/' + commit + '.json', removedModels: []};
  for (const file of skipped) { const bytes = fs.readFileSync(path.join(root, 'assets/Parts', file)); actualManifest.files[file] = {sha256: sha(bytes), bytes: bytes.length}; }
  write('docs/migration/parts-manifest.json', Buffer.from(JSON.stringify(actualManifest, null, 2)), 'Source provenance; no asset deletion');
  if (apply) {
    for (const [relative, expected] of Object.entries(beforeFiles)) if (!report.writes.some(record => record.file === relative)) assert.equal(sha(fs.readFileSync(path.join(root, relative))), expected, 'Untouched asset hash ' + relative);
    for (const record of report.writes) assert.equal(sha(fs.readFileSync(path.join(root, record.file))), record.afterSha256, 'Applied hash ' + record.file);
  }
  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({applied: apply, evidence, writes: report.writes.length, newPartIds: ids, skipped, unchangedExistingPartFiles: Object.keys(beforeFiles).length - report.writes.filter(record => record.beforeSha256 && record.file.startsWith('assets/Parts/')).length}, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
