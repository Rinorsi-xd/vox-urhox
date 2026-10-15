import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const file='shared/drive/trackSim.js',source=path.resolve(root,baseline.snapshot,file);
const hash=createHash('sha256').update(fs.readFileSync(source)).digest('hex');
if(hash!==baseline.files[file]?.sha256)throw Error('Frozen TrackSim changed');
const {TrackSim}=await import(pathToFileURL(source));
const unitFile='shared/combat/carUnit.js',unitSource=path.resolve(root,baseline.snapshot,unitFile);
const unitHash=createHash('sha256').update(fs.readFileSync(unitSource)).digest('hex');
if(unitHash!==baseline.files[unitFile]?.sha256)throw Error('Frozen CarUnit changed');
const {CarUnit}=await import(pathToFileURL(unitSource));
const cases=[];
for(const target of ['player','enemy'])for(const attacker of ['none','player','enemy'])for(const kind of ['normal','shield','pierce']){
 const player={team:'player'},enemy={team:'red'};
 const state={player,attacker:attacker==='none'?null:attacker==='player'?player:enemy,time:4,stats:{damage:0,kills:0,recent:[]},events:[]};
 TrackSim.prototype.recordDamage.call(state,target==='player'?player:enemy,25,[1,2,3],kind==='normal'?{}:{[kind]:true});
 const event=state.events[0];
 const eligible=event.target!==player&&(!event.source||event.source===player);
 const killed=target==='player'?player:enemy;killed.lastHitBy=state.attacker;
 TrackSim.prototype.recordKill.call(state,killed,[1,2,3]);
 cases.push({target,attacker,kind,damage:state.stats.damage,feedback:eligible,kills:state.stats.kills});
}
const hits=[];
for(const shield of [0,80])for(const attacker of ['none','player','enemy'])for(const amount of [0,25])for(const hp of [0,30]){
 const player={},enemy={};const by=attacker==='none'?null:attacker==='player'?player:enemy;
 const unit=Object.assign(Object.create(CarUnit.prototype),{alive:true,kill:null,lastHitBy:enemy,hullEnabled:true,
  hp:new Map([[1,hp]]),shields:new Map(),bp:{parts:new Map([[1,{type:'cube',_cells:[[0,0,0]]}]])},
  struct:0,bodyHp:1000,bodyHpMax:1000,lostCells:0,lostMajor:0,hitAt:-1,
  env:{time:4,attacker:by,fx:[],viewEvents:[],recordDamage(){}}});
 if(shield)unit.shields.set(1,{v:shield,hit:0,t:0});unit.shieldOf=id=>unit.shields.get(id).v;
 unit._layers(1,amount,[0,0,0],false);
 hits.push({shield,attacker,amount,hp,lastHitBy:unit.lastHitBy==null?'none':unit.lastHitBy===player?'player':'enemy'});
}
const output=path.join(root,'.tmp/source-damage-credit.json');
fs.writeFileSync(output,JSON.stringify({sourceCommit:baseline.commit,provenance:{[file]:hash,[unitFile]:unitHash},cases,hits}));
console.log(JSON.stringify({output,cases:cases.length,hits:hits.length}));
