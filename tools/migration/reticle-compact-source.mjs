import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const file='shared/ui/homeScale.js';
const hash=createHash('sha256').update(fs.readFileSync(path.join(baseline.snapshot,file))).digest('hex');
if(hash!==baseline.files[file].sha256)throw Error('Frozen source mismatch');
const {detectCompactUi,reticleScale}=await import(pathToFileURL(path.join(baseline.snapshot,file)));
const cases=[];
for(const [name,touch,platform,w,h]of [
 ['desktop',false,'Windows',1600,900],['phone',true,'Android',960,432],
 ['phone-ios',true,'iOS',844,390],['tablet',true,'Android',1024,768],
 ['touch-emulation',true,'Windows',960,540]]){
 for(const forced of [null,false,true]){
  let compact=false;
  globalThis.location={search:forced===null?'':`?compact=${forced?1:0}`};
  globalThis.matchMedia=()=>({matches:touch});
  Object.defineProperty(globalThis,'navigator',{value:{maxTouchPoints:touch?5:0},configurable:true});
  globalThis.screen={width:w,height:h};
  globalThis.document={documentElement:{toggleAttribute:(_,on)=>{compact=on},hasAttribute:()=>compact}};
  const initial=detectCompactUi();
  const frames=[];
  for(const [width,height]of [[w,h],[2000,900],[960,432],[1024,768],[1600,900]]){
   frames.push({width,height,compact:initial,k:reticleScale(width,height)});
  }
  cases.push({name,touch,platform,forced,width:w,height:h,frames});
 }
}
console.log(JSON.stringify({baseline:baseline.commit,sourceHashes:{[file]:hash},cases}));
