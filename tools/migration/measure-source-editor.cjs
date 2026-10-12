const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).snapshot;
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.waitForTimeout(2000);
  async function capture(name){
   await page.waitForTimeout(1200);
   const data=await page.evaluate(()=>[...document.querySelectorAll('#inventory *,#editbar *,#dock *,#stats *')].flatMap(el=>{
    const r=el.getBoundingClientRect(),c=getComputedStyle(el);if(!r.width||!r.height||c.display==='none')return [];
    return [{tag:el.tagName,class:el.getAttribute('class'),text:[...el.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent.trim()).join(''),rect:[r.x,r.y,r.width,r.height],font:c.fontFamily,size:c.fontSize,line:c.lineHeight,background:c.background,padding:c.padding,gap:c.gap}];
   }));
   fs.writeFileSync(path.join(out,'source-editor-pc-'+name+'.json'),JSON.stringify(data,null,2));
   await page.screenshot({path:path.join(out,'source-editor-pc-'+name+'.png')});console.log('Captured frozen editor '+name);
  }
  await page.locator('[data-cta="edit"]').click();await capture('builder');
  await page.keyboard.press('b');await page.waitForSelector('body.inv-open #inventory',{timeout:15000});await capture('inventory');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(error=>{console.error(error);process.exitCode=1;});
