// Export source-owned rules and Chromium's Chinese collation from the frozen baseline.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).snapshot;
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url==='/rules.html')return res.end('<script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","@shared/":"/shared/"}}</script>');
  const file=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',path.extname(file)==='.js'?'text/javascript':'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 let browser;
 try{
  browser=await chromium.launch({headless:true,channel:'chrome'});const page=await browser.newPage();
  await page.goto('http://127.0.0.1:'+server.address().port+'/rules.html');
  const rules=await page.evaluate(async()=>{
   const {ITEMS,SELL_RATE}=await import('/shared/salvage/items.js');
   const {STASH_CELLS,TEST_FILL,stackMax}=await import('/shared/salvage/stash.js');
   const order={movement:0,weapon:1,function:2,shield:3,structure:4,frame:5,decor:6};
   return {cells:STASH_CELLS,testFill:TEST_FILL,sellRate:SELL_RATE,
    stack:Object.fromEntries(Object.keys(ITEMS).map(id=>[id,stackMax(id)])),
    itemOrder:Object.keys(ITEMS),marketOrder:Object.values(ITEMS).sort((a,b)=>(order[a.partCat]??0)-(order[b.partCat]??0)||a.name.localeCompare(b.name,'zh')).map(it=>it.id)};
  });
  fs.writeFileSync(path.join(root,'assets/UI/SalvageRules.json'),JSON.stringify(rules));
  console.log('Frozen salvage rules: '+rules.cells+' cells, '+rules.marketOrder.length+' items, testFill='+rules.testFill);
 }finally{if(browser)await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
