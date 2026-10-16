// Evaluate frozen ES modules without rewriting imports or copying AI formulas.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'),'utf8'));
const hashes={};const box=vm.createContext({console});
function read(name){const bytes=fs.readFileSync(path.join(baseline.snapshot,name));const hash=crypto.createHash('sha256').update(bytes).digest('hex');if(hash!==baseline.files[name].sha256)throw Error('Frozen source drift '+name);hashes[name]=hash;return bytes.toString('utf8');}
class Vector3{}
const imported=['BattleFlowMix','sfx','cameraListener','Blueprint','CarUnit','createEnemyBlueprint','centeredSpawn','findMatch','recordResult','codename','MatchHud','MatchLobby','TIERS','ZoneMarker','Reactor','PayloadCart','RouteLine','mapShot','prepareMapShot','MatchIntro','introSeen','markIntroSeen','MvpShow','MatchVoice','Radio','MATCH_FOUND_VOICE','MATCH_FOUND_SFX','Vector3'];
const stubs=new vm.SyntheticModule(imported,function(){for(const name of imported)this.setExport(name,name==='Vector3'?Vector3:function(){});},{context:box});
async function main(){
 const driver=new vm.SourceTextModule(read('shared/ai/driver.js'),{context:box});await driver.link(()=>{throw Error('Unexpected driver import')});await driver.evaluate();
 const rules=new vm.SourceTextModule(read('shared/battle/match.js'),{context:box});await rules.link(()=>{throw Error('Unexpected rules import')});await rules.evaluate();
 const shield=new vm.SourceTextModule(read('shared/battle/shieldQuery.js'),{context:box});await shield.link(()=>{throw Error('Unexpected shield import')});await shield.evaluate();
 const source=new vm.SourceTextModule(read('three/src/battle/matchSession.js')+'\nexport { EliminationMode, ConquestMode, EscortMode };',{context:box});
 await source.link(name=>name==='@shared/ai/driver.js'?driver:name==='@shared/battle/match.js'?rules:name==='@shared/battle/shieldQuery.js'?shield:stubs);await source.evaluate();
 const api=source.namespace;
 const copy=v=>JSON.parse(JSON.stringify(v));
 function unit(row){return {...copy(row),pos:copy(row.pos||[0,0,0]),alive:row.alive!==false,health:row.health??1,team:row.team||'red',vehicle:{body:{id:row.id}},spec:{bounds:{radius:3}}};}
 const pickCases=[];
 function pickCase(name,rows,steps,mode='elimination'){
  const units=[unit({id:'self',team:'blue',pos:[0,8,0]}),...rows.map(unit)];const calls=[];
  const sim={time:0,castRay(from,dir,length,exclude){
   const end=from.map((n,i)=>n+dir[i]*length);const target=units.find(u=>Math.hypot(u.pos[0]-end[0],u.pos[1]+1-end[1],u.pos[2]-end[2])<1e-6);if(!target)throw Error('Missing ray endpoint');
   calls.push({from:[...from],to:end,length,exclude:exclude.id,target:target.id});
   if(!target.hit||target.hit.kind==='none')return null;
   return {dist:target.hit.margin!==undefined?length+target.hit.margin:target.hit.dist,owner:{ref:target.hit.kind==='target'?target:units[0]}};
  }};
  const zones={blue:{pos:[0,0,0],rx:10,rz:10,h:20},red:{pos:[100,0,0],rx:10,rz:10,h:20}};
  const session=Object.assign(Object.create(api.MatchSession.prototype),{units:units.map(u=>({unit:u})),drive:{sim},rules:{shield:{blue:true,red:true}}});
  const mx=mode==='conquest'?Object.assign(Object.create(api.ConquestMode.prototype),{s:session,base:{blue:{zone:zones.blue},red:{zone:zones.red}}}):{};session.mx=mx;
  const e={unit:units[0]};const expected=[];
  for(const step of steps){sim.time=step.time;for(const patch of step.patches||[]){const u=units.find(u=>u.id===patch.id);Object.assign(u,copy(patch));}if(step.shield)session.rules.shield=copy(step.shield);const before=e.pick;const offset=calls.length;const pick=session._pick(e);expected.push({unit:pick.unit?.id||false,seen:pick.seen,until:pick.until,sameCache:pick===before,calls:calls.slice(offset)});}
  pickCases.push({name,rows,steps,mode,expected});
 }
 const once=[{time:0}];
 pickCase('empty',[],[{time:0},{time:.1}]);
 pickCase('visible-priority',[{id:'near-hidden',pos:[10,8,0],hit:{dist:1}},{id:'far-visible',pos:[100,8,0]}],once);
 pickCase('hurt-weight',[{id:'healthy',pos:[50,8,0]},{id:'hurt',pos:[80,8,0],health:0}],once);
 pickCase('entry-order-tie',[{id:'first',pos:[50,8,0]},{id:'second',pos:[-50,8,0]}],once);
 for(const d of [0,.001,.009,.01,259.999,260,260.001])pickCase('visibility-range-'+d,[{id:'enemy',pos:[d,7,0]}],once);
 for(const margin of [-.600001,-.6,-.599999])pickCase('hit-distance-'+margin,[{id:'enemy',pos:[30,8,40],hit:{kind:'other',margin}}],once);
 pickCase('target-owner-hit',[{id:'enemy',pos:[50,8,0],hit:{kind:'target',dist:1}}],once);
 pickCase('cache-expiry',[{id:'one',pos:[50,8,0]},{id:'two',pos:[80,8,0]}],[{time:0},{time:.499999,patches:[{id:'two',pos:[1,8,0]}]},{time:.5},{time:.9,patches:[{id:'two',alive:false}]},{time:1}]);
 pickCase('cache-empty-rechecks',[{id:'enemy',pos:[50,8,0],alive:false}],[{time:0},{time:.1,patches:[{id:'enemy',alive:true}]}]);
 pickCase('skip-team-and-dead',[{id:'friend',team:'blue',pos:[1,8,0]},{id:'dead',pos:[2,8,0],alive:false},{id:'foe',pos:[30,8,0]}],once);
 pickCase('shield-ignore',[{id:'protected',pos:[100,5,0]},{id:'outside',pos:[80,5,0]}],[{time:0},{time:.5,shield:{blue:true,red:false}}],'conquest');
 let seed=782341;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 for(let i=0;i<300;i++){const rows=[];for(let n=0;n<8;n++)rows.push({id:'e'+n,team:random()<.2?'blue':'red',alive:random()>.2,pos:[(random()-.5)*700,random()*50,(random()-.5)*700],health:random(),hit:random()<.5?{kind:'other',margin:-random()*20}:undefined});pickCase('random-'+i,rows,[{time:random()*100}]);}
 const goals=[];
 function norm(goal){return goal.target.unit?{unit:goal.target.unit.id,passive:!!goal.passive,charge:!!goal.charge}:{pos:[...goal.target.pos],radius:goal.target.radius,shoot:!!goal.target.shoot,passive:!!goal.passive,charge:!!goal.charge};}
 const points=[{id:'A',pos:[-100,4,20],radius:22},{id:'B',pos:[100,5,-20],radius:22},{id:'C',pos:[0,6,0],radius:22}];
 const pathNodes=[[0,3,0],[0,3,300]];
 function goalCase(input){
  const me=unit({id:'self',team:input.team,pos:input.pos||[0,8,0]});const foe=input.distance===null?null:unit({id:'foe',team:input.team==='blue'?'red':'blue',pos:[input.distance,8,0]});
  const session={drive:{layout:{nav:{nodes:{iC1:[0,6,0]}}},sim:{time:input.now??3}},rules:{t:input.t??0,sudden:!!input.sudden,s:90,attack:input.attack||'blue',shield:{blue:true,red:true},points:points.map(p=>({id:p.id,owner:null,count:{blue:0,red:0}})),score:{blue:input.score??0,red:input.score??0}}};
  const entry={unit:me,member:{role:input.role},driver:{}};session.units=[entry];
  const proto={elimination:api.EliminationMode,conquest:api.ConquestMode,escort:api.EscortMode}[input.mode].prototype;
  const mx=Object.assign(Object.create(proto),{s:session,center:[0,6,0],points:copy(points),base:{blue:{reactor:{aim:[-400,30,0]}},red:{reactor:{aim:[400,30,0]}}},assignAt:{},cart:{pos:[0,3,90]},path:copy(pathNodes),cum:[0,300],length:300});
  const expected=norm(mx.goal(entry,{unit:foe,seen:!!input.seen}));goals.push({name:'goal-'+goals.length,...input,expected});
 }
 for(const mode of ['elimination','conquest','escort'])for(const team of ['blue','red'])for(const role of ['assault','heavy','hover','sniper'])for(const seen of [false,true])for(const distance of [null,59.999,60,89.999,90,99.999,100,129.999,130,259.999])for(const t of [40,40.000001])goalCase({mode,team,role,seen,distance,t});
 goalCase({mode:'elimination',team:'blue',role:'assault',distance:500,seen:true,sudden:true});
 const assignments=[];
 for(const score of [0,99.999,100,101])for(const shieldDown of [false,true])for(const shuffled of [false,true]){
  const rows=[{id:'assault',team:'blue',role:'assault',pos:[-90,8,20]},{id:'hover',team:'blue',role:'hover',pos:[90,8,-20]},{id:'sniper',team:'blue',role:'sniper',pos:[0,8,0]},{id:'heavy',team:'blue',role:'heavy',pos:[0,8,0]},{id:'dead',team:'blue',role:'heavy',pos:[0,8,0],alive:false},{id:'player',team:'blue',role:'heavy',pos:[0,8,0],driver:false}];
  const entries=rows.map(row=>({unit:unit(row),member:{role:row.role},driver:row.driver===false?null:{}}));
  const states=points.map((p,i)=>({id:p.id,owner:i===0?'blue':i===1?'red':null,count:{blue:0,red:i===0?1:0}}));if(shuffled)states.reverse();
  const session={units:entries,drive:{sim:{time:0}},rules:{score:{blue:score,red:0},shield:{blue:true,red:!shieldDown},points:states}};
  const mx=Object.assign(Object.create(api.ConquestMode.prototype),{s:session,points:copy(points),base:{blue:{reactor:{aim:[-400,30,0]}},red:{reactor:{aim:[400,30,0]}}},assignAt:{}});
  mx._assign('blue');const expected=entries.map(e=>({id:e.unit.id,job:e.job||false}));
  assignments.push({name:'assign-'+score+'-'+shieldDown+'-'+shuffled,rows,states,score,shieldDown,expected,until:mx.assignAt.blue});
 }
 const assignmentCache=[];
 for(const team of ['blue','red']){
  const rows=[{id:'heavy',team,role:'heavy',pos:[-90,8,20]},{id:'sniper',team,role:'sniper',pos:[90,8,-20]},{id:'assault',team,role:'assault',pos:[0,8,0]}];
  const entries=rows.map(row=>({unit:unit(row),member:{role:row.role},driver:{}}));
  const session={units:entries,drive:{sim:{time:0}},rules:{score:{blue:0,red:0},shield:{blue:true,red:true},points:points.map(p=>({id:p.id,owner:null,count:{blue:0,red:0}}))}};
  const mx=Object.assign(Object.create(api.ConquestMode.prototype),{s:session,points:copy(points),base:{blue:{reactor:{aim:[-400,30,0]}},red:{reactor:{aim:[400,30,0]}}},assignAt:{}});
  const steps=[{time:0,score:0,shield:true},{time:1.999999,score:0,shield:false},{time:2,score:0,shield:false},{time:3.999999,score:100,shield:false},{time:4,score:100,shield:false}];
  const expected=steps.map(step=>{session.drive.sim.time=step.time;session.rules.score[team]=step.score;session.rules.shield[team==='blue'?'red':'blue']=step.shield;const goal=mx.goal(entries[0],{seen:false});return {goal:norm(goal),jobs:entries.map(e=>({id:e.unit.id,job:e.job||false})),until:mx.assignAt[team]};});
  assignmentCache.push({name:'assignment-cache-'+team,team,rows,steps,expected});
 }
 process.stdout.write(JSON.stringify({sourceCommit:baseline.commit,hashes,pickCases,goals,assignments,assignmentCache,escort:rules.namespace.ESCORT}));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
