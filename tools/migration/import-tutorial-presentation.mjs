// Evaluate the frozen UI's actual _go/touchCopy without constructing a browser.
// Run with: node --experimental-vm-modules tools/migration/import-tutorial-presentation.mjs
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const files=['shared/ui/tutorial.js','shared/ui/touchCopy.js','shared/story/tutorial.js'];
const input={};
for(const relative of files){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));
 const hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[relative]?.sha256)throw Error('Frozen input changed: '+relative);
 input[relative]={source:bytes.toString('utf8'),sha256:hash};
}
const classes={add(){},remove(){},toggle(){}};
const node=()=>({classList:classes,remove(){},insertBefore(){},querySelectorAll(){return[];}});
const context=vm.createContext({document:{body:{classList:{contains:()=>true}},createElement:node},setTimeout(){},clearTimeout(){}});
const synthetic=exports=>new vm.SyntheticModule(Object.keys(exports),function(){for(const [name,value]of Object.entries(exports))this.setExport(name,value);},{context});
const script=new vm.SourceTextModule(input['shared/story/tutorial.js'].source,{context});await script.link(()=>{throw Error('Unexpected story import')});await script.evaluate();
const copy=new vm.SourceTextModule(input['shared/ui/touchCopy.js'].source,{context});await copy.link(()=>{throw Error('Unexpected touchCopy import')});await copy.evaluate();
const ui=new vm.SourceTextModule(input['shared/ui/tutorial.js'].source,{context});
await ui.link(name=>{
 if(name==='../story/tutorial.js')return script;
 if(name==='./touchCopy.js')return copy;
 const dependencies={'./icons.js':{icon(){}},'./nonoComms.js':{comms:{}},'./uiSound.js':{sfx:{}},'./uiScale.js':{uiCoordinates(){}}};
 if(!dependencies[name])throw Error('Unexpected UI import '+name);
 return synthetic(dependencies[name]);
});await ui.evaluate();
const steps=script.namespace.TUTORIAL;
const owner=Object.create(ui.namespace.Tutorial.prototype);
Object.assign(owner,{app:{editor:{input:{touchEnabled:true},bp:{parts:new Map()}}},byId:Object.fromEntries(steps.map(s=>[s.id,s])),flow:steps.map(s=>s.id),record:{},replay:true,
 _save(){},_busy(){return true;},suspend(){},root:node(),$(selector){return selector==='.tu-picks'?null:node();}});
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Tutorial.json')));
let mobileLines=0;
for(let index=0;index<steps.length;index++){
 owner._go(index);
 const target=data.steps.find(step=>step.id===steps[index].id);
 if(!target)throw Error('Missing tutorial step '+steps[index].id);
 target.touchHint=copy.namespace.touchCopy(steps[index].hint||'');
 if(JSON.stringify(owner._lines)!==JSON.stringify(steps[index].lines)){
  target.touchLines=JSON.parse(JSON.stringify(owner._lines));mobileLines++;
 }else delete target.touchLines;
}
data.source={branch:baseline.branch,commit:baseline.commit,scriptSha256:input['shared/story/tutorial.js'].sha256,
 presentation:Object.fromEntries(files.slice(0,2).map(name=>[name,input[name].sha256]))};
const report={result:'PASS',source:data.source,steps:data.steps.length,touchDialogueOverrides:mobileLines,
 voiceCount:Object.keys(data.voices).length,
 boundary:'Exact frozen tutorial _go/touchCopy evaluated in a native-free VM. Source touch dialogue says operation menu while same-source hints/editor use bottom bag and top save; retained as authored.'};
if(process.argv.includes('--check')){
 const actual=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Tutorial.json')));
 if(JSON.stringify(actual)!==JSON.stringify(data))throw Error('Tutorial presentation is stale; rerun importer');
}else fs.writeFileSync(path.join(root,'assets/UI/Tutorial.json'),JSON.stringify(data));
const output=path.join(root,'docs/migration/evidence/tutorial-presentation-import.json');fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
