const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const out=path.join(root,'docs/migration/evidence/full-parity',prepared.identity.sourceCommit.slice(0,12),'G0',
 ...(process.argv.includes('--batch')?[path.basename(prepared.manifest_path,'.json')]:[]));
const digest=data=>crypto.createHash('sha256').update(data).digest('hex');
const git=(...args)=>cp.execFileSync('git',args,{cwd:root,windowsHide:true,encoding:'utf8'}).trim();
fs.mkdirSync(out,{recursive:true});
const mismatches=[];
for(const [name,hash]of Object.entries(prepared.identity.scripts)){
 const file=path.join(root,'scripts',name);
 if(!fs.existsSync(file)||digest(fs.readFileSync(file))!==hash)mismatches.push(name);
}
if(mismatches.length)throw Error('Live scripts differ from tested build: '+mismatches.join(', '));
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const identity={...prepared.identity,manifest:path.basename(prepared.manifest_path),manifestSha256:digest(fs.readFileSync(prepared.manifest_path)),
 capturedAt:new Date().toISOString(),targetBranch:git('branch','--show-current'),status:git('status','--porcelain=v1'),
 trackedRuntimeDiffSha256:digest(cp.execFileSync('git',['diff','HEAD','--binary','--','scripts','assets','.project'],{cwd:root,windowsHide:true})),
 scriptCheck:'PASS',engineSources:prepared.engineSources};
fs.writeFileSync(path.join(out,'build-identity.json'),JSON.stringify(identity,null,2));
fs.copyFileSync(prepared.manifest_path,path.join(out,path.basename(prepared.manifest_path)));
fs.copyFileSync(path.join(root,'docs/migration/evidence/cloud-storage.json'),path.join(out,'cloud-storage.json'));
const files=manifest.files,inventory={totalFiles:files.length,fontBytes:files.filter(f=>/^Fonts\//.test(f.fs_path||'')).reduce((n,f)=>n+(f.size||0),0),
 blockingFiles:files.filter(f=>f.groups?.includes('#blocking')).length,blockingMdl:files.filter(f=>f.ext==='.mdl'&&f.groups?.includes('#blocking')).length,
 excludedSourceMeshesInPackage:files.filter(f=>/^Salvage\/model-/.test(f.fs_path||'')).length,
 preloadGroups:manifest.preload_groups,engineSources:prepared.engineSources};
fs.writeFileSync(path.join(out,'package-inventory.json'),JSON.stringify(inventory,null,2));
if(process.env.VOX_G0_EDITOR_LUA_LOG){
 const file=process.env.VOX_G0_EDITOR_LUA_LOG,data=fs.readFileSync(file);
 const lines=data.toString('utf8').split(/\r?\n/).filter(l=>/Bound authored scene|Four source canvases|\[HangarApp\] Ready/.test(l));
 fs.writeFileSync(path.join(out,'editor-boot.json'),JSON.stringify({log:file,sha256:digest(data),lines,
  result:lines.some(l=>l.includes('[HangarApp] Ready'))?'BOOT_READY':'NOT_READY',
  visual:'NOT_RUN',input:'NOT_RUN',note:'PIE startup logs only; does not establish complete native interaction acceptance.'},null,2));
}
console.log(JSON.stringify({out,scriptCheck:'PASS',inventory}));
