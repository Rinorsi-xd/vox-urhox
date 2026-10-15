import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const root='D:/Rino_Project/Vox/';
const {PART_LIST}=await import(pathToFileURL(root+'shared/parts/defs.js'));
const {getInstancedLayers}=await import(pathToFileURL(root+'shared/parts/models.js'));
const source=fs.readFileSync(root+'three/src/build/vehicleView.js','utf8');
const materials=source.match(/const xrayMats = \{[\s\S]*?\n\};/)[0];
const method=source.match(/\tsetXray\( on \) \{([\s\S]*?)\n\t\}/)[1];
const toggle=new Function('THREE',`${materials}\nreturn function(on){${method}};`)({MeshStandardMaterial:class{constructor(props){Object.assign(this,props);}}});
const parts={};
for(const part of PART_LIST){
  const layers=part.instanced?getInstancedLayers(part.id):[];
  const meshes=layers.map(l=>{const base={slot:l.slot};return {material:base,userData:{slot:l.slot,baseMaterial:base},castShadow:true};});
  toggle.call({meshes},true);
  const slots=meshes.map((m,i)=>({slot:layers[i].slot,painted:layers[i].painted,...m.material,castShadow:m.castShadow}));
  toggle.call({meshes},false);
  if(meshes.some(m=>m.material!==m.userData.baseMaterial||!m.castShadow))throw Error('Source restore changed');
  parts[part.id]={instanced:!!part.instanced,slots};
}
fs.writeFileSync(new URL('./source-build-xray.json',import.meta.url),JSON.stringify({parts}));
console.log(`Original xray method: ${Object.keys(parts).length} types; ${Object.values(parts).filter(p=>p.instanced).length} structural types`);
