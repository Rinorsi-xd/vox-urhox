const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const paths=['main.lua','app/BuildSession.lua','app/TrialSession.lua','construction/Rotors.lua',
 'construction/TurretRange.lua','construction/BuildEditor.lua','construction/BlueprintDiagnostics.lua',
 'drive/RotorMotion.lua','drive/Vehicle.lua','drive/VehicleSpec.lua','drive/VehicleSetup.lua',
 'drive/RaySuspension.lua','controls/DriveInput.lua','parts/Dependencies.lua','render/RotorView.lua',
 'render/DriveView.lua','render/VehicleView.lua','render/ActuatorView.lua','render/BuildHighlights.lua',
 'render/LiveryLayer.lua','combat/WeaponSystem.lua','combat/CarUnit.lua','combat/VehicleRay.lua',
 'combat/BattleController.lua','story/Mission.lua','salvage/Run.lua','ui/RotorHud.lua','ui/BuildHud.lua',
 'ui/SourceDraw.lua','ui/Workshop.lua','ui/WorkshopPaint.lua','ui/WorkshopButton.lua','ui/WorkshopCard.lua',
 'Parts/Rigs/rotor.json','Parts/Rigs/rotorSpin.json','Parts/Rigs/rotorStep.json','Parts/Dependencies.json'];
(async()=>{
 const base='http://127.0.0.1:4206',name=path.basename(prepared.manifest_path);
 const report={build:prepared.source_directory,manifest:name,baseline:baseline.commit,checks:[]};
 const latest=await fetch(base+'/game-dist/latest.json');assert.equal(latest.status,200);
 const tag=await latest.json();assert.equal('manifest-'+tag.client+'.json',name);report.checks.push('latest identifies prepared build');
 assert.equal((await fetch(base+'/outgame.html')).status,200);report.checks.push('entry HTTP 200');
 const response=await fetch(base+'/game-dist/'+tag.version+'/'+name);assert.equal(response.status,200);
 const body=Buffer.from(await response.arrayBuffer());assert.ok(body.equals(fs.readFileSync(prepared.manifest_path)));report.checks.push('manifest bytes equal prepared build');
 const manifest=JSON.parse(body);
 for(const resource of paths){
  const f=manifest.files.find(f=>f.fs_path===resource);assert.ok(f,'packaged '+resource);
  const leaf=f.uuid+'-'+f.hash+f.ext,r=await fetch(base+'/game-dist/assets/'+leaf);assert.equal(r.status,200,resource);
  const bytes=Buffer.from(await r.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',leaf))));
  assert.ok(bytes.equals(fs.readFileSync(path.join(root,resource.endsWith('.lua')?'scripts':'assets',resource))),'workspace identity '+resource);
  if(resource==='main.lua')assert.ok(!bytes.includes(Buffer.from('OUTGAME_STATE')),'ordinary main excludes QA probe');
  report.checks.push(resource+' HTTP 200 and verified bytes');
 }
 report.result='PASS';fs.writeFileSync(path.join(root,'docs/migration/evidence/rotors-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,manifest:name}));
})().catch(e=>{console.error(e);process.exitCode=1;});
