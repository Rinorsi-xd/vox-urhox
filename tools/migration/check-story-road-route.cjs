const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const {createRequire}=require('node:module');
const filename=path.join(__dirname,'check-story-natural-web.cjs'),source=fs.readFileSync(filename,'utf8');
function load(text){
 const module={exports:{}};
 vm.runInNewContext(text,{require:createRequire(filename),module,exports:module.exports,__filename:filename,__dirname,process,console,Buffer,setTimeout,structuredClone},{filename});
 return module.exports;
}
let checks=0;
const check=(value,label)=>{assert.ok(value,label);checks++;};
function verify(api){
 const roads=JSON.parse(fs.readFileSync(path.join(__dirname,'../../assets/Crater/Layout.json'),'utf8'));
 api.loadRoadTerrain(roads);
 check(roads.terrain.heights.length===103041,'source dataParts first index reconstructs all authored heights');
 const from=[-30.242109298706055,4.737438201904297,-222.00038146972656],target=[-190,-12,0];
 const legacy=api.roadRoute(from,target,roads);
 check(legacy[0].id==='bEt','actual prior S4 sample reproduces legacy bad nearest entry');
 let diagnostic;
 const route=api.roadRoute(from,target,roads,{terrainConnector:true,onConnector:value=>{diagnostic=value;}});
 check(route[0].id==='bP','actual S4 route now starts at selected terrain-reachable pad entry');
 check(diagnostic.result==='SELECTED'&&diagnostic.selected.id==='bP','selected connector is recorded');
 check(diagnostic.rejected.some(x=>x.id==='bEt'&&x.reason==='steep-terrain'&&x.maxSlopeDeg>15),'actual rejected 28-degree ditch connector is recorded');
 check(route.at(-1).id===legacy.at(-1).id,'original target-node selection retained');
 for(let i=1;i<route.length;i++)check(roads.nav.edges.some(([a,b])=>a===route[i-1].id&&b===route[i].id||b===route[i-1].id&&a===route[i].id),'remaining route uses original authored edges');
 let rejected;
 const failure=api.roadRoute(from,target,roads,{terrainConnector:true,connectorLimits:{maxDistance:1},onConnector:value=>{rejected=value;}});
 check(failure===null,'unreachable terrain entry returns explicit failure instead of legacy nearest fallback');
 check(rejected.result==='NO_REACHABLE_ENTRY'&&rejected.selected===null&&rejected.rejected.length>0,'failed connector retains rejected-candidate diagnostics');
 const missing=structuredClone(roads);delete missing.terrain.heights;
 check(api.roadRoute(from,target,missing,{terrainConnector:true})===null,'missing terrain cannot silently fall back');
 check(api.roadRoute(from,target,roads).map(x=>x.id).join(',')===legacy.map(x=>x.id).join(','),'default routes remain unchanged for S1 S2 and S5');
 return {route:route.map(x=>x.id),diagnostic,rejected};
}
const result=verify(load(source)),mutations={
 'skip source first offset':['part.first-1+i','i'],
 'ignore selected connector':['start=selected.id;','start=near(from);'],
 'restore unreachable nearest fallback':['if(!selected)return null;','if(!selected)return roadRoute(from,to,roads);'],
 'disable entry terrain screening':['if(options.terrainConnector){','if(false&&options.terrainConnector){'],
};
const rejectedMutations=[];
for(const [label,[before,after]]of Object.entries(mutations)){
 assert(source.includes(before),'mutation anchor '+label);
 assert.throws(()=>verify(load(source.replace(before,after))),'negative control '+label);rejectedMutations.push(label);
}
check(source.includes('terrainConnector:levelNo===4'),'runtime opts into terrain entry only for S4');
check(source.includes("if(route===null)throw Error('S4 natural navigation has no terrain-reachable road entry"),'runtime stops explicitly when no reachable entry exists');
check(source.includes("sharedGpu:process.env.VOX_QA_SHARED_GPU==='1'"),'parallel GPU functional runs are explicitly labelled');
const sha=text=>crypto.createHash('sha256').update(text).digest('hex');
const assetFiles=['assets/Crater/Layout.json',...JSON.parse(fs.readFileSync(path.join(__dirname,'../../assets/Crater/Layout.json'),'utf8')).dataParts.parts.filter(p=>p.field==='heights').map(p=>'assets/'+p.path)];
const inputs=Object.fromEntries([...['check-story-natural-web.cjs','story-road-connector.cjs','check-story-road-route.cjs'].map(name=>'tools/migration/'+name),...assetFiles].map(name=>[name,sha(fs.readFileSync(path.join(__dirname,'../..',name)))]));
const report={result:'PASS',checks,rejectedMutations,toolSha256:sha(source),testSha256:sha(fs.readFileSync(__filename)),inputs,...result,boundary:'Offline integration of actual S4 observed position and authored terrain into the natural driving tool. No browser, GPU, fresh driving, static-object clearance or mission completion acceptance. Legacy failed S4 evidence is unchanged.'};
fs.writeFileSync(path.join(__dirname,'../../docs/migration/evidence/story-road-route-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
