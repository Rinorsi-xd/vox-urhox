const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const feedback=JSON.parse(fs.readFileSync(path.join(root,'assets/Combat/FeedbackSounds.json')));
const paths=['main.lua','app/HangarApp.lua','app/TrialSession.lua','combat/CarUnit.lua','combat/BattleController.lua',
 'combat/BattleObjectives.lua','drive/TrackWorld.lua','story/Mission.lua','salvage/Run.lua',
 'audio/CombatFeedbackAudio.lua','audio/RecoveryMix.lua','ui/SourceDraw.lua','ui/DriveHud.lua','ui/DriveOverlay.lua',
 'ui/DriveFeedback.lua','ui/DriveChrome.lua','ui/MissileHud.lua','ui/MechReticle.lua','ui/ReticleState.lua',
 'ui/ReticleDraw.lua','ui/ReticleGauges.lua','ui/ReticleWeapons.lua','ui/ReticleTarget.lua',
 'ui/CombatFeedbackMotion.lua','ui/CombatFeedbackDraw.lua','Combat/FeedbackSounds.json',
 'Fonts/ChakraPetch-Bold.ttf','Fonts/ChakraPetch-Medium.ttf','Fonts/ChakraPetch-OFL.txt',
 ...fs.readdirSync(path.join(root,'assets/UI/WeaponIcons')).filter(p=>p.endsWith('.png')).map(p=>'UI/WeaponIcons/'+p),
 ...Object.values(feedback.cues).map(c=>c.path)];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 const base='http://127.0.0.1:4206',manifestName=path.basename(prepared.manifest_path);
 const report={build:prepared.source_directory,manifest:manifestName,baseline:baseline.commit,checks:[]};
 assert.equal((await fetch(base+'/outgame.html')).status,200);report.checks.push('preview HTTP 200');
 const response=await fetch(base+'/game-dist/1.0.0/'+manifestName);assert.equal(response.status,200);
 const body=Buffer.from(await response.arrayBuffer());assert.ok(body.equals(fs.readFileSync(prepared.manifest_path)));
 const manifest=JSON.parse(body);report.checks.push('served manifest equals prepared build');
 assert.ok(!manifest.files.some(f=>f.fs_path==='ui/DriveVitals.lua'));report.checks.push('obsolete DriveVitals not packaged');
 for(const name of paths){
  const file=manifest.files.find(f=>f.fs_path===name);assert.ok(file,'missing '+name);
  const filename=file.uuid+'-'+file.hash+file.ext,resource=await fetch(base+'/game-dist/assets/'+filename);
  assert.equal(resource.status,200,name);const bytes=Buffer.from(await resource.arrayBuffer());
  assert.ok(bytes.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',filename))),name+' build content differs');
  assert.ok(bytes.equals(fs.readFileSync(path.join(root,name==='main.lua'||name.endsWith('.lua')?'scripts':'assets',name))),name+' workspace content differs');
  if(name==='main.lua')assert.ok(!bytes.toString().includes('OUTGAME_STATE'),'QA probe in ordinary main');
  if(name.startsWith('UI/WeaponIcons/'))assert.equal(hash(bytes),hash(fs.readFileSync(path.join(baseline.snapshot,'shared/assets/ui/weapon-icons',path.basename(name)))));
  const cue=Object.values(feedback.cues).find(c=>c.path===name);
  if(cue){assert.equal(hash(bytes),cue.sha256);assert.equal(hash(bytes),hash(fs.readFileSync(path.join(baseline.snapshot,cue.source))));}
  report.checks.push(name+' HTTP 200 and verified content');
 }
 report.result='PASS';fs.writeFileSync(path.join(root,'docs/migration/evidence/reticle-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,manifest:manifestName,checks:report.checks.length}));
})().catch(e=>{console.error(e);process.exitCode=1;});
