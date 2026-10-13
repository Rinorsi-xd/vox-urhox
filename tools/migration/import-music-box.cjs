// Read only the frozen Git baseline; export the original catalog and DOM geometry.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot,out=path.join(root,'docs/migration/evidence');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const files=[],states={};let catalog;
  for(const [name,width,height] of [['pc',1920,1080],['phone-landscape',840,378],['phone-16-9',800,450],['tablet',1024,768],['phone-narrow',740,333],['phone-narrow-16-9',760,428]]){
   const page=await browser.newPage({viewport:width<=760?{width:1920,height:1080}:{width,height}});
   await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await page.waitForFunction(()=>window.__vox,{},{timeout:120000});
   await page.locator('.home-music-console').click();
   await page.locator('#music-box .mb-art img').evaluate(img=>img.decode());
   await page.locator('[data-play="hangar-01-workshop-floor"]').click();
   await page.waitForTimeout(700);
   await page.locator('[data-mb="play"]').click();
   await page.waitForTimeout(350);
   if(width<=760){await page.setViewportSize({width,height});await page.waitForTimeout(350);}
   catalog=await page.evaluate(async()=>{
    const {MUSIC_BOX_TRACKS:tracks,MUSIC_BOX_GROUPS:groups}=await import('/shared/audio/musicBoxCatalog.js');
    return {tracks:tracks.map(({url,...t})=>({...t,file:'Sounds/Music/'+t.id+'.mp3'})),groups};
   });
   states[name]=await page.evaluate(()=>{
    const box=document.querySelector('#music-box').getBoundingClientRect();
    return [...document.querySelectorAll('#music-box,#music-box *')].map(el=>{
     const r=el.getBoundingClientRect(),c=getComputedStyle(el);
     return {tag:el.tagName,class:typeof el.className==='string'?el.className:el.className.baseVal,data:{...el.dataset},text:el.children.length?undefined:el.textContent,
      rect:[r.x-box.x,r.y-box.y,r.width,r.height],font:c.fontFamily,size:c.fontSize,lineHeight:c.lineHeight,color:c.color,background:c.background,display:c.display};
    });
   });
   await page.screenshot({path:path.join(out,'source-music-box-'+name+'.png')});await page.close();
  }
  fs.mkdirSync(path.join(root,'assets/Sounds/Music'),{recursive:true});fs.mkdirSync(path.join(root,'assets/UI/Music'),{recursive:true});
  for(const track of catalog.tracks){
   const from=path.join(source,'shared/assets/audio/music/runtime',track.id+'.mp3'),to=path.join(root,'assets',track.file);
   fs.copyFileSync(from,to);files.push({source:path.relative(source,from).replaceAll('\\','/'),target:'assets/'+track.file,sha256:hash(from),bytes:fs.statSync(from).size});
  }
  const art='shared/assets/ui/music-box/archive-cartridge.webp';
  const exportPage=await browser.newPage();await exportPage.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  for(const [name,url,bg] of [['archive-cartridge','/'+art,null],['header','/shared/assets/ui/new-ui/relief-side.svg','#35434b'],['transport','/shared/assets/ui/new-ui/relief-side.svg','#303d44']]){
   const png=await exportPage.evaluate(async({url,bg})=>{
    const image=new Image();image.src=url;await image.decode();const canvas=document.createElement('canvas');
    canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;const ctx=canvas.getContext('2d');
    if(bg){ctx.fillStyle=bg;ctx.fillRect(0,0,canvas.width,canvas.height);}ctx.drawImage(image,0,0);
    return canvas.toDataURL('image/png').split(',')[1];
   },{url,bg});
   const to=path.join(root,'assets/UI/Music',name+'.png');fs.writeFileSync(to,Buffer.from(png,'base64'));
   const from=name==='archive-cartridge'?art:'shared/assets/ui/new-ui/relief-side.svg';
   files.push({source:from,source_sha256:hash(path.join(source,from)),target:'assets/UI/Music/'+name+'.png',sha256:hash(to),background:bg});
  }
  await exportPage.close();
  fs.writeFileSync(path.join(root,'assets/UI/Music/Catalog.json'),JSON.stringify(catalog));
  const sourceFiles=Object.fromEntries([...new Set([...files.map(f=>f.source),'shared/ui/musicBox.js','shared/css/music-box.css','shared/audio/musicBoxCatalog.js','shared/audio/musicLibrary.js','shared/audio/musicQueue.js','shared/audio/musicPlayer.js','shared/audio/levels.js'])].map(f=>[f,hash(path.join(source,f))]));
  fs.writeFileSync(path.join(root,'docs/migration/music-box-source.json'),JSON.stringify({baseline:{commit:baseline.commit,branch:baseline.branch},files,sourceFiles,catalog:{path:'assets/UI/Music/Catalog.json',sha256:hash(path.join(root,'assets/UI/Music/Catalog.json'))}},null,2));
  fs.writeFileSync(path.join(out,'source-music-box.json'),JSON.stringify({baseline:{commit:baseline.commit,branch:baseline.branch},files,states},null,2));
  console.log('Imported '+catalog.tracks.length+' approved original MP3s and original cartridge. Captured '+Object.keys(states).length+' landscape layouts.');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
