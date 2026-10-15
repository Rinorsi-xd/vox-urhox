import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),base=path.join(root,'.tmp/outgame-source-2026-10-14T10-09-50-505Z');
const file=path.join(base,'shared/ai/driver.js');const {EnemyDriver,seededRandom,findPath,insideZone,zoneEdge}=await import(pathToFileURL(file));
const nav={nodes:{a:[0,0,0],b:[0,0,40],c:[40,0,40],d:[-40,0,40],e:[0,0,100],f:[0,0,150],g:[60,0,180],h:[-60,0,180],i:[0,0,-45],j:[50,0,-45],k:[-50,0,-45],ebP:[0,10,-200],nD:[0,0,-120]},edges:[['a','b',30],['b','c',30],['b','d',30],['b','e',30],['e','f',30],['f','g',30],['f','h',30],['a','i',30],['i','j',30],['i','k',30],['ebP','nD',60],['nD','i',60],['c','g',14],['d','h',14]]};
const spec=(width=4)=>({bounds:{min:[-width/2,-1,-3],max:[width/2,2,3]},weapons:[{pivot:[0,1.5,1]}]});
const scenarios=[];
for(const role of ['assault','heavy','boss','hover','sniper'])for(const mode of ['engage','retreat','blocked','objective','crowd','missile','charging','stuck','flip','shield','landing','disabled','launch']){
 const seed=61+scenarios.length,tier=2,width=role==='boss'?16:4,s=spec(width),ts=spec(4);let pos=[0,1,0],vel={x:0,y:0,z:0},tp=[0,1,role==='sniper'?150:35],tv={x:0,y:0,z:0};
 const body={translation:()=>({x:pos[0],y:pos[1],z:pos[2]}),linvel:()=>vel,rotation:()=>mode==='flip'?{x:1,y:0,z:0,w:0}:{x:0,y:0,z:0,w:1}};
 const vehicle={spec:s,yaw:0,body,capabilities:{totalLoad:10}};const targetVehicle={spec:ts,yaw:0,body:{linvel:()=>tv}};
 const self={vehicle,spec:s,core:{hp:100,max:100},integrity:1,hitAt:-1,alive:true,team:'enemy',get pos(){return pos}};
 const targetUnit={vehicle:targetVehicle,spec:ts};const weapon={stats:{range:250},err:0};const pod={stats:{range:350,homing:true,share:.5,lockMin:0,lockRange:350},mphase:'ready'};
 const ws={groups:[{weapons:[weapon],kind:'gun'}],aligned:()=>true,current:0,energy:100,offline:false,volleyCost:()=>50,select(i){this.current=i;},get group(){return this.groups[this.current]}};
 if(['missile','charging'].includes(mode))ws.groups.push({weapons:[pod],kind:'missile'});
 const castRay=(p,d,length)=>{if(d[1]<-.99){const y=0,dist=(p[1]-y)/-d[1];return dist>=0&&dist<=length?{point:[p[0],y,p[2]],dist}:null;}if(mode==='blocked'&&p[2]<60&&d[2]>.1)return {point:p,dist:2};return null;};
 const allies=[1,-1].map((side)=>({alive:true,team:'enemy',spec:ts,vehicle:{spec:ts,yaw:0},get pos(){return [pos[0]+side*1.5,pos[1],pos[2]+side*10];}}));
 const sim={layout:{nav},castRay,combatUnits:mode==='crowd'?[self,...allies]:[self]};const driver=new EnemyDriver({role,tier,seed,nav,width,team:'enemy'});const frames=[];
 const shield={active:true,pos:[0,1,35],zone:{pos:[0,0,35],rx:15,rz:12},contains:p=>(p[0]/15)**2+((p[2]-35)/12)**2<=1,aimPoint:()=>[0,3,23]};
 for(let frame=0;frame<180;frame++){
  pos=[Math.sin(frame*.025)*3,1,frame*.035];vel={x:Math.cos(frame*.025)*.5,y:0,z:frame%45<5?0:3};vehicle.yaw=Math.sin(frame*.03)*.2;
  tp=[Math.sin(frame*.017)*8,1,(role==='sniper'?150:35)+Math.cos(frame*.021)*3];tv={x:frame>20?2:0,y:0,z:.2};
  if(mode==='stuck'){pos=[0,1,0];vel={x:0,y:0,z:0};tp=[0,1,150];}if(mode==='launch'){pos=[0,11-frame*.055,-200+frame*.25];tp=[0,1,30];}
  vehicle.capabilities.totalLoad=mode==='disabled'?0:10;vehicle.airdropActive=mode==='landing'&&frame<40;
  if(mode==='missile'){ws.energy=frame<90?100:60;pod.mphase=frame>=80&&frame<100?'reload':'ready';}if(mode==='charging')ws.energy=frame<70?10:frame<120?55:100;
  self.core.hp=mode==='retreat'?(frame<110?20:90):100;self.integrity=1;if(frame===65)self.hitAt=4;
  const target=mode==='objective'?{pos:tp,radius:16}:{pos:tp,unit:targetUnit};const passive=mode==='objective';
  const energy=ws.energy;
  const out=driver.step(.1,{vehicle,target,sim,weaponSystem:ws,self,passive,charge:frame>=150,shield:mode==='shield'?shield:null});
  frames.push(structuredClone({pos,vel,tp,tv,yaw:vehicle.yaw,hp:self.core.hp,hitAt:self.hitAt,charge:frame>=150,energy,mphase:pod.mphase,airdrop:vehicle.airdropActive,out:{...out,reset:out.reset??null,tactic:out.tactic??null},state:{circle:driver.circle,lane:driver.lane,reaction:driver.reaction,error:driver.error,lag:driver.lag??null,route:driver.route,goal:driver.goal??null,life:driver.life??null,current:ws.current+1}}));
 }
 scenarios.push({role,mode,tier,seed,width,spec:s,targetSpec:ts,frames});
}
const rng=[1,123,4294967295,'Vox'].map(seed=>{const r=seededRandom(seed);return {seed,values:Array.from({length:12},()=>r())};});
const paths=[4,16,40,65].map(width=>({width,value:findPath(nav,[0,1,0],[60,1,180],width)}));
const zones=[[-5,0,0],[0,0,5],[40,0,4]].map(p=>({p,inside:insideZone({pos:[0,0,0],rx:20,rz:10},p,4),edge:zoneEdge({pos:[0,0,0],rx:20,rz:10},p,4,[1,0,1])}));
const data={source:{file:'shared/ai/driver.js',sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')},nav,rng,paths,zones,scenarios};
fs.writeFileSync(path.join(root,'tools/migration/source-enemy-fixtures.json'),JSON.stringify(data));console.log(JSON.stringify({source:data.source,scenarios:scenarios.length,frames:scenarios.reduce((n,s)=>n+s.frames.length,0)}));
