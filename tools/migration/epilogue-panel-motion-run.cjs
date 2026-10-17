'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function run(base,out,width=1600,height=900){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert([1600,2000].includes(width)&&height===900);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.epiloguePanelMotion?.isolated);
 const manifest=await fetch(base+'/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')).then(r=>r.json());
 const report={status:'RUNNING',identity,viewport:[width,height],errors:[],httpErrors:[],snapshots:[],httpHashes:{}};
 for(const [name,hash]of Object.entries({'main.lua':identity.g1WebCpu.entrySha256,...identity.epiloguePanelMotion.modules})){
  const e=manifest.files.find(e=>e.fs_path===name);assert(e,name);const response=await fetch(base+'/game-dist/assets/'+e.uuid+'-'+e.hash+e.ext);assert(response.ok);const actual=sha(Buffer.from(await response.arrayBuffer()));assert.equal(actual,hash);report.httpHashes[name]=actual;
 }
 let browser,done=null,capture=Promise.resolve();const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});const page=await browser.newPage({viewport:{width,height}});
  page.on('console',m=>{
   const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(m.type()==='error'||/ERROR:|Aborted\(|stack traceback|Shader compilation failed/.test(line))report.errors.push(line);
   const prefix='EPILOGUE_PANEL_MOTION_SNAPSHOT ',at=line.indexOf(prefix);
   if(at>=0)capture=capture.then(async()=>{
    const row=JSON.parse(line.slice(at+prefix.length));assert.equal(row.stage,identity.epiloguePanelMotion.stages[report.snapshots.length]);assert(row.fixture&&row.frames>=10);
    for(const image of Object.values(row.images))assert(image.handle>0&&image.width>0&&image.height>0);
    row.surface=await page.evaluate(()=>{
     const overlay=document.querySelector('#loading');if(overlay)overlay.remove();const r=document.querySelector('#canvas').getBoundingClientRect();
     return {loadingAbsent:!document.querySelector('#loading'),rect:[r.x,r.y,r.width,r.height],topmost:[[.5,.5],[.1,.1],[.9,.1],[.1,.9],[.9,.9]].map(([x,y])=>document.elementFromPoint(innerWidth*x,innerHeight*y)?.id)};
    });
    assert(row.surface.loadingAbsent&&row.surface.topmost.every(x=>x==='canvas'));assert.deepEqual(row.surface.rect,[0,0,width,height]);
    const png=await page.locator('#canvas').screenshot({path:path.join(out,row.stage+'.png'),timeout:15000});row.pngSha256=sha(png);
    row.pixels=await page.evaluate(async encoded=>{
     const i=new Image();i.src='data:image/png;base64,'+encoded;await i.decode();const c=document.createElement('canvas');c.width=i.width;c.height=i.height;const ctx=c.getContext('2d');ctx.drawImage(i,0,0);const d=ctx.getImageData(0,0,c.width,c.height).data;let visible=0;
     for(let p=0;p<d.length;p+=4)if(Math.max(d[p],d[p+1],d[p+2])>35)visible++;
     return {width:c.width,height:c.height,visible};
    },png.toString('base64'));
    assert(row.pixels.visible>1000,'Actual panel/portrait/text pixels must be nonblank');report.snapshots.push(row);persist();await page.keyboard.press('F8');
   }).catch(e=>report.errors.push(e.stack));
   const final='EPILOGUE_PANEL_MOTION_DONE ',end=line.indexOf(final);if(end>=0)try{assert.equal(done,null);done=JSON.parse(line.slice(end+final.length))}catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Renderer crash'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),error:r.failure()}));
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  const deadline=Date.now()+180000;while(!done){assert(Date.now()<deadline,'180s fixture timeout');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0);await sleep(100)}
  await capture;assert.equal(done.status,'PASS',done.error);assert(done.released);assert.equal(done.stages,8);assert.equal(report.snapshots.length,8);assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);
  for(const [a,b]of [[0,1],[2,3],[4,5],[6,7]])assert.notEqual(report.snapshots[a].pngSha256,report.snapshots[b].pngSha256,'Different rendered animation phases');
  report.status='PASS';report.boundary=identity.epiloguePanelMotion.boundary;
 }catch(e){report.status='FAIL';report.failure=e.stack;throw e}
 finally{
  if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('close deadline')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}
  persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
module.exports={run};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3]),Number(process.argv[4]||1600),Number(process.argv[5]||900)).catch(e=>{console.error(e.stack);process.exitCode=1});
