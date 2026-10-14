const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=baseline.snapshot;
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const errors=[];
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.waitForTimeout(1500);
  await page.locator('[data-cta="edit"]').click();await page.waitForTimeout(1200);await page.keyboard.press('b');
  await page.waitForSelector('body.inv-open #inventory');await page.waitForTimeout(900);
  await page.evaluate(()=>document.activeElement.blur());await page.mouse.move(1910,1070);
  const entry=await page.evaluate(()=>{
   const cards=[...document.querySelectorAll('#inventory .inv-part')];
   return cards.slice(0,26).map((el,index)=>{
    const original=getComputedStyle(el).animation;el.style.animation='none';void el.offsetWidth;el.style.animation=original;
    const animation=el.getAnimations().find(a=>a.animationName==='nuInvTileIn');assertAnimation(animation);
    animation.pause();const samples=[0,40,120,240,400,580].map(time=>{animation.currentTime=time;const css=getComputedStyle(el);return {time,opacity:Number(css.opacity),translate:css.translate};});
    animation.finish();return {index,samples};
   });
   function assertAnimation(a){if(!a)throw Error('Missing source tile animation');}
  });
  const card=page.locator('#inventory .inv-part').first();await page.mouse.move(1910,1070);await page.waitForTimeout(400);
  async function motion(phase){
   if(phase==='hover')await card.hover();else if(phase==='press')await page.mouse.down();else if(phase==='release')await page.mouse.up();else await page.mouse.move(1910,1070);
   await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
   return page.evaluate(()=>{
    const el=document.querySelector('#inventory .inv-part'),image=el.querySelector('img'),tip=el.querySelector('.c');
    const animations=el.getAnimations({subtree:true}).filter(a=>a.constructor.name==='CSSTransition');for(const a of animations)a.pause();
    const samples=[0,30,80,150,180,220,300].map(time=>{
     for(const a of animations)a.currentTime=time;
     const css=getComputedStyle(el),img=getComputedStyle(image),budget=getComputedStyle(tip),matrix=new DOMMatrix(img.transform),tipMatrix=new DOMMatrix(budget.transform);
     return {time,translate:css.translate,background:getComputedStyle(el,'::before').backgroundColor,
      image:{angle:Math.atan2(matrix.b,matrix.a)*180/Math.PI,scale:Math.hypot(matrix.a,matrix.b),y:matrix.f},budget:{opacity:Number(budget.opacity),y:tipMatrix.f}};
    });
    for(const a of animations)a.finish();return samples;
   });
  }
  const hover=await motion('hover'),press=await motion('press'),release=await motion('release'),leave=await motion('leave');
  const filters=await page.evaluate(()=>{
   const css=s=>{const c=getComputedStyle(document.querySelector(s));return {filter:c.filter,shadow:c.boxShadow,transition:c.transition};};
   return {card:css('.inv-part'),image:css('.inv-part img'),detail:css('.inv-big img'),slot:css('.inv-slot'),slotImage:css('.inv-slot img'),tip:css('.inv-tip')};
  });
  async function control(selector,action){
   await page.mouse.move(1910,1070);await page.waitForTimeout(350);
   const element=page.locator(selector).first();
   await element.hover();if(action==='press')await page.mouse.down();
   await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
   const samples=await page.evaluate(selector=>{
    const el=document.querySelector(selector),animations=el.getAnimations({subtree:true}).filter(a=>a.constructor.name==='CSSTransition');
    for(const a of animations)a.pause();
    const data=[0,30,80,150,160,180,260].map(time=>{
     for(const a of animations)a.currentTime=time;
     const c=getComputedStyle(el),matrix=new DOMMatrix(c.transform);
     return {time,x:matrix.e,y:matrix.f,translate:c.translate,color:c.color,background:c.backgroundColor,shadow:c.boxShadow,filter:c.filter};
    });for(const a of animations)a.finish();return data;
   },selector);
   if(action==='press'){await page.mouse.move(1910,1070);await page.mouse.up();}
   return samples;
  }
  const controls={close:await control('.inv-close'),closePress:await control('.inv-close','press'),material:await control('.inv-mat'),slot:await control('.inv-slot:not(.on)')};
  await page.keyboard.press('Tab');
  await card.focus();await page.waitForTimeout(350);
  const focus=await page.evaluate(()=>{
   const el=document.querySelector('#inventory .inv-part'),number=el.querySelector('.no'),r=el.getBoundingClientRect(),n=number.getBoundingClientRect(),css=getComputedStyle(el);
   return {filter:css.filter,number:{bottom:r.bottom-n.bottom,height:n.height,width:n.width,fontSize:getComputedStyle(number).fontSize,lineHeight:getComputedStyle(number).lineHeight}};
  });
  await page.locator('.inv-slot').first().focus();
  focus.slotFilter=await page.locator('.inv-slot').first().evaluate(el=>getComputedStyle(el).filter);
  const result={baseline:{branch:baseline.branch,commit:baseline.commit},entry,hover,press,release,leave,filters,controls,focus,errors};
  fs.writeFileSync(path.join(out,'source-inventory-effects.json'),JSON.stringify(result,null,2));
  fs.writeFileSync(path.join(__dirname,'source-inventory-effects.json'),JSON.stringify(result,null,2)+'\n');
  await card.hover();await page.waitForTimeout(500);await page.screenshot({path:path.join(out,'source-inventory-effects-hover.png')});
  assert.equal(errors.length,0,errors.join('\n'));console.log(JSON.stringify({commit:baseline.commit,entryCards:entry.length,phases:4,errors}));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
