// Source-only typography evidence from the user's running H5 service.
const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
async function main(){
 const out=path.resolve('docs/migration/evidence/source-font-pages-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1920,height:1080}});
 const report={url:'http://localhost:5173/three/',viewport:{width:1920,height:1080},pages:[],errors:[],boundary:'Isolated source browser; computed CSS and visible text bounds, not proof of target rendering parity or actual glyph fallback.'};
 page.on('pageerror',e=>report.errors.push(e.message));
 async function capture(name){
  await page.evaluate(()=>document.fonts.ready);
  const evidence=await page.evaluate(()=>{
   const texts=[];
   for(const el of document.querySelectorAll('body *')){
    const direct=[...el.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.textContent).join('').trim();
    if(!direct)continue;
    const c=getComputedStyle(el),r=el.getBoundingClientRect();
    if(c.visibility==='hidden'||c.display==='none'||Number(c.opacity)===0||r.width===0||r.height===0||r.bottom<=0||r.top>=innerHeight||r.right<=0||r.left>=innerWidth)continue;
    if(el.closest('script,style'))continue;
    const range=document.createRange();range.selectNodeContents(el);const ink=range.getBoundingClientRect();
    texts.push({tag:el.tagName,id:el.id,className:el.className,text:direct,
     fontFamily:c.fontFamily,fontSize:c.fontSize,fontWeight:c.fontWeight,fontStyle:c.fontStyle,
     lineHeight:c.lineHeight,letterSpacing:c.letterSpacing,textTransform:c.textTransform,textShadow:c.textShadow,
     rect:[r.x,r.y,r.width,r.height],textRect:[ink.x,ink.y,ink.width,ink.height]});
   }
   return {title:document.title,fonts:[...document.fonts].map(f=>({family:f.family,status:f.status,weight:f.weight,style:f.style})),texts};
  });
  report.pages.push({name,...evidence});
  await page.screenshot({path:path.join(out,name+'.png')});
 }
 try{
  await page.goto(report.url);
  await page.locator('[data-top="help"]').waitFor({state:'visible',timeout:120000});
  await page.locator('[data-top="help"]').click();await page.waitForTimeout(700);await capture('help');
  await page.keyboard.press('Escape');await page.waitForTimeout(400);
  await page.locator('[data-top="settings"]').click();await page.waitForTimeout(700);await capture('settings');
  await page.keyboard.press('Escape');await page.waitForTimeout(400);
  await page.locator('.home-tabs [data-tab="workshop"]').click();await page.waitForTimeout(1400);await capture('workshop');
  report.result='CAPTURED';
 }catch(e){report.result='FAIL';report.failure=e.stack;throw e;}
 finally{
  await browser.close();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({out,result:report.result,pages:report.pages.map(p=>({name:p.name,texts:p.texts.length})),errors:report.errors},null,2));
 }
}
main().catch(e=>{console.error(e);process.exitCode=1;});
