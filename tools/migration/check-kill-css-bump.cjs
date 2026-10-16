// Isolated DOM/CSS only. No game, WebGL, hardware GPU or live preview connection.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8').replace(/^\uFEFF/,''));
const relative='shared/ui/combatFeedback.js',source=fs.readFileSync(path.join(baseline.snapshot,relative));
const sha256=crypto.createHash('sha256').update(source).digest('hex');
assert.equal(sha256,baseline.files[relative].sha256,'Frozen source hash');
const css=source.toString('utf8').match(/const CSS = `([\s\S]*?)`;/)[1];
const output=path.join(root,'docs/migration/evidence/kill-css-bump.json');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--disable-gpu','--disable-webgl','--disable-webgl2','--disable-software-rasterizer']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}}),errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  await page.setContent('<!doctype html><html><head><style>'+css+'</style></head><body class="driving"><div id="combatFx"></div></body></html>');
  const rows=await page.evaluate(async()=>{
   const samples=[];
   const frame=()=>new Promise(resolve=>requestAnimationFrame(()=>resolve()));
   const read=el=>{const s=getComputedStyle(el);return {scale:s.scale,opacity:s.opacity,color:s.color,animation:s.animation,transition:s.transition,
    animations:el.getAnimations().map(a=>({name:a.animationName||null,property:a.transitionProperty||null,type:a.constructor.name,currentTime:a.currentTime,playState:a.playState}))};};
   for(const streak of [false,true])for(const age of [.016,.08,.192,.32,.5,.75,1.5,1.9,2.1]){
    const kill=document.createElement('div');kill.className='kill on'+(streak?' streak':'');
    kill.innerHTML='<div class="pts" style="font-size:58px"><i>+</i><b>300</b></div><div class="who">击毁 target</div>';
    document.querySelector('#combatFx').replaceChildren(kill);
    const pts=kill.querySelector('.pts');getComputedStyle(pts).scale;
    for(const a of document.getAnimations()){a.pause();a.currentTime=age*1000;}
    const before=read(pts);pts.classList.add('bump');getComputedStyle(pts).scale;
    await frame();await frame();
    const added=read(pts);pts.classList.remove('bump');getComputedStyle(pts).scale;
    await frame();await frame();
    samples.push({streak,age,before,added,removed:read(pts)});
   }
   // Positive control: removing the animation exposes the authored scale transition.
   const kill=document.createElement('div');kill.className='kill';kill.innerHTML='<div class="pts">+300</div>';
   document.querySelector('#combatFx').replaceChildren(kill);const pts=kill.firstChild;
   const before=read(pts);await frame();pts.classList.add('bump');getComputedStyle(pts).scale;
   const transitions=pts.getAnimations().filter(a=>a instanceof CSSTransition);
   for(const a of transitions){a.pause();a.currentTime=80;}
   const added=read(pts);
   return {samples,positiveControl:{before,added,transitions:transitions.length},canvasCount:document.querySelectorAll('canvas').length};
  });
  assert.equal(errors.length,0,'No isolated page errors');assert.equal(rows.canvasCount,0,'No game canvas');
  for(const row of rows.samples){
   assert.equal(row.before.scale,row.added.scale,'Source animation masks bump at '+row.age);
   assert.equal(row.before.scale,row.removed.scale,'Source animation masks removed bump at '+row.age);
   assert(row.before.animations.some(a=>a.type==='CSSAnimation'&&a.name==='cfSlam'),'Actual source animation exists');
   assert(!row.added.animations.some(a=>a.type==='CSSTransition'),'No scale transition starts while animation owns property');
  }
  assert(rows.positiveControl.transitions>0,'Unanimated positive control creates scale transition');
  assert.equal(Number(rows.positiveControl.added.scale),1.12,'Unanimated authored bump reaches 1.12');
  const report={result:'PASS',browser:await browser.version(),args:['--disable-gpu','--disable-webgl','--disable-webgl2','--disable-software-rasterizer'],
   source:{branch:baseline.branch,commit:baseline.commit,path:relative,sha256},errors,...rows,
   conclusion:'The real source cfSlam animation, including its both fill, masks the .bump scale declaration. Adding/removing bump creates no scale transition. The same original bump rule works when the animation is absent. Lua must not multiply the animated kill score scale by 1.12.',
   boundary:'Actual Chrome CSS cascade on original frozen CSS and minimal DOM only. CSS animations paused at explicit times; no game, canvas, WebGL, hardware GPU, visible game rendering, performance or mobile acceptance.'};
  fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({result:report.result,browser:report.browser,samples:rows.samples.length,positiveControl:rows.positiveControl,conclusion:report.conclusion,evidence:output}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
