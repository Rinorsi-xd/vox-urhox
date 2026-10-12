import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const source=path.resolve(process.argv[2]||baseline.snapshot);
const load=p=>import(pathToFileURL(path.join(source,p)));
const {LEG_GLB}=await load('shared/parts/legData.js');
const {solveLegIK}=await load('shared/parts/legIK.js');
const {PART_LIST}=await load('shared/parts/defs.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const prefabs=await load('shared/build/prefab.js');
const fixtures={parts:PART_LIST.length,legs:[],prefabs:{},sourceHashes:{}};
for(const file of ['shared/parts/legData.js','shared/parts/legIK.js','shared/parts/defs.js','shared/build/prefab.js','shared/build/blueprint.js']){
 fixtures.sourceHashes[file]=createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex');
}
for(const [type,g] of Object.entries(LEG_GLB))for(const offset of [[0,0,0],[0,-1,0],[1,0,.5],[2,1,-1],[-.5,1,.5]]){
 const target=g.origins.toe.map((x,i)=>x+offset[i]);
 fixtures.legs.push({type,target,expected:solveLegIK(g,target)});
}
for(const name of ['buildRaceCar','buildMegaMech']){
 const bp=prefabs[name](new Blueprint());
 fixtures.prefabs[name]={parts:bp.size,mass:bp.stats().mass,budget:bp.stats().budget,floating:bp.connectivity().floating.size};
}
fs.writeFileSync(path.join(root,'tools/migration/source-parts-fixtures.json'),JSON.stringify(fixtures));
console.log(JSON.stringify({parts:fixtures.parts,ikCases:fixtures.legs.length,prefabs:fixtures.prefabs}));
