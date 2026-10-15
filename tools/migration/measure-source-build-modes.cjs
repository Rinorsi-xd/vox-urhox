const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={commit:baseline.commit,cases:{}};
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.waitForTimeout(1800);
  await page.locator('[data-cta="edit"]').click();
  for(const [name,width,height] of [['pc',1920,1080],['pc-16-10',1440,900],['phone-landscape',840,378],['tablet',1024,768]]){
   await page.setViewportSize({width,height});report.cases[name]={viewport:[width,height],modes:{}};
   for(const mode of ['build','paint','accent','erase','select','stretch','paste']){
    await page.evaluate(mode=>{
     const e=window.__vox.editor;e.pasting=false;e.setTool(mode==='accent'?'paint':mode==='paste'?'build':mode);
     if(mode==='paint'||mode==='accent')e.setPaintChannel(mode==='accent'?'accent':'shell');
     if(mode==='paste'){e.pasting=true;e._modeChanged();}
    },mode);
    await page.waitForTimeout(600);
    report.cases[name].modes[mode]=await page.evaluate(()=>{
     const style=(el,pseudo)=>{const c=getComputedStyle(el,pseudo),r=el.getBoundingClientRect();return {rect:[r.x,r.y,r.width,r.height],text:el.textContent,
      background:c.backgroundColor,color:c.color,font:c.fontFamily,size:c.fontSize,weight:c.fontWeight,line:c.lineHeight,spacing:c.letterSpacing,
      padding:c.padding,gap:c.gap,border:c.border,shadow:c.boxShadow,clip:c.clipPath,opacity:c.opacity,display:c.display,visibility:c.visibility,translate:c.translate,
      scale:c.scale,transition:c.transition,animation:c.animation,top:c.top,left:c.left,width:c.width,height:c.height};};
     const badge=document.querySelector('#modeBadge'),cross=document.querySelector('#crosshair');
     return {badge:style(badge),children:[...badge.children].map(el=>({tag:el.tagName,class:el.getAttribute('class'),...style(el),children:[...el.children].map(c=>({tag:c.tagName,...style(c)}))})),
      crosshair:style(cross),center:style(cross.querySelector('i')),before:style(cross,'::before'),after:style(cross,'::after'),hints:style(document.querySelector('#hintbar'))};
    });
    if(['paint','erase','select'].includes(mode))await page.screenshot({path:path.join(out,'source-build-mode-'+name+'-'+mode+'.png')});
   }
   console.log('Measured source build modes '+name);
  }
  fs.writeFileSync(path.join(out,'source-build-modes.json'),JSON.stringify(report,null,2));
  const smallWidths={};
  for(const mode of Object.values(report.cases.pc.modes))for(const child of mode.children){
   for(const part of [child,...child.children])if(part.tag==='SMALL')smallWidths[part.text]=Number.parseFloat(part.width);
  }
  fs.writeFileSync(path.join(root,'assets/UI/SourceBuildModeLayout.json'),JSON.stringify({commit:baseline.commit,smallWidths},null,2));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
