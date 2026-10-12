// Lossless optimization of the converter's single-geometry UMDL format.
// Weld complete vertex records, never positions alone: UV/color seams survive.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const STRIDE = 44;
function parse(data) {
  assert.equal(data.toString('ascii', 0, 4), 'UMDL');
  assert.equal(data.readUInt32LE(4), 1, 'one vertex buffer required');
  assert.equal(data.readUInt32LE(12), 31, 'position/normal/color/UV/UV2 required');
  assert.equal(data.readUInt32LE(16), 0); assert.equal(data.readUInt32LE(20), 0);
  const count = data.readUInt32LE(8), end = 24 + count * STRIDE;
  assert.equal(data.readUInt32LE(end), 1, 'one index buffer required');
  const indexCount = data.readUInt32LE(end + 4), indexSize = data.readUInt32LE(end + 8);
  assert.ok(indexSize === 2 || indexSize === 4); assert.equal(indexCount % 3, 0);
  const vertices = data.subarray(24, end), indices = data.subarray(end + 12, end + 12 + indexCount * indexSize);
  const trailer = data.subarray(end + 12 + indexCount * indexSize);
  assert.equal(trailer.length, 80, 'only static single-geometry converter output supported');
  const expected = [1, 0, 1, 0, 0, 0, 0, 0, indexCount, 0, 0];
  expected.forEach((v, i) => assert.equal(trailer.readUInt32LE(i * 4), v));
  const indexAt = i => indexSize === 2 ? indices.readUInt16LE(i * 2) : indices.readUInt32LE(i * 4);
  for (let i = 0; i < indexCount; i++) assert.ok(indexAt(i) < count, 'index within vertex buffer');
  return {count, vertices, indexCount, indexSize, indexAt, trailer};
}
function triangleHash(data) {
  const mesh = parse(data), hash = crypto.createHash('sha256');
  for (let i = 0; i < mesh.indexCount; i++) {
    const start = mesh.indexAt(i) * STRIDE;
    hash.update(mesh.vertices.subarray(start, start + STRIDE));
  }
  return hash.digest('hex');
}
function optimize(data) {
  const mesh = parse(data), keys = new Map(), records = [], remap = new Uint32Array(mesh.count);
  for (let i = 0; i < mesh.count; i++) {
    const record = mesh.vertices.subarray(i * STRIDE, (i + 1) * STRIDE), key = record.toString('hex');
    let target = keys.get(key);
    if (target === undefined) { target = records.length; keys.set(key, target); records.push(record); }
    remap[i] = target;
  }
  const size = records.length <= 65536 ? 2 : 4;
  const header = Buffer.from(data.subarray(0, 24)); header.writeUInt32LE(records.length, 8);
  const ibHeader = Buffer.alloc(12); ibHeader.writeUInt32LE(1); ibHeader.writeUInt32LE(mesh.indexCount, 4); ibHeader.writeUInt32LE(size, 8);
  const indices = Buffer.alloc(mesh.indexCount * size);
  for (let i = 0; i < mesh.indexCount; i++) {
    const index = remap[mesh.indexAt(i)];
    if (size === 2) indices.writeUInt16LE(index, i * 2); else indices.writeUInt32LE(index, i * 4);
  }
  return Buffer.concat([header, ...records, ibHeader, indices, mesh.trailer]);
}
module.exports = {parse, optimize, triangleHash};
