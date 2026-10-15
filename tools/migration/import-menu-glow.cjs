// Bake only the original CSS shadow masks, not menu contents or new artwork.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const sourceFile='shared/css/bay-menu.css',padding=20,dpr=3;
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.locator('.bay-new-btn').click();
  const specs=await page.evaluate(()=>['.bnm','.bnm-i'].map(selector=>{
   const el=document.querySelector(selector),c=getComputedStyle(el,'::before');
   return {selector,width:parseFloat(c.width),height:parseFloat(c.height),shadow:c.boxShadow,background:c.backgroundColor};
  }));
  const canvas=await browser.newPage({deviceScaleFactor:dpr});
  for(const [i,spec] of specs.entries()){
   if(!Number.isFinite(spec.width)||!Number.isFinite(spec.height)||spec.shadow==='none')throw Error('Source shadow unavailable');
   spec.file='UI/SourceMenuGlow-'+(i===0?'top':'bar')+'.png';spec.padding=padding;spec.dpr=dpr;
   const width=spec.width+padding*2,height=spec.height+padding*2;
   await canvas.setViewportSize({width,height});
   await canvas.setContent('<style>html,body{margin:0;background:transparent}</style><div id="shadow"></div>');
   await canvas.evaluate(({spec,padding})=>{
    const el=document.querySelector('#shadow');
    Object.assign(el.style,{position:'absolute',left:padding+'px',top:padding+'px',width:spec.width+'px',height:spec.height+'px',background:'transparent',boxShadow:spec.shadow.replace(/rgba?\([^)]+\)/,'rgba(255,255,255,0.9)')});
   },{spec,padding});
   const png=await canvas.screenshot({omitBackground:true}),file=path.join(root,'assets',spec.file);
   fs.writeFileSync(file,png);spec.sha256=crypto.createHash('sha256').update(png).digest('hex');
   if(!fs.existsSync(file+'.meta'))fs.writeFileSync(file+'.meta',JSON.stringify({uuid:crypto.randomBytes(18).toString('base64url')},null,2)+'\n');
  }
  const report={baseline:baseline.commit,source:sourceFile,source_sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(baseline.snapshot,sourceFile))).digest('hex'),specs};
  fs.writeFileSync(path.join(root,'docs/migration/evidence/source-menu-glow.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
