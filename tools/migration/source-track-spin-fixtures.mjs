// Execute frozen source presentation methods without creating a renderer.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const source=path.join(root,'.tmp/outgame-source-2026-10-15T12-35-57-243Z');
const read=p=>fs.readFileSync(path.join(source,p),'utf8').replaceAll('\r\n','\n');
const THREE=await import(pathToFileURL(path.join(source,'three/vendor/three/build/three.core.js')));
const car=read('three/src/drive/carVisual.js'),view=read('three/src/build/vehicleView.js');
const pathText=read('shared/parts/trackPath.js');
const atBody=pathText.split('const at = ( s, out =')[1].split(') => {')[1].split('\n\t};')[0];
const at=new Function('total','segs','s','out',atBody);
const offsetBody=view.split('export function setTrackOffset( track, s ) {')[1].split('\n}\n')[0];
const setTrackOffset=new Function('_pf','_tm',`return function(track,s){${offsetBody}\n}`)(
 {p:[0,0],n:[0,0],t:[0,0]},new THREE.Matrix4());
const method=car.slice(car.indexOf('_tracks() {'),car.indexOf('\n\t// 炮塔',car.indexOf('_tracks() {')));
const CELL=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/Catalog.json'),'utf8')).cell;
const tracks=new Function('CELL','Y','ONE','_qb','setTrackOffset',`return ({${method}})._tracks`)(
 CELL,new THREE.Vector3(0,1,0),new THREE.Vector3(1,1,1),new THREE.Quaternion(),setTrackOffset);
const cases=[],inputs={};
for(const type of ['track2','track3','track4','track5']){
 const rigPath=`assets/Parts/Rigs/${type}.json`;
 const s=JSON.parse(fs.readFileSync(path.join(root,rigPath),'utf8')).segments;
 inputs[rigPath]=createHash('sha256').update(fs.readFileSync(path.join(root,rigPath))).digest('hex');
 for(const sign of [-1,1]){
  const pads=s.pads.map(p=>({idx:p.idx,meshes:[{matrices:[],setMatrixAt(i,m){this.matrices[i]=m.elements.slice();},instanceMatrix:{}}]}));
  const wheels=list=>list.map(w=>({c:new THREE.Vector3(...w.c),r:w.r,grp:{matrix:new THREE.Matrix4()}}));
  const track={pads,wheels:wheels(s.wheels),rings:wheels(s.rings),path:{at:(v,o)=>at(s.path.total,s.path.segs,v,o)},spacing:s.spacing,offset:null};
  const owner={trackObjs:[{i:1,sgn:sign,track}],vehicle:{wheelTravel:()=>0}};
  // The Lua verifier rebinds the surviving rig before the final two steps.
  for(const [step,travel]of [0,.37,-.61,3.2,-3.2,.37,-.61].entries()){
   owner.vehicle={wheelTravel:()=>travel};tracks.call(owner);
   cases.push({type,sign,step,travel,retained:step>=5,offset:track.offset,
    pads:track.pads.flatMap(p=>p.meshes[0].matrices),
    wheels:[...track.wheels,...track.rings].map(w=>w.grp.matrix.elements.slice())});
  }
 }
}
const files=['three/src/drive/carVisual.js','three/src/build/vehicleView.js','shared/parts/trackPath.js','three/vendor/three/build/three.core.js'];
process.stdout.write(JSON.stringify({sourceCommit:'b276064942ae09c0227ec28d4cfda1d5ff006455',CELL,inputs,
 hashes:Object.fromEntries(files.map(p=>[p,createHash('sha256').update(fs.readFileSync(path.join(source,p))).digest('hex')])),cases}));
