const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence/match-source-'+new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(out,{recursive:true});
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});const report={url:'http://localhost:5173/three/',layouts:[]};
try{for(const viewport of [{width:1920,height:1080},{width:840,height:378}]){const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto(report.url);await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.waitForTimeout(1800);
const battle=page.locator('[data-cta="battle"]');await battle.click();await page.waitForTimeout(1000);await documentReady(page);
await page.screenshot({path:path.join(out,'modes-'+viewport.width+'.png')});
const selectors=['.bt','.bt-left','.bt-card','.bt-foot','.bt-story','.bt-en','.bt-ic','.bt-new','.bt-map','.bt-car','.bt-start'];
const modes=await measure(page,selectors);report.layouts.push({viewport,modes,errors});await page.close();}
fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(out);
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
async function documentReady(page){await page.evaluate(()=>document.fonts.ready);}
async function measure(page,selectors){return page.evaluate(sels=>Object.fromEntries(sels.map(s=>[s,[...document.querySelectorAll(s)].map(e=>{const r=e.getBoundingClientRect(),c=getComputedStyle(e);return {text:e.textContent,rect:[r.x,r.y,r.width,r.height],font:c.font,color:c.color,background:c.background,shadow:c.boxShadow,clip:c.clipPath,padding:c.padding};})])),selectors);}
