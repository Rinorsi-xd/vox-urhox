// Source H5 stays read-only. Validate the entire batch before replacing assets.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {parse, optimize, triangleHash} = require('./crater-model.cjs');
const root = path.resolve(__dirname, '../..'), dir = path.join(root, 'assets/Crater');
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const apply = process.argv.includes('--apply');
const batch = fs.readdirSync(dir).filter(n => /^mesh-\d+\.mdl$/.test(n)).sort().map(name => {
  const before = fs.readFileSync(path.join(dir, name)), after = optimize(before);
  const a = parse(before), b = parse(after), expandedHash = triangleHash(before);
  assert.equal(triangleHash(after), expandedHash, name + ': ordered triangle bytes changed');
  assert.ok(a.trailer.equals(b.trailer), name + ': metadata changed');
  assert.ok(after.equals(optimize(after)), name + ': optimizer must be idempotent');
  return {after, record: {name, beforeBytes: before.length, afterBytes: after.length,
    beforeVertices: a.count, afterVertices: b.count, indexCount: a.indexCount,
    beforeIndexSize: a.indexSize, afterIndexSize: b.indexSize,
    beforeHash: hash(before), afterHash: hash(after), triangleHash: expandedHash}};
});
const records = batch.map(v => v.record);
const report = {applied: apply, models: records.length, beforeBytes: records.reduce((n,r)=>n+r.beforeBytes,0),
  afterBytes: records.reduce((n,r)=>n+r.afterBytes,0), equivalence: 'SHA256 of every ordered, expanded 44-byte triangle vertex; unchanged metadata', records};
if (apply) {
  for (const {after, record} of batch) {
    if (record.beforeHash === record.afterHash) continue;
    const target = path.join(dir, record.name), temp = target + '.optimizing';
    fs.writeFileSync(temp, after); fs.renameSync(temp, target);
  }
  fs.writeFileSync(path.join(root, 'docs/migration/evidence/crater-model-optimization.json'), JSON.stringify(report, null, 2));
}
console.log(JSON.stringify({...report, records: undefined, savedBytes: report.beforeBytes-report.afterBytes},null,2));
