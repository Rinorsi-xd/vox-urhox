// Frozen source DOM reference; original methods/CSS, no battle or WebGL runtime.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=baseline.snapshot;
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),inputs=new Map();
function original(relative){const b=fs.readFileSync(path.join(source,relative));assert.equal(hash(b),baseline.files[relative].sha256,relative);inputs.set(relative,hash(b));return b;}
const intro=original('three/src/intro/intro.js').toString().replaceAll('\r\n','\n'),story=original('three/src/intro/introStory.js').toString().replaceAll('\r\n','\n');
function between(text,a,b){return text.slice(text.indexOf(a),text.indexOf(b,text.indexOf(a)));}
const methods=[between(intro,'\t_panel( P,','\n\t// 「觉得眼熟'),between(intro,'\tasync actFamiliar()','\n\t// 「两百个'),between(intro,'\tasync actGalaxy()','\n\t// 「工资条'),between(intro,'\tasync actPayslip()','\n\t// 工资条碎'),between(intro,'\t_shred( el )','\n\t// 抉择'),between(story,'\t_in( el,','\n\n\t// 全息屏')].join('\n');
const hSource=between(story,'export const h =','\n\nexport class IntroStory').replace('export const h =','const h =');
const durations=JSON.parse(fs.readFileSync(path.join(root,'assets/Intro/Intro.json'))).durations;
const html='<link rel="stylesheet" href="/shared/css/style.css"><link rel="stylesheet" href="/shared/css/new-ui-tokens.css"><link rel="stylesheet" href="/shared/css/intro.css"><style>body{background:#080f1c}#intro{background:transparent;opacity:1;--ui-vh:1vh;--ui-vw:1vw}.ly{position:absolute;inset:0}</style><script type="importmap">{"imports":{"@shared/":"/shared/"}}</script><div id="intro"><div class="ly in-panels" id="panels"></div><div id="bars"></div><div id="tint"></div></div>';
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://local');
 if(url.pathname==='/reference.html'){res.setHeader('Content-Type','text/html');res.end(html);return;}
 const relative=decodeURIComponent(url.pathname).slice(1),file=path.resolve(source,relative);
 if(!file.startsWith(path.resolve(source)+path.sep)||!fs.existsSync(file)){res.writeHead(404).end();return;}
 const data=original(relative);res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':file.endsWith('.png')?'image/png':'application/octet-stream');res.end(data);
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'chrome'});const rows=[];
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  for(const [shot,age,wrecked]of [['familiar',2,false],['familiar',2,true],['galaxy',2.5,false],['payslip',2,false],['payslip',2,true]]){
   await page.goto('http://127.0.0.1:'+server.address().port+'/reference.html');
   const result=await page.evaluate(async({methods,hSource,durations,shot,age,wrecked})=>{
    await document.fonts.load('40px GameFont','轰——！滋滋……？已扣款');await document.fonts.load('40px VoxIndustrial','星际前途有限公司');await document.fonts.load('40px VoxNum','001237');
    const fx=await import('/three/src/intro/introFx.js'),logo=await import('/three/src/intro/introLogo.js');
    const Actor=new Function('GalaxyMap','LockOn','wipe','mark','ground',hSource+`;const IMG=n=>'/shared/assets/intro/raw/'+n+'.png';return class{${methods}}`)(fx.GalaxyMap,fx.LockOn,()=>({covered:Promise.resolve()}),logo.mark,()=>0);
    const actor=new Actor();Object.assign(actor,{root:document.querySelector('#intro'),L:{panels:document.querySelector('#panels'),bars:document.querySelector('#bars'),tint:document.querySelector('#tint')},wrecked,clock:0,waits:[],tasks:[],animations:[],audio:{duration:id=>durations[id],sfx:()=>{}},cine:{target:{pos:[30,0,-170]}},cam:{pos:{set(){}},look:{set(){}}},clearCam:()=>[0,0,0],clearTasks(){this.tasks=[]},shakeDom(){},mark(){this.clock=0},task(fn){this.tasks.push({fn,born:this.clock})},say(id,opt={}){return this.wait(Math.max(opt.min||0,(durations['vo_'+id]||1)+(opt.tail||0)))},wait(seconds){return new Promise(resolve=>this.waits.push({at:this.clock+seconds,resolve}))}});
    const animate=Element.prototype.animate;Element.prototype.animate=function(...args){const a=animate.apply(this,args);a.pause();a.currentTime=0;actor.animations.push({a,born:actor.clock});return a};
    actor['act'+shot[0].toUpperCase()+shot.slice(1)]().catch(error=>{actor.error=String(error)});
    await Promise.resolve();await Promise.resolve();
    for(let t=0;t<=age+1e-8;t=Math.min(age,t+1/120)){
     actor.clock=t;
     for(let pass=0;pass<4;pass++){
      const due=actor.waits.filter(w=>w.at<=t+1e-8);actor.waits=actor.waits.filter(w=>w.at>t+1e-8);
      for(const w of due)w.resolve();await Promise.resolve();
     }
     for(const {a,born}of actor.animations)a.currentTime=Math.max(0,(t-born)*1000);
     actor.tasks=actor.tasks.filter(task=>task.fn(0,1/120,t-task.born)!==false);
     if(t===age)break;
    }
    for(const {a,born}of actor.animations)a.currentTime=Math.max(0,(age-born)*1000);
    for(const a of document.getAnimations())if(!actor.animations.some(row=>row.a===a)){a.pause();a.currentTime=age*1000;}
    await document.fonts.ready;
    await Promise.all([...document.images].map(img=>img.decode().catch(()=>{})));
    const backgroundUrls=[...document.querySelectorAll('.im')].map(e=>getComputedStyle(e).backgroundImage).filter(s=>s.startsWith('url')).map(s=>s.slice(5,-2));
    await Promise.all(backgroundUrls.map(src=>new Promise(resolve=>{const img=new Image();img.onload=img.onerror=resolve;img.src=src})));
    await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
    if(actor.error)throw Error(actor.error);
    return [...document.querySelectorAll('.lbl,.sfx,.gx-hud small,.gx-hud b,.gx-n,.gx-hud em,.gx-tag,.slip2,.slip2 .sh b,.slip2 .sh small,.slip2 .sh em,.slip2 .who,.slip2 .r,.slip2 .tot,.slip2 .stp,.lk-tx')].map(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {class:e.className,text:e.textContent,rect:[r.x,r.y,r.width,r.height],font:s.font,fontFamily:s.fontFamily,lineHeight:s.lineHeight,letterSpacing:s.letterSpacing,textStroke:s.webkitTextStroke,textShadow:s.textShadow,transform:s.transform,opacity:s.opacity};});
   },{methods,hSource,durations,shot,age,wrecked});
   const file='intro-noncaption-source-'+shot+'-'+(wrecked?'wrecked':'intact')+'-t'+age+'.png';await page.screenshot({path:path.join(root,'docs/migration/evidence',file)});rows.push({shot,age,wrecked,screenshot:file,measurements:result});
  }
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(root,'docs/migration/evidence/intro-noncaption-source.json'),JSON.stringify({result:'PASS',sourceCommit:baseline.commit,viewport:[1920,1080],dpr:1,inputs:Object.fromEntries(inputs),rows,errors,boundary:'Original source class methods extracted byte-for-byte and original CSS/FX/Logo modules. Native scene/camera/audio/task scheduling are adapted; wipe covered resolves immediately so ages are measured after mark. Familiar has no captured driving screenshots and therefore uses the original workshop fallback. Payslip has a neutral background instead of the original live crater. Animation clock is paused at the stated age. This is source DOM typography reference, not full gameplay or target parity.'},null,2));
  console.log(JSON.stringify({result:'PASS',screenshots:rows.length,inputs:inputs.size}));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(error=>{console.error(error);process.exitCode=1;server.close();});
