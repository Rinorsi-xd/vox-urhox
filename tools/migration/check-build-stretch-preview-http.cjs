const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const paths=['main.lua','construction/BuildStretch.lua','construction/Blueprint.lua','construction/BlueprintMigration.lua',
 'construction/BuildEditor.lua','construction/EditHistory.lua','app/BuildSession.lua','controls/BuildInput.lua',
 'render/BuildGhost.lua','storage/BlueprintCode.lua','ui/BuildDock.lua','ui/BuildHover.lua','ui/BuildModeBadge.lua','ui/BuildOverlay.lua'];
(async()=>{
 const base='http://127.0.0.1:4206',manifestName=path.basename(prepared.manifest_path);
 const report={build:prepared.source_directory,manifest:manifestName,checks:[]};
 assert.equal((await fetch(base+'/outgame.html')).status,200);report.checks.push('preview HTTP 200');
 const response=await fetch(base+'/game-dist/1.0.0/'+manifestName);assert.equal(response.status,200);
 const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(prepared.manifest_path)));
 const manifest=JSON.parse(bytes);report.checks.push('served manifest equals final prepared build');
 for(const name of paths){
  const file=manifest.files.find(f=>f.fs_path===name);assert.ok(file,'missing '+name);
  const filename=file.uuid+'-'+file.hash+file.ext;const response=await fetch(base+'/game-dist/assets/'+filename);
  assert.equal(response.status,200,name);const data=Buffer.from(await response.arrayBuffer());
  assert.ok(data.equals(fs.readFileSync(path.join(prepared.source_directory,'dist/assets',filename))),name+' differs from build');
  assert.ok(data.equals(fs.readFileSync(path.join(root,'scripts',name))),name+' differs from workspace');
  if(name==='main.lua')assert.ok(!data.toString().includes('OUTGAME_STATE'),'QA probe found in ordinary preview');
  report.checks.push(name+' HTTP 200, exact build and workspace content');
 }
 report.result='PASS';fs.writeFileSync(path.join(root,'docs/migration/evidence/build-stretch-preview-http.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,manifest:manifestName,checks:report.checks.length}));
})().catch(e=>{console.error(e);process.exitCode=1;});
