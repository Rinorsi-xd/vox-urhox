const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),runner=path.join(__dirname,'check-story-natural-web.cjs');
const evidence=path.join(root,'docs/migration/evidence/story-natural-s3-manifest-fc1c6c62-2026-10-16T18-02-53-554Z');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const paths=['result.json','runtime.log'],original=Object.fromEntries(paths.map(name=>[name,sha(fs.readFileSync(path.join(evidence,name)))]));
const originalResult=JSON.parse(fs.readFileSync(path.join(evidence,'result.json')));
const states=fs.readFileSync(path.join(evidence,'runtime.log'),'utf8').split(/\r?\n/).filter(line=>line.includes('OUTGAME_STATE ')).map(line=>JSON.parse(line.slice(line.indexOf('OUTGAME_STATE ')+14)));
const paused=states.filter(s=>Array.isArray(s.widgets)&&s.widgets.some(w=>w.text==='返回车库'));
const source=fs.readFileSync(runner,'utf8'),start=source.indexOf(' async function returnViaUi(timeout){'),end=source.indexOf(' async function sampleBattleObjects',start);
assert(start>=0&&end>start);const actual=source.slice(start,end),results=[];
async function execute({name,acceptAt=1,confirmation=false,realReplay=false,wrongText=false},code=actual){
 let clock=0,dispatches=0,confirmed=false,reads=0;const clicks=[];
 const context={seq:0,state:{},report:{},persist:()=>{},structuredClone,Date:{now:()=>clock},sleep:async()=>{},
  readKey:async()=>{
   clock+=1000;context.seq++;reads++;
   if(realReplay){context.state=structuredClone(paused[Math.min(reads-1,paused.length-1)]);return;}
   if(dispatches>=acceptAt&&(!confirmation||confirmed)){context.state={mode:'hangar',loadingFlow:{active:false},performance:{arrayBytes:0}};return;}
   context.state=structuredClone(paused[0]);
   if(wrongText)context.state.widgets=context.state.widgets.filter(w=>w.text!=='返回车库');
   if(confirmation&&dispatches>=acceptAt)context.state.widgets=[{text:'确定',rect:[300,200,40,50]}];
  },
  wait:async(predicate,label,timeout,ignoreStop)=>{assert(timeout>0&&timeout<=30000);assert.equal(ignoreStop,true);assert(predicate());},
  page:{mouse:{click:async(x,y,options)=>{
   const button=context.state.widgets.find(w=>w.text==='确定')||context.state.widgets.find(w=>w.text==='返回车库');
   assert(button,'Only actual visible return/confirmation may be clicked');
   const [bx,by,w,h]=button.rect;assert.equal(x,(bx+w/2)/context.state.width*1600);assert.equal(y,(by+h/2)/context.state.height*900);
   assert.equal(options.delay,120);clicks.push({label:button.text,x,y});
   if(button.text==='确定')confirmed=true;else dispatches++;
  }}}};
 let outcome;
 try{const state=await vm.runInNewContext(code+';returnViaUi(30000)',context);assert.equal(state.mode,'hangar');outcome='OBSERVED_HALL';}
 catch(error){if(!/Timeout observed/.test(error.message))throw error;outcome='TIMEOUT';}
 if(realReplay||wrongText){assert.equal(outcome,'TIMEOUT');assert.equal(dispatches,wrongText?0:3);assert(!confirmed);}
 else{assert.equal(outcome,'OBSERVED_HALL');assert.equal(dispatches,acceptAt);assert.equal(confirmed,confirmation);}
 assert(dispatches<=3);assert(context.report.publicReturnControls.observations.length>0);
 return {name,outcome,clicks,observations:reads};
}
async function main(){
 assert.equal(originalResult.result,'FAIL');assert.match(originalResult.failure,/30-second total budget/);assert.equal(paused.length,390);
 results.push(await execute({name:'Actual fc1c unchanged 390 pause snapshots remain failed',realReplay:true}));
 results.push(await execute({name:'Actual first pause rect with ordinary received click'}));
 results.push(await execute({name:'First dispatch unacknowledged, second received',acceptAt:2}));
 results.push(await execute({name:'Confirmation appears only after accepted second dispatch',acceptAt:2,confirmation:true}));
 results.push(await execute({name:'Missing exact public return label cannot pass',wrongText:true}));
 const negatives=[];
 for(const [name,before,after,options]of [
  ['No retry after first unacknowledged dispatch','length<3','length<1',{acceptAt:2}],
  ['Zero-duration mouse click','delayMs:120','delayMs:0',{}],
  ['Trust dispatch without observed hall',"if(state.mode==='hangar'&&!state.loadingFlow?.active)",'if(actions.length>0)',{realReplay:true}],
 ]){assert(actual.includes(before));await assert.rejects(()=>execute({name,...options},actual.replace(before,after)));negatives.push(name);}
 for(const name of paths)assert.equal(sha(fs.readFileSync(path.join(evidence,name))),original[name]);
 const report={result:'PASS',originalResult:'FAIL',actualSnapshots:states.length,actualPauseSnapshots:paused.length,
  originalHashes:original,runnerSha256:sha(fs.readFileSync(runner)),tests:results,rejectedMutations:negatives,
  boundary:'Offline execution of actual QA return function over preserved fc1c observations and controlled input delivery. Unchanged real telemetry remains FAIL. No browser, Native, production changes, natural hold completion or performance acceptance. Original log does not prove why first input had no visible effect.'};
 const output=path.join(root,'docs/migration/evidence/story-public-return-offline.json');fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
