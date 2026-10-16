import fs from 'node:fs';import {pathToFileURL} from 'node:url';
const root='D:/Rino_Project/Vox/';const load=p=>import(pathToFileURL(root+p));
const {loadRapier}=await load('shared/drive/physics.js');const {Vehicle}=await load('shared/drive/vehicle.js');const {Blueprint}=await load('shared/build/blueprint.js');const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');const prefabs=await load('shared/build/planePrefab.js');const {stepWings}=await load('shared/drive/wingControl.js');const R=await loadRapier();
const input=JSON.parse(fs.readFileSync(process.argv[2]));const out={status:'PASS',rows:[]};
const plain=v=>JSON.parse(JSON.stringify(v,(_,x)=>ArrayBuffer.isView(x)?Array.from(x):x instanceof Map?Object.fromEntries(x):x));
const pose=v=>plain({p:v.body.translation(),q:v.body.rotation(),lv:v.body.linvel(),av:v.body.angvel()});
for(const row of input.rows){
 const world=new R.World({x:0,y:-9.81,z:0});world.timestep=1/60;world.numSolverIterations=12;
 if(!process.argv.includes('--air')){const floor=world.createRigidBody(R.RigidBodyDesc.fixed().setTranslation(0,-1,0));world.createCollider(R.ColliderDesc.cuboid(500,1,500).setFriction(.8).setRestitution(0),floor);}
 const spec=buildVehicleSpec(prefabs[row.id==='hawk'?'buildHawk':'buildFeather'](new Blueprint()));const v=new Vehicle(R,world,spec);const seed=structuredClone(row.seed);
 if(seed.wing)seed.wing.surfaces=new Map(Object.entries(seed.wing.surfaces));v.setState(seed);
 const calls=[];for(const name of ['addForce','addTorque','addForceAtPoint','applyImpulse','applyImpulseAtPoint','applyTorqueImpulse']){const fn=v.body[name].bind(v.body);v.body[name]=(...args)=>{calls.push(plain({method:name,value:args[0],point:typeof args[1]==='object'?args[1]:null}));return fn(...args);};}
 const r={id:row.id,checkpoint:row.checkpoint,mode:row.mode,before:pose(v),linearDamping:v.body.linearDamping(),angularDamping:v.body.angularDamping(),com:plain(v.body.localCom()),inertia:plain(v.body.principalInertia()),inertiaFrame:plain(v.body.principalInertiaLocalFrame()),inverseWorld:plain(v.body.effectiveWorldInvInertia())};
 const cmd={throttle:1,steer:0,climb:1,strafe:0,handbrake:false,boost:false};
 if(row.mode.startsWith('wing'))r.telemetry=stepWings(v,cmd,1/60,0,0);else if(row.mode.startsWith('full')){v.step(cmd,1/60);r.telemetry=plain(v.telemetry);}
 r.calls=calls;r.force=v.body.userForce();r.torque=v.body.userTorque();r.afterVehicle=pose(v);r.wing=plain(v.wingState);
 world.step();v.postStep();r.afterPhysics=pose(v);out.rows.push(r);v.dispose();world.free();
}
fs.writeFileSync(process.argv[3],JSON.stringify(out));console.log('PASS '+out.rows.length+' real Rapier common-state single steps');
