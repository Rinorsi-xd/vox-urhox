// Read-only integrity gate: acceptance fixtures must never repair production data.
// Run after export-parts.cjs --apply and after changing the original H5 checkout.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/parts-manifest.json'),'utf8'));
const source=path.resolve(process.argv[2]||manifest.source),assets=path.join(root,'assets');
const sha=b=>createHash('sha256').update(b).digest('hex');
const issues=[],counts={sourceFiles:0,artifacts:0,rigs:0,modelReferences:0,thumbnails:0};
function inside(base,relative){
 const file=path.resolve(base,relative);
 if(!file.startsWith(base+path.sep))throw Error('Path outside expected root: '+relative);
 return file;
}
function check(base,relative,digest,kind){
 const file=inside(base,relative);
 if(!fs.existsSync(file))issues.push({kind,path:relative,error:'missing'});
 else if(sha(fs.readFileSync(file))!==digest)issues.push({kind,path:relative,error:'hash mismatch'});
}
if(!manifest.sourceHashes||!manifest.files||!manifest.driveGeometry)throw Error('Run the current offline exporter first');
for(const [relative,digest]of Object.entries(manifest.sourceHashes)){
 check(source,relative,digest,'source');counts.sourceFiles++;
}
for(const [relative,record]of Object.entries(manifest.files)){
 check(assets,'Parts/'+relative,record.sha256,'artifact');counts.artifacts++;
}
check(assets,manifest.driveGeometry.path,manifest.driveGeometry.sha256,'drive geometry');counts.artifacts++;
const models=new Set(manifest.models);
function references(value){
 if(!value||typeof value!=='object')return;
 if(typeof value.model==='string'){
  counts.modelReferences++;
  if(!models.has(value.model)||!fs.existsSync(inside(assets,value.model)))issues.push({kind:'rig',path:value.model,error:'unresolved model'});
 }
 for(const item of Object.values(value))references(item);
}
for(const part of manifest.parts){
 const file=inside(assets,part.path);
 if(fs.existsSync(file)){references(JSON.parse(fs.readFileSync(file,'utf8')));counts.rigs++;}
}
const thumbnails=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/source-thumbnails-import.json'),'utf8'));
for(const [relative,digest]of Object.entries(thumbnails.sourceFiles))check(source,relative,digest,'thumbnail source');
for(const record of thumbnails.images){check(assets,'UI/Parts/'+record.id+'.png',record.sha256,'thumbnail');counts.thumbnails++;}
const catalog=JSON.parse(fs.readFileSync(path.join(assets,'Parts/Catalog.json'),'utf8'));
if(catalog.parts.length!==counts.thumbnails||catalog.parts.some(p=>!thumbnails.images.some(r=>r.id===p.id)))issues.push({kind:'thumbnail',error:'catalog IDs differ'});
const result={result:issues.length?'FAIL':'PASS',checkedAt:new Date().toISOString(),source,counts,issues};
fs.writeFileSync(path.join(root,'docs/migration/evidence/source-assets-integrity.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));process.exitCode=issues.length?1:0;
