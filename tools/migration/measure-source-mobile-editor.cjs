const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=baseline.snapshot,checked={};
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url==='/fixture.html')return res.end('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/shared/css/style.css"><link rel="stylesheet" href="/shared/css/new-ui-tokens.css"><link rel="stylesheet" href="/shared/css/touch-controls.css"><link rel="stylesheet" href="/shared/css/mobile-editor.css"><body class="screen-edit touch-input" style="margin:0;background:#111e26"><canvas style="width:100%;height:100%"></canvas><div hidden><span id="tierName">T3 重型</span><input id="bpName" value="迁移测试车"><span id="stBudget"><i class="v">1280 / 4000</i></span><span id="dockLabel">建造</span></div>');
  const relative=decodeURIComponent(req.url.split('?')[0]).replace(/^\//,'');const file=path.resolve(source,relative);
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  const bytes=fs.readFileSync(file),hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==baseline.files[relative]?.sha256)return res.writeHead(409).end('Frozen hash mismatch');checked[relative]=hash;
  res.setHeader('Content-Type',path.extname(file)==='.js'?'text/javascript':path.extname(file)==='.css'?'text/css':'application/octet-stream');res.end(bytes);
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome'}),report={baseline:baseline.commit,fixture:'actual source TouchControls/MobileEdit constructors and CSS',layouts:[]};
 try{for(const v of [{width:840,height:378},{width:800,height:450},{width:1024,height:768},{width:640,height:320}]){
  const page=await browser.newPage({viewport:v,hasTouch:true,isMobile:true});await page.goto('http://127.0.0.1:'+server.address().port+'/fixture.html');
  await page.evaluate(async()=>{
   const {TouchControls}=await import('/shared/controls/touchControls.js');
   const input={dom:document.querySelector('canvas'),touchMove:{x:0,y:0},touchKeys:new Set(),clearTouch(){this.touchKeys.clear();},mdx:0,mdy:0};
   const rig={mode:'fp',endDrag(){},beginDrag(){},zoom(){}};
   const editor={ui:{},hotbar:['cube','slope','corner','heavy','glass','drive3','steer3','mg3','laser3','light'],slot:0,tool:'build',color:0xd0182a,autoColor:false,paintChannel:'shell',viewOnly:false,suspended:false,update(){},_pointerDown(){},_pointerUp(){}};
   window.fixture={input,rig,editor,touch:new TouchControls({input,rig,editor,drive:{active:false},shell:{transition:{},storyPage:{visible:false}}})};fixture.touch.setEnabled(true);fixture.touch.update();
  });await page.waitForTimeout(600);await page.evaluate(()=>{fixture.touch.me.sig=null;fixture.touch.update();return document.fonts.ready;});
  const sample={...v,innerWidth:await page.evaluate(()=>innerWidth),states:{}};
  for(const state of ['tap','aim','tools','more','paint']){
   await page.evaluate(state=>{fixture.touch.prefs.build=state==='aim'?'aim':'tap';fixture.touch.me.sheet=['tools','more','paint'].includes(state)?state:null;fixture.touch.me.sig=null;fixture.touch.update();},state);
   sample.states[state]=await page.evaluate(()=>[...document.querySelectorAll('.me button,.me-dock,.me-sheet,.me-hint,.me-split .lb')].flatMap(el=>{const r=el.getBoundingClientRect();if(!r.width||!r.height)return[];return[{action:el.dataset.touch||el.dataset.sheet||el.className,index:el.dataset.i,value:el.dataset.v,tool:el.dataset.tool,hex:el.dataset.hex,rect:[r.x,r.y,r.width,r.height],text:el.textContent}];}));
   if(v.width===840)await page.screenshot({path:path.join(out,'source-mobile-editor-'+state+'.png')});
  }
  report.layouts.push(sample);await page.close();
 }
 report.sourceHashes=checked;fs.writeFileSync(path.join(out,'source-mobile-editor.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({layouts:report.layouts.length,states:20,sourceHashes:Object.keys(checked).length}));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
