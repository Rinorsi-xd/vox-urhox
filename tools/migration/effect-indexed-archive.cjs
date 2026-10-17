const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const destination = path.join(root, 'docs/migration/evidence/effect-indexed-candidate-2026-10-17');
if (fs.existsSync(destination)) throw new Error('Preserve existing archive; no overwrites');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const entries = [];
function copy(source, relative) {
  const target = path.join(destination, relative);fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
  const sourceSha256 = sha(source), archiveSha256 = sha(target);
  if (sourceSha256 !== archiveSha256) throw new Error(`Archive mismatch: ${relative}`);
  entries.push({ archive: relative, source, sourceSha256, archiveSha256 });
}
for (const fixture of ['effect-indexed-bounds-gate1', 'effect-indexed-bounds-gate2', 'effect-indexed-candidate-candidate1']) {
  const source = path.join(root, '.tmp', fixture);
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    if (entry.isFile()) copy(path.join(source, entry.name), `${fixture}/${entry.name}`);
  }
  const names = fixture.includes('candidate')
    ? ['effect-indexed-mixed.lua', 'effect-indexed-strict.lua', 'dev/IndexedEffectCandidate.lua', 'render/EffectBatch.lua', 'render/CombatEffects.lua']
    : ['effect-indexed-bounds.lua', 'render/EffectBatch.lua'];
  for (const name of names) copy(path.join(source, 'scripts', name), `${fixture}/source/${name}`);
}
for (const name of fs.readdirSync(__dirname)) {
  if (name.startsWith('effect-indexed-') || name === 'IndexedEffectCandidate.lua') {
    const file = path.join(__dirname, name);if (fs.statSync(file).isFile()) copy(file, `tools/${name}`);
  }
}
copy(path.join(root, 'docs/migration/PERF_EFFECT_INDEXED_CANDIDATE_2026_10_17.md'), 'REPORT-at-archive.md');
fs.writeFileSync(path.join(destination, 'archive-hashes.json'), JSON.stringify({
  status: 'ARCHIVED_REJECTED_CANDIDATE', entries,
  boundary: 'Byte-identical copies of all original top-level result/process/log/identity records from both bounds gates and candidate strict/equivalence/eight timing runs, plus exact tested probe/candidate/base sources. Current tool copies include later runner-output/ExitCode handling and experiment relocation changes, distinct from frozen tested source. Original fixtures remain untouched. Full asset/Runtime packages are referenced by original immutable identities, not duplicated here.'
}, null, 2));
console.log(JSON.stringify({ status: 'ARCHIVED_REJECTED_CANDIDATE', files: entries.length, destination }));
