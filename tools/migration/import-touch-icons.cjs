const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json')));
const source = path.resolve(root, baseline.snapshot, 'shared/assets/ui/touch');
const target = path.join(root, 'assets/UI/Touch');
fs.mkdirSync(target, { recursive: true });
const files = fs.readdirSync(source).filter(n => n.endsWith('.png')).map(name => {
  const bytes = fs.readFileSync(path.join(source, name));
  fs.copyFileSync(path.join(source, name), path.join(target, name));
  return { name, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
});
fs.writeFileSync(path.join(root, 'docs/migration/evidence/touch-icon-import.json'), JSON.stringify({ baseline: baseline.commit, files }, null, 2));
console.log(`Imported ${files.length} original touch icons without modification`);
