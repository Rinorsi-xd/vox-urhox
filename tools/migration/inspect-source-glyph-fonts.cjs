const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
 const report={url:'http://localhost:5173/three/',samples:[],boundary:'CDP reports actual platform fonts per original DOM element, not just computed family. This is source typography evidence only.'};
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});await page.goto(report.url);
  await page.locator('[data-top="settings"]').waitFor({state:'visible',timeout:120000});
  await page.locator('[data-top="settings"]').click();await page.waitForTimeout(700);await page.evaluate(()=>document.fonts.ready);
  const cdp=await page.context().newCDPSession(page);await cdp.send('DOM.enable');await cdp.send('CSS.enable');
  for(const text of ['继续','回到机库','操作说明','让诺诺从头再带一遍']){
   const id='font-inspect-'+report.samples.length;
   const computed=await page.evaluate(({text,id})=>{
    const el=[...document.querySelectorAll('#modal *')].find(e=>e.children.length===0&&e.textContent.trim()===text);if(!el)throw Error('Missing original text '+text);
    el.id=id;const c=getComputedStyle(el),r=el.getBoundingClientRect();return {family:c.fontFamily,size:c.fontSize,weight:c.fontWeight,synthesis:c.fontSynthesis,lineHeight:c.lineHeight,spacing:c.letterSpacing,rect:[r.x,r.y,r.width,r.height]};
   },{text,id});
   const {root}=await cdp.send('DOM.getDocument');const {nodeId}=await cdp.send('DOM.querySelector',{nodeId:root.nodeId,selector:'#'+id});
   const actual=await cdp.send('CSS.getPlatformFontsForNode',{nodeId});report.samples.push({text,computed,actual});
  }
  report.result='CAPTURED';
 }finally{await browser.close();fs.writeFileSync(path.resolve('docs/migration/evidence/source-settings-actual-glyph-fonts.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));}
})().catch(e=>{console.error(e);process.exitCode=1;});
