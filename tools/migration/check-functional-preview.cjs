const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
(async()=>{
 const build=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),'utf8'));
 const manifest=JSON.parse(fs.readFileSync(build.manifest_path,'utf8'));
 const base='http://127.0.0.1:4206',tag=await fetch(base+'/game-dist/latest.json');assert.equal(tag.status,200);
 const latest=await tag.json();assert.equal(`manifest-${latest.client}.json`,path.basename(build.manifest_path));
 const published=await fetch(base+'/game-dist/'+latest.version+'/'+path.basename(build.manifest_path));assert.equal(published.status,200);
 assert.deepEqual(await published.json(),manifest);
 const files=['main.lua','app/LoadingFlow.lua','app/TrialSession.lua','combat/ArenaData.lua','combat/WeaponSystem.lua',
  'story/Mission.lua','story/MissionRules.lua','audio/StoryComms.lua','render/MissionView.lua','ui/MissionHud.lua','ui/MissionResult.lua','ui/MissionFrame.lua',
  'Story/Mission/Level1.json','Story/Mission/Level2.json','Story/Mission/Level3.json','Story/Mission/Level4.json','story/ConvoyRules.lua','story/HoldRules.lua','story/CaptureRules.lua',
  'ui/MissionChoice.lua','Story/Mission/model-1.bin','Shaders/BLGL/Story/MissionBeam.shader','Shaders/BLGL/Story/MissionFlag.shader','Story/Mission/company.png','Story/Mission/graffiti.png',
  'story/Tutorial.lua','story/TutorialRules.lua','ui/TutorialPage.lua','UI/Tutorial.json'];
 const tutorial=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Tutorial.json'),'utf8'));files.push(...Object.values(tutorial.voices).map(v=>v.path));
 const mission=JSON.parse(fs.readFileSync(path.join(root,'assets/Story/Mission/Level1.json'),'utf8'));files.push(Object.values(mission.voices)[0].path);
 const checked=[];
 for(const name of files){
  const file=manifest.files.find(f=>f.fs_path===name);assert.ok(file,'packaged '+name);
  const leaf=file.uuid+'-'+file.hash+file.ext;const response=await fetch(base+'/game-dist/assets/'+leaf);assert.equal(response.status,200,name);
  const body=Buffer.from(await response.arrayBuffer());assert.deepEqual(body,fs.readFileSync(path.join(build.source_directory,'dist/assets',leaf)),name+' matches tested build');
  if(name==='main.lua')assert.ok(!body.includes(Buffer.from('OUTGAME_STATE')),'ordinary preview excludes QA probe');
  checked.push({path:name,status:response.status,bytes:body.length});
 }
 const entry=await fetch(base+'/outgame.html');assert.equal(entry.status,200);
 fs.writeFileSync(path.join(root,'docs/migration/evidence/functional-preview-http.json'),JSON.stringify({result:'PASS',build:build.source_directory,manifest:path.basename(build.manifest_path),ordinaryProbe:false,files:checked},null,2));
 console.log(JSON.stringify({result:'PASS',files:checked.length,manifest:path.basename(build.manifest_path)}));
})().catch(error=>{console.error(error);process.exitCode=1;});
