import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),sourceHashes={};
function read(file){const bytes=fs.readFileSync(path.join(baseline.snapshot,file));const hash=createHash('sha256').update(bytes).digest('hex');if(hash!==baseline.files[file]?.sha256)throw Error('Source drift '+file);sourceHashes[file]=hash;return bytes.toString('utf8');}
read('three/src/intro/holoPortrait.js');
const {HoloPortrait}=await import(pathToFileURL(path.join(baseline.snapshot,'three/src/intro/holoPortrait.js')).href);
const input=JSON.parse(fs.readFileSync(path.join(root,'.tmp/comms-portraits-input.json'))),cases=[];
globalThis.window={devicePixelRatio:2};
for(const image of input.images)for(const size of [[330,410],[156,195],[158,196],[210,260]]){
 const uniforms={};const gl=new Proxy({COLOR_BUFFER_BIT:1,TEXTURE1:1,TEXTURE0:0,TEXTURE_2D:2,TRIANGLES:4,
  uniform2f:(key,x,y)=>uniforms[key]=[x,y]}, {get:(target,key)=>key in target?target[key]:()=>{}});
 const portrait=Object.assign(Object.create(HoloPortrait.prototype),{gl,u:{uScale:'scale',uOff:'offset'},
  canvas:{},size,aspect:image.width/image.height,lastT:0,face:'talk',glitch:0,nextGlitch:100,
  tex:{talk:1},imgs:{},mouth:{from:'smile'},_upload:()=>true});
 portrait.render(1,'talk',false);cases.push({name:image.name,size,scale:uniforms.scale,offset:uniforms.offset});
}
for(const file of ['shared/css/storyHud.css','shared/css/tutorial.css','shared/ui/nonoComms.js','three/src/intro/nonoHolo.js','three/src/intro/huhuHolo.js','shared/story/huhuPortraits.js'])read(file);
fs.writeFileSync(path.join(root,'.tmp/comms-portraits-source.json'),JSON.stringify({commit:baseline.commit,sourceHashes,cases},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',sourceFitCases:cases.length}));
