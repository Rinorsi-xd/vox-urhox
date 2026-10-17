'use strict';
const assert=require('node:assert/strict'),path=require('node:path'),zlib=require('node:zlib'),fs=require('node:fs');
const {loadFrozenReference,resources}=require('./salvage-frozen-reference.cjs');
const root=path.resolve(__dirname,'../../.tmp/frozen-reference-offline'),manifestPath=path.join(root,'dist/1.0.0/manifest.json');
const rows=[],files=new Map();let count=0;
for(const [key,name]of Object.entries(resources)){
 const bytes=Buffer.from(JSON.stringify({from:'frozen',key})),row={uuid:'R'+count++,hash:zlib.crc32(bytes).toString(16).padStart(8,'0'),ext:'.json',size:bytes.length,fs_path:name};
 rows.push(row);files.set(path.join(root,'dist/assets',row.uuid+'-'+row.hash+row.ext),bytes);
}
const identity={ok:true,qa:true,source_directory:root,manifest_path:manifestPath};
const read=(file)=>{if(file===manifestPath)return Buffer.from(JSON.stringify({assets_pak:0,files:rows}));assert.ok(files.has(file),'Only frozen paths are read');return files.get(file);};
const value=loadFrozenReference(identity,read);for(const key of Object.keys(resources))assert.deepEqual(value[key],{from:'frozen',key});
assert.equal(Object.keys(value.audit.resources).length,4);
for(const invalid of [{...identity,qa:false},{...identity,ok:false},{...identity,source_directory:'relative'},{...identity,manifest_path:path.resolve(root,'../elsewhere.json')}])assert.throws(()=>loadFrozenReference(invalid,read));
for(const mutate of [rows=>rows.pop(),rows=>rows.push(rows[0]),rows=>rows[0].size++,rows=>rows[0].hash='00000000',rows=>rows[0].uuid='../outside',rows=>rows[0].source='remote']){
 const snapshot=structuredClone(rows);mutate(rows);assert.throws(()=>loadFrozenReference(identity,read));rows.splice(0,rows.length,...snapshot);
}
const runner=fs.readFileSync(path.join(__dirname,'check-salvage-natural-web.cjs'),'utf8');
for(const name of ['Salvage/RunData.json','UI/Workshop.json','UI/Outgame.json'])assert.ok(!runner.includes("require('../../assets/"+name+"')"));
assert.ok(runner.includes('gp=reference.gameplay'));assert.ok(runner.includes('report.reference=reference.audit'));
console.log(JSON.stringify({result:'PASS',resources:4,negativeControls:10,boundary:'Offline frozen-payload validation only; no browser, server or Runtime launched.'}));
