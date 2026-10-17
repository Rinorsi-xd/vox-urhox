import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const hashes={};
function source(file){const bytes=fs.readFileSync(path.join(baseline.snapshot,file));const hash=createHash('sha256').update(bytes).digest('hex');assert.equal(hash,baseline.files[file].sha256,file);hashes[file]=hash;return bytes.toString('utf8');}
const intro=source('three/src/intro/intro.js'),css=source('shared/css/intro.css');
const body=intro.slice(intro.indexOf('\tasync actDecide() {'),intro.indexOf('\n\t// 四连闪'));
const cases=[];
let holdHTML;
for(const progress of [0,.25,.5,.75,1]){
 const styles={};const nodes={};
 const node=name=>nodes[name]??=( {style:styles[name]??={setProperty(key,value){this[key]=value;}},classList:{add(){},remove(){}},remove(){},setAttribute(key,value){this[key]=value;},animate(frames,options){return {finished:Promise.resolve()};},querySelector(selector){return node(selector);},querySelectorAll(){return [node('idle'),node('hero')];}} );
 const context=vm.createContext({h(tag,cls,parent,html){assert.equal(tag,'div');assert.equal(cls,'hold');holdHTML=html;return node('hold');},IMG:name=>name,Math});
 vm.runInContext(`globalThis.Host=class {${body}}`,context);
 const host=new context.Host();let holdState;
 Object.assign(host,{L:{panels:node('panels'),decide:node('decide'),black:node('black'),tint:node('tint')},holding:true,
  mark(){},clearTasks(){},audio:{stopMusic(){},sfx(){return {src:{playbackRate:{value:1}},stop(){}};},playMusic(){}},say(){return Promise.resolve();},wait(){return Promise.resolve();},_in(){},flash(){},
  task(callback){callback(0,progress*1.3);holdState=JSON.parse(JSON.stringify(styles));if(progress<1)callback(0,(1-progress)*1.3);return Promise.resolve();}});
 await host.actDecide();
 cases.push({progress,hold:holdState,decided:JSON.parse(JSON.stringify(styles))});
}
const speed=css.match(/#intro \.speed \{[\s\S]*?\}/)?.[0],cone=css.match(/#intro \.beam-cone \{[\s\S]*?\}/)?.[0];
const hold=css.match(/#intro \.hold \{[\s\S]*?\}/)?.[0],holdSvg=css.match(/#intro \.hold svg \{[\s\S]*?\}/)?.[0],holdText=css.match(/#intro \.hold \.k \{[\s\S]*?\}/)?.[0];
assert(hold?.includes('* 16)')&&hold.includes('* 1.6)'));assert(holdSvg?.includes('* 11)'));assert(holdText?.includes('* 2.6)/1')&&holdText.includes('letter-spacing: .14em'));
assert(holdHTML.includes('viewBox="0 0 100 100"')&&holdHTML.includes('y="58"')&&holdHTML.includes('r="44"'));
assert.ok(speed?.includes('inSpin 7s linear infinite')&&speed.includes('transparent 22%, #000 60%'));
assert.ok(cone?.includes('from 168deg at 50% 0%')&&cone.includes('rgba(214, 238, 255, .32) 12deg'));
process.stdout.write(JSON.stringify({baseline:baseline.commit,hashes,cases,css:{speed,cone,hold,holdSvg,holdText},dom:{holdHTML}}));
