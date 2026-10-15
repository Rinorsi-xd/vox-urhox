const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const out=path.resolve('docs/migration/evidence/source-build-livery-fonts-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 const report={url:'http://localhost:5173/three/',pages:[],errors:[],boundary:'Actual UI entry with rendered screenshots; computed CSS is not final glyph proof.'};
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});page.on('pageerror',e=>report.errors.push(e.message));await page.goto(report.url);
  await page.locator('.home-tabs [data-tab="livery"]').waitFor({state:'visible',timeout:120000});
  async function capture(name){
   await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(700);
   const texts=await page.evaluate(()=>[...document.querySelectorAll('body *')].flatMap(el=>{
    const text=[...el.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.textContent).join('').trim();if(!text||el.closest('script,style'))return [];
    const c=getComputedStyle(el),r=el.getBoundingClientRect();if(!r.width||!r.height||r.bottom<0||r.top>innerHeight||c.visibility==='hidden'||c.opacity==='0')return [];
    return [{tag:el.tagName,id:el.id,className:el.className,text,font:c.fontFamily,size:c.fontSize,weight:c.fontWeight,style:c.fontStyle,synthesis:c.fontSynthesis,lineHeight:c.lineHeight,spacing:c.letterSpacing,rect:[r.x,r.y,r.width,r.height]}];
   }));report.pages.push({name,texts});await page.screenshot({path:path.join(out,name+'.png')});
  }
  await page.locator('.home-tabs [data-tab="livery"]').click();await capture('livery');
  await page.locator('.home-tabs [data-tab="hangar"]').click();await page.keyboard.press('e');
  await page.locator('#editbar').waitFor({state:'visible',timeout:30000});await capture('build');report.result='CAPTURED';
 }catch(e){report.result='FAIL';report.failure=e.stack;}
 finally{await browser.close();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({out,result:report.result,pages:report.pages.map(p=>({name:p.name,texts:p.texts.length})),errors:report.errors,failure:report.failure},null,2));}
 if(report.result==='FAIL')process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
