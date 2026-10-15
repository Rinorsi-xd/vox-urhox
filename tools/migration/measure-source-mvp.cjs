const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=baseline.snapshot;
(async()=>{
 const html=fs.readFileSync(path.join(source,'three/index.html'),'utf8'),links=html.match(/<link rel="stylesheet"[^>]+>/g).join('\n').replaceAll('../shared/','/shared/');
 const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://local');
  if(url.pathname==='/fixture.html'){res.setHeader('Content-Type','text/html');return res.end('<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+links+'<script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","three/addons/":"/three/vendor/three/addons/","@shared/":"/shared/"}}</script><body class="screen-drive">');}
  const file=path.resolve(source,'.'+decodeURIComponent(url.pathname));if(!file.startsWith(source+path.sep)||!fs.existsSync(file))return res.writeHead(404).end();
  res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'application/octet-stream');res.end(fs.readFileSync(file));
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'chrome'});
 const report={baseline:baseline.commit,fixture:'actual frozen MvpShow._overlay with production stylesheet cascade',layouts:[]};
 try{for(const viewport of [{width:1920,height:1080},{width:840,height:378},{width:800,height:450},{width:1024,height:768}]){
  const page=await browser.newPage({viewport});await page.goto('http://127.0.0.1:'+server.address().port+'/fixture.html');
  await page.evaluate(async()=>{const {MvpShow}=await import('/three/src/battle/mvpShow.js');const show=Object.create(MvpShow.prototype);show.o={name:'赤焰 GT',team:'blue',me:true,stats:{kills:12,assists:5,deaths:1,damage:28640}};show._overlay();show.root.classList.add('on','wide');document.body.classList.add('match-mvp');await document.fonts.ready;});
  await page.waitForTimeout(1000);
  const layout=await page.evaluate(()=>Object.fromEntries(['.tag','.tag small','.tag > b','.who','.who i','.st','.st div','.st div b','.skip'].map(selector=>{
   const el=document.querySelector('#mvp-show '+selector),r=el.getBoundingClientRect(),c=getComputedStyle(el);return [selector,{rect:[r.x,r.y,r.width,r.height],font:c.font,spacing:parseFloat(c.letterSpacing),shadow:c.textShadow,color:c.color}];
  })));
  report.layouts.push({viewport,layout});await page.screenshot({path:path.join(root,'docs/migration/evidence/source-mvp-'+viewport.width+'x'+viewport.height+'.png')});
  if(viewport.width===1920){
   await page.evaluate(()=>{
    document.documentElement.style.background='transparent';document.body.style.background='transparent';
    const title=document.querySelector('#mvp-show .tag > b');
    for(const el of document.querySelectorAll('#mvp-show .bar,#mvp-show .skip,#mvp-show .tag > :not(b)'))el.style.display='none';
    const tag=title.parentElement;tag.style.cssText='position:absolute;left:60px;top:60px;bottom:auto;opacity:1;transform:none';
   });
   await page.screenshot({path:path.join(root,'assets/Mvp/title.png'),omitBackground:true,clip:{x:0,y:0,width:420,height:223}});
  }
  await page.close();
 }
 fs.writeFileSync(path.join(root,'docs/migration/evidence/source-mvp-ui.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report.layouts[0]));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
