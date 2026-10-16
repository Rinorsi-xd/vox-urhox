import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const hashes={};
function source(file){const bytes=fs.readFileSync(path.join(baseline.snapshot,file));const hash=createHash('sha256').update(bytes).digest('hex');assert.equal(hash,baseline.files[file].sha256);hashes[file]=hash;return bytes.toString('utf8');}
const code=source('three/src/intro/intro.js'),css=source('shared/css/intro.css');
const slam=code.slice(code.indexOf('\tslam( html,'),code.indexOf('\n\twords( text,'));
const actNo=code.slice(code.indexOf('\tasync actNo()'),code.indexOf('\n\t// 一个 DOM 元素碎成'));
assert.ok(slam&&actNo);
const events=[],elements=[];let wall=0;
function h(tag,cls,parent,html){const el={className:cls,html,style:{},classList:{add(){}},remove(){},querySelector(){return {}},animate(frames,options){events.push({at:wall,className:cls,frames,options});return {finished:Promise.resolve()};}};elements.push(el);return el;}
const context=vm.createContext({h,setTimeout(){},RED_DOVE:'red'});
vm.runInContext(`globalThis.Host=class {${slam}\n${actNo}}`,context);
const host=new context.Host();
host.W=1920;host.H=1080;host.L={panels:h('div','panels'),slams:h('div','slams')};host.comic={dove:h('div','dove')};host.trauma=0;
host._rect=()=>({left:1400,top:100,width:200,height:260});
host._in=(el,frames,duration,easing)=>el.animate(frames,{duration,easing});
host.wait=async seconds=>{wall+=seconds;};host.mark=host.flash=host.shakeDom=host.grade=host._burst=()=>{};
host.audio={sfx(){},stopMusic(){}};
await host.actNo();
const styles={};
for(const selector of ['.slam','.slam.huge','.sfx','.sfx.red','.tc-tag','.tc-tag b','.tc-tag span']){
 const blocks=[];const needle=`#intro ${selector} {`;let offset=0;
 while((offset=css.indexOf(needle,offset))>=0){const end=css.indexOf('}',offset);blocks.push(css.slice(offset,end+1));offset=end+1;}
 assert.ok(blocks.length,selector);styles[selector]=blocks;
}
assert.match(styles['.slam'].at(-1),/\.12em #fff/);assert.match(styles['.slam.huge'][0],/\* 34/);
assert.match(styles['.sfx'][0],/\.1em #0b0b0d/);assert.match(styles['.sfx.red'][0],/\.09em \.09em 0 #fff/);
assert.match(styles['.tc-tag'][0],/"VoxNum"/);
const bang=elements.find(e=>e.html==='砰——！');assert.equal(bang.style.left,'1294px');assert.equal(bang.style.top,'295.6px');
assert.deepEqual(events.map(e=>e.className),['zap big','sfx red','slam huge']);
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,events,styles,bang:{text:bang.html,style:bang.style},no:{text:host.no.html,className:host.no.className},boundary:'Actual frozen actNo and slam methods executed with DOM/WAAPI adapters; CSS blocks from hash-verified source. No computed browser raster.'}));
