const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const resources=['main.lua','ui/InventoryPanel.lua','ui/InventoryChrome.lua','ui/InventoryDetail.lua',
 'ui/InventoryCardMotion.lua','ui/InventoryKeys.lua','ui/InventoryList.lua','ui/InventorySearch.lua','ui/InventoryFeedback.lua','ui/InventoryShadows.lua',
 'ui/BuildHotbar.lua','ui/SourceButtonMotion.lua','render/SceneBackdrop.lua','render/FilterGraph.lua',
 'render/RenderTargetLifetime.lua','Shaders/BLGL/UI/BackdropBlur.shader',
 'UI/Parts/Shadows/card-laser1.png','UI/Parts/Shadows/slot-laser1.png','UI/Parts/Shadows/detail-laser1.png','UI/Parts/Shadows/tile-rest.png'];
(async()=>{
 const base='http://127.0.0.1:4206',name=path.basename(prepared.manifest_path);
 const report={build:path.basename(prepared.source_directory),manifest:name,baseline:baseline.commit,checks:[]};
 const latest=await fetch(base+'/game-dist/latest.json');assert.equal(latest.status,200);
 const tag=await latest.json();assert.equal('manifest-'+tag.client+'.json',name);report.checks.push('latest build identity');
 assert.equal((await fetch(base+'/outgame.html')).status,200);report.checks.push('entry HTTP 200');
 const response=await fetch(base+'/game-dist/'+tag.version+'/'+name);assert.equal(response.status,200);
 const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(prepared.manifest_path)));
 report.checks.push('manifest identity');
 const manifest=JSON.parse(bytes);
 const boot=new Set(manifest.files.filter(f=>(f.groups||[]).some(g=>manifest.preload_groups.includes(g))).map(f=>f.uuid));
 const byUuid=new Map(manifest.files.map(f=>[f.uuid,f]));
 const pending=[...boot];
 for(let i=0;i<pending.length;i++)for(const uuid of byUuid.get(pending[i])?.refs||[]){
  if(!boot.has(uuid)){boot.add(uuid);pending.push(uuid);}
 }
 const masks=manifest.files.filter(f=>f.fs_path?.startsWith('UI/Parts/Shadows/'));
 assert.equal(masks.length,936,'all source alpha masks packaged');
 assert.ok(masks.every(f=>!boot.has(f.uuid)&&!(f.groups||[]).includes('#blocking')),'masks excluded from startup and blocking groups');
 report.checks.push('936 shadow masks load on demand, including transitive boot dependencies');
 for(const resource of resources){
  const file=manifest.files.find(f=>f.fs_path===resource);assert.ok(file,'packaged '+resource);
  const leaf=file.uuid+'-'+file.hash+file.ext;
  const response=await fetch(base+'/game-dist/assets/'+leaf);assert.equal(response.status,200,resource);
  const body=Buffer.from(await response.arrayBuffer());
  assert.ok(body.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',leaf))));
  assert.ok(body.equals(fs.readFileSync(path.join(root,resource.endsWith('.lua')?'scripts':'assets',resource))),'workspace identity '+resource);
  if(resource==='main.lua')assert.ok(!body.includes(Buffer.from('OUTGAME_STATE')),'ordinary entry excludes QA');
  report.checks.push(resource+' HTTP 200 and exact workspace bytes');
 }
 report.result='PASS';fs.writeFileSync(path.join(root,'docs/migration/evidence/inventory-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,manifest:name}));
})().catch(e=>{console.error(e);process.exitCode=1;});
