// Curate an immutable tested runtime without modifying the development index.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const frozen=path.resolve(root,process.argv[2]||'');
if(!frozen.startsWith(path.join(root,'.tmp')+path.sep))throw Error('Expected an immutable .tmp build snapshot');
const prepared=JSON.parse(fs.readFileSync(path.join(frozen,'identity.json')));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
for(const [name,expected]of Object.entries(prepared.identity.scripts)){
 if(hash(fs.readFileSync(path.join(frozen,'scripts',name)))!==expected)throw Error('Frozen Lua changed: '+name);
}
const stage=path.join(root,'.tmp','engine-handoff-'+Date.now());fs.mkdirSync(stage);
for(const name of ['scripts','assets'])fs.cpSync(path.join(frozen,name),path.join(stage,name),{recursive:true});
for(const name of ['README.md','AGENTS.md','.gitignore','preview-hangar.ps1'])fs.copyFileSync(path.join(root,name),path.join(stage,name));
fs.mkdirSync(path.join(stage,'.project'));
for(const name of ['project.json','settings.json','engine.json','resources.json']){
 fs.copyFileSync(path.join(root,'.project',name),path.join(stage,'.project',name));
 const meta=path.join(root,'.project',name+'.meta');if(fs.existsSync(meta))fs.copyFileSync(meta,path.join(stage,'.project',name+'.meta'));
}
fs.mkdirSync(path.join(stage,'tools/migration'),{recursive:true});
for(const item of fs.readdirSync(path.join(root,'tools/migration'),{withFileTypes:true})){
 if(item.isFile()&&/\.(cjs|mjs|js|lua|ps1|py|html|json|meta)$/.test(item.name)
  && !/^source-.*-fixtures\.json$/.test(item.name)&&item.name!=='source-wheel-size.json')
  fs.copyFileSync(path.join(root,'tools/migration',item.name),path.join(stage,'tools/migration',item.name));
}
const documents=['ARCHITECTURE.md',...['CURRENT_EXECUTION.md','ENGINE_TEAM_HANDOFF_2026_10_15.md','outgame-baseline.json',
 'SOUND_LOADING_PROGRESS.md','COMBAT_FIRST_FIRE_2026-10-15.md','COMBAT_ENEMY_GROUND_PROBE_PROGRESS.md',
 'COMBAT_NAV_EDGE_INDEX_PROGRESS.md','MATCH_MAP_BAKE_PROGRESS_2026_10_15.md','MAP_LOAD_HOTSPOTS_2026_10_15.md'].map(f=>'migration/'+f)];
for(const file of documents){const dest=path.join(stage,'docs',file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,'docs',file),dest);}
const diagnostic=path.join(stage,'docs/migration/engine-handoff-706d');fs.mkdirSync(diagnostic,{recursive:true});
fs.copyFileSync(path.join(frozen,'identity.json'),path.join(diagnostic,'build-identity.json'));
const cases={combat:'combat-performance-2026-10-15T13-56-49-208Z',destruction:'destruction-web-2026-10-15T14-01-57-237Z'};
for(const [name,folder]of Object.entries(cases))fs.cpSync(path.join(root,'docs/migration/evidence',folder),path.join(diagnostic,name),{recursive:true});
fs.copyFileSync(path.join(root,'docs/migration/evidence/sound-preparation-20261015T135449902.json'),path.join(diagnostic,'sound-preparation-native.json'));
const files=[];
function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){
 const file=path.join(dir,item.name);if(item.isSymbolicLink())throw Error('Symlink not permitted: '+file);
 if(item.isDirectory())walk(file);else{const bytes=fs.statSync(file).size;if(bytes>=100*1024*1024)throw Error('GitHub size limit: '+file);files.push({path:path.relative(stage,file).replaceAll('\\','/'),bytes,sha256:hash(fs.readFileSync(file))});}
}}
walk(stage);
const inventory={schema:1,testedManifest:path.basename(prepared.manifest_path),scriptFingerprint:prepared.identity.scriptFingerprint,
 sourceCommit:prepared.identity.sourceCommit,files,totalBytes:files.reduce((sum,f)=>sum+f.bytes,0)};
fs.writeFileSync(path.join(diagnostic,'inventory.json'),JSON.stringify(inventory,null,2)+'\n');
const output={stage,manifest:inventory.testedManifest,scriptFingerprint:inventory.scriptFingerprint,files:files.length,totalBytes:inventory.totalBytes};
fs.writeFileSync(path.join(root,'.tmp/engine-handoff-current.json'),JSON.stringify(output,null,2));console.log(JSON.stringify(output));
