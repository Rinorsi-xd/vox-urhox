import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),hashes={};
function read(p){const b=fs.readFileSync(path.join(baseline.snapshot,p));const sha=createHash('sha256').update(b).digest('hex');if(baseline.files[p]?.sha256!==sha)throw Error('Source drift '+p);hashes[p]=sha;return b.toString('utf8');}
const load=p=>{read(p);return import(pathToFileURL(path.join(baseline.snapshot,p)).href);};
globalThis.window={};globalThis.location={search:'?rawModels'};
globalThis.document={pointerLockElement:null};
const {Editor}=await load('shared/build/editor.js'),{Blueprint}=await load('shared/build/blueprint.js');
const {buildBounds}=await load('shared/config.js'),{ROTOR_MODES}=await load('shared/build/rotor.js');
const {storage}=await load('shared/storage.js'),{sfx}=await load('shared/ui/uiSound.js');
let sounds=[];sfx.play=id=>{sounds.push(id);return true;};
const nil=new Proxy({},{get:()=>()=>{}});
function make(initial=[]){const bp=new Blueprint();for(const d of initial)bp.add(d);const e=Object.create(Editor.prototype);Object.assign(e,{bp,view:nil,ui:nil,bounds:buildBounds(),mirror:false,spin:0,selection:new Set(),undoStack:[],redoStack:[],color:0xd0182a,paintChannel:'shell',tool:'build',clipboard:null,pasteSpin:0,hotbar:['cube'],slot:0});e._changed=()=>{};e._modeChanged=()=>{};e._saveSettings=()=>{};return e;}
const cube=(x=0,y=4,z=0)=>({type:'cube',pos:[x,y,z],rot:0,color:0x336699});
const cases=[];
function run(name,initial,action,params={}){sounds=[];const e=make(initial);action(e);cases.push({name,initial,params,sounds:[...sounds],count:e.bp.parts.size});}
run('place-none',[cube()],e=>e.place());
for(const [name,pos] of [['place-valid',[0,5,0]],['place-overlap',[0,4,0]],['place-disconnected',[20,5,0]]])run(name,[cube()],e=>{e.preview={type:'cube',pos,rot:0,res:e.bp.check('cube',pos,0,e.bounds),normal:[0,1,0]};e.place();},{pos});
run('place-mirror',[cube(3),cube(-3)],e=>{e.mirror=true;const pos=[3,5,0],m=e._mirrorOf('cube',pos,0);e.preview={type:'cube',pos,rot:0,res:e.bp.check('cube',pos,0,e.bounds),normal:[0,1,0],mirror:m};e.place();},{pos:[3,5,0],mirror:true});
for(const [name,hit] of [['remove-none',null],['remove-missing',{partId:99}],['remove-valid',{partId:1}]])run(name,[cube()],e=>e.removeTarget(hit),{hit});
run('remove-mirror',[cube(3),cube(-3)],e=>{e.mirror=true;e.removeTarget({partId:1});},{mirror:true,hit:{partId:1}});
for(const [name,tool,channel,color] of [['paint-valid','paint','shell',0xd0182a],['paint-noop','paint','shell',0x336699],['paint-channel-none','paint','accent',0xd0182a],['paint-wrong-tool','build','shell',0xd0182a]])run(name,[cube()],e=>{e.tool=tool;e.paintChannel=channel;e.color=color;e.hit={partId:1};e.paintTarget();},{tool,channel,color});
for(const [name,paste,ok] of [['paste-valid',[{type:'cube',pos:[0,5,0],rot:0,color:1}],true],['paste-invalid',[{type:'cube',pos:[0,4,0],rot:0,color:1}],false],['paste-empty',[],true]])run(name,[cube()],e=>{e.preview={paste,ok};e.commitPaste();},{paste,ok});
for(const index of [0,1,99])run('rotor-'+index,[{type:ROTOR_MODES[0].type,pos:[0,4,0],rot:0}],e=>{e.rotorAim=e.bp.parts.get(1);e.setRotorMode(index);},{index,rotorType:ROTOR_MODES[0].type});
for(const selected of [false,true])run('join-'+selected,[cube(),cube(1)],e=>{if(selected)e.selection=new Set([1,2]);e.joinSelection();},{selected});
const saves=[];
for(const spec of [{ok:true,blocked:false},{ok:false,blocked:false},{ok:true,blocked:true}]){sounds=[];const e=make([cube()]);e._runBlocked=()=>spec.blocked;e._thumbnail=async()=>null;storage.saveSlot=()=>spec.ok;await e.save(0);saves.push({...spec,sounds:[...sounds]});}
function method(text,name){const re=new RegExp('\\n\\t'+name+'\\('),m=re.exec(text);if(!m)throw Error(name);const end=text.indexOf('\n\t}',m.index);return text.slice(m.index,end+3);}
const invText=read('shared/ui/inventory.js');let opened=false;
const invContext=vm.createContext({sfx:{play:id=>sounds.push(id)},PARTS:{},document:{activeElement:null,body:{classList:{contains:()=>opened,toggle:(_,on)=>{opened=on;}}}}});
const toggle=vm.runInContext('({'+method(invText,'toggle')+'}).toggle',invContext);
const inventory=[];const inv={h:{},hotbar:[],active:0,grid:{children:[]},root:{querySelector:()=>({focus(){}})},search:{blur(){}},_fill(){},_detail(){},_save(){},get isOpen(){return opened;}};
for(const force of [true,true,false,false,true]){sounds=[];toggle.call(inv,force);inventory.push({force,sounds:[...sounds],open:opened});}
const live=read('three/src/build/liveryStudio.js');const {mirrorDecal,onCenter}=await load('shared/build/livery.js');
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/Livery/Catalog.json'))),st=catalog.stickers[0];
const ctx=vm.createContext({LIVERY_MAX:48,mirrorDecal,onCenter,sfx:{play:id=>sounds.push(id)}});
vm.runInContext(live.split('\n').find(s=>s.startsWith('const clone ='))+'\nglobalThis.Live=class{'+['place','_newDecal','remove','_twin','_nextGroup'].map(n=>method(live,n)).join('')+'};',ctx);
const livery=[];
for(const spec of [{kind:'place',size:0,pick:true,mirror:false},{kind:'place',size:0,pick:true,mirror:true},{kind:'place',size:48,pick:true,mirror:false},{kind:'place',size:0,pick:false,mirror:false},{kind:'remove',size:1,selected:true},{kind:'remove',size:1,selected:false}]){
 sounds=[];const t=new ctx.Live();const decal={s:st.id,p:[2,3,4],n:[0,0,1],r:0,w:3};Object.assign(t,{list:Array.from({length:spec.size},()=>structuredClone(decal)),pick:spec.pick?st.id:null,mirrorNew:spec.mirror,sel:spec.selected?0:-1,catalog:{byId:new Map([[st.id,st]])},ui:nil,view:{livery:{setPreview(){}}},_apply(list){this.list=list;},_record(){}});if(spec.kind==='place')t.place({p:[2,3,4],n:[0,0,1]});else t.remove();livery.push({...spec,sticker:st.id,sounds:[...sounds],count:t.list.length});
}
for(const p of ['shared/audio/workshopCues.js','shared/audio/hangarCues.js','shared/audio/mixTrim.js'])read(p);
fs.writeFileSync(path.join(root,'.tmp/build-sounds-source.json'),JSON.stringify({commit:baseline.commit,sourceHashes:hashes,cases,saves,inventory,livery},null,2)+'\n');
console.log(JSON.stringify({result:'PASS',cases:cases.length,saves:saves.length,inventory:inventory.length,livery:livery.length}));
