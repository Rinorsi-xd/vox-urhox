import fs from 'node:fs';
import path from 'node:path';
import {registerHooks,createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot,url=p=>pathToFileURL(path.join(source,p)).href;
const entry=url('three/src/battle/storyView.js');
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);},
 load(u,c,n){const r=n(u,c);if(u!==entry)return r;
  // Canvas glow sprites have no geometry. Keep their hierarchy placeholders;
  // the native view uses the original beam/ring shaders and mesh geometry.
  return {...r,source:String(r.source).replace(/const glowSprite = .*?;(?=\r?\n)/,'const glowSprite = () => new THREE.Group();')
   .replace(/function foxFlagTexture\( company \) \{[\s\S]*?\n\}/,'function foxFlagTexture() { return null; }')
   .replace(/function textSprite\( text,[\s\S]*?\n\}/,'function textSprite() { return new THREE.Group(); }')
   .replace('const t = { pos, hitT: - 1, roll: 0 };','g.userData = { wheels, lamp, flash }; const t = { pos, hitT: - 1, roll: 0 };')+'\nexport {Beacon,IntelCube,collectorModel};'};
 }});
const THREE=await import(url('three/vendor/three/build/three.module.js'));
const {LEVEL1}=await import(url('shared/story/level1.js'));
const {LEVEL2}=await import(url('shared/story/level2.js'));
const {LEVEL3}=await import(url('shared/story/level3.js'));
const {LEVEL4}=await import(url('shared/story/level4.js'));
const {Beacon,IntelCube,collectorModel,StoryView}=await import(entry);
const {optimize}=createRequire(import.meta.url)('./crater-model.cjs');
const dest=path.join(root,'assets/Story/Mission');fs.mkdirSync(dest,{recursive:true});
const hash=b=>createHash('sha256').update(b).digest('hex');
function writeJson(file,data){
 const bytes=JSON.stringify(data),temp=file+'.import-tmp';
 if(fs.existsSync(file)&&fs.readFileSync(file,'utf8')===bytes)return;
 fs.writeFileSync(temp,bytes);fs.renameSync(temp,file);
}
const models=[],materials=[],modelMap=new Map(),materialMap=new Map();
function model(geometry){
 if(modelMap.has(geometry.uuid))return modelMap.get(geometry.uuid);
 const g=geometry.index?geometry.toNonIndexed():geometry.clone();if(!g.attributes.normal)g.computeVertexNormals();
 const p=g.attributes.position,n=g.attributes.normal,uv=g.attributes.uv,count=p.count,chunks=[];
 const u=(...v)=>{const b=Buffer.alloc(v.length*4);v.forEach((x,i)=>b.writeUInt32LE(x,i*4));chunks.push(b);};
 const f=(...v)=>{const b=Buffer.alloc(v.length*4);v.forEach((x,i)=>b.writeFloatLE(x,i*4));chunks.push(b);};
 chunks.push(Buffer.from('UMDL'));u(1,count,31,0,0);const vertices=Buffer.alloc(count*44),lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
 for(let i=0;i<count;i++){
  const pos=[-p.getX(i),p.getY(i),p.getZ(i)];[...pos,-n.getX(i),n.getY(i),n.getZ(i)].forEach((v,j)=>vertices.writeFloatLE(v,i*44+j*4));
  vertices.fill(255,i*44+24,i*44+28);vertices.writeFloatLE(uv?uv.getX(i):0,i*44+28);vertices.writeFloatLE(uv?1-uv.getY(i):0,i*44+32);
  for(let j=0;j<3;j++){lo[j]=Math.min(lo[j],pos[j]);hi[j]=Math.max(hi[j],pos[j]);}
 }
 chunks.push(vertices);u(1,count,2);const indices=Buffer.alloc(count*2);for(let i=0;i<count;i+=3)[i,i+2,i+1].forEach((v,j)=>indices.writeUInt16LE(v,(i+j)*2));chunks.push(indices);
 u(1,0,1);f(0);u(0,0,0,0,count,0,0);f(...lo,...hi,...lo.map((v,i)=>(v+hi[i])/2));
 const bytes=optimize(Buffer.concat(chunks)),id=models.length+1,name=`Story/Mission/model-${id}.bin`;
 fs.writeFileSync(path.join(root,'assets',name),bytes);models.push({path:name,bytes:bytes.length,sha256:hash(bytes),triangles:count/3});modelMap.set(geometry.uuid,id);g.dispose();return id;
}
function material(m){
 if(materialMap.has(m.uuid))return materialMap.get(m.uuid);
 const id=materials.length+1,uniform=m.uniforms||{};
 const shader=m.isShaderMaterial?(uniform.uProgress?'Ring':'Beam'):m.transparent?'Holo':m.isMeshBasicMaterial?'Unlit':'Body';
 const color=uniform.uColor?.value||m.color;
 materials.push({shader,color:color?.toArray()||[1,1,1],alpha:uniform.uAlpha?.value??m.opacity,roughness:m.roughness??.5,metalness:m.metalness??0,
  emission:m.emissive?.toArray()||[0,0,0]});materialMap.set(m.uuid,id);return id;
}
function tree(object){
 const nodes=[],ids=new Map();
 function walk(o,parent){const id=nodes.length+1;ids.set(o,id);
  nodes.push({parent,position:o.position.toArray(),quaternion:o.quaternion.toArray(),scale:o.scale.toArray(),visible:o.visible,
   ...(o.isMesh?{model:model(o.geometry),material:material(o.material),shadow:!!o.castShadow}:{})});
  for(const child of o.children)if(!child.isLine)walk(child,id);
 }walk(object,0);return {nodes,ids};
}
const scene=new THREE.Scene(),clock={value:0};
const beacon=new Beacon(scene,clock),intel=new IntelCube(scene,[0,0,0],clock),collector=collectorModel(clock);
const b=tree(beacon.g),i=tree(intel.g),c=tree(collector),u=collector.userData;
const rig={};for(const key of ['body','drill','lamp','halo','flame','up'])rig[key]=c.ids.get(u[key]);
rig.legs=u.legs.map(o=>c.ids.get(o));rig.rings=u.rings.map(o=>c.ids.get(o));
const zone=model(new THREE.PlaneGeometry(2,2).rotateX(-Math.PI/2));
const view={models,materials,zone,beacon:{nodes:b.nodes,gem:b.ids.get(beacon.gem),ring:b.ids.get(beacon.ring),ring2:b.ids.get(beacon.ring2)},
 intel:{nodes:i.nodes,float:i.ids.get(intel.float),core:i.ids.get(intel.core),inner:i.ids.get(intel.inner),rings:intel.rings.map(o=>i.ids.get(o)),pad2:i.ids.get(intel.pad2),shards:i.ids.get(intel.shards),shardNodes:intel.shards.children.map(o=>i.ids.get(o))},collector:{nodes:c.nodes,rig},
 limitations:['Canvas halo sprites and mesh edge lines are not exported; original mesh silhouettes, beam/ring formulas and animation hierarchy are retained.']};
