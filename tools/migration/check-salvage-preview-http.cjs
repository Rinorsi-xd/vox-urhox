const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const base='http://127.0.0.1:4206';
const paths=['main.lua','app/DriveMaps.lua','app/HangarApp.lua','app/LoadingFlow.lua','app/TrialSession.lua','app/SalvageLobby.lua',
 'ui/SalvagePage.lua','ui/SalvageRunHud.lua','ui/SalvageLootMotion.lua','ui/SourceButton.lua','ui/SourceButtonMotion.lua','ui/TouchDriveControls.lua',
 'salvage/Run.lua','salvage/RunRules.lua','salvage/Loot.lua','salvage/Director.lua','salvage/Drops.lua',
 'drive/SalvageWorld.lua','drive/SalvagePhysics.lua','scene/SalvageAssets.lua','render/SalvageView.lua','render/WarehouseEffects.lua',
 'Scenes/Salvage.xml','Salvage/Resources.json','Salvage/RunManifest.json','Salvage/Gameplay.json','Salvage/RunData.json','Salvage/Physics.json',
 'Salvage/Height.bin','Salvage/GroundBaked.png','Salvage/run-model-0.bin','Warehouse/Effects.json','Warehouse/Manifest.json','scene/Warehouse.lua','scene/WarehouseMotion.lua',
 'Shaders/BLGL/Outgame/Ground.shader','Shaders/BLGL/Warehouse/Dust.shader','Shaders/BLGL/Warehouse/Holo.shader',
 'salvage/Cinematics.lua','salvage/CineMotion.lua','ui/SalvageCinematics.lua','render/SalvageCinematics.lua',
 'render/SalvageCineDust.lua','render/CineDeathFilter.lua','SalvageCine/Manifest.json',
 'SalvageCine/smoke-0.png','SalvageCine/smoke-1.png',
 'Shaders/BLGL/Salvage/CineFlame.shader','Shaders/BLGL/Salvage/CineDust.shader','Shaders/BLGL/Salvage/CineDeath.shader'];
(async()=>{
 const manifestName=path.basename(prepared.manifest_path),report={build:prepared.source_directory,manifest:manifestName,checks:[]};
 const page=await fetch(base+'/outgame.html');assert.equal(page.status,200);report.checks.push('preview entry HTTP 200');
 const response=await fetch(base+'/game-dist/1.0.0/'+manifestName);assert.equal(response.status,200);
 const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(prepared.manifest_path)),'served manifest differs');
 const manifest=JSON.parse(bytes);report.checks.push('served manifest equals prepared build');
 for(const item of JSON.parse(fs.readFileSync(path.join(root,'assets/SalvageCine/Manifest.json'))).models)paths.push(item.model);
 for(const file of manifest.files.filter(f=>/^SalvageCine\/.*\.(bin|png)$/.test(f.fs_path))){
  assert.ok(!(file.groups||[]).some(g=>g==='boot'||g==='#blocking'),file.fs_path+' unexpectedly blocks startup');
 }
 report.checks.push('cinematic model and smoke payloads excluded from startup/blocking groups');
 assert.ok(!manifest.files.some(f=>/^Salvage\/model-/.test(f.fs_path)),'stale salvage models packaged');
 report.checks.push('no stale salvage models in release manifest');
 for(const name of paths){
  const file=manifest.files.find(f=>f.fs_path===name);assert.ok(file,'missing '+name);
  const filename=file.uuid+'-'+file.hash+file.ext;
  const resource=await fetch(base+'/game-dist/assets/'+filename);assert.equal(resource.status,200,name);
  const body=Buffer.from(await resource.arrayBuffer());
  assert.ok(body.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',filename))),name+' content differs');
  if(name==='main.lua')assert.ok(!body.toString().includes('OUTGAME_STATE'),'QA probe in ordinary preview');
  report.checks.push(name+' HTTP 200 and exact build content');
 }
 report.result='PASS';fs.writeFileSync(path.join(root,'docs/migration/evidence/salvage-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,manifest:manifestName,checks:report.checks.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});
