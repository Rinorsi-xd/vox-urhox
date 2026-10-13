const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=baseline.snapshot,dest=path.join(root,'assets/Livery'),evidence=path.join(root,'docs/migration/evidence');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(source,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  fs.mkdirSync(dest,{recursive:true});fs.mkdirSync(evidence,{recursive:true});const files=[],states={};let catalog;
  for(const [name,width,height] of [['pc',1920,1080],['phone-landscape',840,378],['phone-16-9',800,450],['tablet',1024,768]]){
   const page=await browser.newPage({viewport:{width,height}});await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.locator('.home-tabs [data-tab="livery"]').click();
   await page.waitForFunction(()=>document.querySelectorAll('.lv-st').length===7);await page.waitForTimeout(800);
   const capture=async key=>{
    states[key]=await page.evaluate(()=>{
     const base=document.querySelector('#home').getBoundingClientRect();const scale=base.width/document.querySelector('#home').offsetWidth;
     return {viewport:[innerWidth,innerHeight],home:[base.x,base.y,base.width,base.height],scale,elements:[...document.querySelectorAll('#home .home-tabs button,[data-pane="livery"] *')].map(el=>{
      const r=el.getBoundingClientRect(),s=getComputedStyle(el);return {class:typeof el.className==='string'?el.className:el.className.baseVal,data:{...el.dataset},text:el.children.length?undefined:el.textContent,
       rect:[(r.x-base.x)/scale,(r.y-base.y)/scale,r.width/scale,r.height/scale],font:s.fontFamily,size:s.fontSize,line:s.lineHeight,color:s.color,background:s.background,display:s.display};
     })};
    });await page.screenshot({path:path.join(evidence,'source-livery-'+key+'.png')});
   };
   await capture(name+'-empty');
   catalog=await page.evaluate(async()=>{const c=await import('/shared/build/livery.js');return (await c.loadCatalog()).list.map(({url,...s})=>s);});
   if(name==='pc'){
    for(const action of ['undo','redo','clear','done']){
     const button=page.locator('[data-pane="livery"] [data-lv="'+action+'"]');
     const style=await button.evaluate(el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);return {w:r.width,h:r.height,background:s.background,shadow:s.boxShadow,clip:s.clipPath};});
     const raster=await browser.newPage({viewport:{width:Math.round(style.w),height:Math.round(style.h)},deviceScaleFactor:4});
     await raster.setContent('<style>html,body{margin:0;background:transparent}div{position:absolute;inset:0;background:'+style.background+';box-shadow:'+style.shadow+';clip-path:'+style.clip+'}</style><div></div>');
     await raster.waitForTimeout(200);await raster.screenshot({path:path.join(dest,'bar-'+action+'.png'),omitBackground:true});await raster.close();
     files.push({source:'shared/css/livery.css',source_sha256:sha(path.join(source,'shared/css/livery.css')),target:'assets/Livery/bar-'+action+'.png',sha256:sha(path.join(dest,'bar-'+action+'.png'))});
    }
    for(const st of catalog){
     const original='shared/assets/livery/'+st.file,from=path.join(source,original);const asset=st.id+'.png';
     if(st.kind==='portrait')fs.copyFileSync(from,path.join(dest,asset));
     else{
      const png=await page.evaluate(async st=>{
       const txt=await(await fetch('/shared/assets/livery/'+st.file)).text();const cv=document.createElement('canvas');
       cv.width=Math.round(st.aspect>=1?1024:1024*st.aspect);cv.height=Math.round(st.aspect>=1?1024/st.aspect:1024);
       const draw=async colors=>{const im=new Image();im.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(txt.replace(/#ff00ff/gi,colors[0]).replace(/#00ffff/gi,colors[1]));await im.decode();const ctx=cv.getContext('2d');ctx.clearRect(0,0,cv.width,cv.height);ctx.drawImage(im,0,0,cv.width,cv.height);return cv.toDataURL('image/png').split(',')[1];};
       const hex=n=>'#'+n.toString(16).padStart(6,'0');return {default:await draw(st.colors.map(hex)),mask:await draw(['#ff0000','#00ff00'])};
      },st);
      fs.writeFileSync(path.join(dest,asset),Buffer.from(png.default,'base64'));fs.writeFileSync(path.join(dest,st.id+'-mask.png'),Buffer.from(png.mask,'base64'));
      files.push({source:original,source_sha256:sha(from),target:'assets/Livery/'+st.id+'-mask.png',sha256:sha(path.join(dest,st.id+'-mask.png'))});
     }
     files.push({source:original,source_sha256:sha(from),target:'assets/Livery/'+asset,sha256:sha(path.join(dest,asset))});
    }
   }
   // Real studio data supplies the selected state; no replacement reference UI.
   await page.evaluate(async()=>{
    const studio=window.__vox.shell.livery;studio.setPick('burst');studio.place({p:[0,2,0],n:[0,1,0]});
   });
   // Layer refresh follows source rendering; select the original layer control.
   await page.waitForTimeout(500);
   if(name==='pc'){
    const fixtures=await page.evaluate(async()=>{
     const api=await import('/three/src/build/liveryView.js'),studio=window.__vox.shell.livery;
     const part=[...studio.editor.bp.parts.values()].find(api.fixedPart),parts=[{...part,pos:[0,0,0],rot:0}];
     return [{s:'burst',p:[0,1,0],n:[0,1,0],w:3,r:0},{s:'burst',p:[0,.5,.5],n:[0,0,1],w:2,r:.35,f:1}].map(d=>{
      const g=api.projectDecal(d,studio.catalog.byId.get(d.s),parts);
      const result={part:{type:part.type,pos:[0,0,0],rot:0},decal:d,positions:g?Array.from(g.attributes.position.array):[],uv:g?Array.from(g.attributes.uv.array):[]};g?.dispose();return result;
     });
    });
    fs.writeFileSync(path.join(evidence,'source-livery-projection.json'),JSON.stringify(fixtures));
    const picker=page.locator('.lv-custom').first();
    await picker.evaluate(el=>{el.classList.remove('on');el.style.width='128px';el.style.height='128px';el.style.boxShadow='none';});
    await picker.screenshot({path:path.join(dest,'custom-color.png')});
    files.push({source:'shared/css/livery.css',source_sha256:sha(path.join(source,'shared/css/livery.css')),target:'assets/Livery/custom-color.png',sha256:sha(path.join(dest,'custom-color.png'))});
    await picker.evaluate(el=>{el.style.removeProperty('width');el.style.removeProperty('height');el.style.removeProperty('box-shadow');});
   }
   if(await page.locator('.lv-layer').count()){await page.locator('.lv-layer').first().click();await page.waitForTimeout(300);await capture(name+'-selected');}
   await page.close();
  }
  fs.writeFileSync(path.join(dest,'Catalog.json'),JSON.stringify({stickers:catalog.map(s=>({...s,texture:'Livery/'+s.id+'.png',mask:s.kind==='shape'?'Livery/'+s.id+'-mask.png':null}))}));
  const sourceFiles=Object.fromEntries([...new Set([...files.map(f=>f.source),'shared/assets/livery/manifest.json','shared/build/livery.js','shared/ui/liveryPanel.js','shared/css/livery.css','shared/assets/ui/new-ui/relief-side.svg','shared/assets/ui/new-ui/relief-primary.svg','three/src/build/liveryStudio.js','three/src/build/liveryView.js'])].map(f=>[f,sha(path.join(source,f))]));
  fs.writeFileSync(path.join(root,'docs/migration/livery-source.json'),JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceFiles,files,catalog:{path:'assets/Livery/Catalog.json',sha256:sha(path.join(dest,'Catalog.json'))}},null,2));
  fs.writeFileSync(path.join(evidence,'source-livery.json'),JSON.stringify({baseline:{commit:baseline.commit},states},null,2));
  console.log('Imported '+catalog.length+' original stickers; captured '+Object.keys(states).length+' source states.');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
