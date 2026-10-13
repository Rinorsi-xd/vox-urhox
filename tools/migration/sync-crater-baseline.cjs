const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.tmp/crater-baseline-2026-10-13');
(async()=>{
 const server=spawn(process.execPath,[path.join(__dirname,'crater-export-server.cjs')],{cwd:root,env:{...process.env,VOX_CRATER_EXPORT_ROOT:stage},stdio:['ignore','pipe','pipe'],windowsHide:true});
 let browser;
 try{
  await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('error',reject);server.once('exit',code=>reject(Error('Converter exited '+code)));});
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  const page=await browser.newPage({viewport:{width:1280,height:900}});
  page.on('pageerror',e=>console.error(e));
  await page.goto('http://127.0.0.1:43187/three/crater-export.html');
  await page.locator('#export').click();
  await page.waitForFunction(()=>document.querySelector('#status').textContent.startsWith('完成：')||document.querySelector('#status').textContent.includes('Error'),{},{timeout:360000});
  const status=await page.locator('#status').textContent();assert.ok(status.startsWith('完成：'),status);
  const manifest=JSON.parse(fs.readFileSync(path.join(stage,'crater-source/Manifest.json'),'utf8'));
  assert.ok(manifest.layout.pads?.player&&manifest.layout.pads?.enemy,'Frozen baseline launch pads required');
  await page.screenshot({path:path.join(root,'docs/migration/evidence/crater-source-baseline.png')});
  console.log(JSON.stringify({stage,status,pads:manifest.layout.pads,models:manifest.geometryCount,materials:manifest.materials.length}));
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
