const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const base='http://127.0.0.1:4206';
(async()=>{
 const report={build:path.basename(prepared.source_directory),manifest:path.basename(prepared.manifest_path),checks:[],errors:[],cloudLogs:[],authenticatedRoundtrip:false};
 const tag=await fetch(base+'/game-dist/latest.json').then(r=>r.json());
 assert.equal('manifest-'+tag.client+'.json',report.manifest);
 const manifest=await fetch(base+'/game-dist/'+tag.version+'/'+report.manifest).then(r=>r.json());
 for(const name of ['main.lua','storage/CloudStorage.lua','storage/CloudSync.lua','storage/BlueprintStore.lua','app/HangarApp.lua','ui/GarageDialogs.lua','ui/BlueprintLibrary.lua']){
  const f=manifest.files.find(f=>f.fs_path===name);assert.ok(f,'packaged '+name);
  const r=await fetch(base+'/game-dist/assets/'+f.uuid+'-'+f.hash+f.ext);assert.equal(r.status,200);
  const bytes=Buffer.from(await r.arrayBuffer());assert.ok(bytes.equals(fs.readFileSync(path.join(root,'scripts',name))),'current workspace bytes '+name);
  if(name==='main.lua')assert.ok(!bytes.includes(Buffer.from('VOX_CLOUD_VALIDATION')),'ordinary boot does not bypass cloud');
  report.checks.push(name+' served current bytes');
 }
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  page.on('console',m=>{
   const text=m.text();if(text.includes('[CloudStorage]'))report.cloudLogs.push(text);
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))report.errors.push(text);
  });
  page.on('pageerror',e=>report.errors.push(e.message));
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await page.waitForFunction(()=>!!window.Module?.calledRun,{},{timeout:120000});
  const start=Date.now();while(!report.cloudLogs.length&&Date.now()-start<120000)await page.waitForTimeout(250);
  assert.ok(report.cloudLogs.length,'ordinary Web storage boot reports its actual capability');
  await page.waitForTimeout(12000);
  await page.screenshot({path:path.join(out,'cloud-preview-ordinary.png')});
  assert.equal(report.errors.length,0,'ordinary Web runtime has no captured Lua/JS errors');
  report.checks.push('ordinary Web boot without QA cloud bypass');
  report.checks.push('ordinary rendered home screenshot');
  report.result='PASS';
 }finally{await browser.close();}
 fs.writeFileSync(path.join(out,'cloud-preview.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
})().catch(e=>{console.error(e);process.exitCode=1;});
