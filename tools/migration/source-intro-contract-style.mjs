import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const hashes={};
function source(file){const bytes=fs.readFileSync(path.join(baseline.snapshot,file));const hash=createHash('sha256').update(bytes).digest('hex');if(hash!==baseline.files[file].sha256)throw Error(`Frozen drift: ${file}`);hashes[file]=hash;return bytes.toString('utf8');}
const story=source('three/src/intro/introStory.js');
const css=source('shared/css/intro.css');
const unfold=story.slice(story.indexOf('\t_unfold( el,'),story.indexOf('\n\t_out( el,'));
const out=story.slice(story.indexOf('\t_out( el,'),story.indexOf('\n\t// 整层淡入淡出'));
const choose=story.slice(story.indexOf('\tchoose( list )'),story.indexOf('\n\t// 签约：'));
const events=[];const timers=[];
function element(name){return {name,style:{},classList:{add(){}},isConnected:true,children:[],animate(frames,options){events.push({name,frames,options});return {finished:Promise.resolve()};},remove(){},addEventListener(){}};}
const context=vm.createContext({h:(_,name)=>element(name),setTimeout:(fn,delay)=>timers.push({fn,delay})});
vm.runInContext(`globalThis.Host=class {${unfold}\n${out}\n${choose}}`,context);
const host=new context.Host();
await host._unfold(element('terminal'),{ms:240});await host._unfold(element('pad'),{delay:250,ms:200});
const unfoldEvents=events.splice(0);
host.vv={opts:element('options')};host.vv.opts.children=[0,1,2].map(i=>element(`option${i}`));
host.audio={sfx(){}};host.wait=()=>new Promise(()=>{});
const choosing=host.choose(['a','b','c']);host.onPick(1);
const timer=timers.find(t=>t.delay===260);if(!timer)throw Error('Missing frozen choose timer');timer.fn();await choosing;
const selectors=['.contract .kv em','.contract .terms','.contract .terms .fz','.motto-card','.motto-card .ip-mark','.motto-card .m1','.motto-card .m2'];
const styles={};for(const selector of selectors){const start=css.indexOf(`#intro ${selector} {`);if(start<0)throw Error(selector);styles[selector]=css.slice(start,css.indexOf('}',start)+1);}
const focus=story.match(/setTimeout\( \(\) => input\.focus\(\), (\d+) \)/);if(!focus)throw Error('Missing frozen focus timer');
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,unfold:unfoldEvents,choices:events,chooseResolveMs:timer.delay,focusMs:Number(focus[1]),styles}));
