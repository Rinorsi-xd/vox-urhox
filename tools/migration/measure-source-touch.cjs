const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=path.resolve(root,baseline.snapshot);
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url==='/fixture.html')return res.end('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/shared/css/touch-controls.css"><body style="margin:0;background:#111e26"><canvas></canvas>');
  const file=path.resolve(source,'.'+req.url.split('?')[0]);
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',path.extname(file)==='.js'?'text/javascript':path.extname(file)==='.css'?'text/css':'application/octet-stream');fs.createReadStream(file).pipe(res);
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome'});const report={baseline:baseline.commit,fixture:'actual source TouchControls constructor and stylesheet, isolated from scene',layouts:[]};
 try{for(const v of [{width:840,height:378},{width:800,height:450},{width:1024,height:768},{width:640,height:320}]){
  const page=await browser.newPage({viewport:v,hasTouch:true,isMobile:true});await page.goto('http://127.0.0.1:'+server.address().port+'/fixture.html');
  await page.evaluate(async()=>{
   const {TouchControls}=await import('/shared/controls/touchControls.js');
   const input={dom:document.querySelector('canvas'),touchMove:{x:0,y:0},touchKeys:new Set(),clearTouch(){this.touchKeys.clear();this.touchMove.x=this.touchMove.y=0;},mdx:0,mdy:0};
   const rig={mode:'fp',endDrag(){},beginDrag(){},zoom(delta){this.zoomed=delta;}};
   const editor={ui:{},hotbar:[],viewOnly:false,suspended:false,tool:'build',update(){},_pointerDown(){},_pointerUp(){}};
   const drive={active:true,vehicle:{spec:{wings:[],thrusters:[]}},hud:{setPaused(){}},cam:{zoomBy(delta){this.zoomed=delta;}}};
   window.fixture={input,rig,editor,drive,touch:new TouchControls({input,rig,editor,drive,shell:{transition:{},storyPage:{visible:false}}})};fixture.touch.setEnabled(true);
  });
  const sample={...v,modes:{}};
  for(const mode of ['drive']){
   await page.evaluate(mode=>{fixture.drive.active=mode==='drive';fixture.touch.menu=false;fixture.touch.update();},mode);
   sample.modes[mode]=await page.evaluate(()=>[...document.querySelectorAll('#touch-controls button,.tc-stick')].flatMap(el=>{
    const r=el.getBoundingClientRect(),c=getComputedStyle(el);if(!r.width||!r.height)return [];
    return [{action:el.dataset.touch||'move',rect:[r.x,r.y,r.width,r.height],text:el.textContent,background:c.backgroundImage,color:c.backgroundColor,shadow:c.boxShadow,font:c.font,border:c.border,borderRadius:c.borderRadius}];
   }));await page.screenshot({path:path.join(out,`source-touch-${v.width}x${v.height}-${mode}.png`)});
  }
  if(v.width===840){
   report.gestures=await page.evaluate(()=>{
    const {input,drive,rig,touch}=fixture;const samples=[];drive.active=true;touch.mode='drive';input.touchActive=true;
    const r=touch.stick.getBoundingClientRect(),rect={left:r.x,top:r.y,width:r.width,height:r.height};
    const [cx,cy]=touch.stickC;
    for(let i=-100;i<=100;i++){const x=cx+i*.55,y=cy+i*.21;touch.moveStick(x,y);samples.push({x,y,move:[input.touchMove.x,input.touchMove.y]});}
    const mock={classList:{remove(){}},hasPointerCapture(){return false},getBoundingClientRect(){return {left:400,top:100,right:456,bottom:148};}};
    const moves=[];touch.pointers=new Map([[1,{action:'look',el:mock,x:200,y:150,ox:200,oy:150}],[2,{action:'look',el:mock,x:400,y:150,ox:400,oy:150}]]);
    for(const [id,x,y] of [[2,450,160],[1,180,145],[2,420,180]]){
     touch.pointerMove({pointerId:id,clientX:x,clientY:y,preventDefault(){}});moves.push({id,x,y,zoom:drive.cam.zoomed});
    }
    touch.pointers=new Map([[3,{action:'primary',el:mock,x:410,y:120,ox:410,oy:120}]]);input.mdx=input.mdy=0;
    touch.pointerMove({pointerId:3,clientX:437,clientY:131,preventDefault(){}});
    const size=touch.stick.offsetWidth;
    return {rect:{x:cx-size/2,y:cy-size/2,w:size,h:size},samples,moves,primaryLook:[input.mdx,input.mdy]};
   });
   await page.evaluate(()=>{fixture.drive.active=true;fixture.touch.menu=true;fixture.touch.update();});await page.screenshot({path:path.join(out,'source-touch-drive-menu.png')});
  }
  report.layouts.push(sample);await page.close();
 }
 fs.writeFileSync(path.join(out,'source-touch.json'),JSON.stringify(report,null,2));console.log('Captured source touch layouts and '+report.gestures.samples.length+' analog samples');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
