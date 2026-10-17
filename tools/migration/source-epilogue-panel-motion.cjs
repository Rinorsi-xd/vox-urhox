'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),baseline=require('../../docs/migration/outgame-baseline.json');
const name='three/src/battle/storyEpilogue.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const hash=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(hash,baseline.files[name].sha256);
const animations=[];
class Element{
 constructor(){this.className='';this.style={};this.classList={add(){},remove(){}};this.children=[]}
 appendChild(e){this.children.push(e);return e}append(...all){this.children.push(...all)}insertBefore(e){this.children.push(e)}
 addEventListener(){}remove(){}
 querySelector(selector){const e=new Element();e.className=selector;return e}
 animate(frames,options){animations.push({className:this.className,frames:structuredClone(frames),options:structuredClone(options)})}
}
let serial=0;const card={root:new Element(),hide(){},say(){},queue:[]};
const context=vm.createContext({URL,document:{body:new Element(),createElement:()=>new Element()},performance:{now:()=>0},
 setTimeout:()=>++serial,clearTimeout(){},requestAnimationFrame:()=>++serial,cancelAnimationFrame(){},addEventListener(){},removeEventListener(){},
 radio(){},comms:{use:()=>card,release(){}},CHAIRMAN:'chairman',HUHU_FACES:{smug:'huhu',angry:'huhuAngry'}});
const source=bytes.toString('utf8');
vm.runInContext(source.replace(/^import .*;\r?$/gm,'').replaceAll('import.meta.url',JSON.stringify(require('node:url').pathToFileURL(path.join(baseline.snapshot,name)).href)).replace('export function playEpilogue','function playEpilogue')+'\nglobalThis.play=playEpilogue;',context);
for(const deal of [false,true]){
 const player=context.play({scenes:[{page:true,panel:{bg:'ep_photo_bg',rect:[5,10,60,75],from:'-30vw 12vw',chr:{src:'huhu',left:10,width:60,top:15,bottom:20},sfx:['POW','red','right:12%;bottom:10%',-11],deal}}]},()=>{});player.advance();
}
const panels=animations.filter(x=>x.className==='pn'),impacts=animations.filter(x=>x.className==='sfx red'),characters=animations.filter(x=>x.className==='.chr');
assert.equal(panels.length,2);assert.equal(impacts.length,2);assert.equal(characters.length,2);
const report={commit:baseline.commit,source:{path:name,sha256:hash},panels,impacts,characters,
 boundary:'Executes full hash-verified frozen playEpilogue with DOM/WAAPI recording adapters. No browser CSS compositor or GPU execution.'};
fs.writeFileSync(path.join(root,'.tmp/source-epilogue-panel-motion.json'),JSON.stringify(report,null,2)+'\n');
console.log('PASS actual frozen panel/impact/character animation recording');
