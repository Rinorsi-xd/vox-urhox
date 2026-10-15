const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json'), 'utf8'));
const snapshot = baseline.snapshot.replaceAll('\\\\', '/');
const inventory = fs.readFileSync(path.join(snapshot, 'shared/ui/inventory.js'), 'utf8');
const weapons = fs.readFileSync(path.join(snapshot, 'shared/combat/weapons.js'), 'utf8');
for (const [file, text] of [['shared/ui/inventory.js', inventory], ['shared/combat/weapons.js', weapons]]) {
  const hash = crypto.createHash('sha256').update(text).digest('hex');
  if (hash !== baseline.files[file].sha256) throw new Error(`Frozen source mismatch: ${file}`);
}
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'assets/Parts/Catalog.json'), 'utf8'));
const current = JSON.parse(fs.readFileSync(path.join(root, 'assets/Combat/Weapons.json'), 'utf8'));
const PARTS = Object.fromEntries(catalog.parts.map(d => [d.id, d]));
// Only muzzle-array length enters weaponStats; geometry scaling leaves it unchanged.
const context = vm.createContext({PARTS, applyPartSizing() {}});
for (const file of ['shared/parts/drillData.js', 'shared/parts/weaponData.js']) {
  const text = fs.readFileSync(path.join(snapshot, file), 'utf8');
  if (crypto.createHash('sha256').update(text).digest('hex') !== baseline.files[file].sha256) throw new Error(`Frozen source mismatch: ${file}`);
  vm.runInContext(text.replace(/^import .*;\r?\n/gm, '').replace(/\bexport /g, ''), context);
}
const statsSource = weapons.slice(0, weapons.indexOf('\nfunction rotate(')).replace(/^import .*;\r?\n/gm, '').replace(/\bexport /g, '');
vm.runInContext(statsSource, context);
const start = inventory.indexOf('\t\tconst rows = [];', inventory.indexOf('\t_detail( type )'));
const end = inventory.indexOf('\t\tconst slot =', start);
if (start < 0 || end < 0) throw new Error('Frozen detail extraction failed');
vm.runInContext(`function detailRows(def, injectedStats) { const type=def.id; const weaponStats=()=>injectedStats; ${inventory.slice(start, end)} return rows; }`, context);
const cases = [], resourceDrift = [];
for (const def of catalog.parts) {
  context.def = def;
  const sourceStats = vm.runInContext('weaponStats(def.id)', context);
  const currentStats = current.stats[def.id] || null;
  const core = [['chip', '预算', def.budget ? `${def.budget} 点` : '免费'], ['weight', '质量', `${def.mass} kg`], ['shield', '耐久', String(def.hp)]];
  context.ws = currentStats;
  const currentRows = vm.runInContext('detailRows(def,ws)', context);
  context.ws = sourceStats;
  const sourceRows = vm.runInContext('detailRows(def,ws)', context);
  if (JSON.stringify(currentRows) !== JSON.stringify(sourceRows)) resourceDrift.push({id:def.id,current:currentRows,source:sourceRows});
  cases.push({id:def.id,def,ws:currentStats,expected:[...core,...currentRows]});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},cases,resourceDrift}));
