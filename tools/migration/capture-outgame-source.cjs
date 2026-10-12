const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).snapshot;
const evidence=path.join(root,'docs/migration/evidence');fs.mkdirSync(evidence,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11','--enable-gpu','--ignore-gpu-blocklist']});
 const server=http.createServer((req,res)=>{
  const p=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!p.startsWith(source+path.sep)||!fs.existsSync(p)||fs.statSync(p).isDirectory())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(p)]||'application/octet-stream');fs.createReadStream(p).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  page.on('pageerror',e=>console.log('SOURCE ERROR '+e.message));
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.waitForTimeout(2000);
  const metadata=await page.evaluate(async()=>{
   const {PREFABS}=await import('/shared/ui/workshop.js');const {PREFAB_STATS}=await import('/shared/ui/prefabStats.js');
   const {MATCH_MODES}=await import('/shared/battle/match.js');
   const {CHAPTER,STORY_LEVELS}=await import('/shared/story/chapter1.js');
   const {OPS}=await import('/shared/salvage/salvageLoot.js');
   const {ITEMS,ITEM_CATS,RARITY}=await import('/shared/salvage/items.js');
   return {workshop:{prefabs:PREFABS,stats:PREFAB_STATS},pages:{modes:MATCH_MODES,chapter:CHAPTER,levels:STORY_LEVELS,ops:OPS,items:ITEMS,categories:ITEM_CATS,rarity:RARITY}};
  });
  fs.writeFileSync(path.join(root,'assets/UI/Workshop.json'),JSON.stringify(metadata.workshop));
  fs.writeFileSync(path.join(root,'assets/UI/Outgame.json'),JSON.stringify(metadata.pages));
  await page.screenshot({path:path.join(evidence,'source-home-20261012.png')});
  console.log(await page.locator('body').innerText().then(x=>x.slice(0,400)));
  const tab=page.locator('.home-tabs button').filter({hasText:'创意工坊'});if(await tab.count())await tab.click();
  await page.waitForTimeout(1800);await page.screenshot({path:path.join(evidence,'source-workshop-20261012.png')});
  await page.locator('.home-tabs button').filter({hasText:'机库'}).click();
  await page.locator('[data-cta="battle"]').click();
  await page.waitForTimeout(800);await page.screenshot({path:path.join(evidence,'source-modes-20261012.png')});
  await page.locator('[data-story]').click();
  await page.waitForSelector('#storyPage.on',{timeout:120000});await page.waitForTimeout(2000);await page.screenshot({path:path.join(evidence,'source-story-20261012.png')});
  await page.locator('[data-x="back"]').click();
  await page.waitForFunction(()=>!window.__vox.shell.busy&&!window.__vox.shell.transition.playing);
  await page.locator('.home-tabs button').filter({hasText:'机库'}).click();
  await page.waitForTimeout(800);
  await page.locator('[data-top="salvage"]').click();
  await page.waitForSelector('.sv-pane[data-pane="loadout"]',{state:'visible',timeout:120000});await page.waitForTimeout(12000);await page.screenshot({path:path.join(evidence,'source-salvage-20261012.png')});
  console.log('Captured frozen H5 source');
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
