// Execute the frozen source methods with recording HUD sinks, without a browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const base=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8')).snapshot;
const sandbox=vm.createContext({THREE:{Vector3:class{}},sfx:{consumeDamage(){}},cameraListener(){}});
const code=fs.readFileSync(path.join(base,'three/src/battle/matchSession.js'),'utf8')
  .replace(/^import .*;\r?\n/gm,'').replace(/export (class|function) /g,'$1 ');
const modes=vm.runInContext(`(()=>{${code};return MODES})()`,sandbox);
const cases=[];
function add(mode,event,extra={}){
  const calls=[];const rules={score:{blue:1,red:0},cfg:{prep:5},half:1,round:2,attack:'blue',...extra};
  rules.owned=team=>team==='blue'?2:1;
  const hud={banner:(title,sub='',cls='',ms=2600,tag='',{mini=false}={})=>calls.push({text:title,sub,cls,ms,tag,mini}),dead(){}};
  const modeObject=Object.create(modes[mode].prototype);
  Object.assign(modeObject,{s:{rules,cfg:rules.cfg,hud,placeAll(){},drive:{camera:{}}},cart:{reset(){}},
    base:Object.fromEntries(['blue','red'].map(t=>[t,{zone:{pos:[0,0,0]},fx:{down(){},raise(){}}}]))});
  modeObject.onEvent(event);
  cases.push({mode,event,rules:{score:rules.score,cfg:rules.cfg,half:rules.half,round:rules.round,attack:rules.attack,final:!!extra.final},
    world:{alive:event.alive||{blue:2,red:1},hp:event.hp||{blue:.75,red:.5}},expected:calls[0]||null});
}
add('elimination',{type:'roundPrep',round:1,final:false});
add('elimination',{type:'roundPrep',round:3,final:true},{final:true,score:{blue:1,red:1}});
for(const type of ['roundStart','suddenDeath'])add('elimination',{type});
for(const winner of ['blue','red',null])for(const how of ['wipe','alive','hp'])add('elimination',{type:'roundEnd',round:2,winner,how,score:{blue:1,red:1},alive:{blue:2,red:1},hp:{blue:.756,red:.456}});
for(const type of ['roundPrep','roundStart','overtime','pointNode'])add('conquest',{type});
for(const team of ['blue','red'])for(const type of ['pointTaken','pointLost','shieldDown','shieldUp'])add('conquest',{type,team,id:'C'});
for(const attack of ['blue','red']){
  add('escort',{type:'halfPrep',half:attack==='blue'?1:2,attack},{attack});
  add('escort',{type:'halfStart',attack},{attack});
  add('escort',{type:'checkpoint',attack,n:2,bonus:60},{attack});
  for(const done of [true,false])add('escort',{type:'halfEnd',attack,done,dist:201.8,time:125.2},{attack,half:attack==='blue'?1:2});
}
add('escort',{type:'overtime'});
process.stdout.write(JSON.stringify(cases));
