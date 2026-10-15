import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
if(baseline.commit!=='2b169a9964645f5f346a7158bcb14447f040814a')throw Error('Unexpected frozen source');
const file='three/src/drive/testDrive.js',reticleFile='shared/ui/reticle.js';
const source=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
const reticle=fs.readFileSync(path.join(baseline.snapshot,reticleFile),'utf8');
const THREE=await import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')));
function Slice(text,start,end){const a=text.indexOf(start),b=text.indexOf(end,a);if(a<0||b<0)throw Error('Frozen method missing '+start);return text.slice(a,b);}
const hull=source.match(/const hullOf = .*?; \/\//)?.[0].replace(/; \/\/$/,';');
const drive=vm.runInNewContext(hull+'\n({'+Slice(source,'\t_focusPick(','\n\t// 其它单位头顶的标记').trim().replace('\n\t_aimTarget(','\n\t,_aimTarget(')+'})',{_u:new THREE.Vector3(),_v:new THREE.Vector3()});
const render=vm.runInNewContext(Slice(reticle,'const f1 =','// 中间准星')+'\n({'+Slice(reticle,'\t_ghost(','\n\t// 头顶标记').trim()+','+Slice(reticle,'\t_target(','\n\t// 飞弹搜索区').trim()+'})');
const cases=[];const layouts=[[1920,1080],[2400,1080],[840,378]];
for(const [w,h]of layouts){
 const cam=new THREE.PerspectiveCamera(48,w/h,.1,2600);cam.position.set(120,7,33);cam.lookAt(120,7,34);cam.updateMatrixWorld();
 const pos=(fraction,depth=100)=>[120-fraction*h*depth/(h/2/Math.tan(48*Math.PI/360)),7,33+depth];
 const defs={me:{team:'player',pos:pos(0,1)},a:{team:'enemy',pos:pos(.12)},b:{team:'enemy',pos:pos(.04)},friend:{team:'player',pos:pos(0)},neutral:{team:'neutral',pos:pos(.02)},dead:{team:'enemy',pos:pos(0),alive:false}};
 const scenarios=[
  {name:'new within thirteen percent',units:['a']},
  {name:'closest enemy wins',units:['a','b']},
  {name:'new outside thirteen percent',units:['a'],move:{a:pos(.131)}},
  {name:'keep within twenty-five percent wins over closer',units:['a','b'],keep:'a',move:{a:pos(.249)}},
  {name:'keep outside twenty-five percent repicks',units:['a','b'],keep:'a',move:{a:pos(.251)}},
  {name:'friends dead and own player excluded',units:['friend','dead','me','a']},
  {name:'neutral eligible',units:['friend','neutral','a']},
  {name:'direct enemy overrides closer screen target',units:['b'],direct:'a'},
  {name:'direct friendly falls back to focus',units:['b'],direct:'friend'},
  {name:'direct dead falls back to focus',units:['b'],direct:'dead'},
  {name:'direct neutral accepted',units:['b'],direct:'neutral'},
  {name:'new exact one-thousand metres eligible',units:['a'],move:{a:pos(0,1000)}},
  {name:'new beyond one-thousand metres excluded',units:['a'],move:{a:pos(0,1000.01)}},
  {name:'kept target beyond one-thousand metres remains',units:['a','b'],keep:'a',move:{a:pos(.1,1200)}},
  {name:'new behind camera excluded',units:['a'],move:{a:pos(0,-100)}},
  {name:'kept beyond far clip excluded',units:['a'],keep:'a',move:{a:pos(0,2700)}},
  {name:'direct offscreen target still produces source target',units:[],direct:'a',move:{a:pos(1.5)}},
  {name:'nonscope does not proximity pick',units:['b'],scope:false},
  {name:'nonscope direct enemy tracks',units:['b'],scope:false,direct:'a'},
  {name:'nonscope half-second hold persists',units:[],scope:false,hold:'a',holdT:.5,dt:.49},
  {name:'nonscope half-second hold expires',units:[],scope:false,hold:'a',holdT:.5,dt:.51},
  {name:'dead held reference is hidden',units:[],scope:false,hold:'dead',holdT:.5},
  {name:'wall-hit aim has no additional LOS test',units:['a'],wall:true},
  {name:'combatUnits list overrides units',units:['a'],combatUnits:['b']}
 ];
 for(const scenario of scenarios){
  const actors=Object.fromEntries(Object.entries(defs).map(([id,d])=>[id,{id,name:id,alive:d.alive!==false,team:d.team,pos:scenario.move?.[id]||d.pos,life:.67,spec:{bounds:{min:[-2,-1,-3],max:[2,1,3]},weapons:[1,2,3]}}]));
  const state={scope:scenario.scope!==false,player:actors.me,camera:cam,sim:{units:scenario.units.map(id=>actors[id])},focusRef:actors[scenario.keep],aimRef:actors[scenario.direct],aimHold:actors[scenario.hold],aimHoldT:scenario.holdT,_focusPick:drive._focusPick};
  if(scenario.combatUnits)state.sim.combatUnits=scenario.combatUnits.map(id=>actors[id]);
  const target=drive._aimTarget.call(state,scenario.dt??1/60,w,h);
  cases.push({name:scenario.name,w,h,camera:{pos:cam.position.toArray(),fov:48,near:.1,far:2600},actors:Object.values(actors),scenario,expected:{ref:target?.ref.id??null,focus:state.focusRef?.id??null,hold:state.aimHold?.id??null,holdT:state.aimHoldT??null,target:target?{x:target.x,y:target.y,size:target.size,distance:target.dist,hp:target.health,arms:target.arms}:null}});
 }
}
const plates=[];
for(const k of[1,.3906])for(const hp of[1,.29,.15])for(const arms of[3,1,0])for(const now of[219,220,439,440]){
 const host={innerHTML:''},ref={};const state={k,w:1920,h:1080,cx:960,cy:540,q:()=>host,acq:{ref,t0:-1000},_ghost:render._ghost};
 render._ghost.call(state,ref,1,now-16);
 const target={ref,x:960,y:540,size:180*k,name:'TARGET',dist:185.4,health:hp,arms,focus:true};
 render._target.call(state,target,now,null);
 const texts=[...host.innerHTML.matchAll(/<text x="([^"]+)" y="([^"]+)" class="([^"]+)" style="font-size:([\d.]+)px">(.*?)<\/text>/gs)].map(m=>({x:+m[1],y:+m[2],class:m[3],size:+m[4],text:m[5].replace(/<[^>]*>/g,'')}));
 const segments=[...host.innerHTML.matchAll(/class="seg([^"]*)"/g)].map(m=>m[1].trim());
 plates.push({k,hp,arms,time:now/1000,half:90*k,expected:{texts,segments,blink:/class="tlow"/.test(host.innerHTML),svg:host.innerHTML}});
}
const output={baseline:baseline.commit,inputs:[{file,sha256:createHash('sha256').update(source).digest('hex')},{file:reticleFile,sha256:createHash('sha256').update(reticle).digest('hex')}],cases,plates};
fs.writeFileSync(path.join(root,'tools/migration/source-target-focus.json'),JSON.stringify(output,null,2));
console.log(JSON.stringify({result:'PASS',baseline:baseline.commit,cases:cases.length,plates:plates.length,inputs:output.inputs}));
