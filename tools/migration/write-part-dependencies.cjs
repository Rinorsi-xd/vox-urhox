const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const rigs = path.join(root, 'assets/Parts/Rigs');
const map = {};
function collect(value, names) {
  if (!value || typeof value !== 'object') return;
  if (typeof value.model === 'string') names.add(value.model);
  for (const child of Object.values(value)) collect(child, names);
}
for (const name of fs.readdirSync(rigs).filter(n => n.endsWith('.json')).sort()) {
  const names = new Set([`Parts/Rigs/${name}`]);
  collect(JSON.parse(fs.readFileSync(path.join(rigs, name))), names);
  map[name.slice(0, -5)] = [...names].sort();
}
fs.writeFileSync(path.join(root, 'assets/Parts/Dependencies.json'), JSON.stringify(map));
console.log(`Dependency index: ${Object.keys(map).length} part variants`);
