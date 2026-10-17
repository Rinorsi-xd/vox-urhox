'use strict';
// Separate QA service/runner; existing baseline and production files stay intact.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const baseline=require('./run-normal-gc-baseline.cjs');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
function once(source,needle,replacement){assert.equal(source.split(needle).length,2,'Exact mode boundary '+needle.slice(0,80));return source.replace(needle,replacement)}
function mode(value=process.env.VOX_GC_MODE){assert.ok(['generational','incremental'].includes(value),'Explicit VOX_GC_MODE=generational|incremental required');return value}
function controller(target){return '\ndo\n'+once(fs.readFileSync(path.join(__dirname,'qa-normal-gc-mode.lua'),'utf8'),'__VOX_GC_TARGET__',JSON.stringify(mode(target)))+'\nend\n'}
function modeProbe(){return once(baseline.gcProbe(),"local data={qaQuiet=VOX_QA_NORMAL_GC_QUIET==true,","local data={normalGcMode=VOX_QA_NORMAL_GC_MODE and VOX_QA_NORMAL_GC_MODE.Snapshot() or false,qaQuiet=VOX_QA_NORMAL_GC_QUIET==true,")}
function serverSource(source,target){
 target=mode(target);source=baseline.serverSource(source);
 source=once(source,JSON.stringify(baseline.gcProbe()),JSON.stringify(modeProbe()));
 source=once(source,'const fullProbe=probe+aimEngineProbe+salvageStockProbe;','const fullProbe=probe+aimEngineProbe+salvageStockProbe+'+JSON.stringify(controller(target))+';');
 return once(source,'previewIdentity=()=>({...prepared,normalGcBaseline:true,','previewIdentity=()=>({...prepared,normalGcMode:'+JSON.stringify(target)+',normalGcModeControllerSha256:'+JSON.stringify(sha(controller(target)))+',normalGcModeProbeSha256:'+JSON.stringify(sha(modeProbe()))+',normalGcBaseline:true,');
}
function endpoint(state,target,selected=true){
 const data=state.performance?.normalGcMode;assert.ok(data,'Actual mode endpoint');
 assert.equal(data.target,mode(target));assert.equal(data.running,true);assert.equal(data.error,false);
 assert.equal(data.contaminated,false);assert.equal(data.mutations,0);assert.equal(data.guard.clear,true,'No endpoint retirement/loading/focus/lease work');
 assert.equal(data.phase,selected?'selected':'idle');assert.equal(data.wrapperOwned,selected);
 if(selected){
  assert.equal(data.previous,'generational','Verified engine startup mode required');assert.ok(Number.isFinite(data.selectedAtMs));
  assert.equal(data.assembly.length,8);for(const unit of data.assembly){assert.ok(/^[a-f0-9]{8}$/.test(unit.fnv1a32));assert.ok(unit.count>0);assert.ok(unit.bytes>0)}
 }
 return data;
}
function runnerSource(source,target){
 target=mode(target);source=baseline.runnerSource(source);
 source=once(source,"const normalTools=require(path.join(__dirname,'run-normal-gc-baseline.cjs'));",String.raw`
 const normalTools=require(path.join(__dirname,'run-normal-gc-baseline.cjs'));
 const modeTools=require(path.join(__dirname,'run-normal-gc-mode.cjs'));
 const modeTarget=`+JSON.stringify(target)+String.raw`;
 assert.equal(identity.normalGcMode,modeTarget);
 assert.equal(identity.normalGcModeControllerSha256,modeTools.controllerSha(modeTarget));
 assert.equal(identity.normalGcModeProbeSha256,modeTools.probeSha());`);
 source=once(source,'let ownedBrowserServer;let cdp,profileRunning=false,','let normalModeRestoreAck=null;let normalModeSelected=false;let ownedBrowserServer;let cdp,profileRunning=false,');
 source=once(source,String.raw`const line=message.text();lineNumber++;fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');`,String.raw`
   const line=message.text();lineNumber++;fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   const gcAckAt=line.indexOf('VOX_NORMAL_GC_ACK ');
   if(gcAckAt>=0){try{const ack=JSON.parse(line.slice(gcAckAt+'VOX_NORMAL_GC_ACK '.length));
    report.normalGcModeAcks=report.normalGcModeAcks||[];report.normalGcModeAcks.push(ack);
    if(ack.kind==='restore')normalModeRestoreAck=ack;
   }catch(error){report.errors.push('Mode ACK parse: '+error.message)}}`);
 source=once(source,'report.normalGcBaseline.beforeEndpoint=normalTools.endpoint(state);',String.raw`
 modeTools.endpoint(state,modeTarget,false);
 await page.keyboard.press('F10');normalModeSelected=true;
 const selectSeq=seq;await poll();
 await wait(s=>seq>selectSeq&&s.performance?.normalGcMode?.phase!=='idle','explicit mode selection ACK',15000);
 report.normalGcMode={target:modeTarget,selected:structuredClone(modeTools.endpoint(state,modeTarget)),stabilizationExcludedMs:3000};
 await sleep(3000);
 const stabilizedSeq=seq;await poll();await wait(()=>seq>stabilizedSeq,'mode stabilization endpoint',15000);
 report.normalGcMode.stabilized=structuredClone(modeTools.endpoint(state,modeTarget));
 report.normalGcMode.boundary='Automatic GC stays running; one no-argument mode switch before excluded 3s stabilization. Explicit mutator calls pass through and contaminate this run. No periodic GC queries, no numeric tuning, no stopped GC or full collection. Endpoint gates are not continuous scene/focus observation; assembled vehicles are signed only at selection. Desktop-only comparison.';
 report.normalGcBaseline.beforeEndpoint=normalTools.endpoint(state);`);
 source=once(source,"await page.keyboard.press('F7');\n report.measurementResult='PASS';",String.raw`
 report.normalGcMode.after=structuredClone(modeTools.endpoint(report.afterDrive.state,modeTarget));
 await page.keyboard.press('F11');
 await wait(()=>normalModeRestoreAck!==null,'explicit original collector restoration ACK',15000);
 check(normalModeRestoreAck.restored===true&&normalModeRestoreAck.running===true&&!normalModeRestoreAck.error&&!normalModeRestoreAck.contaminated,'Original automatic collector restored without error or contamination');
 report.normalGcMode.restore=normalModeRestoreAck;
 await page.keyboard.press('F7');
 report.measurementResult='PASS';`);
 source=once(source,'measuring=false;\n  try{if(page&&!page.isClosed())',String.raw`
measuring=false;
  if(normalModeSelected&&!normalModeRestoreAck){
   try{
    if(page&&!page.isClosed()){
     await page.keyboard.press('F11',{timeout:3000});
     const restoreDeadline=now()+6000;
     while(!normalModeRestoreAck&&now()<restoreDeadline)await sleep(60);
    }
   }catch(error){report.normalGcModeCleanupError=error.message}
   if(!normalModeRestoreAck?.restored||!normalModeRestoreAck?.running||normalModeRestoreAck?.error){
    report.normalGcModeCleanupError=report.normalGcModeCleanupError||'Missing/failed collector restoration ACK; closing owned browser';
   }
  }
  if(normalModeSelected)report.normalGcModeFinalRestore=normalModeRestoreAck;
  try{if(page&&!page.isClosed())`);
 return source+'\nmodule.exports.runNormalGcModeMain=main;\n';
}
function selfTest(){
 const vm=require('node:vm'),server=fs.readFileSync(path.join(__dirname,'serve-outgame.cjs'),'utf8'),runner=fs.readFileSync(path.join(__dirname,'check-performance-uninstrumented-web.cjs'),'utf8');
 for(const target of ['generational','incremental']){new vm.Script(serverSource(server,target));new vm.Script(runnerSource(runner,target))}
 assert.equal(controller('generational').replace('"generational"','"MODE"'),controller('incremental').replace('"incremental"','"MODE"'),'Served main mode difference is only target string');
 assert.throws(()=>serverSource(server.replace('const fullProbe=probe+aimEngineProbe+salvageStockProbe;','drift'),'incremental'));
 assert.throws(()=>runnerSource(runner.replace('measuring=false;\n  try{if(page&&!page.isClosed())','drift'),'incremental'));
 for(const target of ['',undefined,'stop','incremental,200'])assert.throws(()=>mode(target));
 const sample={performance:{normalGcMode:{target:'incremental',running:true,error:false,contaminated:false,mutations:0,guard:{clear:true},phase:'selected',wrapperOwned:true,previous:'generational',selectedAtMs:10,assembly:Array.from({length:8},()=>({fnv1a32:'12345678',count:4,bytes:80}))}}};
 endpoint(sample,'incremental');
 for(const key of ['running','error','contaminated','mutations','phase','wrapperOwned','assembly']){
  const bad=structuredClone(sample);bad.performance.normalGcMode[key]=({running:false,error:'failure',contaminated:true,mutations:1,phase:'restored',wrapperOwned:false,assembly:[]})[key];assert.throws(()=>endpoint(bad,'incremental'));
 }
 console.log('PASS: generated service/runner parse; target-only Lua difference; source drift/invalid mode and seven endpoint rejection controls; no hardware launched');
}
function compile(file,source){const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(path.dirname(file));m._compile(source,file);return m.exports}
module.exports={controller,controllerSha:target=>sha(controller(target)),modeProbe,probeSha:()=>sha(modeProbe()),serverSource,runnerSource,endpoint,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test'))selfTest();
 else if(process.argv.includes('--serve')){
  assert.deepEqual(process.argv.slice(2),['--serve']);const target=mode();process.argv.push('--qa','--monitor-disabled');
  const file=path.join(__dirname,'serve-outgame.cjs');compile(file,serverSource(fs.readFileSync(file,'utf8'),target)).startPreviewServer();
 }else{
  assert.deepEqual(process.argv.slice(2),[]);const target=mode();
  process.env.VOX_PERF_ROUTE='match';process.env.VOX_PERF_MATCH_MODE='conquest';process.env.VOX_PERF_DRIVE_MS='30000';
  const file=path.join(__dirname,'check-performance-uninstrumented-web.cjs');
  compile(file,runnerSource(fs.readFileSync(file,'utf8'),target)).runNormalGcModeMain().catch(error=>{console.error(error.stack);process.exitCode=1});
 }
}
