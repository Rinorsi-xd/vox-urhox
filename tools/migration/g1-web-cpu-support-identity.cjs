'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),file=path.resolve(root,process.argv[2]||'.tmp/g1-web-cpu-support-51f4-profile/identity.json');
const id=JSON.parse(fs.readFileSync(file)),before=JSON.parse(fs.readFileSync(id.g1WebCpu.sourceFrozen));
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const manifest=JSON.parse(fs.readFileSync(id.manifest_path)),entries=new Map(manifest.files.map(r=>[r.fs_path,r]));
assert.equal(require('node:zlib').crc32(fs.readFileSync(id.manifest_path)).toString(16).padStart(8,'0'),JSON.parse(fs.readFileSync(path.join(id.source_directory,'dist/latest.json'))).client);
const diff=[];
for(const[name,expected]of Object.entries(id.identity.scripts)){
 const source=fs.readFileSync(path.join(id.source_directory,'scripts',name));assert.equal(sha(source),expected,name);
 const frozen=fs.readFileSync(path.join(before.source_directory,'scripts',name));assert.equal(sha(frozen),before.identity.scripts[name],'Frozen source untouched');
 const entry=entries.get(name);assert(entry,name);const payload=fs.readFileSync(path.join(id.source_directory,'dist/assets',entry.uuid+'-'+entry.hash+entry.ext));
 assert.equal(sha(payload),expected,'Packaged script');assert.equal(payload.length,entry.size);
 if(expected!==before.identity.scripts[name])diff.push(name);
}
assert.deepEqual(diff.sort(),['drive/RaySuspension.lua','main.lua','physics/Space.lua']);
assert.equal(sha(fs.readFileSync(path.join(id.source_directory,'scripts/main.lua'))),id.g1WebCpu.entrySha256);
const record={status:'PASS',identity:file,sourceFrozen:id.g1WebCpu.sourceFrozen,scripts:Object.keys(id.identity.scripts).length,diff,
 entrySha256:id.g1WebCpu.entrySha256,probeSha256:id.g1WebCpu.probeSha256,configuration:id.g1WebCpu.configuration,
 boundary:'Offline source/payload/hash/CRC audit only. Actual HTTP and Runtime execution not performed.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/g1-web-cpu-support-identity.json'),JSON.stringify(record,null,2)+'\n');console.log(JSON.stringify(record));
