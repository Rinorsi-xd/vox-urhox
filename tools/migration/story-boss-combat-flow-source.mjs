import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const context=vm.createContext({THREE:{Vector3:class{}},Blueprint:class{},buildDrillTank:()=>({toJSON:()=>({})}),radio(){}});
const source={branch:baseline.branch,commit:baseline.commit,files:{}};
for(const [path,names] of [['three/src/battle/storyBoss.js',['FoxBoss','FOX_BOSS']],['shared/story/level5.js',['LEVEL5']]]){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`);const hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[path].sha256)throw new Error(`Frozen source drift: ${path}`);
  source.files[path]=hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')}\n${names.map(name=>`globalThis.${name}=${name};`).join('\n')}})()`,context);
}
const lines=context.LEVEL5.steps.find(s=>s.kind==='boss').lines;
function run(test){
  const calls=[];let lands=0,launches=0;
  const boss=Object.create(context.FoxBoss.prototype),pos=[0,20,0],focus={alive:true,pos:[220,0,0]};
  const body={linvel:()=>({x:5,y:-3,z:8}),setLinvel(){lands++;}};
  const player={alive:true,pos:[10,2,0]};
  Object.assign(boss,{L:lines,s:{title:'original objective'},hp:100,hpMax:100,state:test.state,time:0,t:0,phase:3,
    cool:{stomp:99,slam:test.coolSlam??9,missile:99,fire:99,sweep:99,lanes:99,ult:99},
    nodes:Array.from({length:4},()=>({broken:false})),said:new Set(),missiles:[],slams:[],ultsDone:0,
    slamT:2.4,slamTarget:[40,3,0],slamKind:test.kind,slamRing:{visible:true},
    shock:{position:{set(){}},userData:{}},_storyUntil:0,
    m:{stats:{},drive:{player,vehicle:{telemetry:{}},sim:{}},fx:{explode(){}},
      hud:{talking:false,retitle(){},banner(){},say(l,urgent,append){calls.push({lines:l,urgent,append});}}},
    unit:{pos,vehicle:{body,yaw:0,telemetry:{legContacts:0}}},
    bar:{set(){},ult(){}},_raidStep(){},_visuals(){},_impact(){},_ringGrow(){},_focus:()=>focus,_sheltered:()=>false,
    _launchMissiles(){launches++;},snap(){}});
  if(test.mode==='target'){
    boss._startUlt=function(){this._go('ult');};
    boss._startSlam=function(){this._go('slamCrouch');};
    boss._startLanes=function(){this._go('lanes');};
    boss._startSweep=function(){this._go('sweep');};
    boss._feet=()=>[0,0,0];boss._ring=()=>{};
  }
  const frames=[];
  for(const step of test.steps){
    if(step.resetState)boss.state=step.resetState;
    if(step.resetT!==undefined)boss.t=step.resetT;
    if(step.resetLaunched)boss.launched=false;
    boss.flyT=step.flightTime??0;boss.unit.vehicle.telemetry.legContacts=step.contacts??0;
    player.alive=step.alive??true;boss.m.hud.talking=step.talking??false;
    if(step.ultPending!==undefined)boss.ultPending=step.ultPending;
    if(step.cool)Object.assign(boss.cool,step.cool);
    boss.update(step.dt);
    if(test.mode==='target')frames.push({state:boss.state});
    else frames.push({state:boss.state,lands,coolSlam:boss.cool.slam,launches,calls:structuredClone(calls),storyUntil:boss._storyUntil});
  }
  return frames;
}
const cases=[];
function add(test){cases.push({test,expected:run(test)});}
for(const kind of ['hop','drill',null])for(const flightTime of [0,.5,2.159999,2.16,2.160001,3.6,3.600001]){
  for(const contacts of [0,1])for(const dt of [0,1/60,1,5]){
    add({name:`flight-${kind}-${flightTime}-${contacts}-${dt}`,mode:'physics',state:'slamAir',kind,
      steps:[{flightTime,contacts,dt}]});
  }
}
add({name:'render-stall-followed-by-physical-flight',mode:'physics',state:'slamAir',kind:'hop',steps:[
  {dt:5,flightTime:.1,contacts:1},{dt:.016,flightTime:2.16,contacts:1},{dt:.016,flightTime:2.160001,contacts:1}]});
for(const alive of [false,true])for(const trigger of ['ultPending','slam','lanes','stomp','sweep','barrage','hop']){
  const cool={stomp:99,slam:99,missile:99,sweep:99,lanes:99,ult:99};let ultPending=false;
  if(trigger==='ultPending')ultPending=true;
  if(trigger==='slam')cool.slam=0;
  if(trigger==='lanes')cool.lanes=0;
  if(trigger==='stomp')cool.stomp=0;
  if(trigger==='sweep')cool.sweep=0;
  if(trigger==='barrage')cool.missile=0;
  if(trigger==='hop')continue;
  add({name:`player-${alive}-${trigger}`,mode:'target',state:'fight',trigger,steps:[{dt:.016,alive,cool,ultPending}]});
}
for(const talking of [false,true])add({name:`barrage-first-line-${talking}`,mode:'barrage',state:'barrage',steps:[
  {dt:1.3999,talking},{dt:.0001,talking},{dt:.01,talking},
  {dt:.01,resetState:'barrage',resetT:1.4,resetLaunched:true,talking}]});
console.log(JSON.stringify({source,cases,retiredBarrageAbsent:!Object.hasOwn(lines,'barrage')}));
