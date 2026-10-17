'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function chunks(){const parts=new Map();let count=null;return {add(value){
 assert(Number.isInteger(value.count)&&value.count>=1&&value.count<=4096);assert(Number.isInteger(value.index)&&value.index>=1&&value.index<=value.count);assert.equal(typeof value.data,'string');assert(value.data.length<=3500);
 if(count!==null)assert.equal(value.count,count,'Chunk total drift');count=value.count;assert(!parts.has(value.index),'Duplicate chunk');parts.set(value.index,value.data);
 },ready(){return count!==null&&parts.size===count},result(){assert(this.ready(),'Missing chunks');let bytes='';for(let i=1;i<=count;i++)bytes+=parts.get(i);return JSON.parse(bytes)}}}
function verifyResult(result,identity){
 assert.equal(result.status,'PASS');assert.deepEqual(result.configuration,identity.g1WebCpu.configuration);assert.equal(result.configuration.seed,1016);
 if(['lanes','crater'].includes(result.configuration.scenario)){
  assert.equal(result.vehicles,6);assert.equal(result.steps,result.configuration.steps);assert.equal(result.samplesMs.length,result.steps);
  assert.equal(result.expectedPhysicsSteps,result.steps);assert.equal(result.expectedVehicleStepCalls,result.steps*6);
  assert.equal(result.totalMs,result.samplesMs.reduce((a,b)=>a+b,0));assert.equal(result.metadata.length,6);
  assert.equal(result.randomTail.length,32);assert.equal(result.snapshots.length,result.steps/60);
  if(result.configuration.mode==='timing')assert.deepEqual(Object.keys(result.scopes),[],'Timing must not install wrappers');
  if(result.configuration.mode==='profile'){
   const scopes=new Map(result.scopes.map(row=>[row.name,row]));assert.equal(scopes.size,14,'Unique method scopes');
   assert.equal(scopes.get('vehicle.Step').calls,result.steps*6);assert.equal(scopes.get('vehicle.StepRotors').calls,result.steps*6);assert.equal(scopes.get('physics.Step').calls,result.steps);
   for(const row of scopes.values())assert(row.ms>=row.selfMs&&row.selfMs>=0,'Nonnegative nested self');
  }
  if(result.configuration.mode==='equivalence')assert(result.rayEquivalence&&Number.isInteger(result.rayEquivalence.calls)&&result.rayEquivalence.calls>=0);
  if(result.configuration.scenario==='crater')assert.equal(result.map.bodies,result.map.terrainChunks+result.map.authored+result.map.boulders);
 }else{assert.deepEqual(result.damage.fixtures.map(row=>[row.name,row.combat]),[['raceCar',false],['raceCar',true],['megaMech',false],['megaMech',true],['bridge-detach',false]]);assert.equal(result.damage.randomTail.length,32);for(const fixture of result.damage.fixtures){assert(fixture.stages.length>=1);assert.equal(fixture.stages.at(-1).alive,false);for(const stage of fixture.stages){
   if(result.configuration.mode==='profile')for(const key of ['damageScopes','flushScopes']){assert.equal(stage[key].length,23);assert.equal(new Set(stage[key].map(row=>row.name)).size,23);for(const row of stage[key])assert(row.ms>=row.selfMs&&row.selfMs>=0)}
   else assert.equal(stage.flushScopes,false,'Timing must not install damage wrappers');
  }}const bridge=result.damage.fixtures.at(-1);assert.equal(bridge.stages[0].partsAfter,2);assert.equal(bridge.stages[0].debrisPieces,1);assert.equal(bridge.stages[0].alive,true);assert.equal(bridge.stages.at(-1).partsAfter,1);assert.equal(bridge.stages.at(-1).debrisPieces,2)}
 const variants=identity.g1WebCpu.variants||{};
 if(result.configuration.mode==='profile'&&variants['construction/TurretRange.lua']&&variants['drive/VehicleSpec.lua']){
  const expected=['TurretRange.For.Signatures','TurretRange.For.Invalidations','TurretRange.Prepare','TurretRange.Evaluate','TurretRange.SameContext','MergeBoxes.Index','MergeBoxes.Sort','MergeBoxes.Sweep'];
  for(const fixture of result.damage.fixtures){
   const measurements=[[fixture.initialBuildScopes,fixture.initialBuildLocalScopes]];
   for(const stage of fixture.stages)measurements.push([stage.damageScopes,stage.damageLocalScopes],[stage.flushScopes,stage.flushLocalScopes]);
   for(const [outer,locals]of measurements){
    assert.deepEqual(locals.map(row=>row.name),expected,'Exact local profile labels');
    const o=new Map(outer.map(row=>[row.name,row])),l=new Map(locals.map(row=>[row.name,row]));
    for(const row of locals)assert(row.ms>=row.selfMs&&row.selfMs>=0&&Number.isInteger(row.calls)&&row.calls>=0);
    assert.equal(l.get('TurretRange.For.Signatures').calls,o.get('TurretRange.For').calls);
    for(const name of ['MergeBoxes.Index','MergeBoxes.Sort','MergeBoxes.Sweep'])assert.equal(l.get(name).calls,o.get('VehicleSpec.MergeBoxes').calls);
    for(const [prefix,parent]of [['TurretRange.','TurretRange.For'],['MergeBoxes.','VehicleSpec.MergeBoxes']])assert(locals.filter(row=>row.name.startsWith(prefix)).reduce((sum,row)=>sum+row.selfMs,0)<=o.get(parent).ms,'Local self does not exceed enclosing export');
   }
  }
 }
 return result;
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);fs.mkdirSync(out,{recursive:true});const identity=await fetch(base+'/identity.json').then(r=>r.json());
 assert(identity.ok&&identity.g1WebCpu?.isolated);assert.equal(identity.qa,false,'No normal gameplay QA wrappers');assert.equal(identity.perfMonitor,false);
 const manifest=await fetch(base+'/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')).then(r=>r.json());
 const main=manifest.files.find(x=>x.fs_path==='main.lua');const mainBytes=Buffer.from(await fetch(base+'/game-dist/assets/'+main.uuid+'-'+main.hash+main.ext).then(r=>r.arrayBuffer()));assert.equal(sha(mainBytes),identity.g1WebCpu.entrySha256,'Actual HTTP CPU entry identity');
 const runtimeRoot=path.resolve(__dirname,'../../.tmp/web-engine'),runtimeHashes={};
 for(const name of ['UrhoXRuntime.js','UrhoXRuntime.wasm','UrhoXRuntime.data'])runtimeHashes[name]=sha(fs.readFileSync(path.join(runtimeRoot,name)));
 const runtimeJs=Buffer.from(await fetch(base+'/UrhoXRuntime.js').then(r=>r.arrayBuffer()));assert.equal(sha(runtimeJs),runtimeHashes['UrhoXRuntime.js'],'Actual Web Runtime JS identity');
 const launchUrl=base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login';
 const report={status:'RUNNING',identity,runtimeHashes,launchUrl,startedAt:new Date().toISOString(),errors:[],httpErrors:[],logs:[],damageProgress:[]};let browser,page;const transport=chunks(),stageStreams=new Map();
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));persist();
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});page=await browser.newPage({viewport:{width:960,height:540}});
  page.on('console',message=>{const text=message.text();report.logs.push(text);if(message.type()==='error'||/\bERROR:|Aborted\(OOM\)/.test(text))report.errors.push(text+' '+JSON.stringify(message.location()));const prefix='G1_WEB_CPU_CHUNK ',offset=text.indexOf(prefix);if(offset>=0){try{transport.add(JSON.parse(text.slice(offset+prefix.length)))}catch(error){report.errors.push(error.message)}}const stagePrefix='G1_WEB_CPU_DAMAGE_STAGE ',stageAt=text.indexOf(stagePrefix);if(stageAt>=0){try{
   const value=JSON.parse(text.slice(stageAt+stagePrefix.length));
   if(value.name)report.damageProgress.push(value);
   else{assert(Number.isInteger(value.sequence)&&value.sequence>=1&&value.sequence<=64);if(!stageStreams.has(value.sequence))stageStreams.set(value.sequence,chunks());const stream=stageStreams.get(value.sequence);stream.add(value);if(stream.ready())report.damageProgress.push(stream.result())}
  }catch(error){report.errors.push(error.message)}}});
  page.on('requestfailed',request=>report.httpErrors.push({url:request.url(),failure:request.failure()}));
  page.on('pageerror',error=>report.errors.push(error.message));page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({url:response.url(),status:response.status()})});
  await page.goto(launchUrl,{waitUntil:'domcontentloaded',timeout:30000});
  const deadline=Date.now()+240000;while(!transport.ready()){
   assert.equal(report.errors.length,0,'Runtime error: '+report.errors[0]);assert.equal(report.httpErrors.length,0,'HTTP error');assert(Date.now()<deadline,'CPU fixture timeout');await new Promise(r=>setTimeout(r,250));
  }
  report.result=transport.result();verifyResult(report.result,identity);assert.equal(report.errors.length,0,'Runtime errors');assert.equal(report.httpErrors.length,0,'HTTP errors');
  assert.deepEqual(await fetch(base+'/identity.json').then(r=>r.json()),identity,'Service identity drift');report.status='PASS';
 }catch(error){report.status='FAIL';report.failure=error.stack;throw error}
 finally{if(browser){try{await Promise.race([browser.close(),new Promise((_,reject)=>setTimeout(()=>reject(Error('Dedicated browser close timed out')),5000))]);report.shutdown='CLOSED'}catch(error){report.shutdown='UNCONFIRMED';report.closeError=error.message}}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));}
 return report;
}
module.exports={chunks,verifyResult,run};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3]||'.tmp/g1-web-cpu-result')).catch(error=>{console.error(error.message);process.exitCode=1});
