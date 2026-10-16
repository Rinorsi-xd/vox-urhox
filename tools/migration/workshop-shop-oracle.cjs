const fs=require('fs');
const path=require('path');
const vm=require('vm');
const root=path.resolve(__dirname,'../..');
const base=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const frozen=path.resolve(root,base.snapshot);
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/Parts/Catalog.json'),'utf8'));
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Workshop.json'),'utf8'));
const items=JSON.parse(require('child_process').execFileSync(process.execPath,[path.join(__dirname,'workshop-source-items.mjs')],{encoding:'utf8'})).items;
const keys={raceCar:'buildRaceCar',empty:'buildEmpty',megaMech:'buildMegaMech',scorpion:'buildScorpion',hawk:'buildHawk',feather:'buildFeather',vanguard:'buildVanguard',tianyuan:'buildDrillTank',fuyuan:'buildFuyuanTank',gruntTianyuan:'buildGruntOne',gruntFuyuan:'buildFuyuanGrunt',fox:'buildFox',trooper:'buildTrooper',manta:'buildManta',rat:'buildRat',roach:'buildRoach',miniAssault:'buildMiniAssault',miniScout:'buildMiniScout',miniHeavy:'buildMiniHeavy'};
function source(file){return fs.readFileSync(path.join(frozen,file),'utf8');}
const context={ITEMS:items,partItemId:t=>'part:'+t,STARTER_CARS:[{source:{parts:[]}}],TIERS:[],CELL:.5,PARTS:{},PREFAB_STATS:data.stats,
 icon:()=>'',enter:()=>{},reduced:()=>true,escapeHtml:s=>s};
vm.createContext(context);
let stash=source('shared/salvage/stash.js').replace(/^import .*;\r?\n/gm,'').replace(/\bexport /g,'');
vm.runInContext(stash+'\nthis.SourceStash=SalvageStash;',context);
const prices={};
for(const p of data.prefabs){
 const parts=catalog.presets[keys[p.id]].parts.map(q=>[q.type,...q.pos,q.rot,q.color??null]);
 prices[p.id]=context.SourceStash.prototype.carValue.call({}, {parts});
}
context.prices=prices;
let workshop=source('shared/ui/workshop.js').replace(/^import .*;\r?\n/gm,'').replace(/\bexport /g,'')
 .replace(/^const PREFAB_ART = .*;\r?$/m,"const PREFAB_ART = id => id;");
vm.runInContext(workshop+'\nthis.SourceWorkshop=Workshop;this.SourceFeatured=FEATURED;',context);
const groups=['all','wheel','track','mech','plane','pirate','blank'];
const sorts=['rec','tier','parts','speed','price'];
const order=[];
for(const group of groups)for(const sort of sorts){
 const grid={innerHTML:'',querySelectorAll:()=>[],children:[]};
 const pane={querySelectorAll:()=>[],querySelector:selector=>{if(selector!=='.wsb-grid')throw Error(selector);return grid;}};
 const ws=Object.create(context.SourceWorkshop.prototype);
 Object.assign(ws,{pane,filter:group,sort,cur:'browse',shop:{price:id=>prices[id],wallet:()=>8000},_meta:()=>{}});
 ws._grid();
 order.push({group,sort,ids:[...grid.innerHTML.matchAll(/data-detail="([^"]+)"/g)].map(m=>m[1])});
}
const refresh=[];
for(const id of data.prefabs.map(p=>p.id))for(const wallet of [0,8000,prices[id],prices[id]+1]){
 const nodes={};const get=selector=>nodes[selector]??=(selector.endsWith(' b')?{}:{classList:{toggle:(name,value)=>{nodes[selector].poor=!!value;}},querySelector:()=>nodes.subtitle??=( {})});
 const pane={querySelector:get,querySelectorAll:()=>[]};
 const ws=Object.create(context.SourceWorkshop.prototype);
 Object.assign(ws,{pane,detailId:id,heroI:0,shop:{price:key=>prices[key],wallet:()=>wallet},_cost:()=>{}});
 ws.refresh();
 refresh.push({id,wallet,cost:prices[id],poor:nodes['.wsd-go'].poor,subtitle:nodes.subtitle.innerHTML});
}
const featureReturn=[];
for(const [heroI,hero]of Array.from(context.SourceFeatured).entries())for(const p of data.prefabs)for(const from of ['feature','browse']){
 const node=()=>({classList:{toggle:()=>{}}});const pane={dataset:{},querySelector:node,querySelectorAll:()=>[]};
 let shown;const ws=Object.create(context.SourceWorkshop.prototype);
 Object.assign(ws,{pane,heroI,cur:from,gridDone:true,thumbs:{},h:{prefabBlueprint:id=>({marker:id,parts:new Map(),stats:()=>({count:0})})},
  preview:{show:bp=>{shown=bp.marker;},stop:()=>{}},_meta:()=>{},_bars:()=>[],refresh:()=>{}});
 ws.detail(p.id,from);const detailId=ws.detailId;ws.view(from);if(from==='browse')ws.view('feature');
 featureReturn.push({hero,detail:p.id,from,detailId,shown,returnedHero:context.SourceFeatured[ws.heroI]});
}
process.stdout.write(JSON.stringify({baseline:{branch:base.branch,commit:base.commit},prices,order,refresh,featureReturn}));
