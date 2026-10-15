import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
if(!vm.SourceTextModule){const r=spawnSync(process.execPath,['--experimental-vm-modules',import.meta.filename],{stdio:'inherit'});process.exit(r.status??1);}
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const filename='shared/ui/reticle.js';const source=fs.readFileSync(path.join(baseline.snapshot,filename),'utf8');
let now=0;const context=vm.createContext({console,performance:{now:()=>now},URL});
const module=new vm.SourceTextModule(source,{context,initializeImportMeta:m=>m.url='file:///frozen/shared/ui/reticle.js'});
await module.link(async()=>{const stub=new vm.SyntheticModule(['HULL','reticleScale'],function(){this.setExport('HULL',{});this.setExport('reticleScale',(w,h)=>Math.min(w/1920,h/1080));},{context});await stub.link(()=>{});return stub;});
await module.evaluate();const Reticle=module.namespace.MechReticle;
const refs={enemy:{},ally:{},locked:{}};const host={innerHTML:''};
const reticle=Object.create(Reticle.prototype);reticle.q=()=>host;
const rows=[];
for(const k of [1,.5,1.25]){
 reticle.k=k;delete reticle._gh;
 for(const step of [{at:1000,hp:1},{at:1100,hp:.26,hit:true},{at:1320,hp:.26},{at:1500,hp:.26},{at:1501,hp:.26},{at:1580,hp:.26},{at:1600,hp:.26005},{at:1700,hp:.75},{at:1800,hp:.2},{at:2020,hp:.2},{at:2201,hp:.2},{at:2400,hp:0},{at:3000,hp:.3}]){
  now=step.at;const marks=[{ref:refs.enemy,x:400*k,y:300*k,name:'Enemy',health:step.hp,enemy:true,hit:!!step.hit,dist:72.5},{ref:refs.ally,x:900*k,y:300*k,name:'Ally',health:step.hp,enemy:false,dist:12.49},{ref:refs.locked,x:600*k,y:700*k,name:'Excluded',health:.1,enemy:true,dist:5}];
  reticle._marks(marks,refs.locked);
  const groups=[...host.innerHTML.matchAll(/<g class="([^"]+)">([\s\S]*?)<\/g>/g)].map(([svg,cls,body])=>({cls,segments:[...body.matchAll(/class="mkb([^"]*)"/g)].map(m=>m[1].trim()||'live'),pct:body.match(/class="mkn mkp n"[^>]*>([^<]+)/)?.[1]??null,svg}));
  if(groups.length!==2||host.innerHTML.includes('Excluded'))throw Error('Actual source focus exclusion failed');
  rows.push({k,now,health:step.hp,hit:!!step.hit,groups,ghost:reticle._gh.get(refs.enemy).v});
 }
}
const ghostRows=[];const ghostRef={};const ghostHost=Object.create(Reticle.prototype);
for(const [at,hp]of[[0,1],[10,.2],[410,.2],[411,.2],[600,.2],[700,.20005],[800,.19996],[1201,.19996],[1500,.8],[1600,.1],[2400,.1]])ghostRows.push({at,hp,expected:ghostHost._ghost(ghostRef,hp,at)});
const fixture={baseline:baseline.commit,source:{file:filename,sha256:createHash('sha256').update(source).digest('hex')},rows,ghostRows};
const evidence=path.join(root,'docs/migration/evidence/unit-marks');fs.mkdirSync(evidence,{recursive:true});
const output=path.join(evidence,'source-'+new Date().toISOString().replaceAll(':','-')+'.json');fs.writeFileSync(output,JSON.stringify(fixture,null,2));
fs.writeFileSync(path.join(root,'.tmp/source-unit-marks.json'),JSON.stringify(fixture));
console.log(JSON.stringify({result:'PASS',baseline:baseline.commit,rows:rows.length,ghostRows:ghostRows.length,evidence:output}));