const truckScene=new THREE.Scene(),truckHost={scene:truckScene,objects:[],time:clock};
const random=Math.random;let seed=0x132026;Math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
try{StoryView.prototype.addTruck.call(truckHost,[0,0,0],0);}finally{Math.random=random;}
const truckRoot=truckScene.children[0],truckTree=tree(truckRoot);
view.truck={nodes:truckTree.nodes,wheels:truckRoot.userData.wheels.map(o=>truckTree.ids.get(o)),lamp:truckTree.ids.get(truckRoot.userData.lamp),
 flash:materialMap.get(truckRoot.userData.flash)};
const siteScene=new THREE.Scene(),siteHost={scene:siteScene,objects:[],addCollector:()=>null};
StoryView.prototype.addSite.call(siteHost,'A',[0,0,0]);
const siteTree=tree(siteHost.sites.A.flag);
view.site={nodes:siteTree.nodes,cloth:siteTree.ids.get(siteHost.sites.A.cloth)};
view.graffiti=model(new THREE.PlaneGeometry(11.2,2.1));
const voiceIndex=JSON.parse(fs.readFileSync(path.join(source,'shared/assets/story/vo/lines.json'))),byText=new Map();
const norm=s=>String(s).replace(/^【[^】]*】/,'').replace(/[^\p{Script=Han}A-Za-z0-9]/gu,'');
for(const [id,v] of Object.entries(voiceIndex))for(const text of v.text)byText.set(norm(text),id);
const voices={},faces=new Set();
const previousFile=path.join(dest,'Level1.json'),previousVoices=fs.existsSync(previousFile)?JSON.parse(fs.readFileSync(previousFile)).voices:{};
const geometryOnly=process.argv.includes('--geometry-only');
const ffmpeg=process.env.VOX_FFMPEG;if(!ffmpeg&&!geometryOnly)throw Error('Set VOX_FFMPEG to the installed ffmpeg executable.');
function lines(list){for(const l of list||[]){if(l[2])faces.add(l[2]);const id=byText.get(norm(l[1]));if(!id||voices[id])continue;
 const input=path.join(source,'shared/assets/story/vo',id+'.mp3'),output=path.join(dest,id+'.ogg');
 if(geometryOnly){if(!fs.existsSync(output))throw Error('Missing existing voice '+output);}
 else if(!fs.existsSync(output)||previousVoices[id]?.sha256!==hash(fs.readFileSync(input)))execFileSync(ffmpeg,['-v','error','-y','-i',input,'-ac','1','-ar','24000','-c:a','libvorbis','-q:a','4',output],{windowsHide:true});
 voices[id]={path:`Story/Mission/${id}.ogg`,text:voiceIndex[id].text,sha256:hash(fs.readFileSync(input))};
}}
function gather(value){if(!value||typeof value!=='object')return;
 if(Array.isArray(value)&&typeof value[0]==='string'&&typeof value[1]==='string'&&['nono','huhu','yun'].includes(value[0])){lines([value]);return;}
 for(const child of Object.values(value))gather(child);
}
gather(LEVEL1);gather(LEVEL2);gather(LEVEL3);gather(LEVEL4);
for(const face of faces){const input=face.startsWith('huhu_')?path.join(source,'shared/assets/story/huhu/pilot',face+'.png'):path.join(source,'shared/assets/intro/raw',face+'.png');
 if(!fs.existsSync(input))throw Error('Missing original portrait '+face);
 const output=path.join(root,'assets/UI/Faces',face+'.png');
 // Existing faces were already reduced offline for mobile; preserve those bytes.
 if(!fs.existsSync(output))fs.copyFileSync(input,output);}
