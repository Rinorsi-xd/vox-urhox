// Compare recorded public-entry runs; never drives or changes the game.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
function read(directory){
 const dir=path.resolve(root,directory),file=path.join(dir,'runtime.log'),raw=fs.readFileSync(file,'utf8');
 const run=JSON.parse(fs.readFileSync(path.join(dir,'result.json'),'utf8'));
 const states=[],shaders=new Set(),prepared=[],events=[];let active=false,opens=0,closes=0,rawCompiles=0,truncatedStates=0;
 for(const line of raw.split(/\r?\n/)){
  if(line.includes('[LoadingFlow] Open story3')){active=true;opens++;events.push(line);}
  if(active){
   const compile=line.match(/Succeed to compile shader \[([^\]]+)\],defines \[([^\]]*)\]/);
   if(compile){shaders.add(compile[1]+'|'+compile[2]);rawCompiles++;}
   const texture=line.match(/\[SceneLoader\] Prepared (\S+) bytes=([\d.]+)/);
   if(texture)prepared.push({path:texture[1],bytes:Number(texture[2])});
   if(/\[(?:LoadingFlow|CombatWarmup)\]/.test(line)&&!line.includes('OUTGAME_STATE'))events.push(line);
   if(line.includes('[LoadingFlow] Closed')){active=false;closes++;}
  }
  const at=line.indexOf('OUTGAME_STATE ');
  if(at>=0){
   const message=line.slice(at+14);
   if(!message.trimEnd().endsWith('}')){truncatedStates++;continue;}
   try{states.push(JSON.parse(message));}catch(error){throw Error(file+': malformed complete observed state: '+error.message);}
  }
 }
 assert.equal(opens,1,'Exactly one public story3 loading entry');
 assert.equal(closes,1,'Story3 loading closes normally');
 assert.equal(run.level,'s3','Recorded run is the intended third mission');
 const entered=states.find(s=>s.mode==='trial'&&s.story?.id==='s3'&&!s.loadingFlow?.active);
 assert(entered,'Actual live mission state');
 assert.equal(run.result,'PASS','Public route assertions passed');
 assert.equal(run.errors.length,0,'No recorded runtime errors');
 assert.equal((run.httpFailures||[]).length,0,'No recorded HTTP failures');
 assert.equal(shaders.size,331,'Observed original S3 shader set is nonempty and complete');
 assert.equal(prepared.length,2,'Both arrays prepared exactly once');
 assert.deepEqual(prepared.map(item=>[item.path,item.bytes]),[['Crater/albedo.xml',33554792],['Crater/nra.xml',33554792]],'Original array payload memory sizes and order');
 const returned=states.at(-1);
 assert.equal(returned?.mode,'hangar','Last observed state is the restored hall');
 assert.equal(returned.loadingFlow?.active,false,'Return loading finished');
 assert.equal(returned.performance?.arrayBytes,0,'Terrain arrays released after actual return');
 assert(run.checks.includes('natural attempt return releases terrain arrays'),'Public test explicitly asserted return');
 const timing={};
 for(const state of states)for(const [name,value]of Object.entries(state.performance?.updateTiming||{})){
  if(value.calls>0&&(!timing[name]||value.maxMs>timing[name].maxMs))timing[name]=value;
 }
 const frames=states.map(s=>s.frames).filter(Boolean);
 const frameWindows={count:frames.length,observedFrames:frames.reduce((n,f)=>n+f.count,0),
  maxMs:Math.max(0,...frames.map(f=>f.max)),maxWindowP95Ms:Math.max(0,...frames.map(f=>f.p95)),
  boundary:'Engine TimeStep windows reported by the read-only probe, including loading/return and diagnostic overhead. TimeStep may be clamped (both runs reach 100ms), so these values cannot measure wall-clock freezes. Window P95 values are not a pooled percentile; no GPU timer or earliest boot coverage.'};
 return {directory:path.relative(root,dir).replaceAll('\\','/'),logSha256:crypto.createHash('sha256').update(raw).digest('hex'),
  result:run.result,errors:run.errors.length,manifest:run.identity.servedManifest,probeSha256:run.identity.probeSha256,
  loaderSha256:run.identity.identity.scripts['app/SceneLoader.lua'],rawCompiles,truncatedStates,shaders:[...shaders].sort(),prepared,events,timing,frameWindows,
  entry:{arrayBytes:entered.performance.arrayBytes,phaseTimes:Object.fromEntries((entered.loadingFlow?.steps||[]).map(step=>[step.id,step.elapsed])),warmup:entered.loadingFlow?.warmupTimes},
  returnedArrayBytes:states.at(-1)?.performance?.arrayBytes};
}
const before=read(process.argv[2]),after=read(process.argv[3]);
const a=new Set(before.shaders),b=new Set(after.shaders);
const missing=before.shaders.filter(s=>!b.has(s)),added=after.shaders.filter(s=>!a.has(s));
const report={result:before.result==='PASS'&&after.result==='PASS'&&!after.errors&&!missing.length&&!added.length?'PASS':'FAIL',
 before,after,shaderComparison:{before:a.size,after:b.size,missing,added},
 boundary:'Recorded same-machine sequential public S3 entry/return runs, including QA wrappers and screenshots. Truncated engine console messages are counted and excluded, never parsed as complete states; complete messages and asserted entry/return are required. Exact logged shader identity equality and method wall maxima only. Not a controlled repeated A/B, listening test, complete mission, total main-thread/GPU cost or mobile performance acceptance.'};
const out=path.resolve(root,process.argv[4]||'docs/migration/evidence/story-loader-latest-comparison.json');
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({result:report.result,shaderComparison:report.shaderComparison,before:before.timing['app.SceneLoader.Update'],after:after.timing['app.SceneLoader.Update'],prepared:after.prepared,out}));
if(report.result!=='PASS')process.exitCode=1;
