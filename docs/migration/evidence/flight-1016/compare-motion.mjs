import fs from 'node:fs';
const dir='.tmp/flight-parity-20261016/';
const load=p=>JSON.parse(fs.readFileSync(dir+p));
const b=load('before-snapshot/native-motion-result.json');
const a=load('after-snapshot/native-motion-result.json');
const s=load('source-motion-result.json');
const angle=(p,q)=>{const keys=['x','y','z','w'];const dot=keys.reduce((n,k)=>n+p[k]*q[k],0);const len=v=>Math.sqrt(keys.reduce((n,k)=>n+v[k]*v[k],0));return 2*Math.acos(Math.min(1,Math.abs(dot)/(len(p)*len(q))))*180/Math.PI;};
const dist=(p,q)=>Math.hypot(p.x-q.x,p.y-q.y,p.z-q.z);
const cases=[];
for(const ref of s.rows.filter(x=>x.id!=='raceCar')){
 const old=b.rows.find(x=>x.id===ref.id),now=a.rows.find(x=>x.id===ref.id);
 for(const seg of ref.segments){
  const before=old.segments.find(x=>x.name===seg.name),after=now.segments.find(x=>x.name===seg.name);
  const errs=(n)=>seg.samples.map((x,i)=>({angle:angle(x.state.q,n.samples[i].state.q),position:dist(x.state.p,n.samples[i].state.p)}));
  const eb=errs(before),ea=errs(after);const avg=(v,k)=>v.reduce((n,x)=>n+x[k],0)/v.length;
  cases.push({id:ref.id,name:seg.name,attitudeMeanBefore:avg(eb,'angle'),attitudeMeanAfter:avg(ea,'angle'),attitudeEndBefore:eb.at(-1).angle,attitudeEndAfter:ea.at(-1).angle,positionMeanBefore:avg(eb,'position'),positionMeanAfter:avg(ea,'position')});
 }
}
let same=true;const check=(p,q)=>{if(typeof p==='number'){if(p!==q)same=false;}else if(p&&typeof p==='object'){for(const k of new Set([...Object.keys(p),...Object.keys(q||{})]))check(p[k],q?.[k]);}else if(p!==q)same=false;};
check(b.rows.find(x=>x.id==='raceCar'),a.rows.find(x=>x.id==='raceCar'));
const avg=k=>cases.reduce((n,x)=>n+x[k],0)/cases.length;
const report={nonWingUnchanged:same,cases,meanAttitudeBefore:avg('attitudeMeanBefore'),meanAttitudeAfter:avg('attitudeMeanAfter'),meanPositionBefore:avg('positionMeanBefore'),meanPositionAfter:avg('positionMeanAfter'),scope:'16 cases x120 real integrated physics steps; Native Bullet vs actual H5 Rapier in empty world. No rendering, map contacts, ground takeoff, damage, or subjective feel acceptance.'};
console.log(JSON.stringify(report,null,2));
fs.writeFileSync(dir+'motion-comparison.json',JSON.stringify(report,null,2));
