const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const resources=['main.lua','app/BuildSession.lua','app/TrialSession.lua','controls/BuildCamera.lua','controls/BuildInput.lua',
 'controls/FreeFlight.lua','controls/TouchGestures.lua','ui/BuildHud.lua','ui/BuildOverlay.lua','ui/DriveHud.lua',
 'ui/MatchHud.lua','ui/SourceTouchLayout.lua','ui/SourceTouchWidgets.lua','ui/SourceTouchOverlay.lua',
 'ui/TouchBuildControls.lua','ui/TouchDriveControls.lua'];
(async()=>{
 const base='http://127.0.0.1:4206',name=path.basename(prepared.manifest_path);
 const report={build:prepared.source_directory,manifest:name,checks:[]};
 const latest=await fetch(base+'/game-dist/latest.json');assert.equal(latest.status,200);
 const tag=await latest.json();assert.equal('manifest-'+tag.client+'.json',name);report.checks.push('latest identifies tested build');
 assert.equal((await fetch(base+'/outgame.html')).status,200);report.checks.push('entry HTTP 200');
 const response=await fetch(base+'/game-dist/'+tag.version+'/'+name);assert.equal(response.status,200);
 const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(prepared.manifest_path)));
 const manifest=JSON.parse(bytes);report.checks.push('manifest equals tested build');
 for(const resource of resources){
  const item=manifest.files.find(f=>f.fs_path===resource);assert.ok(item,'packaged '+resource);
  const leaf=item.uuid+'-'+item.hash+item.ext,r=await fetch(base+'/game-dist/assets/'+leaf);assert.equal(r.status,200);
  const body=Buffer.from(await r.arrayBuffer());
  assert.ok(body.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',leaf))));
  assert.ok(body.equals(fs.readFileSync(path.join(root,'scripts',resource))),'workspace identity '+resource);
  assert.ok(!body.includes(Buffer.from('OUTGAME_STATE')),'ordinary script excludes QA probe');
  report.checks.push(resource+' HTTP 200 and exact workspace/build bytes');
 }
 assert.ok(!manifest.files.some(f=>/check-touch|probe-outgame|source-touch\.json/.test(f.fs_path)),'no test payload in release manifest');
 report.checks.push('test fixtures and probes excluded');report.result='PASS';
 fs.writeFileSync(path.join(root,'docs/migration/evidence/touch-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,manifest:name,checks:report.checks.length}));
})().catch(e=>{console.error(e);process.exitCode=1;});
