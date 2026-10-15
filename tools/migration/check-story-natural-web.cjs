const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const memoryProbe=require('./web-memory-probe.cjs');
const levelNo=Number(process.env.VOX_STORY_LEVEL||1),limit=Number(process.env.VOX_STORY_SECONDS||360);
const entryOnly=process.env.VOX_STORY_ENTRY_ONLY==='1';
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4283);
const level=require('../../assets/Story/Mission/Level'+levelNo+'.json').level;
const layout=require('../../assets/'+(levelNo===5?'EnginePit':'Crater')+'/Layout.json');
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
function roadRoute(from,to){
 const nodes=layout.nav.nodes,ids=Object.keys(nodes),adj=new Map(ids.map(id=>[id,[]]));
 for(const [a,b,width]of layout.nav.edges){if(!nodes[a]||!nodes[b])continue;const cost=Math.hypot(...nodes[a].map((v,i)=>v-nodes[b][i]));adj.get(a).push([b,cost,width]);adj.get(b).push([a,cost,width]);}
 const near=p=>ids.reduce((best,id)=>flat(nodes[id],p)+Math.abs(nodes[id][1]-p[1])*5<flat(nodes[best],p)+Math.abs(nodes[best][1]-p[1])*5?id:best,ids[0]);
 const start=near(from),end=near(to),cost=new Map([[start,0]]),prev=new Map(),done=new Set();
 while(done.size<ids.length){let current;for(const [id,d]of cost)if(!done.has(id)&&(!current||d<cost.get(current)))current=id;if(!current||current===end)break;done.add(current);for(const [id,w]of adj.get(current)){const d=cost.get(current)+w;if(d<(cost.get(id)??Infinity)){cost.set(id,d);prev.set(id,current);}}}
 if(!cost.has(end))return [];
 const route=[];for(let id=end;id;id=prev.get(id)){route.unshift({id,pos:nodes[id]});if(id===start)break;}
 return route;
}
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert.ok(identity.qa);
 const out=path.resolve('docs/migration/evidence/story-natural-s'+levelNo+'-'+path.basename(identity.manifest_path,'.json')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log('Evidence: '+out);
 const report={identity,level:level.id,entryOnly,checks:[],errors:[],probeErrors:[],samples:[],transitions:[],startedAt:new Date().toISOString(),
  boundary:'Actual source story selection and keyboard/mouse operation. F8 reads state only. No teleport, phase/clock/HP changes, enemy destruction, voice skipping or synthetic completion. Automated road following may fail; that alone is not proof of a gameplay defect. Functional run, not isolated performance or physical mobile evidence.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1600,height:900}});let state,seq=0;const held=new Set();let firing=false;
 page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;}catch(e){report.probeErrors.push(e.message);}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);});
 page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
 async function wait(fn,label,timeout=240000){const start=Date.now();let probe=0;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>timeout)throw Error('Timeout '+label);if(Date.now()-probe>800){probe=Date.now();await page.keyboard.press('F8');}await sleep(100);}return state;}
 async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'fresh state',20000);}
 async function keys(next=[]){for(const key of held)if(!next.includes(key)){await page.keyboard.up(key);held.delete(key);}for(const key of next)if(!held.has(key)){await page.keyboard.down(key);held.add(key);}}
 async function fire(value){if(value===firing)return;firing=value;if(value)await page.mouse.down();else await page.mouse.up();}
 async function click(text){await dump();await wait(s=>s.widgets.some(w=>w.text===text&&w.rect[2]>0&&w.rect[3]>0),'button '+text,30000);const b=state.widgets.find(w=>w.text===text),[x,y,w,h]=b.rect;await page.mouse.click((x+w/2)/state.width*1600,(y+h/2)/state.height*900);}
 async function shot(name){report.memory??=[];report.memory.push({stage:name,...await memoryProbe.read(page)});await page.screenshot({path:path.join(out,name+'.png'),timeout:10000});}
 const check=(value,label)=>{assert.ok(value,label);report.checks.push(label);};
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'hall');report.initialMemory=await memoryProbe.install(page);await click('出战');await click('剧情模式');
  await wait(s=>s.tab==='story'&&s.story?.ready,'story selector');await click(level.no+'  '+level.name);await click('开始任务');
  await wait(s=>s.mode==='trial'&&s.story?.id===level.id&&!s.loadingFlow.active,'real mission');await page.mouse.click(800,450);await wait(s=>s.pointer.captured,'actual pointer capture');
  check(state.sceneVisible&&state.loadingFlow.warmFrames>=2,'real mission revealed after source loading and rendered warmup');await shot('entered');
  if(entryOnly){check(state.story.alive&&state.vehicle,'source mission entry has live player vehicle and original rules');report.result='PASS';report.boundary+=' Entry-only run: does not claim mission completion.';}
  const begun=Date.now();let transition='',route=[],best=Infinity,stuckAt=Date.now(),reverseUntil=0,mouseX=800,mouseY=450;
  while(!entryOnly&&Date.now()-begun<limit*1000){
   await dump();const s=state.story;if(!s)throw Error('Story session disappeared');
   const current=s.step+':'+s.phase+':'+(s.cap?.phase||'')+':'+(s.boss?.flow||'');
   if(current!==transition){transition=current;route=[];best=Infinity;stuckAt=Date.now();report.transitions.push({at:Date.now()-begun,story:structuredClone(s),vehicle:structuredClone(state.vehicle)});await shot('stage-'+report.transitions.length);}
   report.samples.push({at:Date.now()-begun,story:structuredClone(s),vehicle:structuredClone(state.vehicle),keys:[...held],firing});
   if(s.finished){check(true,'complete mission reached through natural commands and original rules');report.result='PASS';await shot('result');break;}
   if(s.choice){await keys();await fire(false);await page.keyboard.press('1');await sleep(500);continue;}
   if(!s.alive||!state.vehicle){await keys();await fire(false);await sleep(500);continue;}
   if(!state.pointer.captured){await page.mouse.click(800,450);await sleep(400);continue;}
   const p=state.vehicle.position,target=s.target;
   if(!target||s.boss?.cinematic){await keys();await fire(false);await sleep(500);continue;}
   const enemy=s.marker?.enemy||s.boss?.flow==='fight',distance=flat(p,target);
   if(!enemy&&!route.length&&distance>80)route=roadRoute(p,target);
   while(route.length&&flat(p,route[0].pos)<6&&Math.abs(p[1]-route[0].pos[1])<8)route.shift();
   const goal=route.length?route[0].pos:target,d=flat(p,goal),angle=wrap(Math.atan2(goal[0]-p[0],goal[2]-p[2])-state.vehicle.yaw);
   const speed=Math.abs(state.vehicle.speed||0),kind=level.steps[s.index-1]?.kind;
   if(enemy){
    const eye=[-state.camera.position[0],state.camera.position[1],state.camera.position[2]],dx=target[0]-eye[0],dz=target[2]-eye[2];
    const delta=wrap(-Math.atan2(dx,dz)-state.camera.yaw*Math.PI/180);
    const wantedPitch=-Math.atan2(target[1]+2-eye[1],Math.max(1,Math.hypot(dx,dz)))*180/Math.PI;
    mouseX+=Math.max(-300,Math.min(300,delta/.0024));mouseY+=Math.max(-200,Math.min(200,(wantedPitch-state.camera.pitch)/(180/Math.PI*.002)));
    await page.mouse.move(mouseX,mouseY);await fire(true);
   }else await fire(false);
   if(!route.length&&d<6&&Math.abs(p[1]-target[1])<18){await keys(['Space',...(['install','capture'].includes(kind)?['g']:[])]);await sleep(250);continue;}
   if(d<best-1){best=d;stuckAt=Date.now();}if(Date.now()-stuckAt>8000&&Date.now()>reverseUntil){reverseUntil=Date.now()+1800;stuckAt=Date.now();}
   const throttle=Date.now()<reverseUntil?'s':'w',steer=throttle==='s'?-angle:angle;
   const turning=Math.abs(steer)>.12?(steer>0?'a':'d'):null,desired=enemy?12:Math.min(15,Math.sqrt(d)*2);
   await keys(enemy&&distance<25||speed>desired?['Space']:[throttle,...(turning?[turning]:[])]);await sleep(250);
  }
  if(!report.result){report.result='INCOMPLETE';report.failure='Natural command route deadline; inspect captured transitions and screenshots before attributing to game logic.';report.lastState=state;await shot('deadline');}
  await keys();await fire(false);if(!state.story?.finished)await page.keyboard.press('Escape');await page.keyboard.press('t');
  if(levelNo===5&&state.story?.finished){
   const observed=new Set();report.epilogue=[];const endingAt=Date.now();
   while(state.mode==='trial'&&Date.now()-endingAt<180000){
    await dump();const ep=state.story?.naturalEpilogueDetail;
    if(ep&&!observed.has(ep.index)){observed.add(ep.index);report.epilogue.push(structuredClone(ep));}
    if(state.mode==='hangar'&&!state.loadingFlow.active)break;await sleep(500);
   }
  }
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'actual return',180000);check(state.performance.arrayBytes===0,'natural attempt return releases terrain arrays');
 }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;
  fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));
  if(!report.errors.some(s=>/Aborted\(OOM\)|renderer crashed/i.test(s)))await shot('failure').catch(()=>{});}
 finally{report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));await Promise.race([browser.close().catch(()=>{}),sleep(5000)]);}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,transitions:report.transitions.length,out}));if(report.result!=='PASS')process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
