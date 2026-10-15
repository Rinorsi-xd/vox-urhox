// Mechanical resource-path migration; model bytes and UUIDs remain unchanged.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),assets=path.join(root,'assets'),dir=path.join(assets,'Parts/Models');
const evidence=path.join(root,'docs/migration/evidence/parts-deferred-models.json');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const originals=fs.readdirSync(dir).filter(n=>/^[a-f0-9]{24}\.mdl$/.test(n));
if(!originals.length){
 const report=JSON.parse(fs.readFileSync(evidence));
 for(const r of report.models){
  assert.equal(sha(fs.readFileSync(path.join(assets,r.target))),r.sha256,r.target+' geometry');
  assert.equal(JSON.parse(fs.readFileSync(path.join(assets,r.target+'.meta'))).uuid,r.uuid,r.target+' identity');
 }
 console.log(JSON.stringify({verified:true,models:report.models.length,bytes:report.bytes}));
}else{
 const models=originals.sort().map(n=>{
  const source='Parts/Models/'+n,target=source.replace(/\.mdl$/,'.bin'),bytes=fs.readFileSync(path.join(assets,source));
  assert.equal(bytes.toString('ascii',0,4),'UMDL');
  assert.ok(!fs.existsSync(path.join(assets,target))&&!fs.existsSync(path.join(assets,target+'.meta')),'destination is unused');
  const uuid=JSON.parse(fs.readFileSync(path.join(assets,source+'.meta'))).uuid;assert.ok(uuid);
  return {source,target,bytes:bytes.length,sha256:sha(bytes),uuid};
 });
 const replacements=new Map(models.map(m=>[m.source,m.target]));
 function convert(value){
  if(typeof value==='string')return replacements.get(value)||value;
  if(Array.isArray(value))return value.map(convert);
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,convert(v)]));
  return value;
 }
 const rigs=path.join(assets,'Parts/Rigs');
 const updates=fs.readdirSync(rigs).filter(n=>n.endsWith('.json')).map(n=>{
  const file=path.join(rigs,n),body=JSON.stringify(convert(JSON.parse(fs.readFileSync(file))));
  return {file,body,relative:'Rigs/'+n};
 });
 const dependencyFile=path.join(assets,'Parts/Dependencies.json');
 const dependencies=JSON.stringify(convert(JSON.parse(fs.readFileSync(dependencyFile))));
 const manifestFile=path.join(root,'docs/migration/parts-manifest.json');
 const manifest=convert(JSON.parse(fs.readFileSync(manifestFile)));
 manifest.files=Object.fromEntries(Object.entries(manifest.files).map(([name,record])=>[name.replace(/^(Models\/[a-f0-9]{24})\.mdl$/,'$1.bin'),record]));
 for(const u of updates)manifest.files[u.relative]={sha256:sha(Buffer.from(u.body)),bytes:Buffer.byteLength(u.body)};
 const report={migratedAt:new Date().toISOString(),format:'UMDL',extension:'.bin',bytes:models.reduce((s,m)=>s+m.bytes,0),models};
 if(process.argv.includes('--apply')){
  for(const r of models){
   fs.renameSync(path.join(assets,r.source),path.join(assets,r.target));
   fs.renameSync(path.join(assets,r.source+'.meta'),path.join(assets,r.target+'.meta'));
  }
  for(const u of updates)fs.writeFileSync(u.file,u.body);
  fs.writeFileSync(dependencyFile,dependencies);
  fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2));
  fs.writeFileSync(evidence,JSON.stringify(report,null,2));
 }
 console.log(JSON.stringify({applied:process.argv.includes('--apply'),models:models.length,rigs:updates.length,bytes:report.bytes}));
}
