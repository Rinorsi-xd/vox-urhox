import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=name=>import(pathToFileURL(path.join(baseline.snapshot,'shared',name)));
const R=await load('build/rotor.js');
const {Blueprint}=await load('build/blueprint.js');
const {applyRot,IDENTITY}=await load('core/rotations.js');
const {PARTS}=await load('parts/defs.js');
const specs=[],motions=[];
const canonical=bp=>[...bp.parts.values()].map(p=>({id:p.id,type:p.type,pos:p.pos,rot:p.rot,color:p.color,g:p.g||0}));
const sorted=s=>[...s].sort((a,b)=>a-b);
const range=r=>({...r,lo:Number.isFinite(r.lo)?r.lo:null,hi:Number.isFinite(r.hi)?r.hi:null,blockers:sorted(r.blockers||[]),hiBlockers:sorted(r.hiBlockers||[]),loBlockers:sorted(r.loBlockers||[])});
const blueprint=list=>{const b=new Blueprint();for(const p of list)b.add(p);return b;};
for(let rot=0;rot<24;rot++)for(let variant=0;variant<6;variant++){
 const p={type:['rotor','rotorSpin','rotorStep'][variant%3],pos:[variant%2?-4:4,8,0],rot};
 const bp=blueprint([p]);
 const at=v=>applyRot(rot,v).map((n,k)=>n+p.pos[k]);
 bp.add({type:'cube',pos:at([0,1,0]),rot:IDENTITY,g:variant>=3?2:0});
 bp.add({type:'cube',pos:at([1,1,0]),rot:IDENTITY,g:variant>=3?2:0});
 bp.add({type:'cube',pos:at([2,1,0]),rot:IDENTITY,g:variant===4?3:variant>=3?2:0});
 if(variant===1)bp.add({type:'cube',pos:at([2,1,2]),rot:IDENTITY});
 if(variant===2)for(const v of [[2,0,0],[2,-1,0],[1,-1,0],[0,-1,0]])bp.add({type:'cube',pos:at(v),rot:IDENTITY});
 if(variant===5)bp.add({type:'rotorStep',pos:at([0,2,0]),rot});
 const loads=R.rotorLoads(bp),tree=R.rotorTree(loads),inspect={};
 for(const [id,l] of loads)inspect[id]={load:sorted(l.load),problem:l.problem,blockers:sorted(l.blockers),stuck:l.stuck,range:range(R.rotorRange(bp,bp.parts.get(id),l.load))};
 specs.push({parts:canonical(bp),inspect,owner:Object.fromEntries(tree.owner),parent:Object.fromEntries(tree.parent),order:tree.order,
  frame:R.rotorFrame(bp.parts.get(1)),aimRef:R.rotorAimRef(bp.parts.get(1)),aimOffset:R.rotorAimOffset(bp.parts.get(1))});
}
// Execute the frozen method directly; do not generate expected motion from Lua.
const source=fs.readFileSync(path.join(baseline.snapshot,'shared/drive/vehicle.js'),'utf8');
const method=source.slice(source.indexOf('\tstepRotors('),source.indexOf('\n\tsetRotor(',source.indexOf('\tstepRotors(')));
const clamp=(a,lo,hi)=>Math.max(lo,Math.min(hi,a));
const Simulation=vm.runInNewContext('class Simulation {'+method+'}; Simulation',{
 Math,ROTOR_SPEED:R.ROTOR_SPEED,ROTOR_RANGE_STEP:R.ROTOR_RANGE_STEP,IDENT:R.IDENT,rotorPose:R.rotorPose,poseInverse:R.poseInverse,
 rotate:R.qrot,dot:(a,b)=>a.reduce((s,v,k)=>s+v*b[k],0),clamp,FREE_RANGE:{free:true,lo:-Infinity,hi:Infinity},BOUNCE:{time:.4,min:Math.PI/18,max:Math.PI/10}
});
for(const mode of ['aim','spin','step'])for(const limited of [0,1,2])for(const sign of [1,-1]){
 const descriptors=[{index:1,partId:1,parent:null,mode,pivot:[0,2,0],axis:[0,sign,0],sign,ref:[0,0,1],load:[2,3],own:[2],range:limited===0?{free:true,lo:null,hi:null}:{free:false,lo:limited===1?-Math.PI/2:0,hi:limited===1?Math.PI:0}},
  {index:2,partId:2,parent:1,mode:'aim',pivot:[1,3,0],axis:[1,0,0],sign:1,ref:[0,0,1],load:[3],own:[3],range:{free:true,lo:null,hi:null}}];
 const sim=new Simulation();sim.body={translation:()=>({x:0,y:0,z:0}),rotation:()=>({x:0,y:0,z:0,w:1})};sim._applyRotors=()=>{};
 sim.rotors=descriptors.map(r=>({...r,parent:r.parent===null?-1:r.parent-1,angle:0,target:0,prev:0,pose:R.IDENT,range:{...r.range,lo:r.range.lo??-Infinity,hi:r.range.hi??Infinity}}));
 const frames=[];
 for(let i=0;i<160;i++){
  const aim=[Math.sin(i*.04)*20,5+Math.cos(i*.03)*8,Math.cos(i*.04)*20],step=i%37===0,dt=1/30;
  sim.stepRotors({aim,step},dt);
  frames.push({aim,step,dt,rotors:sim.rotors.map(r=>({angle:r.angle,target:r.target,prev:r.prev,pose:r.pose}))});
 }
 motions.push({descriptors,frames});
}
fs.writeFileSync(path.join(root,'tools/migration/source-rotors-fixtures.json'),JSON.stringify({commit:baseline.commit,specs,motions}));
console.log(JSON.stringify({specs:specs.length,motions:motions.length,frames:motions.reduce((n,c)=>n+c.frames.length,0)}));
