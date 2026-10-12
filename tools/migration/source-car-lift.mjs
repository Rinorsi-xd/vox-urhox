// Execute the unchanged source CarLift and editor's grounding getter.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root='D:/Rino_Project/Vox';
globalThis.window={};globalThis.document={pointerLockElement:null};
const mod=p=>import(pathToFileURL(root+'/'+p));
const {Editor}=await mod('shared/build/editor.js');
const {Blueprint}=await mod('shared/build/blueprint.js');
const {buildRaceCar,buildTank}=await mod('shared/build/prefab.js');
const {CELL}=await mod('shared/config.js');
const file='three/src/scene/carLift.js',source=fs.readFileSync(root+'/'+file,'utf8');
const code=source.replace(/^import .*;\r?\n/gm,'').replace('export class CarLift','class CarLift');
const CarLift=new Function('CELL','reduced',code+'\nreturn CarLift;')(CELL,()=>false);
const raised=buildRaceCar(new Blueprint()).toJSON();for(const part of raised.parts)part[2]+=7;
const leg=new Blueprint();leg.add({type:'leg5',pos:[0,8,0],rot:0,color:0xffffff});
const cases=[];
for(const [name,bp] of [['race',buildRaceCar(new Blueprint())],['tank',buildTank(new Blueprint())],['raised',new Blueprint().load(raised)],['leg',leg],['empty',new Blueprint()]]){
 const editor=Object.create(Editor.prototype);Object.assign(editor,{bp,bounds:{minY:0},viewOnly:true});
 const view={root:{position:{y:-editor.liftHeight*CELL}}};let welcomes=0;
 const lift=new CarLift({editor,view,garage:{welcome(){welcomes++;}}}),frames=[];
 function frame(action,dt=0){
  if(action==='sink')lift.sink();else if(action==='rise')lift.rise();else if(action==='settle')lift.settle();
  else if(action==='edit'){editor.viewOnly=false;lift.settle();}
  else lift.update(dt);
  frames.push({action,dt,y:view.root.position.y,active:!!lift.anim,welcomes});
 }
 frame('sink');for(const dt of [0,.03,.07,.05,.05,.1])frame('step',dt);
 frame('rise');for(const dt of [.016,.034,.05,.05,.1,.1,.1,.2])frame('step',dt);
 frame('sink');frame('step',.1);frame('rise');frame('step',.2);
 frame('sink');frame('step',.2);frame('rise');frame('step',.1);frame('settle');
 frame('rise');frame('step',.1);frame('edit');frame('step',.2);
 cases.push({name,blueprint:bp.toJSON(),rest:-editor.liftHeight*CELL,depth:lift._depth(),frames});
}
const hashes=Object.fromEntries([file,'shared/build/editor.js','shared/config.js'].map(p=>[p,createHash('sha256').update(fs.readFileSync(root+'/'+p)).digest('hex')]));
fs.writeFileSync(new URL('./source-car-lift.json',import.meta.url),JSON.stringify({hashes,cell:CELL,cases},null,2));
console.log('Source CarLift: '+cases.length+' vehicles, '+cases.reduce((n,c)=>n+c.frames.length,0)+' trajectory samples');
