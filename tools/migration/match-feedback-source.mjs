import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const name='shared/ui/matchHud.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const sha256=createHash('sha256').update(bytes).digest('hex');
if(sha256!==baseline.files[name].sha256)throw Error('Frozen matchHud changed');
let now=1000,frames=[];
const context=vm.createContext({document:{body:{style:{setProperty(){}}}},performance:{now:()=>now},requestAnimationFrame:fn=>frames.push(fn)});
const module=new vm.SourceTextModule(bytes.toString('utf8'),{context});
await module.link(id=>{
 const values=id==='./ui.js'?{escapeHtml:s=>s}:id==='./matchLobby.js'?{avatarUrl:s=>s}:{uiViewport:()=>({scale:1})};
 return new vm.SyntheticModule(Object.keys(values),function(){for(const [key,value]of Object.entries(values))this.setExport(key,value);},{context});
});await module.evaluate();
function element(){const classes=new Set();return {textContent:'',style:{},classList:{toggle(k,v){if(v)classes.add(k);else classes.delete(k);},add:k=>classes.add(k),remove:k=>classes.delete(k),contains:k=>classes.has(k)}};}
const nodes=new Map(),actor=Object.create(module.namespace.MatchHud.prototype);
Object.assign(actor,{$:s=>{if(!nodes.has(s))nodes.set(s,element());return nodes.get(s);},avs:{blue:[],red:[]},_fill(){},_marks(){},_cap(){}});
const cases=[];
for(const mode of ['elimination','conquest','escort'])for(const state of ['prep','live','over'])for(const intro of [false,true])for(const t of [0,6.99,7,7.01,8,9,9.99,10,11])for(const alive of [false,true]){
 const rules={mode,state,cfg:{prep:10},t,timeLeft:30,score:{blue:0,red:0},round:1,sudden:true,shield:{blue:true,red:true},points:[],results:[],length:100,s:0,attack:'blue'};
 actor.update({rules,units:[],intro,me:{alive}});
 cases.push({mode,state,intro,t,alive,count:actor.$('.mh-count').classList.contains('on')?Number(actor.$('.mh-count').textContent):0,disabled:actor.$('.mh-regen').className==='mh-regen sd'});
}
const hurt=[];
for(const time of [1000,1100,1349,1350,1600,1700]){
 now=time;const before=actor._hurtAt;actor.hurt();hurt.push({time:time/1000,accepted:before!==actor._hurtAt});
}
const frameStates=[actor.$('.mh-hurt').classList.contains('on')];
for(let i=0;i<2;i++){const pending=frames;frames=[];pending.forEach(fn=>fn());frameStates.push(actor.$('.mh-hurt').classList.contains('on'));}
console.log(JSON.stringify({source:{commit:baseline.commit,name,sha256},cases,hurt,frameStates}));
