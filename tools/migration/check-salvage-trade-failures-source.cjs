const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json')));
const sourceHashes={};
function read(name){const bytes=fs.readFileSync(path.join(baseline.snapshot,name)),sha=crypto.createHash('sha256').update(bytes).digest('hex');if(sha!==baseline.files[name].sha256)throw Error('Frozen source drift '+name);sourceHashes[name]=sha;return bytes.toString('utf8');}
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json')));
const rules=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/SalvageRules.json')));
const ctx=vm.createContext({URL,ITEMS:data.items,ITEM_CATS:data.categories,RARITY:data.rarity,PARTS:{},STARTER_CARS:[],
  REGIONS:[],PLAN_LOOT:[],PLAN_EX:[],PLAN_SPAWNS:[],OPS:[{}],OP_KEY:'op',CARGO_SLOTS:20,
  partItemId:t=>'part:'+t,sellPrice:id=>Math.max(1,Math.floor(data.items[id].price*rules.sellRate)),icon:()=>''});
const strip=raw=>raw.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify('file:///frozen/shared/ui/salvageHub.js'));
vm.runInContext(strip(read('shared/salvage/stash.js'))+'\nglobalThis.Stash=SalvageStash;',ctx);
vm.runInContext(strip(read('shared/ui/salvageHub.js'))+'\nglobalThis.Hub=SalvageHub;',ctx);
const cases=[];
const ids=[Object.values(data.items).find(it=>it.cat==='part'&&it.partCat==='weapon').id,'alloy'];
for(const id of ids){
  const price=data.items[id].price;
  for(const [owned,used,n]of [[9,4,6],[9,9,1],[9,12,1],[0,1,1],[2,0,3],[0,0,1]]){
    cases.push({name:'sell-'+id+'-'+owned+'-'+used+'-'+n,id,sell:true,n,credits:87654,items:{[id]:owned},usage:{[id]:used}});
  }
  for(const missing of [1,99,1000,12345,1234567]){
    const n=Math.ceil(missing/price)+3,credits=price*n-missing;
    cases.push({name:'credit-'+id+'-'+missing,id,sell:false,n,credits,items:{},usage:{}});
  }
  for(const credits of [99999999,0])cases.push({name:'full-'+id+'-'+credits,id,sell:false,n:1,credits,items:{scrap:50*rules.cells},usage:{}});
}
for(const c of cases){
  const stash=Object.create(ctx.Stash.prototype),notes=[],sounds=[];let saves=0;
  Object.assign(stash,{credits:c.credits,items:new Map(Object.entries(c.items)),usage:()=>c.usage,save(){saves++;}});
  ctx.sfx={play(id){sounds.push(id);}};
  const hub=Object.assign(Object.create(ctx.Hub.prototype),{stash,qty:c.n,h:{toast:(text,kind)=>notes.push({text,kind})},$(){throw Error('Failure must not animate money');}});
  hub._trade(c.sell?'sell':'buy',data.items[c.id],c.n);
  c.expected={notes,sounds,saves,credits:stash.credits,items:Object.fromEntries(stash.items),qty:hub.qty};
  if(saves||sounds.length||notes.length!==1||notes[0].kind!=='bad')throw Error('Fixture must exercise a real source failure '+c.name);
}
const out=path.join(root,'.tmp/source-salvage-trade-failures.json');
fs.writeFileSync(out,JSON.stringify({commit,sourceHashes,cases},null,2)+'\n');
console.log(JSON.stringify({out,cases:cases.length}));
