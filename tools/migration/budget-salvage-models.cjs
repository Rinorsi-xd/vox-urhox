// Losslessly remove unused white color and zero UV2 channels from source batches.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {parse}=require('./crater-model.cjs');const root=path.resolve(__dirname,'../..');
const file=path.join(root,'assets/Salvage/RunManifest.json'),data=JSON.parse(fs.readFileSync(file));
const rows=[];
for(const model of data.models){const target=path.join(root,'assets',model.model),bytes=fs.readFileSync(target);
 if([11,15].includes(bytes.readUInt32LE(12))){if(model.bytes!==bytes.length){rows.push({model:model.model,before:model.bytes,after:bytes.length});model.bytes=bytes.length;}continue;}
 const m=parse(bytes),header=Buffer.from(bytes.subarray(0,24));let white=true;
 for(let i=0;i<m.count;i++)if(m.vertices.readUInt32LE(i*44+24)!==0xffffffff){white=false;break;}
 const stride=white?32:36,vertices=Buffer.alloc(m.count*stride);header.writeUInt32LE(white?11:15,12);
 for(let i=0;i<m.count;i++){
  const at=i*44;
  assert.equal(m.vertices.readFloatLE(at+36),0);assert.equal(m.vertices.readFloatLE(at+40),0);
  m.vertices.copy(vertices,i*stride,at,at+(white?24:28));m.vertices.copy(vertices,i*stride+(white?24:28),at+28,at+36);
 }
 const after=Buffer.concat([header,vertices,bytes.subarray(24+m.count*44)]);fs.writeFileSync(target,after);
 rows.push({model:model.model,before:bytes.length,after:after.length,vertices:m.count,triangles:m.indexCount/3});model.bytes=after.length;
}
fs.writeFileSync(file,JSON.stringify(data));
const report={method:'Lossless removal of zero UV2; remove COLOR only when uniformly white; identical positions, normals, UV and indices',models:rows.length,before:rows.reduce((n,r)=>n+r.before,0),after:rows.reduce((n,r)=>n+r.after,0),rows};
if(rows.length)fs.writeFileSync(path.join(root,'docs/migration/evidence/salvage-model-budget.json'),JSON.stringify(report,null,2));console.log({models:report.models,before:report.before,after:report.after});
