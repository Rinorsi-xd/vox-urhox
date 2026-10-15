const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const acorn=require('../../.tmp/salvage-source-export/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),frozen=path.join(root,'.tmp/outgame-source-2026-10-14T10-09-50-505Z');
const source=path.join(frozen,'three/src/salvage/salvageFx.js'),code=fs.readFileSync(source,'utf8');
const ast=acorn.parse(code,{ecmaVersion:'latest',sourceType:'module'});
const body=ast.body.filter(n=>n.type!=='ImportDeclaration').map(n=>code.slice(n.type==='ExportNamedDeclaration'?n.declaration.start:n.start,n.end)).join('\n');
const document={createElement:()=>({width:128,height:128,getContext:()=>({createRadialGradient:()=>({addColorStop(){}}),beginPath(){},arc(){},fill(){},fillRect(){},getImageData:()=>({data:new Uint8ClampedArray(128*128*4)}),putImageData(){}})})};
(async()=>{
 const THREE=await import(pathToFileURL(path.join(frozen,'three/vendor/three/build/three.module.js')));
 const Fx=new Function('THREE','document',body+'\nreturn SalvageFx;')(THREE,document);
 const pick=[0,1,4,19,29,35,50,110,170,239],frames=[0,1,14,30,60,120,240,540,900];
 const cases=[];const random=Math.random;
 try{
  for(const test of [{seed:1414,pos:[3,2,-4],size:3,big:false},{seed:20261014,pos:[-8,6,12],size:5,big:true}]){
   const fx=new Fx(new THREE.Scene());let seed=test.seed;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
   fx.explode(test.pos,test.size,test.big);const snapshots=[];
   function snapshot(frame){
    const pools={};for(const kind of ['fire','core','smoke'])pools[kind]={count:fx[kind].filter(q=>q.on).length,items:pick.filter(i=>i<fx[kind].length).map(i=>{const q=fx[kind][i];return {i:i+1,on:q.on,life:q.life,max:q.max,p:q.p?.toArray(),v:q.v?.toArray(),s0:q.s0,s1:q.s1,heat:q.heat,op:q.op,rise:q.rise,dark:q.dark,rotation:q.m.rotation,spin:q.spin};})};
    const emb=[0,1,4,19,99,159,239,599].map(i=>({i:i+1,life:fx.emb.life[i],max:fx.emb.max[i],p:Array.from(fx.emb.p.slice(i*3,i*3+3)),v:Array.from(fx.emb.v.slice(i*3,i*3+3))}));
    snapshots.push({frame,shake:fx.shake,fi:fx.fi+1,ki:fx.ki+1,si:fx.si+1,ei:fx.emb.i+1,timers:fx.timers.length,brands:fx.brands.length,fires:fx.fires.length,pools,embers:emb,rings:fx.rings.map(r=>({t:r.t,r:r.r,dur:r.dur,visible:r.m.visible,scale:r.m.scale.x,opacity:r.m.material.opacity})),lights:fx.lights.map(l=>({t:l.t,peak:l.peak,dur:l.dur,intensity:l.l.intensity}))});
   }
   snapshot(0);for(let frame=1;frame<=900;frame++){fx.update(1/60,frame/60);if(frames.includes(frame))snapshot(frame);}
   fx.dispose();cases.push({...test,snapshots});
  }
 }finally{Math.random=random;}
 const report={sourceCommit:require('../../docs/migration/outgame-baseline.json').commit,sourceSha256:crypto.createHash('sha256').update(code).digest('hex'),method:'Execute original frozen SalvageFx class with actual frozen THREE. Canvas is stubbed only because original textures are exported separately; RNG reset after constructor. No modified simulation functions.',dt:1/60,cases};
 fs.writeFileSync(path.join(root,'tools/migration/source-salvage-explosion-fixtures.json'),JSON.stringify(report));console.log(JSON.stringify({cases:cases.length,snapshots:cases.reduce((n,c)=>n+c.snapshots.length,0)}));
})().catch(e=>{console.error(e);process.exitCode=1;});
