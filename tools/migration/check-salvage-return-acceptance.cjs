const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {assertReturnedSurface,assertLobbyRoundTrip,assertResultInReturnedHall,assertResultAcknowledgement}=require('./salvage-return-acceptance.cjs');
const checks=[];const check=(ok,name)=>{assert.ok(ok,name);checks.push(name);};
const overlay={present:true,className:'VoxDebugPanel',owner:'app.debugPanel',registeredName:'vox-debug',open:false,disposed:false,stackAvailable:true,stackTruncated:false};overlay.stack=[{...overlay}];
const state=()=>({mode:'hangar',lobby:'salvage',hallGeneration:7,blueprint:'actual selected mech',mouse:{overlay:true},overlayState:structuredClone(overlay),salvage:{tab:'loadout'},dialog:false,loadingFlow:{active:false}});
const a=state(),b=state(),c=state();b.salvage.tab='garage';
check(assertReturnedSurface(a).status==='SURFACE_OBSERVED_INPUT_PENDING','Nonempty owned debug is not a completed input proof');
check(assertLobbyRoundTrip(a,b,c).status==='PASS','Two distinct observed garage/loadout transitions complete input contract');
const none=state();none.mouse.overlay=false;none.overlayState={present:false,stack:[]};check(assertReturnedSurface(none).status.endsWith('PENDING'),'No overlay still requires input proof');
const perf=state();perf.overlayState.stack=[{className:'Panel',owner:'main.performancePanel',pointerEvents:'box-none',hitTestBound:true,visible:true,panelVisible:true,disposed:false}];
check(assertReturnedSurface(perf).status.endsWith('PENDING'),'Actual owned performance root still requires real public input proof');
for(const [label,mutate]of [
 ['unknown Panel',s=>s.overlayState.stack[0].owner='unknown'],
 ['missing performance hit test',s=>delete s.overlayState.stack[0].hitTestBound],
 ['blocking performance root',s=>s.overlayState.stack[0].pointerEvents='auto'],
 ['hidden performance owner',s=>s.overlayState.stack[0].panelVisible=false],
 ['hidden performance root',s=>s.overlayState.stack[0].visible=false],
 ['disposed performance owner',s=>s.overlayState.stack[0].disposed=true],
 ['modal under performance root',s=>s.overlayState.stack.unshift({className:'VoxSourceModal',owner:'unknown'})]]){
 const bad=structuredClone(perf);mutate(bad);assert.throws(()=>assertReturnedSurface(bad));check(true,'Reject '+label);
}
const resultState=state();resultState.dialog=true;resultState.salvageInventory={items:{scrap:4},credits:8000,lastRun:'original-run'};
resultState.salvageReturn={runId:'original-run',shown:true,committed:true,result:{ok:false,title:'放弃行动'},release:Object.fromEntries(['disposed','scene','world','combat','effects','view','hud'].map(k=>[k,true]))};
check(assertResultInReturnedHall(resultState).status==='HALL_RESULT_ACK_PENDING','Hall result requires explicit original trial disposal before acknowledgement');
const acknowledged=state();acknowledged.salvageInventory=structuredClone(resultState.salvageInventory);
check(assertResultAcknowledgement(resultState,acknowledged).status==='ACK_CLOSED_IN_HALL','Acknowledgement only closes hall modal and preserves economy');
for(const [label,mutate]of [
 ['result before hall',s=>s.mode='trial'],['result under loading',s=>s.loadingFlow.active=true],
 ['live driver behind result',s=>s.salvageRun={}],['unshown detached result',s=>s.salvageReturn.shown=false],
 ['uncommitted natural result',s=>s.salvageReturn.committed=false],['missing disposal evidence',s=>delete s.salvageReturn.release],
 ...['disposed','scene','world','combat','effects','view','hud'].map(key=>['unreleased '+key,s=>s.salvageReturn.release[key]=false])]){
 const bad=structuredClone(resultState);mutate(bad);assert.throws(()=>assertResultInReturnedHall(bad));check(true,'Reject '+label);
}
const double=structuredClone(acknowledged);double.salvageInventory.items.scrap++;
assert.throws(()=>assertResultAcknowledgement(resultState,double),/economy/);check(true,'Reject second settlement during acknowledgement');
const reloaded=structuredClone(acknowledged);reloaded.hallGeneration++;
assert.throws(()=>assertResultAcknowledgement(resultState,reloaded),/reload hall/);check(true,'Reject reload hidden inside acknowledgement');
const unobserved=structuredClone(resultState);delete unobserved.hallGeneration;
assert.throws(()=>assertResultAcknowledgement(unobserved,acknowledged),/generation/);check(true,'Reject missing actual hall generation evidence');
for(const [label,mutate]of [
 ['open owned result dialog',s=>s.dialog=true],['live trial survives return',s=>s.salvageRun={result:{}}],
 ['missing actual identity',s=>delete s.overlayState],['unknown lookalike owner',s=>s.overlayState.stack[0].owner='unknown'],
 ['opened debug panel',s=>s.overlayState.stack[0].open=true],['disposed debug page',s=>s.overlayState.stack[0].disposed=true],
 ['hidden modal under debug',s=>s.overlayState.stack.unshift({className:'VoxSourceModal'})],['truncated unknown stack',s=>s.overlayState.stackTruncated=true],
 ['no real stack API',s=>s.overlayState.stackAvailable=false],['legacy flag mismatch',s=>s.mouse.overlay=false],
 ['still loading',s=>s.loadingFlow.active=true],['wrong return lobby',s=>s.lobby='arena']]){
  const s=state();mutate(s);assert.throws(()=>assertReturnedSurface(s));check(true,'Reject '+label);
 }
