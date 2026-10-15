import fs from 'node:fs';import path from 'node:path';import {pathToFileURL,fileURLToPath} from 'node:url';import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));const source=path.resolve(baseline.snapshot);
const {stepWings,normalCoefficient}=await import(pathToFileURL(path.join(source,'shared/drive/wingControl.js')));
const {stepThrusters}=await import(pathToFileURL(path.join(source,'shared/drive/thrusterControl.js')));
const wing=(id,x,kind='wing')=>({partId:id,kind,lift:1.1,pos:[x,0,-1],n:kind==='wing'?[0,1,0]:[1,0,0],c:[0,0,1],area:kind==='wing'?9:3,surfaces:[{name:'flap0',pos:[x,0,-2]}]});
const dynamics=[];
for(const layout of ['pair','single','rudder','pairRudder'])for(const mode of ['flight','slow','ceiling','ground']){
 const ws=layout==='pair'?[wing(1,-3),wing(2,3)]:layout==='single'?[wing(1,-3)]:layout==='rudder'?[wing(3,0,'rudder')]:[wing(1,-3),wing(2,3),wing(3,0,'rudder')];
 const spec={wings:ws,boxes:[{center:[0,0,0],half:[1,.5,2],mass:600}],hulls:[],wheels:[{center:[0,-1,0],mass:20}]};let position,velocity,spin,quat,forces=[];
 const body={rotation:()=>quat,translation:()=>position,linvel:()=>velocity,angvel:()=>spin};for(const method of ['addForce','addTorque','addForceAtPoint'])body[method]=(...args)=>forces.push({method,args:args.filter(a=>typeof a==='object')});
 class Ray{constructor(origin,dir){this.origin=origin;this.dir=dir;}}
 const v={spec:{...spec,bounds:{min:[-4,-1,-2]}},mass:620,com:[.1,.2,-.4],body,R:{Ray,QueryFilterFlags:{EXCLUDE_SENSORS:1}},world:{castRay:(ray,d)=>ray.origin.y<=d?{timeOfImpact:ray.origin.y}:null}};
 const frames=[];
 for(let frame=0;frame<120;frame++){
  const cmd={throttle:frame<40?1:frame<80?-1:0,steer:frame>=20&&frame<70?.6:0,climb:frame<35?1:frame<80?-1:0,strafe:frame>=60&&frame<100?-.4:0};
  const angle=frame*.004;quat={x:Math.sin(angle*.5),y:0,z:0,w:Math.cos(angle*.5)};
  position={x:0,y:mode==='ceiling'?140+frame*.5:mode==='slow'?8:mode==='ground'?1:18,z:frame};velocity={x:frame>=60?1:0,y:frame<40?0:-1.3,z:mode==='slow'?2:mode==='ground'?frame*.3:24+frame*.12};spin={x:.06,y:cmd.strafe*.3,z:.03};const contact=mode==='ground'&&frame<90;const support=contact?620*9.81*.5:0;
  v.flightTarget=frame>=100&&mode==='slow'?8:null;forces=[];const out=stepWings(v,cmd,1/60,contact,support);
  const st={...v.wingState,surfaces:Object.fromEntries(v.wingState.surfaces)};
  frames.push({cmd,quat,position,velocity,spin,contact,support,flightTarget:v.flightTarget,out,forces,st});
 }
 dynamics.push({layout,mode,spec:v.spec,mass:v.mass,com:v.com,frames});
}
const files=['shared/drive/wingControl.js','shared/drive/thrusterControl.js','shared/parts/wingData.js'];const provenance={};for(const p of files){const hash=createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex');if(hash!==baseline.files[p]?.sha256)throw Error('Frozen source changed '+p);provenance[p]=hash;}
const coefficients=Array.from({length:81},(_,i)=>{const alpha=(i-40)*Math.PI/80;return {alpha,value:normalCoefficient(alpha)};});
const jets=[];
for(const speed of [24,36,-5,-12])for(const throttle of [1,-1]){
 const forces=[];const thruster={partId:4,pos:[0,0,-2],dir:[0,0,1],thrust:2600,speedLimit:30};const v={mass:620,inertiaY:2000,com:[0,0,0],spec:{thrusters:[thruster],wings:[{}],bounds:{min:[-1,-1,-2]}},boostFuel:1};
 v.body={rotation:()=>({x:0,y:0,z:0,w:1}),translation:()=>({x:0,y:15,z:0}),linvel:()=>({x:0,y:0,z:speed}),angvel:()=>({x:0,y:0,z:0})};for(const method of ['addForce','addTorque','addForceAtPoint'])v.body[method]=(...args)=>forces.push({method,args:args.filter(a=>typeof a==='object')});
 const out=stepThrusters(v,{throttle},1/60,0,0);jets.push({speed,throttle,thruster,forces,out,outputs:Object.fromEntries(v.thrusterOutputs),directions:Object.fromEntries(v.thrusterDirections)});
}
fs.writeFileSync(path.join(root,'tools/migration/source-wing-fixtures.json'),JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},provenance,coefficients,dynamics,jets}));console.log(JSON.stringify({scenarios:dynamics.length,frames:dynamics.reduce((n,s)=>n+s.frames.length,0),coefficients:coefficients.length,jets:jets.length}));
