'use strict';
// Existing public-input route, with read-only GC state and bounded owned shutdown.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),gcTools=require('./run-auto-gc-aba.cjs');
const sha=v=>crypto.createHash('sha256').update(v).digest('hex');
function once(source,needle,replacement){assert.equal(source.split(needle).length,2,'Exact integration boundary '+needle.slice(0,70));return source.replace(needle,replacement)}
function compile(file,source){const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));m._compile(source,file);return m.exports}
function endpoint(state,quiet=false){
 assert.equal(state.mode,'trial');assert.equal(state.battle?.state,'live');
 assert.equal(state.performance?.luaGcRunning,true,'Read-only collector running state');
 if(quiet)assert.equal(state.performance.qaQuiet,true,'Actual quiet-state acknowledgement');
 const world=state.performance.battleObjects?.world,units=state.battle.units;
 assert.ok(Number.isInteger(world?.units)&&world.units>=0,'Actual world entry count');
 if(!quiet)assert.equal(world.units,8,'Actual world eight-entry count before input');
 assert.ok(Array.isArray(units)&&units.length===8,'Actual battle eight-entry array');
 assert.equal(world.alive,units.filter(u=>u.alive).length,'World/snapshot alive agreement');
 for(const u of units){assert.ok(Number.isInteger(u.parts)&&u.parts>=0&&(!u.alive||u.parts>0));assert.ok(['red','blue'].includes(u.team));
  assert.ok(Array.isArray(u.position)&&u.position.length===3&&u.position.every(Number.isFinite));}
 assert.equal(units.filter(u=>u.player===true).length,1,'Single real player');
 return {gcRunning:true,world,roster:units.map(u=>({name:u.name,team:u.team,role:u.role??null,parts:u.parts,player:u.player,
  alive:u.alive,position:u.position,hp:u.hp,stats:u.stats??null,prefab:null,tier:null})),
  identityBoundary:'Existing snapshot proves role/part count/player/team; prefab and tier are unavailable and remain null.'};
}
function gcProbe(){let source=once(fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8'),
 "local data={luaKiB=collectgarbage('count'),resourceBytes=cache:GetTotalMemoryUse(),",
 "local data={qaQuiet=VOX_QA_NORMAL_GC_QUIET==true,luaGcRunning=collectgarbage('isrunning'),luaKiB=collectgarbage('count'),resourceBytes=cache:GetTotalMemoryUse(),");
 source=once(source,'function HandleUpdate(et,ed)','function HandleUpdate(et,ed)\n    if input:GetKeyPress(KEY_F7) then VOX_QA_NORMAL_GC_QUIET=not VOX_QA_NORMAL_GC_QUIET end');
 assert.ok(source.includes('not VOX_QA_FRAME_PIPELINE'));
 return source.replaceAll('not VOX_QA_FRAME_PIPELINE','not VOX_QA_NORMAL_GC_QUIET and not VOX_QA_FRAME_PIPELINE');
}
function serverSource(source){
 source=once(source,"fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8')",JSON.stringify(gcProbe()));
 return once(source,'previewIdentity=()=>({...prepared,qa,','previewIdentity=()=>({...prepared,normalGcBaseline:true,normalGcProbeSha256:'+JSON.stringify(sha(gcProbe()))+',qa,');
}
function runnerSource(source){
 source=once(source,"const report={result:'RUNNING',route,matchMode,url,identity,production,",String.raw`
 assert.equal(identity.normalGcBaseline,true,'Dedicated read-only GC baseline server');
 assert.equal(identity.normalGcProbeSha256,require(path.join(__dirname,'run-normal-gc-baseline.cjs')).probeSha(),'Exact read-only GC observer');
 assert.ok(!captureCdp&&!driveSections&&!trialSections&&!afterStep&&!framePipeline&&!fixedStepPipeline&&!correlateFrameTrace,'Normal-GC baseline has no profiling scopes');
 const baselineTools=require(path.join(__dirname,'run-auto-gc-aba.cjs'));
 const normalTools=require(path.join(__dirname,'run-normal-gc-baseline.cjs'));
 const report={normalGcBaseline:{environmentBefore:baselineTools.environmentSnapshot(),probeSha256:identity.normalGcProbeSha256},result:'RUNNING',route,matchMode,url,identity,production,`);
 source=once(source,'let cdp,profileRunning=false,','let ownedBrowserServer;let cdp,profileRunning=false,');
 source=once(source,"browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:VIEWPORT});",String.raw`
 ownedBrowserServer=await chromium.launchServer({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 browser=await chromium.connect(ownedBrowserServer.wsEndpoint());page=await browser.newPage({viewport:VIEWPORT});`);
 source=once(source,'report.beforeDrive={sequence:seq,state};windowBoundary=null;',String.raw`
 report.normalGcBaseline.beforeEndpoint=normalTools.endpoint(state);
 report.beforeDrive={sequence:seq,state};windowBoundary=null;`);
 source=once(source,'const inputDrain=wallSeq;await poll();',"await page.keyboard.press('F7');\n  const inputDrain=wallSeq;await poll();");
 source=once(source,"check(activeState(state,route,storyId),'Wall input anchor is active gameplay');","check(activeState(state,route,storyId),'Wall input anchor is active gameplay');\n  check(state.performance.qaQuiet===true,'Automatic full-state dumps suspended before input');");
 source=once(source,'healthy();const tick=now();await poll();\n   await sleep(Math.max(0,Math.min(POLL_MS-(now()-tick),driveMs-(now()-heldInputStartMs))));',
  'healthy();await sleep(Math.max(0,Math.min(100,driveMs-(now()-heldInputStartMs))));');
 source=once(source,"check(report.coverage.windows>0,'Consecutive nonoverlapping active FrameStats windows retained');","check(report.wallCoverage.windows>0,'Complete entry-wall sample window retained with no mid-input state dump');");
 source=once(source,"report.measurementResult='PASS';",String.raw`
 report.normalGcBaseline.afterEndpoint=normalTools.endpoint(report.afterDrive.state,true);
 check(report.windows.every(w=>w.performance.luaGcRunning===true),'Automatic GC running in post-input snapshot');
 report.normalGcBaseline.roster=report.normalGcBaseline.beforeEndpoint.roster;
 report.normalGcBaseline.aliveBefore=report.normalGcBaseline.beforeEndpoint.world.alive;
 report.normalGcBaseline.aliveAfter=report.normalGcBaseline.afterEndpoint.world.alive;
 report.normalGcBaseline.quietInput=true;
 report.normalGcBaseline.boundary='No mid-input full-state requests or automatic dumps. GC running and roster checked at endpoints only; no claim of continuous internal GC or alive-state observation. Raw entry-wall samples retained. Endpoint input/dump delivery uncertainty remains.';
 await page.keyboard.press('F7');
 report.measurementResult='PASS';`);
 source=once(source,"await browser?.close();report.shutdown='CLOSED';report.finishedAt=new Date().toISOString();",String.raw`
 report.normalGcBaseline.shutdown=await baselineTools.closeOwnedBrowser(page,browser,ownedBrowserServer);
 report.shutdown=report.normalGcBaseline.shutdown.status;report.finishedAt=new Date().toISOString();
 report.normalGcBaseline.environmentAfter=baselineTools.environmentSnapshot();
 report.normalGcBaseline.environmentCpuDelta=baselineTools.environmentDelta(report.normalGcBaseline.environmentBefore,report.normalGcBaseline.environmentAfter);`);
 return source+'\nmodule.exports.runNormalGcMain=main;\n';
}
function selfTest(replayPath){
 const vm=require('node:vm'),s=fs.readFileSync(path.join(__dirname,'serve-outgame.cjs'),'utf8'),r=fs.readFileSync(path.join(__dirname,'check-performance-uninstrumented-web.cjs'),'utf8');
 new vm.Script(serverSource(s));new vm.Script(runnerSource(r));
 assert.throws(()=>serverSource(s.replace('previewIdentity=()=>({...prepared,qa,','drift')));
 assert.throws(()=>runnerSource(r.replace('let cdp,profileRunning=false,','drift')));
 assert.equal(gcProbe().split("luaGcRunning=collectgarbage('isrunning')").length,2);
 assert.ok(!gcProbe().includes('VOX_QA_AUTO_GC_ABA'));
 assert.ok(runnerSource(r).includes('healthy();await sleep(Math.max(0,Math.min(100,'));
 if(replayPath){
  const states=fs.readFileSync(replayPath,'utf8').trim().split('\n').map(line=>JSON.parse(line).state)
   .filter(s=>s.mode==='trial'&&s.battle?.state==='live'&&s.performance?.battleObjects?.world);
  assert.ok(states.length>0,'Actual completed live-state evidence available');
  for(const state of states)endpoint(state);
  const actual=states.at(-1);endpoint({...actual,performance:{...actual.performance,qaQuiet:true}},true);
  for(const mutate of [s=>s.performance.luaGcRunning=false,s=>delete s.performance.battleObjects,
   s=>s.battle.units={},s=>s.battle.units[0].parts=-1,s=>s.performance.battleObjects.world.alive--,
   s=>s.performance.qaQuiet=false]){
   const copy=structuredClone(actual);copy.performance.qaQuiet=true;mutate(copy);assert.throws(()=>endpoint(copy,true));
  }
  assert.equal(endpoint(actual).roster[0].role,null,'Missing Lua field normalized without inventing role');
  console.log('PASS: '+states.length+' actual live state gate replays, six field/empty-table negative controls, missing role normalized');
 }
 console.log('PASS: exact server/runner integration, read-only GC state, no profile flags, source-drift rejection; no engine launched');
}
module.exports={gcProbe,probeSha:()=>sha(gcProbe()),serverSource,runnerSource,endpoint,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test'))selfTest(process.argv.find(arg=>arg.endsWith('states.jsonl')));
 else if(process.argv.includes('--serve')){
  assert.deepEqual(process.argv.slice(2),['--serve'],'No diagnostic profile flags');process.argv.push('--qa','--monitor-disabled');
  const file=path.join(__dirname,'serve-outgame.cjs');compile(file,serverSource(fs.readFileSync(file,'utf8'))).startPreviewServer();
 }else{
  assert.deepEqual(process.argv.slice(2),[],'No diagnostic profile flags');
  process.env.VOX_PERF_ROUTE='match';process.env.VOX_PERF_MATCH_MODE='conquest';process.env.VOX_PERF_DRIVE_MS='30000';
  const file=path.join(__dirname,'check-performance-uninstrumented-web.cjs');
  compile(file,runnerSource(fs.readFileSync(file,'utf8'))).runNormalGcMain().catch(error=>{console.error(error.stack);process.exitCode=1});
 }
}
