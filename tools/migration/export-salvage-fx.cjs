const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const acorn=require('../../.tmp/salvage-source-export/node_modules/acorn');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=require('../../docs/migration/outgame-baseline.json');
const source=path.join(root,'.tmp/outgame-source-2026-10-14T10-09-50-505Z/three/src/salvage/salvageFx.js');
const text=fs.readFileSync(source,'utf8'),ast=acorn.parse(text,{ecmaVersion:'latest',sourceType:'module'});
const functions=ast.body.filter(n=>n.type==='FunctionDeclaration'&&['puffTex','dotTex'].includes(n.id.name)).map(n=>text.slice(n.start,n.end)).join('\n');
if(!functions.includes('function puffTex')||!functions.includes('function dotTex'))throw Error('Frozen procedural functions missing');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  const page=await browser.newPage();const images=await page.evaluate(({functions})=>{
   let seed=20261014;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
   const three={CanvasTexture:function(image){this.image=image;},SRGBColorSpace:'srgb'};
   return new Function('THREE',functions+`;return [puffTex(),puffTex(),puffTex({soft:.4,blobs:34}),puffTex({soft:.7,core:false}),puffTex({soft:.7,core:false,blobs:34}),dotTex()].map(t=>t.image.toDataURL('image/png'));`)(three);
  },{functions});
  const dir=path.join(root,'assets/Salvage/Fx');fs.mkdirSync(dir,{recursive:true});const names=['fire-0','fire-1','fire-2','smoke-0','smoke-1','dot'];const files=[];
  for(let i=0;i<images.length;i++){const data=Buffer.from(images[i].split(',')[1],'base64'),name=names[i]+'.png';fs.writeFileSync(path.join(dir,name),data);files.push({name,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')});}
  const report={baseline,source:path.relative(root,source),sourceSha256:crypto.createHash('sha256').update(text).digest('hex'),method:'Original frozen puffTex/dotTex Canvas functions extracted through Acorn AST. Deterministic seed 20261014. No redesigned texture.',files};
  fs.writeFileSync(path.join(root,'docs/migration/evidence/salvage-fx-source-textures.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({files:files.length,bytes:files.reduce((n,f)=>n+f.bytes,0)}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
