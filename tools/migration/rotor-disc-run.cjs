'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.rotorDisc?.isolated);
 const manifest=await fetch(base+'/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')).then(r=>r.json());
 const report={status:'RUNNING',identity,snapshots:[],errors:[],httpErrors:[],httpHashes:{},boundary:identity.rotorDisc.boundary};
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 for(const [name,expected]of Object.entries({'main.lua':identity.g1WebCpu.entrySha256,...identity.rotorDisc.modules})){
  const e=manifest.files.find(e=>e.fs_path===name);assert(e);const r=await fetch(base+'/game-dist/assets/'+e.uuid+'-'+e.hash+e.ext);assert(r.ok);
  const actual=sha(Buffer.from(await r.arrayBuffer()));assert.equal(actual,expected,name);report.httpHashes[name]=actual;
 }
 let browser,done=null,capture=Promise.resolve();const cameras=new Map();
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:false,channel:'chrome',args:['--use-angle=d3d11']});const page=await browser.newPage({viewport:{width:1600,height:900}});
  page.on('console',m=>{
   const line=m.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(m.type()==='error'||/ERROR:|Aborted\(|stack traceback|Shader compilation failed/.test(line))report.errors.push(line);
   const cam='ROTOR_DISC_CAMERA ',ci=line.indexOf(cam);if(ci>=0)try{const camera=JSON.parse(line.slice(ci+cam.length));assert(!cameras.has(camera.stage));cameras.set(camera.stage,camera)}catch(e){report.errors.push(e.stack)}
   const prefix='ROTOR_DISC_SNAPSHOT ',at=line.indexOf(prefix);
   if(at>=0)capture=capture.then(async()=>{
    const row=JSON.parse(line.slice(at+prefix.length));assert.equal(row.stage,identity.rotorDisc.stages[report.snapshots.length]);assert(row.fixture&&row.frames>=15);
    row.camera=cameras.get(row.stage);assert(row.camera,'Actual camera record required');
    assert.equal(row.rows.length,6);for(const part of row.rows){assert.equal(part.scale[0],part.sourceX<0?-1:1);assert(part.slots>0);assert(part.screen.every(v=>v>0&&v<1));
     assert.equal(part.rot,row.camera.identityRotation);assert(part.incidence>=.6,'Actual face normal must face camera');
     assert(part.bounds.every(v=>v>0&&v<1));assert((part.bounds[2]-part.bounds[0])*1600>=70);assert((part.bounds[3]-part.bounds[1])*900>=70);
     if(row.stage.endsWith('double'))assert(part.culls.every(v=>v===row.cullNone));}
    await page.evaluate(()=>document.querySelector('#loading')?.remove());
    const png=await page.locator('#canvas').screenshot({path:path.join(out,row.stage+'.png'),timeout:15000});row.pngSha256=sha(png);
    row.pixels=await page.evaluate(async ({encoded,rows})=>{
     const im=new Image();im.src='data:image/png;base64,'+encoded;await im.decode();const canvas=document.createElement('canvas');canvas.width=im.width;canvas.height=im.height;
     const ctx=canvas.getContext('2d');ctx.drawImage(im,0,0);const data=ctx.getImageData(0,0,canvas.width,canvas.height).data;
     const items=[];for(const row of rows){const cx=Math.round(row.screen[0]*canvas.width),cy=Math.round(row.screen[1]*canvas.height);let visible=0;let total=0;
      const rect=[Math.floor(row.bounds[0]*canvas.width),Math.floor(row.bounds[1]*canvas.height),Math.ceil(row.bounds[2]*canvas.width),Math.ceil(row.bounds[3]*canvas.height)];
      for(let y=rect[1];y<rect[3];y++)for(let x=rect[0];x<rect[2];x++){
       const p=(y*canvas.width+x)*4;total++;if(Math.max(data[p],data[p+1],data[p+2])>35)visible++;}
      items.push({id:row.id,visible,total,coverage:visible/total,cx,cy,rect});}
     return {width:canvas.width,height:canvas.height,items};
    },{encoded:png.toString('base64'),rows:row.rows});
    for(const part of row.pixels.items){assert(part.visible>=500,'Actual rotor face must have sufficient pixels '+part.id);assert(part.coverage>=.15,'Authored projected face must have sufficient coverage '+part.id);}
    report.snapshots.push(row);persist();await page.keyboard.press('F8');
   }).catch(e=>report.errors.push(e.stack));
   const final='ROTOR_DISC_DONE ',end=line.indexOf(final);if(end>=0)try{assert.equal(done,null);done=JSON.parse(line.slice(end+final.length))}catch(e){report.errors.push(e.stack)}
  });
  page.on('pageerror',e=>report.errors.push(e.stack));page.on('crash',()=>report.errors.push('Renderer crash'));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status()})});page.on('requestfailed',r=>report.httpErrors.push({url:r.url(),failure:r.failure()}));
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000});await page.bringToFront();
  const end=Date.now()+180000;while(!done){assert(Date.now()<end,'180s deadline');assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0);await sleep(100)}
  await capture;assert.equal(done.status,'PASS',done.error);assert(done.released);assert.equal(report.snapshots.length,6);assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);
  report.status='RENDERED_PENDING_VISUAL';report.done=done;
 }catch(e){report.status='FAIL';report.failure=e.stack;throw e}
 finally{if(browser)try{await Promise.race([browser.close(),sleep(5000).then(()=>{throw Error('Close deadline')})]);report.shutdown='CLOSED'}catch(e){report.shutdown='UNCONFIRMED';report.closeError=e.message}persist();console.log(JSON.stringify({status:report.status,out,shutdown:report.shutdown,failure:report.failure}));}
 return report;
}
module.exports={run};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3])).catch(e=>{console.error(e.stack);process.exitCode=1});
