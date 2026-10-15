const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot,out=path.join(root,'docs/migration/evidence');
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378},{name:'phone-16-9',width:800,height:450},{name:'tablet',width:1024,height:768},{name:'wide',width:2560,height:1080}];
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');
  fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||t.name===process.env.VOX_QA_CASE)){
   const page=await browser.newPage({viewport:{width:test.width,height:test.height}});
   const errors=[],states={};
   page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   page.on('pageerror',e=>errors.push(e.stack||e.message));
   const persist=()=>fs.writeFileSync(path.join(out,'source-layout-'+test.name+'.json'),JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit,frozenAt:baseline.frozenAt},states,errors},null,2));
   try{
   await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await page.waitForFunction(()=>window.__vox,{},{timeout:120000});
   await page.waitForTimeout(1500);
   async function capture(name){
    await page.waitForTimeout(1200);
    states[name]=await page.evaluate(()=>{
     const nodes=[];
     for(const el of document.querySelectorAll('#home *,#storyPage *,#salvage *')){
      const r=el.getBoundingClientRect(),c=getComputedStyle(el);
      if(!r.width||!r.height||c.visibility==='hidden'||c.display==='none')continue;
      const surface=el.closest('.ui-surface'),scale=surface?parseFloat(getComputedStyle(surface).getPropertyValue('--ui-scale')):1;
      const text=[...el.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent.trim()).join('');
      nodes.push({tag:el.tagName,id:el.id,class:typeof el.className==='string'?el.className:el.className.baseVal,data:{...el.dataset},text,
       rect:[r.x/scale,r.y/scale,r.width/scale,r.height/scale],font:c.fontFamily,size:c.fontSize,lineHeight:c.lineHeight,color:c.color,background:c.background,clip:c.clipPath,gap:c.gap});
     }
     return {viewport:{width:innerWidth,height:innerHeight},nodes};
    });
    await page.screenshot({path:path.join(out,'source-measured-'+test.name+'-'+name+'.png')});
    persist();console.log('Captured '+test.name+' '+name);
   }
   await capture('home');
   await page.locator('.home-tabs [data-tab="workshop"]').click();
   await page.locator('.wsh-hero').first().hover();
   await capture('workshop');
   await page.locator('[data-wsh-view]').first().click();await page.waitForTimeout(1500);await capture('detail');
   await page.locator('[data-wsd-back]').first().click();
   await page.locator('[data-wsv="browse"]').first().click();await capture('browse');
   await page.locator('.home-tabs [data-tab="hangar"]').click();
   await page.locator('[data-cta="battle"]').click();await capture('modes');
   if(process.env.VOX_QA_EXTENDED==='1'){
    await page.locator('[data-story]').click();
    await page.waitForSelector('#storyPage.on',{timeout:120000});await page.waitForTimeout(2500);await capture('story');
    await page.locator('[data-x="back"]').click();
    await page.waitForFunction(()=>!window.__vox.shell.busy&&!window.__vox.shell.transition.playing);
    await page.locator('.home-tabs [data-tab="shop"]').click();await capture('shop');
    await page.locator('.home-tabs [data-tab="hangar"]').click();
    await page.locator('[data-top="salvage"]').click();
    await page.waitForFunction(()=>!window.__vox.shell.busy&&!window.__vox.shell.transition.playing,{},{timeout:120000});
    await page.waitForSelector('body.screen-salvage #salvage .sv-loadl',{state:'visible',timeout:120000});
    await page.waitForFunction(()=>!document.querySelector('#loadingPage')||getComputedStyle(document.querySelector('#loadingPage')).display==='none',{},{timeout:120000});
    await capture('salvage');
    for(const tab of ['ops','market','garage']){
     await page.locator('#salvage .sv-tabs [data-tab="'+tab+'"]').click();await capture('salvage-'+tab);
     if(tab==='ops'&&test.name==='pc')await page.locator('#salvage .sv-opsmap').screenshot({path:path.join(root,'assets/UI/Salvage/operations.png')});
    }
   }
   persist();
   console.log('Measured frozen H5 '+test.name);
   }catch(error){
    errors.push(error.stack||error.message);
    states.failure=await page.evaluate(()=>({screen:window.__vox?.shell?.screen,busy:window.__vox?.shell?.busy,text:document.body.innerText}));
    await page.screenshot({path:path.join(out,'source-measured-'+test.name+'-failure.png')});
    throw error;
   }finally{persist();}
   await page.close();
  }
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
