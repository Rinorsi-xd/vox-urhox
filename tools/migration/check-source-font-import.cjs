// Compare the imported original OpenType with WOFF2 in the frozen H5 DOM.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
(async()=>{
 const server=http.createServer((req,res)=>{
  const url=decodeURIComponent(req.url.split('?')[0]);
  const file=url==='/qa-original.otf'?path.join(root,'assets/Fonts/VoxIndustrial-Bold.otf'):path.resolve(baseline.snapshot,'.'+url);
  if(file!==path.join(root,'assets/Fonts/VoxIndustrial-Bold.otf')&&!file.startsWith(baseline.snapshot+path.sep))return res.writeHead(404).end();
  if(!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.otf':'font/otf','.woff2':'font/woff2'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{},{timeout:120000});
  await page.evaluate(async()=>{await document.fonts.ready;window.__vox.rig.autoSpin=false;});
  await page.locator('.bay-new-btn').click();await page.mouse.move(1916,1076);await page.waitForTimeout(350);
  const menu=page.locator('.bnm'),original=await menu.screenshot({path:path.join(out,'source-font-original-menu.png')});
  await page.evaluate(async()=>{
   const face=new FontFace('VoxImported','url(/qa-original.otf)',{weight:'700'});await face.load();document.fonts.add(face);
   for(const e of document.querySelectorAll('.bnm b,.bnm-h span'))e.style.fontFamily='VoxImported';
  });
  const converted=await menu.screenshot({path:path.join(out,'source-font-imported-menu.png')});
  const report={baseline:baseline.commit,comparisons:[]};
  for(const [label,top] of [['header',10],['empty',55],['import',105],['workshop',155]]){
   const crop={left:label==='header'?16:58,top,width:label==='header'?172:80,height:22};
   const a=await sharp(original).extract(crop).removeAlpha().raw().toBuffer(),b=await sharp(converted).extract(crop).removeAlpha().raw().toBuffer();
   let pixels=0,changed=0,sum=0;
   for(let i=0;i<a.length;i+=3)if(Math.max(a[i],b[i])>120){pixels++;const delta=Math.max(Math.abs(a[i]-b[i]),Math.abs(a[i+1]-b[i+1]),Math.abs(a[i+2]-b[i+2]));sum+=delta;if(delta>10)changed++;}
   report.comparisons.push({label,pixels,changed,meanChannelDelta:sum/Math.max(1,pixels)});
  }
  report.result=report.comparisons.every(row=>row.changed===0)?'PASS':'FAIL';
  fs.writeFileSync(path.join(out,'source-font-import-raster.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
  if(report.result!=='PASS')throw Error('Imported font does not match the original browser raster');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
