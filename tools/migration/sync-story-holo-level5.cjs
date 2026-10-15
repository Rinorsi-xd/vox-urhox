// Import only S5 overlays. Shared terrain and S1-S4 are byte-preserved.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const stage=path.resolve(process.env.VOX_STORY_STAGE||path.join(root,'.tmp/story-holo-level5-current/Story'));
const production=path.join(root,'assets/Story'),manifestFile=path.join(production,'Manifest.json');
const original=JSON.parse(fs.readFileSync(manifestFile)),candidate=JSON.parse(fs.readFileSync(path.join(stage,'Manifest.json')));
const hash=file=>createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sourceFiles=['three/src/ui/storyHolo.js','shared/story/chapter1.js'];
const sourceHashes={};
for(const file of sourceFiles){sourceHashes[file]=hash(path.join(baseline.snapshot,file));assert.equal(sourceHashes[file],baseline.files[file]?.sha256,'Frozen input changed: '+file);}
assert.equal(candidate.levels.length,1);assert.equal(candidate.levels[0].no,'05');
assert.equal(candidate.models.length,4);assert(candidate.models.every(m=>m.level==='05'));
assert.deepEqual(candidate.levels[0].marks.map(m=>[m.label,m.kind]),[['主引擎坑 · 北边几公里','boss']]);
const oldModels=original.models.filter(m=>m.level==='05'),keepModels=original.models.filter(m=>m.level!=='05');
assert(oldModels.length>=4);assert(oldModels.every(m=>/^Story\/model-\d+\.bin$/.test(m.model)));
const excluded=new Set(['Manifest.json',...oldModels.map(m=>m.model.slice('Story/'.length))]);
const files=fs.readdirSync(production,{recursive:true}).filter(f=>fs.statSync(path.join(production,f)).isFile());
const protectedHashes=Object.fromEntries(files.filter(f=>!excluded.has(f)).map(f=>[f,hash(path.join(production,f))]));
const keepMax=Math.max(...keepModels.map(m=>m.material));
const materials=original.materials.slice(0,keepMax+1),materialMap=new Map();
for(let i=0;i<candidate.materials.length;i++){
 const material=candidate.materials[i],serialized=JSON.stringify(material);
 let index=materials.findIndex(m=>JSON.stringify(m)===serialized);
 if(index<0){index=materials.length;materials.push(material);}
 materialMap.set(i,index);
}
const newModels=candidate.models.map((m,i)=>{
 const bytes=fs.readFileSync(path.join(root,'assets',m.model).replace(path.join(root,'assets','Story'),stage));
 assert.equal(bytes.subarray(0,4).toString(),'UMDL');assert.equal(bytes.length,m.bytes);
 const destination=oldModels[i].model;
 return {entry:{...m,model:destination,material:materialMap.get(m.material)},bytes};
});
const levels=original.levels.map(l=>l.no==='05'?candidate.levels[0]:l);
const result={...original,materials,models:[...keepModels,...newModels.map(m=>m.entry)],levels};
assert.deepEqual(result.levels.filter(l=>l.no!=='05'),original.levels.filter(l=>l.no!=='05'));
assert.deepEqual(result.models.filter(m=>m.level!=='05'),keepModels);
for(const model of newModels)fs.writeFileSync(path.join(root,'assets',model.entry.model),model.bytes);
fs.writeFileSync(manifestFile,JSON.stringify(result));
const activePaths=new Set(result.models.map(m=>m.model));
for(const model of oldModels)if(!activePaths.has(model.model))fs.unlinkSync(path.join(root,'assets',model.model));
for(const [file,sha256]of Object.entries(protectedHashes))assert.equal(hash(path.join(production,file)),sha256,'Protected resource changed: '+file);
const report={baseline:baseline.commit,sourceHashes,protectedCount:Object.keys(protectedHashes).length,protectedHashes,
 oldModels,newModels:newModels.map(({entry})=>({...entry,sha256:hash(path.join(root,'assets',entry.model))})),
 removed:oldModels.filter(m=>!activePaths.has(m.model)).map(m=>m.model),marks:result.levels.find(l=>l.no==='05').marks,
 materialsBefore:original.materials.length,materialsAfter:materials.length};
const evidence=path.join(root,'docs/migration/evidence','story-holo-level5-'+new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(evidence,{recursive:true});fs.writeFileSync(path.join(evidence,'report.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({evidence,protected:report.protectedCount,models:report.newModels.length,removed:report.removed,marks:report.marks}));
