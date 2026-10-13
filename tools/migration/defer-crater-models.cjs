// One-time extension migration: UMDL contents and existing resource UUIDs stay intact.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),assets=path.join(root,'assets'),dir=path.join(assets,'Crater');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const reportFile=path.join(root,'docs/migration/evidence/crater-deferred-models.json');
const models=fs.readdirSync(dir).filter(name=>/^mesh-\d+\.mdl$/.test(name));
if(!models.length){
 if(!fs.existsSync(reportFile))throw Error('No source models or previous migration evidence');
 const previous=JSON.parse(fs.readFileSync(reportFile));
 for(const record of previous.models){
  if(sha(fs.readFileSync(path.join(assets,record.target)))!==record.sha256)throw Error('Changed model '+record.target);
  if(JSON.parse(fs.readFileSync(path.join(assets,record.target+'.meta'))).uuid!==record.uuid)throw Error('Changed resource identity '+record.target);
 }
 console.log(JSON.stringify({verified:true,models:previous.models.length,bytes:previous.bytes}));
 process.exit(0);
}
const records=models.map(name=>{
 const source='Crater/'+name,target=source.replace(/\.mdl$/,'.bin'),bytes=fs.readFileSync(path.join(assets,source));
 if(bytes.toString('ascii',0,4)!=='UMDL')throw Error('Unexpected model format '+source);
 if(fs.existsSync(path.join(assets,target))||fs.existsSync(path.join(assets,target+'.meta')))throw Error('Destination exists '+target);
 const meta=JSON.parse(fs.readFileSync(path.join(assets,source+'.meta')));
 if(!meta.uuid)throw Error('Missing resource UUID '+source);
 return {source,target,sha256:sha(bytes),bytes:bytes.length,uuid:meta.uuid};
});
const replacements=new Map(records.map(r=>[r.source,r.target]));
const resources=JSON.parse(fs.readFileSync(path.join(dir,'Resources.json')));
const sceneFile=path.join(assets,'Scenes/Crater.xml');
let scene=fs.readFileSync(sceneFile,'utf8');
for(const record of records){
 if(!resources.includes(record.source))throw Error('Missing readiness dependency '+record.source);
 // Match the complete XML attribute value, never a filename prefix.
 scene=scene.replaceAll('value="Model;'+record.source+'"','value="Model;'+record.target+'"');
}
if(/value="Model;Crater\/mesh-\d+\.mdl"/.test(scene))throw Error('Unconverted scene model');
for(const record of records){
 fs.renameSync(path.join(assets,record.source),path.join(assets,record.target));
 fs.renameSync(path.join(assets,record.source+'.meta'),path.join(assets,record.target+'.meta'));
}
fs.writeFileSync(sceneFile,scene);
fs.writeFileSync(path.join(dir,'Resources.json'),JSON.stringify(resources.map(name=>replacements.get(name)||name),null,2));
const report={migratedAt:new Date().toISOString(),format:'UMDL',extension:'.bin',bytes:records.reduce((sum,r)=>sum+r.bytes,0),models:records};
fs.writeFileSync(reportFile,JSON.stringify(report,null,2));
console.log(JSON.stringify({migrated:true,models:records.length,bytes:report.bytes}));
