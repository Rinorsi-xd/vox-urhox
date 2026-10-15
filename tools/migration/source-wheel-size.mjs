// Read-only source renderer: measure the assembled wheels, not catalog sizes.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
const source='D:/Rino_Project/Vox';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const url=p=>pathToFileURL(path.join(source,p)).href;
const hashes={};
registerHooks({resolve(specifier,context,next){
 if(specifier==='three')specifier=url('three/vendor/three/build/three.module.js');
 else if(specifier.startsWith('@shared/'))specifier=url('shared/'+specifier.slice(8));
 const r=next(specifier,context);
 if(r.url.startsWith('file:')){
  const file=fileURLToPath(r.url);
  if(file.startsWith(source.replaceAll('/',path.sep)+path.sep)) hashes[path.relative(source,file).replaceAll('\\','/')]=createHash('sha256').update(fs.readFileSync(file)).digest('hex');
 }
 return r;
}});
const T=await import(url('three/vendor/three/build/three.module.js'));
const {WHEEL_GLB}=await import(url('shared/parts/wheelData.js'));
const {registerWheelGLB}=await import(url('shared/parts/wheelModels.js'));
for(const [id,g] of Object.entries(WHEEL_GLB)){
 const file='shared/assets/wheels/'+g.file,bytes=fs.readFileSync(path.join(source,file));
 hashes[file]=createHash('sha256').update(bytes).digest('hex');
 registerWheelGLB(id,bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
}
const {VehicleView}=await import(url('three/src/build/vehicleView.js'));
const {CELL}=await import(url('shared/config.js'));
const {Blueprint}=await import(url('shared/build/blueprint.js'));
const {buildRaceCar}=await import(url('shared/build/prefab.js'));
const race=buildRaceCar(new Blueprint());
const cases=[];
function bounds(object){
 const box=new T.Box3().setFromObject(object,true);
 return {min:box.min.toArray(),max:box.max.toArray()};
}
function measure(part){
 part=Object.fromEntries(['id','type','pos','rot','color'].map(k=>[k,part[k]]));
 const view=new VehicleView();view.addPart(part);view.root.updateMatrixWorld(true);
 const obj=view.objects.get(part.id),spin=obj.userData.wheel.spin;
 const tire=new T.Box3();
 spin.traverse(o=>{if(o.isMesh&&o.userData.slot==='rubber')tire.union(new T.Box3().setFromObject(o,true));});
 cases.push({part,whole:bounds(obj),spin:bounds(spin),tire:tire.isEmpty()?null:{min:tire.min.toArray(),max:tire.max.toArray()},hub:spin.getWorldPosition(new T.Vector3()).toArray()});
 view.clear();
}
for(const type of Object.keys(WHEEL_GLB))for(let rot=0;rot<24;rot++)measure({id:1,type,pos:[0,0,0],rot,color:0xd0182a});
for(const part of race.parts.values())if(WHEEL_GLB[part.type])measure(part);
const result={source,generatedAt:new Date().toISOString(),cell:CELL,sourceHashes:hashes,cases};
fs.writeFileSync(path.join(root,'tools/migration/source-wheel-size.json'),JSON.stringify(result));
console.log(JSON.stringify({cases:cases.length,wheels:Object.keys(WHEEL_GLB),race:cases.slice(-4).map(c=>({type:c.part.type,rot:c.part.rot,width:c.spin.max[0]-c.spin.min[0],diameter:c.spin.max[1]-c.spin.min[1]}))}));
