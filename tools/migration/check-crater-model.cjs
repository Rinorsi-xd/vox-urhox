const assert=require('node:assert/strict');
const {parse,optimize,triangleHash}=require('./crater-model.cjs');
function mesh(n, seam=false) {
  const data=Buffer.alloc(24+n*44+12+12+80);
  data.write('UMDL');data.writeUInt32LE(1,4);data.writeUInt32LE(n,8);data.writeUInt32LE(31,12);
  for(let i=0;i<n;i++) data.writeFloatLE(i,24+i*44);
  if(seam) {data.writeFloatLE(0,24+44);data.writeFloatLE(1,24+44+28);}
  const end=24+n*44;[1,3,4,0,1,n-1].forEach((v,i)=>data.writeUInt32LE(v,end+i*4));
  [1,0,1,0,0,0,0,0,3,0,0].forEach((v,i)=>data.writeUInt32LE(v,end+24+i*4));
  return data;
}
for(const n of [3,65536,65537]) {
  const input=mesh(n),output=optimize(input);
  assert.equal(parse(output).indexSize,n<=65536?2:4);
  assert.equal(triangleHash(input),triangleHash(output));
}
const seam=mesh(3,true);assert.equal(parse(optimize(seam)).count,3,'UV seam must survive');
const repeated=mesh(3);repeated.copy(repeated,24+44,24,24+44);
const welded=optimize(repeated);assert.equal(parse(welded).count,2);
assert.equal(triangleHash(repeated),triangleHash(welded));assert.ok(welded.equals(optimize(welded)));
const bad=mesh(3);bad.writeUInt32LE(3,24+3*44+12);assert.throws(()=>optimize(bad));
console.log('PASS: 16-bit boundary, UV seam, exact duplicates, triangle order, idempotence, invalid index');
