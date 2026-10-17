const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json')));
const name='three/src/drive/testDrive.js',raw=fs.readFileSync(path.join(baseline.snapshot,name));
const hash=crypto.createHash('sha256').update(raw).digest('hex');
if(hash!==baseline.files[name].sha256)throw Error('Frozen source drift');
const context=vm.createContext({URLSearchParams,location:{search:''},THREE:{Vector3:class{},Vector2:class{}},
 cameraListener:()=>({}),sfx:{consumeWeapons(events){context.audio=structuredClone(events);}}});
vm.runInContext(raw.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Drive=TestDrive;',context);
const cases=[];
for(const fp of [false,true])for(const distance of [0,4,20,100]){
 const own=[['bolt',0],['bolt',12],['bolt',12.01],['bolt',40],['missile',0],['missile',6],['missile',6.01],['missile',40]]
 .map(([fx,dist],id)=>({id,fx,dist,pos:[0,0,dist]}));
 const remote=[{id:100,fx:'bolt',dist:1},{id:101,fx:'missile',dist:1}];
 const events=[{type:'shot',kind:'laser',own:true,kick:0,shake:0},
  {type:'shot',kind:'sniper',own:false,remote:true},
  {type:'beam',kind:'laser',own:true,from:[2,3,4],to:[2,3,4+distance],dir:[0,0,1]},
  {type:'beam',kind:'sniper',own:false,from:[2,3,4],to:[2,3,4+distance],dir:[0,0,1]}];
 let visual,projectiles;
 const drive=Object.create(context.Drive.prototype);
 Object.assign(drive,{cam:{eye:fp},input:{controlling:true},camera:{},renderer:{getSize:()=>({y:1080})},
  sim:{fx:[],units:[{weapons:{projectiles:remote}}]},weapons:{projectiles:own},stepFx:structuredClone(events),
  fx:{consume(e){visual=structuredClone(e);},update(dt,p){projectiles=structuredClone(p);}},
  trauma:0,drillImpact:0,mechSpeed:0,stompY:0,stompV:0,nodY:0,nodV:0,rumbleT:0,rumbleAt:0,rumble:0,rumbleTo:0,thump:0});
 drive._effects(1/60,[0,0,0]);
 cases.push({fp,distance,events,own,remote,visual,projectiles,audio:context.audio});
}
process.stdout.write(JSON.stringify({commit,sourceHashes:{[name]:hash},cases}));
