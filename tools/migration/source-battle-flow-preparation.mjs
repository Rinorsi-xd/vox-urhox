import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8')),hashes={};
function read(file){
 const text=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
 const hash=crypto.createHash('sha256').update(text).digest('hex');
 if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift: '+file);
 hashes[file]=hash;return text;
}
const source=read('shared/audio/battleFlowMix.js');
const Flow=vm.runInNewContext(source.replace(/export /g,'')+'\nBattleFlowMix',{Math});
const events=[];
for(const type of ['roundStart','halfStart','roundEnd','suddenDeath','overtime','pointTaken','pointLost','checkpoint','matchOver','unknown']){
 for(const team of ['blue','red'])for(const winner of [null,'blue','red']){
  const event={type,team,winner,attack:team},played=[];
  new Flow({play:id=>played.push(id)}).event(event,'blue');events.push({event,played});
 }
}
const countdown=[],played=[],flow=new Flow({play:id=>played.push(id)});
for(const [remaining,active]of [[6,true],[5,true],[4.9,true],[4,true],[0,true],[3,false],[3,true]]){
 const before=played.length;flow.countdown(remaining,active);countdown.push({remaining,active,played:played.slice(before)});
}
const match=read('three/src/battle/matchSession.js');
const fragment=match.slice(match.indexOf('let lastFoundLine ='),match.indexOf('export function openMatch'));
const log=[],timers=[];
const make=vm.runInNewContext(fragment+'\nlobbyAudio',{
 Radio:class{say(id){log.push(['voice',id]);return 1;}dispose(){log.push(['dispose']);}},
 MATCH_FOUND_VOICE:['g01','g02','g03','g04','g06'],MATCH_FOUND_SFX:'match_found_latch',Math,
 sfx:{setLoop:(...args)=>log.push(['loop',...args]),play:id=>log.push(['play',id])},
 setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length;},
});
const audio=make();audio('match_search');audio('match_found');
const delay=timers[0].ms;timers[0].fn();
const lobby=read('shared/ui/matchLobby.js');
if(!lobby.includes("setTimeout( () => found(), 1100 )"))throw Error('Found presentation duration changed');
console.log(JSON.stringify({sourceCommit:baseline.commit,hashes,events,countdown,lobby:{delayMs:delay,foundMs:1100,log}}));
