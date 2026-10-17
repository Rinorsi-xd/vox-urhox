const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {observedUniqueDeath,assertEnemySearchPickup}=require('./check-salvage-natural-web.cjs');
const root=path.resolve(__dirname,'../..');
execFileSync(process.execPath,[path.join(__dirname,'check-salvage-death-order-source.cjs')],{cwd:root,stdio:'pipe'});
const sourcePath=path.join(root,'.tmp/source-salvage-death-order.json');
const sourceBytes=fs.readFileSync(sourcePath),source=JSON.parse(sourceBytes),checks=[];
let sourcePickups=0,noPickupRejections=0;
for(const row of source.cases){
 let cargo=structuredClone(row.initialCargo);
 for(let i=0;i<row.picked.length;i++){
  const actual=row.picked[i],loot=row.loot[i],next=structuredClone(cargo),picked={};
  for(const item of actual.items){const n=item.n-(item.left||0);if(n>0){next[item.id]=(next[item.id]||0)+n;picked[item.id]=(picked[item.id]||0)+n;}}
  const search={title:loot.name+' 残骸箱',done:true,items:actual.items};
  if(Object.keys(picked).length){assert.deepEqual(assertEnemySearchPickup(cargo,next,search,loot.name),picked);sourcePickups++;}
  else{assert.throws(()=>assertEnemySearchPickup(cargo,next,search,loot.name),/At least one real enemy drop/);noPickupRejections++;}
  cargo=next;
 }
 assert.deepEqual(cargo,row.cargo,'Every actual source consumer pickup reconstructs final source cargo');
}
checks.push('Actual frozen source drop/pickup rows pass exact cargo proof; zero-pickup rows never count as collected');
const before={salvageRun:{kills:3},aimTargets:[{name:'a',team:'red'},{name:'b',team:'red'}]},after={salvageRun:{kills:4},aimTargets:[{name:'b',team:'red'}]};
assert.equal(observedUniqueDeath(before,after,'a'),true);checks.push('Unique enemy disappearance plus actual kill count is observable');
const rejectionCases=[
 ['despawn without death',()=>assert.equal(observedUniqueDeath(before,{...after,salvageRun:{kills:3}},'a'),false)],
 ['another enemy died',()=>assert.equal(observedUniqueDeath(before,{...after,aimTargets:before.aimTargets},'a'),false)],
 ['ambiguous duplicate name',()=>assert.equal(observedUniqueDeath({...before,aimTargets:[...before.aimTargets,{name:'a',team:'red'}]},after,'a'),false)],
 ['friendly actor',()=>assert.equal(observedUniqueDeath({...before,aimTargets:[{name:'a',team:'blue'}]},after,'a'),false)],
 ['unobserved enemy',()=>assert.equal(observedUniqueDeath(before,after,'c'),false)],
];
for(const [name,fn]of rejectionCases){fn();checks.push('Reject '+name);}
const initial={scrap:3},final={scrap:7},search={title:'a 残骸箱',done:true,items:[{id:'scrap',n:6,left:2,state:'full'}]};
assert.deepEqual(assertEnemySearchPickup(initial,final,search,'a'),{scrap:4});checks.push('Actual partial pickup leaves bounded remainder and exact cargo');
for(const [name,from,to,panel]of [
 ['nearby map cache',initial,final,{...search,title:'补给箱'}],
 ['unfinished reveal',initial,final,{...search,done:false}],
 ['hidden generated item',initial,final,{...search,items:[{...search.items[0],state:'hidden'}]}],
 ['phantom cargo item',initial,{...final,ore:1},search],
 ['missing pickup',initial,initial,search],
 ['removed carried cargo',{...initial,wire:1},final,search],
 ['invalid negative leftover',initial,final,{...search,items:[{...search.items[0],left:-2}]}],
 ['empty remnant',initial,final,{...search,items:[]}],
]){assert.throws(()=>assertEnemySearchPickup(from,to,panel,'a'));checks.push('Reject '+name);}
const tool=fs.readFileSync(path.join(__dirname,'check-salvage-natural-web.cjs'),'utf8');
assert.ok(tool.includes("process.argv.includes('--combat-loot')"));
assert.ok(tool.includes("if(combatLoot)await combatDrops();\n  else{"));
assert.ok(tool.includes("await page.keyboard.press('e')"));
assert.ok(!/keyboard\.press\('F(?:2|3|4|7|11)'\)/.test(tool));
checks.push('Optional public-input combat branch preserves original route and contains no QA death/teleport/loot hotkey');
const report={result:'PASS',sourceCommit:source.commit,sourceHashes:source.sourceHashes,sourceFixtureSha256:crypto.createHash('sha256').update(sourceBytes).digest('hex'),sourceCases:source.cases.length,sourcePickups,noPickupRejections,checks,
 toolSha256:crypto.createHash('sha256').update(tool).digest('hex'),boundary:'Offline evidence validation contracts and actual frozen source pickup replay only. No browser launched. Navigation, firing, survival, current package consumers, visual quality, complete return and performance remain OPEN until unified Web execution.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/salvage-combat-loot-tool-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
