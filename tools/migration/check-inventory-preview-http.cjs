const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const resources=['main.lua','ui/InventoryPanel.lua','ui/InventoryChrome.lua','ui/InventoryDetail.lua',
 'ui/InventoryCardMotion.lua','ui/InventoryKeys.lua','ui/InventoryList.lua','ui/InventorySearch.lua',
 'ui/BuildHotbar.lua','ui/SourceButtonMotion.lua','render/SceneBackdrop.lua','render/FilterGraph.lua',
 'render/RenderTargetLifetime.lua','Shaders/BLGL/UI/BackdropBlur.shader'];
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
