const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),hashes={};
function read(name){const bytes=fs.readFileSync(path.join(baseline.snapshot,name)),hash=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(hash,baseline.files[name].sha256,name);hashes[name]=hash;return bytes.toString('utf8');}
const ctx=vm.createContext({radio(){},BOSS_KIND:{},COLOR:{install:0}});
vm.runInContext(read('three/src/battle/storyKinds.js').replace(/^import .*;\r?\n/gm,'').replace('export const KINDS','globalThis.KINDS'),ctx);
vm.runInContext(read('shared/story/level3.js').replace('export const LEVEL3','globalThis.LEVEL3'),ctx);
const mission=read('three/src/battle/storyMission.js'),start=mission.indexOf('\t_targetOf( e ) {'),end=mission.indexOf('\n\tbeforeStep(',start);
assert(start>=0&&end>start);vm.runInContext('globalThis.SourceTarget=class{'+mission.slice(start,end)+'}',ctx);
const sourceTarget=new ctx.SourceTarget();sourceTarget.drive={player:{pos:[90,3,-140]}};
assert.deepEqual(sourceTarget._targetOf({target:'player'}).pos,sourceTarget.drive.player.pos);
sourceTarget.drive.player.pos=[-110,3,-160];assert.deepEqual(sourceTarget._targetOf({}).pos,sourceTarget.drive.player.pos);
const step=ctx.LEVEL3.steps.find(s=>s.kind==='hold'),trace=[];
function scenario(name,frames){
 const events=[];let restored=0;const p={alive:true,pos:[...step.pos],heal:f=>events.push(['heal',f]),restoreMissing:n=>{restored+=n;events.push(['restore',n]);return [];},flush(){}};
 const m={drive:{player:p,_syncPlayer(){}},view:{showZone(){}},hud:{clock(){},row(){},retitle(t){m.retitle=t;}},enemies:new Map(),stats:{},stepT:0,progress:0,
  fail(title){events.push(['fail',title]);}};
 ctx.KINDS.hold.enter(m,step);
 for(const f of frames){m.stepT=f.stepT;p.pos=f.pos;p.alive=f.alive;m.enemies.clear();for(const e of f.enemies)m.enemies.set({pos:e.pos,alive:e.alive},{});events.length=0;
  const done=ctx.KINDS.hold.update(m,step,f.dt,!f.alive);
  trace.push({name,input:f,expected:{left:m.hold.left,energy:m.hold.energy,healT:m.hold.healT,progress:m.progress,retitle:m.retitle??null,done,events:[...events],shield:m.stats.shield??null}});
 }
}
const f=(dt,stepT,pos=step.pos,enemies=[],alive=true)=>({dt,stepT,pos:[...pos],enemies,alive}),enemy=(offset,alive=true)=>({pos:[step.pos[0]+offset,999,step.pos[2]],alive});
scenario('delay-and-boundaries',[f(.1,3.9),f(.1,4),f(.1,4.1,step.pos,[enemy(70),enemy(69.999),enemy(0,false)]),f(.1,4.2,[26,6,-234]),f(.1,4.3,[25.999,-999,-234])]);
scenario('restore-death-completion',[f(2.5,4),f(.01,4.01),f(1,5,step.pos,[],false),f(120,125,[90,6,-234])]);
for(const count of [1,2,3,4])scenario('constant-near-'+count,Array.from({length:Math.ceil(1/(count*step.drain*.1))},(_,i)=>f(.1,4+i*.1,[90,6,-234],Array.from({length:count},()=>enemy(1)))));
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,sourceDefaultTargetFollowsPlayer:true,step:JSON.parse(JSON.stringify(step)),trace}));
