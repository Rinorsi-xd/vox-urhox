'use strict';
// Offline identity controls; no browser/server or source mutation.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),Module=require('node:module');
const root=path.resolve(__dirname,'../..'),file=path.join(__dirname,'check-mobile-hotbar-web-20261017.cjs');
const selected=process.env.VOX_MOBILE_HOTBAR_SNAPSHOT||process.env.VOX_PREPARE_FILE;
assert.ok(selected,'Explicit new snapshot required');
const source=fs.readFileSync(file,'utf8'),real= require(file).offline();
const anchor="const prepared=JSON.parse(fs.readFileSync(prepareFile,'utf8').replace(/^\\uFEFF/,''));";
assert.equal(source.split(anchor).length,2,'Exact preparation integration boundary');
const controls=[];
for(const [name,mutate,expected]of [
 ['wrong-source',p=>{p.identity.sourceCommit='0'.repeat(40)},/b2760649/],
 ['wrong-fingerprint',p=>{p.identity.scriptFingerprint='0'.repeat(64)},/Recorded script fingerprint/],
 ['missing-script',p=>{delete p.identity.scripts['ui/TouchEditorWidgets.lua']},/Recorded script fingerprint|547/],
 ['stale-script-byte',p=>{p.identity.scripts['ui/TouchEditorWidgets.lua']='0'.repeat(64);p.identity.scriptFingerprint=require('node:crypto').createHash('sha256').update(JSON.stringify(Object.entries(p.identity.scripts).sort())).digest('hex')},/Production drift ui\/TouchEditorWidgets.lua/],
]){
 const prepared=structuredClone(real.prepared);mutate(prepared);
 const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));
 m._compile(source.replace(anchor,'const prepared='+JSON.stringify(prepared)+';'),file);
 assert.throws(()=>m.exports.offline(),expected,name);controls.push({name,rejected:true});
}
const savedSnapshot=process.env.VOX_MOBILE_HOTBAR_SNAPSHOT,savedPrepare=process.env.VOX_PREPARE_FILE;
try{
 for(const [name,snapshot,prepare]of [['snapshot-directory',real.frozen,null],['snapshot-file',path.join(real.frozen,'identity.json'),null],['prepare-file',null,path.join(real.frozen,'identity.json')]]){
  if(snapshot)process.env.VOX_MOBILE_HOTBAR_SNAPSHOT=snapshot;else delete process.env.VOX_MOBILE_HOTBAR_SNAPSHOT;
  if(prepare)process.env.VOX_PREPARE_FILE=prepare;else delete process.env.VOX_PREPARE_FILE;
  const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));m._compile(source,file);
  assert.deepEqual(m.exports.offline().prepared.identity,real.prepared.identity,name);controls.push({name,result:'PASS'});
 }
}finally{
 if(savedSnapshot===undefined)delete process.env.VOX_MOBILE_HOTBAR_SNAPSHOT;else process.env.VOX_MOBILE_HOTBAR_SNAPSHOT=savedSnapshot;
 if(savedPrepare===undefined)delete process.env.VOX_PREPARE_FILE;else process.env.VOX_PREPARE_FILE=savedPrepare;
}
const report={result:'PASS',manifest:real.manifestName,snapshot:real.frozen,controls,boundary:'In-memory malformed identity negatives and explicit path selection. No browser, service or frozen/production byte changed.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/mobile-hotbar-snapshot-controls-20261017.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
