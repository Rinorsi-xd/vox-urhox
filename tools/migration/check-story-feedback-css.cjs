// Original frozen CSS in an isolated DOM. No engine, canvas, WebGL or GPU.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const inputs={};
function read(relative){const bytes=fs.readFileSync(path.join(baseline.snapshot,relative));const hash=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(hash,baseline.files[relative].sha256);inputs[relative]=hash;return bytes.toString('utf8');}
const css=read('shared/css/storyHud.css'),js=read('shared/ui/storyHud.js');
const prompt=js.match(/<div class="sh-prompt">[^\n]+?<\/div>/)[0],dead=js.match(/<div class="sh-dead">[^\n]+?<\/div>/)[0];
const args=['--disable-gpu','--disable-webgl','--disable-webgl2','--disable-software-rasterizer'];
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  await page.setContent('<!doctype html><html><head><style>:root{--body:sans-serif;--display:sans-serif}'+css+'</style></head><body><div id="storyHud">'+prompt+dead+'</div></body></html>');
  const actual=await page.evaluate(async()=>{
   const frame=()=>new Promise(resolve=>requestAnimationFrame(resolve));
   const kick=document.querySelector('.sh-dkick'),blink=kick.getAnimations().find(a=>a.animationName==='shBlink');
   blink.pause();const blinking=[];
   for(const at of [0,99,100,199,200,201,299,300,399,400,401,499,500,599,600,601,699,700,799,800,801,1000,1001]){
    blink.currentTime=at;blinking.push({at,opacity:Number(getComputedStyle(kick).opacity)});
   }
   const timing=blink.effect.getTiming(),cssTiming=getComputedStyle(kick).animationTimingFunction;
   const sourceKeyframes=blink.effect.getKeyframes();
   const sequences=[];
   for(const selector of ['.sh-prompt','.sh-dead'])for(const reverse of [false,true]){
    const el=document.querySelector(selector);el.classList.remove('on');
    el.getAnimations().filter(a=>a instanceof CSSTransition).forEach(a=>a.finish());
    getComputedStyle(el).opacity;await frame();await frame();
    const duration=selector==='.sh-prompt'?200:300;
    const ops=reverse?[{at:0,on:true},{at:duration/2},{at:duration/2,on:false},{at:duration/2+50},{at:duration},{at:2*duration}]:
     [{at:0,on:true},{at:duration/2},{at:duration},{at:duration+100,on:false},{at:duration+100+duration/2},{at:2*duration+100}];
    let animation=null,start=0;const samples=[];
    for(const op of ops){
     if(animation)animation.currentTime=op.at-start;
     getComputedStyle(el).opacity;
     if(op.on!==undefined){
      el.classList.toggle('on',op.on);getComputedStyle(el).opacity;
      animation=el.getAnimations().filter(a=>a instanceof CSSTransition&&a.transitionProperty==='opacity').at(-1)||null;
      start=op.at;if(animation){animation.pause();animation.currentTime=0;}
     }
     samples.push({at:op.at,on:op.on,opacity:Number(getComputedStyle(el).opacity),
      duration:animation?.effect.getComputedTiming().duration??0});
    }
    sequences.push({selector,reverse,ops,samples});
   }
   const svg=document.querySelector('.sh-prompt svg'),circle=svg.querySelector('circle');
   const key=document.querySelector('.sh-prompt kbd');
   return {blinking,timing,cssTiming,sourceKeyframes,sequences,geometry:{svgWidth:svg.getBoundingClientRect().width,svgHeight:svg.getBoundingClientRect().height,
    viewBox:svg.viewBox.baseVal.width,radius:circle.r.baseVal.value,strokeWidth:Number.parseFloat(getComputedStyle(circle).strokeWidth),key:key.textContent},canvasCount:document.querySelectorAll('canvas').length};
  });
  assert.equal(actual.canvasCount,0);assert.equal(actual.geometry.key,'G');assert.equal(actual.geometry.svgWidth,84);
  assert.equal(actual.geometry.svgHeight,84);assert.equal(actual.geometry.viewBox,80);assert.equal(actual.geometry.radius,34);assert.equal(actual.geometry.strokeWidth,5);
  assert.equal(actual.cssTiming,'steps(2)');assert.equal(actual.timing.duration,800);
  for(const at of [99,299,499,699]){
   const row=actual.blinking.find(row=>row.at===at);assert.equal(row.opacity,[1,.625,.25,.625][Math.floor(at/200)]);
  }
  const report={result:'PASS',browser:await browser.version(),args,source:{branch:baseline.branch,commit:baseline.commit,files:inputs},...actual,
   toolSha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),
   boundary:'Actual Chrome CSS animations/transitions and SVG geometry on original frozen CSS/minimal original DOM only. Animations paused at explicit times; no game, canvas, engine, WebGL, GPU, rendered parity or performance acceptance.'};
  const output=path.join(root,'docs/migration/evidence/story-feedback-css.json');fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({result:report.result,browser:report.browser,blinking:actual.blinking,sequences:actual.sequences,geometry:actual.geometry,evidence:output},null,2));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
