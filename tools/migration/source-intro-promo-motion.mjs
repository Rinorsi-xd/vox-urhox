import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceHashes={};
function source(file){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,file));
 const hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[file].sha256)throw Error(`Frozen source drift: ${file}`);
 sourceHashes[file]=hash;return bytes.toString('utf8');
}
const intro=source('three/src/intro/intro.js');
const story=source('three/src/intro/introStory.js');
const inMethod=story.slice(story.indexOf('\t_in( el,'),story.indexOf('\n\t// 全息屏展开'));
const outMethod=story.slice(story.indexOf('\t_out( el,'),story.indexOf('\n\t// 整层淡入淡出'));
const motto=intro.slice(intro.indexOf("\t\tthis.mark( 'motto' );"),intro.indexOf("\t\tthis._out( card, 160 );")+"\t\tthis._out( card, 160 );".length);
const salvage=intro.slice(intro.indexOf("\t\tthis.mark( 'm-salvage' );"),intro.indexOf("\t\tthis._out( cut, 200,")+intro.slice(intro.indexOf("\t\tthis._out( cut, 200,")).indexOf('\n'));
if(!motto||!salvage||!inMethod||!outMethod)throw Error('Frozen source extraction failed');

const cases=[];
for(const duration of [8.87,4,0]){
 let now=0;const events=[];
 const element=name=>({name,style:{},isConnected:true,
  animate(frames,options){events.push({kind:'animation',name,at:now,frames,options});return {finished:Promise.resolve()};},
  remove(){events.push({kind:'removed',name,at:now});},
  querySelectorAll(){return [element('line1'),element('line2')];}});
 const ctx=vm.createContext({console,
  h:(tag,name,parent,html)=>{events.push({kind:'element',name,html,parent});return element(name);},
  IMG:name=>name,mark:()=>'',
  setTimeout:(fn,delay)=>{events.push({kind:'timer',at:now,delay});const old=now;now+=delay;fn();now=old;},
 });
 vm.runInContext(`globalThis.Host=class {${inMethod}\n${outMethod}};
 globalThis.motto=async function(){${motto}};
 globalThis.salvage=async function(){${salvage}};`,ctx);
 const host=new ctx.Host();
 Object.assign(host,{L:{slams:'slams',panels:'panels',black:'black'},audio:{duration:()=>duration},
  mark:name=>events.push({kind:'mark',name,at:now}),cut(){},task(){},
  fade:(layer,to,ms)=>events.push({kind:'fade',layer,to,ms,at:now}),
  say:async(id,opt)=>{events.push({kind:'say',id,opt,at:now});now+=((id==='n16'?duration: id==='n11'?4.96:.5)+(opt.tail||0))*1000;},
 });
 await ctx.motto.call(host);
 const mottoEvents=events.splice(0);now=0;
 await ctx.salvage.call(host);
 cases.push({duration,motto:mottoEvents,salvage:events.splice(0)});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes,cases}));
