import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const source={};
function Load(path){
  const bytes=fs.readFileSync(`${baseline.snapshot}/${path}`),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  if(sha256!==baseline.files[path].sha256)throw new Error(`Frozen source drift: ${path}`);
  source[path]=sha256;return bytes.toString('utf8');
}
const noop=()=>{};
const context=vm.createContext({THREE:{Vector3:class{},Vector2:class{}},URLSearchParams,location:{search:''},HULL:{breachFlash:.3},
  document:{body:{classList:{toggle:noop,contains:()=>false}}},performance:{now:()=>0},sfx:{hitConfirm:noop}});
vm.runInContext(Load('three/src/drive/testDrive.js').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.TestDrive=TestDrive;',context);
const cases=[];
for(const target of ['enemy','player'])for(const attacker of ['player','ally','none'])for(const part of ['valid','missing','none'])for(const shield of [false,true])for(const time of [0,.079,.08,.080001,.2]){
  const calls=[],player={life:1,core:{hp:1,max:1}},enemy={bp:{parts:new Map([[7,{id:7}]])},_flashAt:0},ally={};
  const unit=target==='enemy'?enemy:player;
  const event={type:'damage',target:unit,source:attacker==='none'?null:attacker==='player'?player:ally,
    amount:1,point:null,partId:part==='none'?null:part==='missing'?8:7,shield};
  const drive=Object.create(context.TestDrive.prototype);
  const empty=new Proxy({},{get:()=>noop});
  Object.assign(drive,{hud:empty,sim:{time,events:[event],stats:{},timing:{}},weapons:{groups:[]},renderer:{getSize:()=>({x:1600,y:900})},
    player,pops:new Map(),combat:{tags:()=>[],units:new Map([[enemy,{view:{paintFlash:(p,color,pop)=>calls.push({id:p.id,color,pop})}}]])},
    feedback:empty,reticle:empty,cam:{},camera:{},ui:{},_threats:noop,_aimMarker:noop,_lockMarker:noop,
    _aimTarget:noop,_marks:noop,_waypoint:noop,_fireState:noop,trauma:0});
  drive._hud(0,{});cases.push({target,attacker,part,shield,time,calls});
}
const html=[];let now=0;
const el=()=>({style:{},classList:{add:noop,remove:noop},remove:noop,querySelector:()=>el()});
const feedback=vm.createContext({reticleScale:()=>1,sfx:{hitConfirm:noop,play:noop},escapeHtml:v=>v,
  performance:{now:()=>now},innerWidth:1920,innerHeight:1080,document:{createElement:el},Math});
vm.runInContext(Load('shared/ui/combatFeedback.js').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.CombatFeedback=CombatFeedback;globalThis.css=CSS;',feedback);
const state=Object.create(feedback.CombatFeedback.prototype);
Object.assign(state,{lastKill:-99,streak:0,killEl:el(),root:{appendChild:noop}});
for(let n=1;n<=5;n++){state.kill('Source target');html.push({n,html:state.killEl.innerHTML});now+=1000;}
Load('shared/css/style.css');
console.log(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},source,cases,html,css:feedback.css}));
