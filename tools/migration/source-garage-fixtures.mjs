// Execute original bay methods, adapting only browser UI/storage/thumbnail I/O.
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(project,'docs/migration/outgame-baseline.json'),'utf8'));
if(baseline.commit!=='90862445074e7e146da900037979ad97899ecf6c')throw Error('Unexpected garage fixture baseline');
const root=baseline.snapshot;
if(!fs.existsSync(root))throw Error('Frozen baseline snapshot is missing');
for(const name of ['shared/build/editor.js','shared/storage.js']){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(root,name))).digest('hex');
 if(hash!==baseline.files[name].sha256)throw Error('Frozen garage source mismatch: '+name);
}
globalThis.window={};globalThis.document={pointerLockElement:null};
const memory=new Map();globalThis.localStorage={getItem:k=>memory.get(k),setItem:(k,v)=>memory.set(k,v)};
const mod=p=>import(pathToFileURL(root+'/'+p));
const {Editor}=await mod('shared/build/editor.js');
const {Blueprint}=await mod('shared/build/blueprint.js');
const {storage}=await mod('shared/storage.js');
const data=(name,n=2)=>({v:1,sizeVersion:1,name,parts:Array.from({length:n},(_,i)=>['cube',i,5,0,0,0xd0182a])});
const e=Object.create(Editor.prototype);
Object.assign(e,{bp:new Blueprint().load(data('草稿')),libSlot:null,unsaved:true,
    ui:{toast(){},closeModal(){},confirm:async()=>true},_thumbnail:async()=>'',_saveSettings(){},onBaysChanged(){}});
e._changed=()=>e.unsaved=true;
e._replace=(builder,name)=>{e.libSlot=null;builder(e.bp);if(name)e.bp.name=name;e.unsaved=true;};
const cases=[];
function snapshot(){return {name:e.bp.name,count:e.bp.size,active:e.libSlot===null?false:e.libSlot+1,unsaved:e.unsaved,
    slots:storage.loadSlots().map(s=>s?{name:s.data.name,count:s.data.parts.length}:false)};}
async function step(op,...args){
    if(op==='save')await e.save(args[0]===undefined?undefined:args[0]-1);
    if(op==='rename')e.rename(args[0]);
    if(op==='new')await e.newBay(bp=>bp.load(data(args[0])));
    if(op==='open')await e.openBay(args[0]-1);
    if(op==='delete')e._dropBay(args[0]-1);
    cases.push({op,args,expected:snapshot()});
}
await step('save');await step('rename','改名');await step('new','第二辆');
await step('open',1);await step('new','第三辆');await step('open',2);await step('delete',2);
await step('delete',3);await step('delete',1);
await step('new','重新开始');await step('save');await step('open',1);
for(let i=2;i<=20;i++)await step('new','车辆 '+i);
await step('new','不应覆盖');await step('open',9);await step('rename','车辆九');await step('open',20);
await step('delete',9);await step('new','填补空位');await step('open',20);await step('delete',20);
const sources=['shared/build/editor.js','shared/storage.js'].map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(root+'/'+p)).digest('hex')}));
fs.writeFileSync(new URL('./source-garage-fixtures.json',import.meta.url),JSON.stringify({sources,initial:data('草稿'),cases},null,2));
console.log('Original H5 garage operations:',cases.length);
