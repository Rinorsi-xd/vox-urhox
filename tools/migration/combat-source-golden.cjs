// Executes frozen H5 class methods with recording render sinks, not hand-copied formulas.
const fs=require('node:fs'),vm=require('node:vm');
const base='.tmp/outgame-source-2026-10-14T10-09-50-505Z/three/src/';
let seed=146982;const random=()=>{seed=seed*48271%2147483647;return seed/2147483647};
const context=vm.createContext({Math:Object.assign(Object.create(Math),{random}),THREE:{Quaternion:class{},Vector3:class{},Matrix4:class{}}});
function load(path,name){const text=fs.readFileSync(base+path,'utf8').replace(/^import .*;\r?\n/gm,'').replace(/export class /g,'class ');return vm.runInContext(`(()=>{${text};return ${name}})()`,context)}
const Weapon=load('drive/weaponFx.js','WeaponFx'),Effects=load('drive/effects.js','Effects');
function linear(hex){const ch=n=>n/255<=.04045?n/255/12.92:((n/255+.055)/1.055)**2.4;return[ch(hex>>16&255),ch(hex>>8&255),ch(hex&255)]}
function fixture(){
 seed=146982;
 const rows=[];const record=(kind,...args)=>rows.push({kind,args});
 const fx={_flash:(p,s,l,c)=>record('flash',p,s,l,linear(c)),_light:(p,n,c=0xffa050,o={})=>record('light',p,n,c,o.decay??18,o.smooth??0),
  _burst:(p,n,s,c,o={})=>record('burst',p,n,s,c,o.normal??null,o.size??.08,o.life??.45,o.grav??12,o.up??.4),
  _puff:(p,n,s,l,g=.35)=>record('puff',p,n,s,l,g),sparks:{emit:(p,v,c,s,l,o={})=>record('spark',p,v,c,s,l,o.drag??0,o.grav??0,o.grow??0)}};
 const w=Object.create(Weapon.prototype);Object.assign(w,{fx,time:{value:0},beams:[],zaps:[],trails:[],rings:[],flares:[],booms:[],blastLog:[],
  ring:(...a)=>record('ring',a[0],a[1],a[2],a[3],a[4],a[5],a[6]??1,a[7]??.18,a[8]??0),flare:(...a)=>record('flare',...a)});
 const sink=()=>({begin(){},end(){},path(){},seg(){},add(){}});w.beamRib=sink();w.arcRib=sink();w.streaks=sink();w.glows=sink();w.msl={instanceMatrix:{count:128}};w.mslGlow={};
 w.streaks.add=(a,b,width,color,alpha=1,core=.45,taper=.85)=>record('streak',a,b,width,color,alpha,core,taper);
 w.glows.add=(p,size,color)=>record('glow',p,size,color);
 const effects=Object.assign(Object.create(Effects.prototype),fx,{wfx:w});
 return {w,effects,rows};
}
const cases=[];
function add(name,event,call){const f=fixture();call(f,event);for(const z of f.w.zaps)f.rows.push({kind:'zap',args:[z.a,z.b,z.age,z.life,z.w]});for(const b of f.w.booms)f.rows.push({kind:'boom',args:[b.pos,b.r,b.dim,b.white,b.age,b.life]});cases.push({name,event,rows:f.rows})}
for(const [kind,tier]of[['mg',3],['mg',4],['mg',5],['laser',4],['sniper',5],['missile',3]])add('shot '+kind+' T'+tier,{type:'shot',kind,tier,pos:[2,3,4],dir:[0,0,1],spin:1,locked:true},(f,e)=>f.w.shot(e));
for(const kind of['laser','sniper'])add('hit '+kind,{kind,tier:5,to:[3,2,5],dir:[0,0,1],normal:[0,1,0],target:true,splash:6},(f,e)=>f.w._hit(e,5,true,kind==='sniper'));
add('dry sniper',{type:'dry',kind:'sniper',pos:[1,2,3],dir:[0,0,1]},(f,e)=>f.w.dry(e));
for(const type of['plateBreak','repair','heal'])add(type,{type,pos:[1,2,3],cells:27,radius:3},(f,e)=>f.effects.consume([e]));
for(const repeat of[1,3])add('missile blast x'+repeat,{type:'blast',kind:'missile',tier:5,pos:[2,3,4],normal:[0,1,0],radius:4,repeat},(f,e)=>{for(let i=0;i<repeat;i++)f.w.blast(e)});
for(const [tier,bright,dist]of[[3,false,40],[5,true,70],[4,true,.02]])add('bolt T'+tier+' dist'+dist,{fx:'bolt',s:{tier},bright,dist,seed:.8,pos:[1,2,20],vel:[0,0,240]},(f,e)=>f.w.update(0,[e]));
// Check actual flare geometry independently of shot method recordings.
add('flare geometry',{pos:[1,2,3],dir:[0,0,1]},(f,e)=>{Weapon.prototype.flare.call(f.w,e.pos,e.dir,3,.85,.26,[4.2,2.6,.7],1.3,.065);for(const x of f.w.flares)f.rows.push({kind:'actualFlare',args:[x.base,x.tip,x.w,x.color,x.life,x.age]})});
process.stdout.write(JSON.stringify(cases));
