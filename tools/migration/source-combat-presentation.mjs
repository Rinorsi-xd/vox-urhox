// Execute the unmodified H5 effect classes without a WebGL context.
import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot;
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);}});
globalThis.document={createElement(){return {width:64,height:64,getContext(){return {createRadialGradient(){return {addColorStop(){}}},fillRect(){}}}}}};
const T=await import(url('three/vendor/three/build/three.module.js'));
const {Effects}=await import(url('three/src/drive/effects.js'));
Math.random=()=>.5;
const cases=[];
const shot=(kind,tier,pos=[2,3,4])=>({type:'shot',kind,tier,pos,dir:[0,0,1],spin:1});
const consume=events=>({op:'consume',events});
const step=dt=>({op:'update',dt});
function run(name,commands){
 const fx=new Effects(new T.Scene()),camera=new T.PerspectiveCamera(48,16/9,.1,1000);
 const states=[];
 for(const cmd of commands){
  if(cmd.op==='consume')fx.consume(cmd.events);
  if(cmd.op==='update')fx.update(cmd.dt,[],camera,1080);
  if(cmd.op==='light')fx._light(cmd.pos,cmd.intensity,cmd.color,cmd.options);
  if(cmd.op==='clear'){fx.clear();fx.update(0,[],camera,1080);}
  states.push({cmd,intensity:fx.lightI,brightness:fx.light.intensity,pos:fx.light.position.toArray(),color:fx.light.color.toArray(),
   zaps:structuredClone(fx.wfx.zaps),trails:structuredClone(fx.wfx.trails)});
 }
 cases.push({name,states});
}
for(const kind of ['mg','laser','sniper'])for(const tier of [2,3,4,5]){
 run(`${kind}${tier}`,[consume([shot(kind,tier)]),step(1/60),step(.05),step(.1),step(1),{op:'clear'}]);
}
run('alternating-muzzles',[consume([shot('mg',5,[-2,3,4])]),step(1/60),consume([shot('mg',5,[2,3,4])]),step(1/60),
 consume([{type:'explode',pos:[8,1,0],radius:2}]),step(.01),consume([shot('mg',2,[-2,3,4])]),step(.05),step(1)]);
run('light-priority',[
 {op:'light',pos:[1,2,3],intensity:100,color:0x4aa8ff},step(.01),
 {op:'light',pos:[9,9,9],intensity:1,color:0xffffff,options:{decay:7,smooth:.6}},step(.01),
 {op:'light',pos:[9,2,3],intensity:100,color:0xffa050,options:{decay:7,smooth:.6}},step(.1),step(2),
 {op:'light',pos:[5,6,7],intensity:20,color:0xffa050,options:{decay:7,smooth:.6}},step(.1),{op:'clear'},
]);
for(const kind of ['laser','sniper'])for(const tier of [2,5]){
 const beam={type:'beam',kind,tier,from:[-2,2,0],to:[10,2,0],dir:[1,0,0],hit:true,normal:[-1,0,0]};
 run(`${kind}${tier}-impact`,[consume([beam]),step(.01),step(.02),...Array.from({length:48},()=>step(1/60)),{op:'clear'}]);
}
run('no-invented-light',[consume([{type:'impact',tier:5,pos:[1,2,3],dir:[0,0,1],bright:true}]),step(.016),
 consume([{type:'dry',kind:'sniper',pos:[1,2,3],dir:[0,0,1]}]),step(.016),
 consume([{type:'break',cells:2,pos:[1,2,3],dir:[0,0,1],color:0xff0000}]),step(.016)]);
const files=['three/src/drive/effects.js','three/src/drive/weaponFx.js'];
const provenance=files.map(file=>({path:file,sha256:createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex')}));
const output=path.join(root,'tools/migration/source-combat-presentation.json'),temp=output+'.import-tmp';
fs.writeFileSync(temp,JSON.stringify({baseline:baseline.commit,provenance,cases}));fs.renameSync(temp,output);
console.log(`${cases.length} source cases / ${cases.reduce((n,c)=>n+c.states.length,0)} states`);
