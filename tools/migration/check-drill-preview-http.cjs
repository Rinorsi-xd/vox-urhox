const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const paths=['main.lua','app/TrialSession.lua','combat/DrillAttack.lua','combat/WeaponSystem.lua','combat/CarUnit.lua',
 'combat/BattleController.lua','combat/BattleObjectives.lua','physics/DrillSweep.lua','physics/Body.lua','physics/Space.lua',
 'drive/Vehicle.lua','drive/TrackWorld.lua','drive/CraterWorld.lua','drive/SalvageWorld.lua','parts/Dependencies.lua',
 'render/DrillEffects.lua','render/DrillSpeed.lua','render/CombatEffects.lua','render/CombatView.lua','render/LegView.lua',
 'salvage/Run.lua','story/Mission.lua','ui/ReticleState.lua','ui/ReticleWeapons.lua','ui/DriveHud.lua',
 'Combat/Weapons.json','Combat/Drills.json','Shaders/BLGL/Combat/DrillSpeed.shader','UI/WeaponIcons/tianyuanDrill.png'];
(async()=>{
 const base='http://127.0.0.1:4206',name=path.basename(prepared.manifest_path);
 const report={build:prepared.source_directory,manifest:name,checks:[]};
 const latest=await fetch(base+'/game-dist/latest.json');assert.equal(latest.status,200);
 const tag=await latest.json();assert.equal('manifest-'+tag.client+'.json',name);report.checks.push('latest identifies tested build');
 assert.equal((await fetch(base+'/outgame.html')).status,200);report.checks.push('entry HTTP 200');
 const response=await fetch(base+'/game-dist/'+tag.version+'/'+name);assert.equal(response.status,200);
 const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(prepared.manifest_path)));
 const manifest=JSON.parse(bytes);report.checks.push('manifest equals tested build');
 for(const resource of paths){
  const f=manifest.files.find(f=>f.fs_path===resource);assert.ok(f,'packaged '+resource);
  const leaf=f.uuid+'-'+f.hash+f.ext,r=await fetch(base+'/game-dist/assets/'+leaf);assert.equal(r.status,200,resource);
  const body=Buffer.from(await r.arrayBuffer());assert.ok(body.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',leaf))));
  assert.ok(body.equals(fs.readFileSync(path.join(root,resource.endsWith('.lua')?'scripts':'assets',resource))),'workspace identity '+resource);
  if(resource==='main.lua')assert.ok(!body.includes(Buffer.from('OUTGAME_STATE')),'ordinary main excludes QA probe');
  report.checks.push(resource+' HTTP 200 and exact workspace/build bytes');
 }
 const stats=JSON.parse(fs.readFileSync(path.join(root,'assets/Combat/Weapons.json'))).stats;
 assert.equal(Object.keys(stats).length,17);assert.ok(stats.tianyuanDrill.drill&&stats.fuyuanDrill.drill);
 report.checks.push('all 17 source weapon types packaged, including both drills');
 assert.ok(!manifest.files.some(f=>/^Salvage\/model-/.test(f.fs_path)));report.checks.push('no obsolete salvage model payloads');
 report.result='PASS';fs.writeFileSync(path.join(root,'docs/migration/evidence/drill-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,manifest:name,checks:report.checks.length}));
})().catch(e=>{console.error(e);process.exitCode=1;});