const data={source:{branch:baseline.branch,commit:baseline.commit,scriptSha256:hash(fs.readFileSync(path.join(source,'shared/story/level1.js')))},level:LEVEL1,view,voices};
writeJson(path.join(dest,'Level1.json'),data);
// Function-bearing fields are translated explicitly, never silently dropped by JSON.
const level2=structuredClone(JSON.parse(JSON.stringify(LEVEL2)));
level2.setup={collectors:[[-188,-12,6]]};level2.gradePolicy='truckHp';level2.resultPolicy='truck';
LEVEL2.steps.forEach((s,i)=>s.beats?.forEach((beat,k)=>{if(beat.when){
 if(String(beat.when).replace(/\s/g,'')!=='(m)=>!m.alive()')throw Error('Untranslated story condition');
 level2.steps[i].beats[k].when='noEnemies';
}}));
writeJson(path.join(dest,'Level2.json'),{source:{branch:baseline.branch,commit:baseline.commit,
 scriptSha256:hash(fs.readFileSync(path.join(source,'shared/story/level2.js')))},level:level2});
const level3=JSON.parse(JSON.stringify(LEVEL3));
level3.setup={};level3.gradePolicy='shield';level3.resultPolicy='shield';
LEVEL3.steps.forEach((s,i)=>s.beats?.forEach((beat,k)=>{
 if(beat.when){
  if(String(beat.when).replace(/\s/g,'')!=='(m)=>m.hold.energy<0.97')throw Error('Untranslated siege condition');
  level3.steps[i].beats[k].when='shieldDamaged';
 }
 if(beat.run){
  const code=String(beat.run).replace(/\s/g,'');
  if(code!=="(m)=>{m.dropPos=[0,6.2,-214];m.view.addIntel('coupon',m.dropPos);}")throw Error('Untranslated siege action '+code);
  level3.steps[i].beats[k].run='dropCoupon';
 }
}));
writeJson(path.join(dest,'Level3.json'),{source:{branch:baseline.branch,commit:baseline.commit,
 scriptSha256:hash(fs.readFileSync(path.join(source,'shared/story/level3.js')))},level:level3});
const level4=JSON.parse(JSON.stringify(LEVEL4));
level4.setup={sites:[{id:'A',pos:[-190,-12,0]},{id:'B',pos:[120,.35,117]},{id:'C',pos:[0,28,-22]}]};
level4.resultPolicy='sites';
writeJson(path.join(dest,'Level4.json'),{source:{branch:baseline.branch,commit:baseline.commit,
 scriptSha256:hash(fs.readFileSync(path.join(source,'shared/story/level4.js')))},level:level4});
console.log(JSON.stringify({steps:LEVEL1.steps.length,models:models.length,voices:Object.keys(voices).length,bytes:models.reduce((n,m)=>n+m.bytes,0)}));
