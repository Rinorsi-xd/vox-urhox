import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceFile='three/src/battle/storyBoss.js',source=fs.readFileSync(path.join(baseline.snapshot,sourceFile),'utf8');
const sha=createHash('sha256').update(source).digest('hex');if(sha!==baseline.files[sourceFile].sha256)throw Error('Boss baseline changed');
const C=JSON.parse(fs.readFileSync('assets/Story/Mission/Level5.json')).boss;
const method=source.match(/\tonHit\( point,[\s\S]*?\n\t\}\r?\n/)[0].trim().replace(/^onHit/,'function');
const hit=vm.runInNewContext('('+method+')',{FOX_BOSS:C,dist3:(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]))});
const cases=[];
for(let broken=0;broken<=4;broken++)for(const armor of [0,.6])cases.push({state:'fight',broken,damage:1000,armor,point:[0,0,50]});
cases.push({state:'kneel',broken:1,damage:100,point:[0,0,60]},{state:'kneel',broken:1,damage:100,point:[0,0,90]},
 {state:'kneel',broken:1,damage:10000,point:[0,0,60]},{state:'idle',damage:1000,point:[0,0,50]},
 {state:'fight',damage:1000,point:[20,0,0]},{state:'fight',damage:1000,point:[20,0,0],braceUntil:100});
for(const c of cases){
 const records=[];const b={state:c.state,time:0,hpMax:20000,hp:20000,kneelDealt:0,braceUntil:c.braceUntil,
 nodes:Array.from({length:4},(_,i)=>({hp:1000,max:1000,pos:[(i+1)*20,0,0],broken:i<(c.broken||0)})),
 m:{drive:{sim:{recordDamage:(u,amount,point,flags)=>records.push({amount,shield:!!flags.shield,pierce:!!flags.pierce,broke:!!flags.broke})}},hud:{banner:()=>{}}},
 cockpit:()=>[0,0,60],_hurt(amount){this.hp=Math.max(0,this.hp-amount);},_stagger:()=>{},once:()=>{},
 _breakNode(n){n.broken=true;this.state='kneel';},_go(state){this.state=state;}};
 Object.defineProperties(b,{kneeling:{get(){return this.state==='kneel';}},braced:{get(){return this.time<(this.braceUntil??0);}},
 broken:{get(){return this.nodes.filter(n=>n.broken).length;}},alive:{get(){return this.hp>0;}}});
 const amount=hit.call(b,c.point,c.damage,c.armor?{armor:c.armor}:null);
 c.expected={amount,hp:b.hp,state:b.state,kneelDealt:b.kneelDealt,records,nodes:b.nodes.map(n=>({hp:n.hp,broken:n.broken}))};
}
fs.writeFileSync('tools/migration/source-boss-fixtures.json',JSON.stringify({source:{commit:baseline.commit,file:sourceFile,sha256:sha},cases}));
console.log(JSON.stringify({cases:cases.length,source:sha}));
