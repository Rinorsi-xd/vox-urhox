const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
(async()=>{
 const base='http://127.0.0.1:4206',name=path.basename(prepared.manifest_path),checks=[];
 const tag=await (await fetch(base+'/game-dist/latest.json')).json();assert.equal('manifest-'+tag.client+'.json',name);checks.push('ordinary latest identifies validated build');
 const response=await fetch(base+'/game-dist/'+tag.version+'/'+name);assert.equal(response.status,200);const bytes=Buffer.from(await response.arrayBuffer());
 assert.ok(bytes.equals(fs.readFileSync(prepared.manifest_path)));const manifest=JSON.parse(bytes);checks.push('ordinary manifest exact identity');
 assert.equal((await fetch(base+'/outgame.html')).status,200);checks.push('entry HTTP 200');
 const scripts=['main.lua','app/MvpShow.lua','app/TrialSession.lua','combat/MvpMotion.lua','combat/BattleController.lua','render/MvpStage.lua','render/MvpBanner.lua','audio/MvpMusic.lua','ui/MvpShow.lua','ui/DriveHud.lua','ui/MatchHud.lua','ui/MatchScoreboard.lua','ui/MatchResultButton.lua'];
 const assets=manifest.files.filter(f=>f.fs_path?.startsWith('Mvp/')||f.fs_path?.startsWith('Shaders/BLGL/Mvp/')).map(f=>f.fs_path);
 for(const resource of [...scripts,...assets]){
  const item=manifest.files.find(f=>f.fs_path===resource);assert.ok(item,'packaged '+resource);const leaf=item.uuid+'-'+item.hash+item.ext;
  const r=await fetch(base+'/game-dist/assets/'+leaf);assert.equal(r.status,200,resource);const body=Buffer.from(await r.arrayBuffer());
  assert.ok(body.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',leaf))),'build bytes '+resource);
  const local=path.join(root,scripts.includes(resource)?'scripts':'assets',resource);
  if(fs.existsSync(local))assert.ok(body.equals(fs.readFileSync(local)),'workspace bytes '+resource);
  if(resource==='main.lua')assert.ok(!body.includes(Buffer.from('OUTGAME_STATE')),'ordinary build has no probe');
  checks.push(resource+' HTTP 200 and exact bytes');
 }
 const streamed=manifest.files.filter(f=>f.fs_path?.startsWith('Mvp/')&&(f.ext==='.bin'||f.fs_path==='Mvp/music.mp3'||f.ext==='.wav'));
 assert.ok(streamed.length>=27);for(const item of streamed)assert.ok(!(item.groups||[]).some(g=>g==='boot'||g==='boot#refs'||g==='#blocking'),item.fs_path+' streams on demand');
 checks.push('MVP models music and cues are outside blocking boot resources');
 assert.ok(!manifest.files.some(f=>/check-mvp|probe-outgame|source-mvp\.json/.test(f.fs_path)));checks.push('QA fixtures excluded');
 const report={result:'PASS',build:prepared.source_directory,manifest:name,checks,streamedBytes:streamed.reduce((n,f)=>n+f.size,0)};
 fs.writeFileSync(path.join(root,'docs/migration/evidence/mvp-preview-http.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,manifest:name,checks:checks.length,streamedBytes:report.streamedBytes}));
})().catch(e=>{console.error(e);process.exitCode=1;});