assert.throws(()=>assertLobbyRoundTrip(a,a,c),/garage/);check(true,'Ignored garage mouse click cannot pass');
const changed=state();changed.blueprint='another vehicle';assert.throws(()=>assertLobbyRoundTrip(a,b,changed),/preserved vehicle/);check(true,'Input proof cannot replace selected vehicle');
const old=JSON.parse(fs.readFileSync('docs/migration/evidence/salvage-natural-manifest-e1bd07fa-2026-10-16T16-21-02-869Z/salvage-natural-web.json'));
assert.throws(()=>assertReturnedSurface(old.lastState),/identity/);check(old.result==='RUNNING'&&old.shutdown==='PENDING','Old blocked evidence stays uncertified without overlay identity and clicks');
const baseline=JSON.parse(fs.readFileSync('docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'));
const sourcePath='shared/ui/salvageRunHud.js',source=fs.readFileSync(path.join(baseline.snapshot,sourcePath),'utf8'),sourceHash=crypto.createHash('sha256').update(source).digest('hex');
assert.equal(sourceHash,baseline.files[sourcePath].sha256,'Actual frozen H5 source hash');
const start=source.indexOf('export function showSalvageResult(');assert.ok(start>=0);
const resultFunction=new Function('RARITY','ITEMS','esc','fmt',source.slice(start).replace('export function','function')+'\nreturn showSalvageResult;')([],{},s=>s,s=>String(s));
for(const ok of [false,true]){
 let clicks=0,html='',listener=null;
 const ui={openModal(text){html=text;return {querySelector(selector){assert.equal(selector,'[data-x="ok"]');return {addEventListener(event,fn){assert.equal(event,'click');listener=fn;}};}};},closeModal(){clicks++;}};
 resultFunction(ui,{ok,title:ok?'撤离':'放弃行动',items:[],value:0,lost:0,time:30,kills:0,opened:0});
 check(html.includes('回大厅')&&html.includes(ok?'撤离成功':'行动失败'),'Actual frozen H5 '+(ok?'success':'loss')+' modal uses original acknowledgement');
 listener();check(clicks===1,'Actual frozen H5 acknowledgement closes its modal exactly once');
}
const report={result:'PASS',checks:checks.length,labels:checks,sourceCommit:baseline.commit,sourceHashes:{[sourcePath]:sourceHash},boundary:'Actual frozen H5 result function with DOM adapters and return evidence contracts/negative controls. No browser or public input acceptance.'};
fs.writeFileSync('docs/migration/evidence/salvage-return-acceptance-offline.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
