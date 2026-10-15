// Browser evidence from the frozen H5 commit, never from the target layout.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const out=path.join(root,'docs/migration/evidence');
const cases=[['pc',1920,1080],['pc-16-10',1440,900],['phone-landscape',840,378],['phone-16-9',800,450],['tablet',1024,768]];
const selectors={nav:'.home-nav',info:'.robot-info',loadout:'.robot-loadout',cta:'.home-cta',edit:'[data-cta="edit"]',battle:'[data-cta="battle"]',trial:'[data-cta="test"]',mode:'.mode-strip',strip:'.bay-strip',card:'.bay',new:'.bay-new-btn',save:'.bay-save',music:'.home-music-console',name:'.ri-name',budget:'.ri-cpu b',budgetCap:'.ri-cpu b em',battleTitle:'.cta-main b',battleIcon:'.cta-main .ic',battleKey:'.cta-main kbd',menu:'.bnm',menuHeader:'.bnm-h',menuEmpty:'.bnm-i[data-new="empty"]',menuImport:'.bnm-i[data-new="import"]',menuWorkshop:'.bnm-i[data-new="workshop"]'};
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={baseline:{branch:baseline.branch,commit:baseline.commit},cases:[],display:[]};
 try{
  for(const [name,width,height] of cases){
   const page=await browser.newPage({viewport:{width,height}});
   await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(1800);
   async function measure(){return page.evaluate(selectors=>{
    const home=document.querySelector('#home'),scale=parseFloat(getComputedStyle(home).getPropertyValue('--ui-scale'))||1;
    const nodes={};
    for(const [key,selector] of Object.entries(selectors)){
     const el=home.querySelector(selector);if(!el)continue;
     const r=el.getBoundingClientRect(),c=getComputedStyle(el);
     nodes[key]={rect:[r.x/scale,r.y/scale,r.width/scale,r.height/scale],text:el.innerText,font:c.fontFamily,size:c.fontSize,lineHeight:c.lineHeight,spacing:c.letterSpacing,numeric:c.fontVariantNumeric,background:c.background,color:c.color,clip:c.clipPath,padding:c.padding,border:c.border};
    }
    return {scale,width:innerWidth/scale,height:innerHeight/scale,nodes};
   },selectors);}
   const home=await measure();await page.screenshot({path:path.join(out,'home-parity-source-'+name+'.png')});
   await page.locator('.bay-new-btn').click();await page.waitForTimeout(350);
   const menu=await measure();await page.screenshot({path:path.join(out,'home-parity-source-'+name+'-menu.png')});
   await page.locator('.bnm-i[data-new="empty"]').hover();await page.waitForTimeout(300);
   const menuHover=await page.evaluate(()=>{
    const scale=parseFloat(getComputedStyle(document.querySelector('#home')).getPropertyValue('--ui-scale'))||1;
    const items={};
    for(const row of document.querySelectorAll('.bnm-i')){
     const parts={};
     for(const [key,el] of Object.entries({icon:row.querySelector('i'),glyph:row.querySelector('i .ic'),title:row.querySelector('b'),count:row.querySelector('em'),arrow:row.querySelector(':scope > .ic')})){
      if(!el)continue;const r=el.getBoundingClientRect(),c=getComputedStyle(el);
      parts[key]={rect:[r.x/scale,r.y/scale,r.width/scale,r.height/scale],text:el.textContent,font:c.fontFamily,size:c.fontSize,lineHeight:c.lineHeight,spacing:c.letterSpacing,color:c.color,background:c.background,transform:c.transform,opacity:c.opacity,transition:c.transition};
     }
     items[row.dataset.new]=parts;
    }
    return items;
   });
   await page.screenshot({path:path.join(out,'home-parity-source-'+name+'-menu-hover.png')});
   report.cases.push({name,viewport:[width,height],home,menu,menuHover});
   if(name==='pc')report.display=await page.evaluate(()=>{
    const result=[],home=document.querySelector('#home');
    for(const font of ['vox-title','vox-tabular','vox-display'])for(const size of [18,24,40])for(const spacing of [0,1])for(const text of ['从零建造','预制车：赤焰 GT','AV','T3 战车','0123456789']){
     const span=document.createElement('span');span.textContent=text;
     span.style.cssText='position:absolute;white-space:pre;font:400 '+size+'px '+(font==='vox-title'?'var(--display)':'var(--nu-number)')+';letter-spacing:'+spacing+'px;';
     if(font==='vox-tabular')span.style.fontVariantNumeric='tabular-nums';home.append(span);
     const width=span.getBoundingClientRect().width,computed=getComputedStyle(span).fontFamily;span.remove();result.push({font,text,size,spacing,width,computed});
    }
    return result;
   });
   await page.close();console.log('Measured current home '+name);
  }
  fs.writeFileSync(path.join(out,'home-parity-source.json'),JSON.stringify(report,null,2));
  const count=report.cases.find(c=>c.name==='pc').menuHover.workshop.count;
  fs.writeFileSync(path.join(root,'assets/UI/SourceHomeMenu.json'),JSON.stringify({baseline:report.baseline,countText:count.text,countWidth:count.rect[2]},null,2)+'\n');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(error=>{console.error(error);process.exitCode=1;});
