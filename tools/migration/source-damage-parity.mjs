import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const root=path.resolve(baseline.snapshot),provenance={};
for(const file of ['shared/combat/carUnit.js','shared/combat/tuning.js','shared/parts/defs.js','three/src/drive/testDrive.js','shared/ui/driveHud.js','shared/css/drive.css']){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
 if(hash!==baseline.files[file]?.sha256)throw Error('Frozen source changed '+file);provenance[file]=hash;
}
const {CarUnit}=await import(pathToFileURL(path.join(root,'shared/combat/carUnit.js')));
const {PARTS}=await import(pathToFileURL(path.join(root,'shared/parts/defs.js')));
const plate=Object.keys(PARTS).find(k=>PARTS[k].plate),rows=[];
const flags=opts=>({partId:opts?.partId??null,shield:!!opts?.shield,pierce:!!opts?.pierce,broke:!!opts?.broke});
for(const type of ['cube',plate])for(const hp of [30,200])for(const bodyHp of [650,900])for(const shield of [0,80])for(const armor of [0,.6,1])for(const amount of [50,400]){
 const input={type,hp,bodyHp,shield,armor,amount,multiplier:1};
 const records=[],u=Object.create(CarUnit.prototype);
 Object.assign(u,{alive:true,kill:null,hullEnabled:true,hp:new Map([[1,hp]]),shields:new Map(),bp:{parts:new Map([[1,{type,_cells:[[0,0,0]]}]])},
  struct:90,bodyHp,bodyHpMax:1000,incomingDamageMultiplier:input.multiplier,hitAt:-1,lostCells:0,lostMajor:0,
  env:{time:10,fx:[],viewEvents:[],recordDamage:(unit,amount,point,opts)=>records.push({amount,...flags(opts)})}});
 if(shield)u.shields.set(1,{v:shield,hit:0,t:0});u.shieldOf=id=>u.shields.get(id).v;
 u._destroy=id=>{u._countLost(u.bp.parts.get(id));u.bp.parts.delete(id);u.hp.delete(id);u.shields.delete(id);};
 const dealt=u._damage(1,amount,[0,0,0],{armor});
 rows.push({input,expected:{dealt,hp:u.hp.get(1)??0,bodyHp:u.bodyHp,struct:u.struct,shield:u.shields.get(1)?.v??0,lostCells:u.lostCells,lostMajor:u.lostMajor,records}});
}
const rays=[];
for(const multiplier of [1,.4,1.8])for(const armor of [0,.6])for(const depth of [1,3]){
 const records=[],u=Object.create(CarUnit.prototype),count=3,hp=30;
 Object.assign(u,{alive:true,kill:null,hullEnabled:true,hp:new Map(Array.from({length:count},(_,i)=>[i+1,hp])),shields:new Map(),
  bp:{parts:new Map(Array.from({length:count},(_,i)=>[i+1,{type:'cube',_cells:[[0,0,i]]}]))},struct:0,bodyHp:400,bodyHpMax:1000,
  incomingDamageMultiplier:multiplier,hitAt:-1,lostCells:0,lostMajor:0,vehicle:{body:{rotation:()=>({x:0,y:0,z:0,w:1})}},
  env:{time:10,fx:[],viewEvents:[],recordDamage:(unit,amount,point,opts)=>records.push({amount,...flags(opts)})}});
 u._local=p=>p;u._march=(p,d,len,skip)=>[1,2,3].find(id=>u.hp.has(id)&&!(skip instanceof Set?skip.has(id):skip===id))??null;
 u._destroy=id=>{u._countLost(u.bp.parts.get(id));u.bp.parts.delete(id);u.hp.delete(id);};
 let splash=null;u.explode=(point,radius,damage,opts)=>{splash={point,radius,damage,armor:opts.armor};return 0;};
 const pierce={armor,depth,carry:.8,splash:{radius:2,share:.2}};
 const dealt=u.hitRay({owner:{partId:1},point:[0,0,0]},260,[0,0,1],pierce);
 rays.push({input:{multiplier,pierce},expected:{dealt,bodyHp:u.bodyHp,hp:[1,2,3].map(id=>u.hp.get(id)??0),records,splash}});
}
const lives=[];
for(const alive of [false,true])for(const core of [0,.2,1])for(const integrity of [.1,.15,.5,1])for(const health of [.1,.7,1])for(const hullEnabled of [false,true]){
 const input={alive,core,integrity,health,hullEnabled,hullMin:hullEnabled?null:.2};
 const u=Object.create(CarUnit.prototype);
 Object.defineProperties(u,{alive:{value:alive},core:{value:{hp:core*100,max:100}},integrity:{value:integrity},health:{value:health},hullEnabled:{value:hullEnabled},hullMin:{value:input.hullMin}});
 lives.push({input,expected:u.life});
}
fs.writeFileSync('tools/migration/source-damage-parity.json',JSON.stringify({commit:baseline.commit,provenance,rows,rays,lives}));
console.log(JSON.stringify({layers:rows.length,penetration:rays.length,plate,commit:baseline.commit}));
