// Read-only frozen source titleCard reference, without a second running game.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=baseline.snapshot;
const files=new Map(),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://local');
 if(url.pathname==='/reference.html'){res.setHeader('Content-Type','text/html');res.end('<link rel="stylesheet" href="/shared/css/style.css"><link rel="stylesheet" href="/shared/css/new-ui-tokens.css"><link rel="stylesheet" href="/shared/css/intro.css"><style>body{background:#080f1c}#intro{background:transparent;opacity:1;--ui-vh:1vh;--ui-vw:1vw}.ly{position:absolute;inset:0}</style><script type="importmap">{"imports":{"@shared/":"/shared/"}}</script><div id="intro"><div class="ly" id="slams"></div></div>');return;}
 const relative=decodeURIComponent(url.pathname).slice(1),file=path.resolve(source,relative);
 if(!file.startsWith(path.resolve(source)+path.sep)||!fs.existsSync(file)){res.writeHead(404).end();return;}
 const data=fs.readFileSync(file);assert.equal(hash(data),baseline.files[relative]?.sha256,relative);files.set(relative,hash(data));
 res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'application/octet-stream');res.end(data);
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  const page=await browser.newPage({viewport:{width:2040,height:1080},deviceScaleFactor:1});await page.goto('http://127.0.0.1:'+server.address().port+'/reference.html');
  const entries=[['prosper','繁荣！',{cls:'gold mid',idx:'01',tag:'PROSPERITY',at:{left:'17vw',top:'45vh'}}],['recruit','加入星际前途',{idx:'JOIN',tag:'特别安保部 · SPECIAL SECURITY'}],['mechanic','战地机修师！',{cls:'orange',idx:'YOU',tag:'FIELD MECHANIC'}]];
  const measurements=[];
  for(const [id,text,options]of entries){
   const value=await page.evaluate(async({text,options})=>{
    await document.fonts.load('40px GameFont',text);await document.fonts.load('40px VoxIndustrial',text);await document.fonts.load('20px VoxNum','JOIN');
    const parent=document.querySelector('#slams');parent.innerHTML='';const module=await import('/three/src/intro/introFx.js');module.titleCard(parent,text,options);
    await new Promise(r=>setTimeout(r,1100));
    return [...parent.firstChild.querySelectorAll('.tc-tx,.tc-slab.a,.tc-tag')].map(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {class:e.className,rect:[r.x,r.y,r.width,r.height],font:s.font,fontFamily:s.fontFamily,lineHeight:s.lineHeight,spacing:s.letterSpacing};});
   },{text,options});measurements.push({id,measurements:value});await page.screenshot({path:path.join(root,'docs/migration/evidence/intro-title-source-'+id+'.png')});
  }
  fs.writeFileSync(path.join(root,'docs/migration/evidence/intro-title-source.json'),JSON.stringify({baseline:baseline.commit,viewport:[2040,1080],inputs:Object.fromEntries(files),measurements},null,2));
  console.log(JSON.stringify({result:'PASS',cards:entries.length,inputs:files.size}));
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;server.close();});
