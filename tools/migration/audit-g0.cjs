// Verify the immutable Git snapshot and inventory source callbacks without executing it.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot,out=path.join(root,'docs/migration/evidence/full-parity',baseline.commit.slice(0,12),'G0');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const git=(cwd,...args)=>cp.execFileSync('git',args,{cwd,encoding:'utf8',windowsHide:true}).trim();
const write=(name,data)=>fs.writeFileSync(path.join(out,name),JSON.stringify(data,null,2));
fs.mkdirSync(out,{recursive:true});
const latest=git(baseline.source,'rev-parse',baseline.branch);
if(latest!==baseline.commit)throw Error('Source branch moved. Freeze its latest commit again before building.');
const changed=[],missing=[];let bytes=0;
for(const [name,expected]of Object.entries(baseline.files)){
 const file=path.join(source,name);
 if(!fs.existsSync(file)){missing.push(name);continue;}
 const data=fs.readFileSync(file);bytes+=data.length;
 if(hash(data)!==expected.sha256||data.length!==expected.bytes)changed.push(name);
}
if(changed.length||missing.length)throw Error('Frozen source mismatch: '+JSON.stringify({changed,missing}));
const previousPath=path.join(root,'docs/migration/baselines/0bf472cbae08f8230102f5bac89ca157d52a2d90.json');
const previous=JSON.parse(fs.readFileSync(previousPath));
const delta={added:[],deleted:[],changed:[]};
for(const [name,item]of Object.entries(baseline.files)){
 if(!previous.files[name])delta.added.push(name);
 else if(previous.files[name].sha256!==item.sha256)delta.changed.push(name);
}
for(const name of Object.keys(previous.files))if(!baseline.files[name])delta.deleted.push(name);
const parts=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/parts-manifest.json')));
const partSources=Object.entries(parts.sourceHashes||{}).map(([name,oldHash])=>({name,status:!baseline.files[name]?'MISSING':baseline.files[name].sha256===oldHash?'UNCHANGED':'CHANGED',oldHash,currentHash:baseline.files[name]?.sha256}));
const staging=process.argv[2]&&path.resolve(process.argv[2]);
let derived=false;
if(staging){
 const manifest=JSON.parse(fs.readFileSync(path.join(staging,'manifest.json')));
 derived={staging,source:manifest.source,changed:[],missing:[],equal:0,driveGeometry:false};
 for(const [name,record]of Object.entries(manifest.files)){
  const target=path.join(root,'assets/Parts',name);
  if(!fs.existsSync(target))derived.missing.push(name);
  else if(hash(fs.readFileSync(target))!==record.sha256)derived.changed.push(name);
  else derived.equal++;
 }
 derived.driveGeometry=hash(fs.readFileSync(path.join(root,'assets/Drive/Geometry.json')))===manifest.driveGeometry.sha256;
 const differences=[];
 function changes(a,b,p='',result=[]){
  if(JSON.stringify(a)===JSON.stringify(b))return result;
  if(a&&b&&typeof a==='object'&&typeof b==='object'){
   for(const key of new Set([...Object.keys(a),...Object.keys(b)]))changes(a[key],b[key],p+'/'+key,result);
  }else result.push({path:p,before:a,after:b});
  return result;
 }
 for(const name of derived.changed.filter(n=>n.endsWith('.json'))){
  const before=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts',name))),after=JSON.parse(fs.readFileSync(path.join(staging,name)));
  differences.push({file:'Parts/'+name,status:'NOT_APPLIED',changes:changes(before,after)});
 }
 const models=derived.missing.map(name=>({file:'Parts/'+name,sha256:manifest.files[name].sha256,bytes:manifest.files[name].bytes,
  referencedBy:manifest.parts.filter(part=>fs.readFileSync(path.join(staging,part.path.replace(/^Parts\//,'')),'utf8').includes('Parts/'+name)).map(p=>p.id),status:'NOT_APPLIED'}));
 write('derived-delta.json',{sourceCommit:baseline.commit,staging,converter:{path:'tools/migration/export-parts.cjs',sha256:hash(fs.readFileSync(path.join(__dirname,'export-parts.cjs')))},
  sourceDependencies:Object.entries(manifest.sourceHashes).map(([file,sha256])=>({file,sha256,baselineMatches:baseline.files[file]?.sha256===sha256})),
  equal:derived.equal,differences,missingModels:models,driveGeometryEqual:derived.driveGeometry,
  acceptance:'Source traceability only. Not applied, not model/physics/visual acceptance.'});
}
// Static candidates are deliberately not reported as dynamically accepted entries.
const callbacks=[],keys=[],urls=[],resources=[];
const family=name=>/\/story\/|story|intro|tutorial/i.test(name)?'S':/endless/i.test(name)?'N':/salvage|warehouse/i.test(name)?'L':/\/build\/|\/controls\/|inventory/i.test(name)?'E':/\/parts\//.test(name)?'R':/\/drive\//.test(name)?'P':/\/combat\//.test(name)?'W':/\/battle\/|\/ai\//.test(name)?'B':/\/audio\//.test(name)?'A':/\/ui\//.test(name)?'H':/\/render\//.test(name)?'Q':'M';
const scanFiles=Object.keys(baseline.files).filter(name=>/^(shared|three\/src)\/.+\.(js|css|html)$/.test(name)&&!name.includes('/assets/'));
for(const name of scanFiles){
 const text=fs.readFileSync(path.join(source,name),'utf8'),lines=text.split(/\r?\n/);
 lines.forEach((line,i)=>{
  for(const m of line.matchAll(/\b(on[A-Z][A-Za-z0-9_]*)\s*[:=]/g))callbacks.push({file:name,line:i+1,name:m[1],group:family(name),status:'STATIC_CANDIDATE',snippet:line.trim().slice(0,300)});
  if(/addEventListener\(\s*['"](?:key|mouse|wheel|pointer|touch|blur|focus)/.test(line)||/\b(?:KEY_|Key[A-Z]|Arrow(?:Up|Down|Left|Right)|key\s*===|code\s*===)/.test(line))keys.push({file:name,line:i+1,group:family(name),snippet:line.trim().slice(0,300)});
  if(/URLSearchParams|location\.search|query\.get\(|benchQuery\.get\(/.test(line))urls.push({file:name,line:i+1,group:family(name),snippet:line.trim().slice(0,400)});
  if(/new URL\(|\.glb['"]|\.png['"]|\.wav['"]|\.mp3['"]|\.otf['"]|\.ttf['"]/.test(line))resources.push({file:name,line:i+1,group:family(name),snippet:line.trim().slice(0,400)});
 });
}
const entries=[
 ['home','首页/车库/车位管理','shared/ui/home.js','scripts/ui/GarageHud.lua','H01,H02','PARTIAL'],
 ['build','改装/输入/零件库','shared/build/editor.js','scripts/app/BuildSession.lua','E01-E10','PARTIAL'],
 ['livery','涂装','shared/ui/liveryPanel.js','scripts/ui/LiveryPage.lua','H04','PARTIAL'],
 ['workshop','官方预制车工坊','shared/ui/workshop.js','scripts/ui/Workshop.lua','H03','PARTIAL'],
 ['shop','普通商店占位','shared/ui/home.js','scripts/ui/GarageHud.lua','H07','SOURCE_PLACEHOLDER'],
 ['music','音乐盒与声音设置','shared/ui/musicBox.js','scripts/ui/MusicBox.lua','H05,A07','PARTIAL'],
 ['trial','试车/节足练习场','three/src/drive/testDrive.js','scripts/app/TrialSession.lua','C07,M01,S03','PARTIAL'],
 ['crater','坠舰陨坑探索/debug','three/src/drive/testDrive.js','scripts/app/DriveMaps.lua','M01-M07','PARTIAL'],
 ['elimination','歼灭3V3','three/src/battle/matchSession.js','scripts/combat/BattleController.lua','B03','PARTIAL'],
 ['conquest','争夺4V4','three/src/battle/matchSession.js','scripts/combat/ConquestRules.lua','B04','PARTIAL'],
 ['escort','推车4V4','three/src/battle/matchSession.js','scripts/combat/EscortRules.lua','B05','PARTIAL'],
 ['story','剧情选择与前四关','shared/ui/storyPage.js','scripts/ui/StoryPage.lua','S04,S05','PARTIAL'],
 ['story5','第五关/Boss','three/src/battle/storyBoss.js',false,'S06','MISSING'],
 ['epilogue','最新片尾','three/src/battle/storyEpilogue.js',false,'S07','MISSING'],
 ['intro','开篇?intro/重播按钮','three/src/main.js',false,'S01','EMPTY_TARGET_CALLBACK'],
 ['tutorial','新手引导两路线','shared/ui/tutorial.js','scripts/story/Tutorial.lua','S02','KNOWN_FAIL'],
 ['endless','无尽含局内改装','three/src/battle/endlessSession.js',false,'N01-N07','MISSING'],
 ['salvage','打捞大厅/仓库/行动/交易','shared/ui/salvageHub.js','scripts/salvage/Run.lua','L01-L08','PARTIAL'],
 ['settings','帮助/暂停/存档/导入/分享','shared/ui/shell.js','scripts/ui/DialogHost.lua','U06,D01-D08','PARTIAL'],
 ['bench-debug','基准/调试/研究URL入口','three/src/main.js',false,'Z05,Q06','INVENTORIED_NOT_GAMEPLAY_PARITY'],
].map(([id,label,from,to,acceptance,status])=>({id,label,source:from,sourceExists:fs.existsSync(path.join(source,from)),target:to,targetExists:!!to&&fs.existsSync(path.join(root,to)),acceptance,status}));
const issues=entries.filter(e=>!e.sourceExists||e.target&&!e.targetExists);
function anchor(base,file,needle){
 const lines=fs.readFileSync(path.join(base,file),'utf8').split(/\r?\n/),index=lines.findIndex(line=>line.includes(needle));
 if(index<0)throw Error('Entry evidence changed: '+file+' '+needle);
 return {file,line:index+1,snippet:lines[index].trim(),sha256:hash(fs.readFileSync(path.join(base,file)))};
}
const routeFindings=[
 {id:'salvage-key',acceptance:'Z05,L01',status:'STATIC_MISMATCH_NOT_FIXED',
  source:anchor(source,'shared/ui/shell.js',"case 'KeyG': if ( this.home.tab === 'hangar' ) this.enterSalvage()"),
  target:anchor(root,'scripts/app/HangarApp.lua','if input:GetKeyPress(KEY_G) then self:ToggleGallery()'),
  finding:'Source home G enters salvage; target home G toggles a legacy part gallery. Context guards still require runtime comparison.'},
 {id:'intro-replay',acceptance:'Z05,S01',status:'EMPTY_TARGET_CALLBACK',
  source:anchor(source,'three/src/main.js',"if ( new URLSearchParams( location.search ).has( 'intro' ) ) {"),
  target:anchor(root,'scripts/ui/GarageHud.lua',"AddButton(s.nav,'intro'"),
  finding:'Source ?intro starts the opening sequence; target replay button callback is empty.'},
 {id:'endless-url',acceptance:'Z05,N01-N07',status:'MISSING_TARGET',
  source:anchor(source,'three/src/main.js',"if ( driveTo === 'endless' )"),target:false,
  finding:'Source ?drive=endless is reachable through the startup query, even without a home button.'},
 {id:'practice-name',acceptance:'Z05,M01,S03',status:'NAME_UNRESOLVED',
  source:anchor(source,'shared/ui/home.js',"const PRACTICE ="),
  target:anchor(root,'scripts/app/DriveMaps.lua',"trial={id='trial'"),
  finding:'Source exposes proving ground and free roam. No literal 考场 found in frozen JS/HTML/MD; this does not prove a separate exam feature is absent.'},
];
const mapDependencies=[];
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
if(prepared.identity.sourceCommit!==baseline.commit)throw Error('Prepared package uses a different source baseline');
const packageManifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
for(const [id,scene,list,routes]of [
 ['trial','Scenes/TrialTrack.xml','Track/Resources.json',['trial']],
 ['crater','Scenes/Crater.xml','Crater/Resources.json',['crater','elimination','conquest','escort','story1','story2','story3','story4']],
 ['salvage','Scenes/Salvage.xml','Salvage/Resources.json',['salvage']],
]){
 const data=fs.readFileSync(path.join(root,'assets',list)),paths=JSON.parse(data);
 mapDependencies.push({id,scene,list,listSha256:hash(data),routes,method:'Explicit target download list, not an exhaustive transitive dependency graph.',
  resources:paths.map(file=>{
   const target=path.join(root,'assets',file),local=fs.existsSync(target),packaged=packageManifest.files.find(f=>f.fs_path===file);
   return {file,local,...(local?{sha256:hash(fs.readFileSync(target)),bytes:fs.statSync(target).size}:
    {resolution:packaged?.source?'ENGINE_MANIFEST_REFERENCE':'NOT_LOCAL_REQUIRES_MANIFEST_CHECK',source:packaged?.source})};
  })});
}
write('map-dependencies.json',{sourceCommit:baseline.commit,manifest:path.basename(prepared.manifest_path),manifestSha256:hash(fs.readFileSync(prepared.manifest_path)),maps:mapDependencies});
const sourceByHash=new Map();
for(const [name,record]of Object.entries(baseline.files)){
 const list=sourceByHash.get(record.sha256)||[];list.push(name);sourceByHash.set(record.sha256,list);
}
const staged=staging&&JSON.parse(fs.readFileSync(path.join(staging,'manifest.json')));
// Historical export records establish traceability, not an independent rebuild.
// Recheck both output bytes and every recorded input against the frozen baseline.
const recorded=new Map(),provenance=[];
function register(report,converter,inputs,outputs){
 const data=fs.readFileSync(path.join(root,report));
 const dependencies=Object.entries(inputs).map(([file,value])=>{
  const sha256=typeof value==='string'?value:value.sha256;
  return {file,sha256,baselineMatches:baseline.files[file]?.sha256===sha256};
 });
 const inputStatus=dependencies.length&&dependencies.every(d=>d.baselineMatches)?'BASELINE_INPUTS_MATCH':'INPUT_DRIFT_OR_UNRECORDED';
 const group={report,reportSha256:hash(data),converter,inputStatus,dependencies,outputs:[]};
 for(const [file,sha256]of outputs){
  if(!sha256)throw Error('Missing recorded output hash: '+report+' '+file);
  const name=file.replace(/^assets\//,''),target=path.join(root,'assets',name);
  const item={file:name,expectedSha256:sha256,outputMatches:fs.existsSync(target)&&hash(fs.readFileSync(target))===sha256};
  group.outputs.push(item);
  recorded.set(name,{report,reportSha256:group.reportSha256,converter,inputStatus,expectedSha256:sha256,outputMatches:item.outputMatches});
 }
 provenance.push(group);
}
for(const [name,converter]of [['music-box','import-music-box.cjs'],['livery','import-livery.cjs']]){
 const report='docs/migration/'+name+'-source.json',data=JSON.parse(fs.readFileSync(path.join(root,report)));
 const inputs={...data.sourceFiles};
 for(const file of data.files)if(file.source_sha256)inputs[file.source]=file.source_sha256;
 register(report,'tools/migration/'+converter,inputs,[...data.files.map(f=>[f.target,f.sha256]),[data.catalog.path,data.catalog.sha256]]);
}
{
 const report='docs/migration/joined-shapes-source.json',data=JSON.parse(fs.readFileSync(path.join(root,report)));
 register(report,'tools/migration/export-joined-shapes.mjs',data.sources,[[data.asset,data.sha256]]);
}
{
 const report='docs/migration/evidence/source-thumbnails-import.json',data=JSON.parse(fs.readFileSync(path.join(root,report)));
 register(report,'tools/migration/export-source-thumbnails.mjs + import-source-thumbnails.py',data.sourceFiles,
  data.images.map(f=>['UI/Parts/'+f.id+'.png',f.sha256]));
}
{
 const report='docs/migration/evidence/industrial-font-import.json',data=JSON.parse(fs.readFileSync(path.join(root,report)));
 register(report,'tools/migration/import-industrial-font.py',{'shared/fonts/AlimamaShuHeiTi/AlimamaShuHeiTi-Bold.woff2':data.source_sha256},
  [['Fonts/VoxIndustrial-Bold.otf',data.output_sha256]]);
}
write('recorded-provenance.json',{sourceCommit:baseline.commit,method:'Verify existing export records. Matching hashes do not establish converter reproducibility, visual parity or complete dependencies.',groups:provenance});
const assets=[];
for(const entry of fs.readdirSync(path.join(root,'assets'),{recursive:true,withFileTypes:true})){
 if(!entry.isFile()||entry.name.endsWith('.meta'))continue;
 const file=path.join(entry.parentPath,entry.name),name=path.relative(path.join(root,'assets'),file).replaceAll('\\','/');
 const content=fs.readFileSync(file),sha256=hash(content),matches=sourceByHash.get(sha256)||[];
 const derivedRecord=staged&&staged.files[name.replace(/^Parts\//,'')];
 const isPart=name.startsWith('Parts/')&&derivedRecord;
 const prior=recorded.get(name);
 const status=matches.length?'EXACT_SOURCE_BYTES':isPart?(derivedRecord.sha256===sha256?'DERIVED_BASELINE_MATCH':'DERIVED_BASELINE_DIFF'):
  prior?(prior.outputMatches?'RECORDED_OUTPUT_MATCH':'RECORDED_OUTPUT_DIFF'):'UNMAPPED';
 assets.push({file:name,sha256,bytes:content.length,status,source:matches,...(isPart?{converter:'tools/migration/export-parts.cjs',expectedSha256:derivedRecord.sha256}:{}),...(prior?{recordedProvenance:prior}:{})});
}
write('asset-ledger.json',{sourceCommit:baseline.commit,method:'Exact source bytes, independently staged part-converter output, or explicitly labelled historical export records. Records are not independent rebuilds. Other resources remain UNMAPPED.',
 counts:assets.reduce((a,r)=>(a[r.status]=(a[r.status]||0)+1,a),{}),assets});
write('baseline.json',{result:'PASS',branch:baseline.branch,commit:baseline.commit,contentSha256:baseline.contentSha256,files:Object.keys(baseline.files).length,bytes,snapshot:source,targetCommit:git(root,'rev-parse','HEAD'),targetBranch:git(root,'branch','--show-current'),targetStatus:git(root,'status','--porcelain=v1'),sourceDelta:delta,partSources,derived});
write('entry-ledger.json',{method:'Explicit entries and reviewed route findings plus textual candidates. Text scanning does not prove completeness or dynamic reachability.',entries,pathIssues:issues,routeFindings,callbacks,keys,urls,resourceCandidates:resources});
console.log(JSON.stringify({out,baseline:'PASS',commit:baseline.commit,delta,partSources:partSources.reduce((a,e)=>(a[e.status]=(a[e.status]||0)+1,a),{}),derived:derived&&{equal:derived.equal,changed:derived.changed.length,missing:derived.missing.length},entries:entries.length,callbackCandidates:callbacks.length,keyCandidates:keys.length,urlCandidates:urls.length,pathIssues:issues},null,2));
