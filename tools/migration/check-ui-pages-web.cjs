// Public controls only. F8 observes production state; it does not drive modes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4307);
const levels=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Outgame.json'))).levels;
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).commit;
const pagesOnly=process.env.VOX_QA_SCOPE==='pages';
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function main(){
 const identity=await fetch(base+'/identity.json').then(r=>{assert.equal(r.status,200);return r.json()});assert.ok(identity.qa,'read-only QA build required');
 if(process.env.VOX_QA_MANIFEST)assert.ok(JSON.stringify(identity).includes(process.env.VOX_QA_MANIFEST),'requested exact candidate identity');
 const out=path.join(root,'docs/migration/evidence/ui-pages-web-'+new Date().toISOString().replace(/[:.]/g,'-'));fs.mkdirSync(out,{recursive:true});
 const report={baseline,identity,scope:pagesOnly?'pages':'pages-and-match',startedAt:new Date().toISOString(),cases:[],boundary:'Actual Web public controls, production StoryPage drawing; optional matchmaking entrance. F8 is read-only. Captures require visual inspection. Not all gameplay, physical phone, frame pacing, audio continuity or pixel-perfect acceptance.'};
 fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity,null,2));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of [{name:'pc',width:1920,height:1080,touch:false},{name:'20x9',width:840,height:378,touch:true}].filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const entry={...test,dpr:test.touch?3:1,checks:[],states:[],errors:[],httpFailures:[],optionalArchive404:[],requiredHttpFailures:[],probeIssues:[],screenshots:[],matchStages:[]};report.cases.push(entry);
  const context=await browser.newContext({viewport:{width:test.width,height:test.height},deviceScaleFactor:entry.dpr,hasTouch:test.touch,isMobile:test.touch});
  const page=await context.newPage();let state,sequence=0,closed=false;
  page.on('console',message=>{const line=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(line.slice(at+14));sequence++;const stage=state.loadingFlow?.match?.stage;if(stage&&entry.matchStages.at(-1)?.stage!==stage)entry.matchStages.push({stage,at:Date.now(),sequence});}catch(error){entry.probeIssues.push({message:error.message,truncated:!line.trimEnd().endsWith('}')});}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(line))entry.errors.push(line);
  });page.on('pageerror',error=>entry.errors.push(error.message));page.on('crash',()=>{closed=true;entry.errors.push('Renderer crashed')});
  page.on('response',response=>{if(response.status()>=400){const failure={url:response.url(),status:response.status()};entry.httpFailures.push(failure);
   const optional=failure.status===404&&failure.url.includes('/cached-engine-source/')&&new URL(failure.url).pathname.endsWith('/assets@windows.7z');
   (optional?entry.optionalArchive404:entry.requiredHttpFailures).push(failure);
  }});
  const check=(ok,label)=>{assert.ok(ok,label);entry.checks.push(label)};
  async function wait(fn,label,timeout=240000){const start=Date.now();let probeAt=0;while(!state||!fn(state)){
   if(closed||entry.errors.length)throw Error('Runtime failed during '+label+': '+entry.errors.join('\n'));
   if(Date.now()-start>timeout)throw Error('Timed out '+label);
   if(Date.now()-probeAt>250){probeAt=Date.now();await page.keyboard.press('F8',{delay:50})}await sleep(60);
  }return state}
  async function dump(){const before=sequence;await page.keyboard.press('F8',{delay:50});return wait(()=>sequence>before,'fresh state',15000)}
  async function click(text){await dump();const widget=state.widgets.find(w=>w.text===text&&!w.disabled&&w.rect[2]>0&&w.rect[3]>0);check(widget,'public widget '+text);
   const [x,y,w,h]=widget.rect,canvas=await page.locator('canvas').boundingBox();assert.ok(canvas,'visible canvas');
   const px=canvas.x+(x+w/2)/state.width*canvas.width,py=canvas.y+(y+h/2)/state.height*canvas.height;
   if(test.touch)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await sleep(250);
  }
  async function shot(name){await dump();entry.states.push({name,state:structuredClone(state)});const file=test.name+'-'+name+'.png';await page.screenshot({path:path.join(out,file)});entry.screenshots.push(file)}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'actionable hall');
   await click('出战');await wait(s=>s.tab==='battle','mode page');await shot('mode');
   await click('剧情模式');await wait(s=>s.tab==='story'&&s.story?.ready,'real story holo ready');
   for(let i=0;i<levels.length;i++){
    if(process.env.VOX_QA_LEVELS&&!process.env.VOX_QA_LEVELS.split(',').includes(String(i+1)))continue;
    const level=levels[i];await click(level.no+'  '+level.name);await wait(s=>s.storyLevel===i+1&&s.story?.level===i+1,'level '+(i+1));
    await sleep(1800);await dump();check(state.widgets.some(w=>w.text==='开始任务'&&!w.disabled),'level '+(i+1)+' has production ready action');
    check(!state.widgets.some(w=>w.text==='制作中'),'level '+(i+1)+' has no obsolete WIP action');await shot('story-'+(i+1));
   }
   await click('播放语音');await sleep(1000);await shot('story-5-voice');
   await click('选择模式');await wait(s=>s.tab==='battle','back from story');
   if(!pagesOnly){
   await click('歼灭战');await wait(s=>s.modeChoice==='elimination','elimination selected');await click('开始匹配');
   await wait(s=>s.loadingFlow?.match?.stage==='queue'&&s.loadingFlow.visible,'real queue');await shot('queue');
   await page.keyboard.press('Escape');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'public queue cancel');check(!state.battle,'cancel preserves outgame');
   await click('开始匹配');await wait(s=>s.loadingFlow?.match?.stage==='roster','real roster');await shot('roster');
   await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'loaded match entrance');
   await wait(s=>s.intro?.active,'real match cinematic');await shot('match-intro');
   await page.keyboard.press('Space');await wait(s=>!s.intro?.active,'public skip cinematic');await shot('match-entered');
   if(state.pointer?.captured){await page.keyboard.press('Escape');await wait(s=>!s.pointer?.captured,'release pointer')}
   await click('退出对局');await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'return to hall');await shot('returned');
   }
   check(entry.errors.length===0,'runtime errors zero');check(entry.requiredHttpFailures.length===0,'required HTTP errors zero; exact optional Windows archive 404 recorded separately');
   check(entry.probeIssues.every(p=>p.truncated),'no malformed complete state');
   const finalIdentity=await fetch(base+'/identity.json').then(r=>r.json());check(JSON.stringify(finalIdentity)===JSON.stringify(identity),'candidate identity unchanged through run');
   entry.result='PASS';
  }catch(error){entry.result='FAIL';entry.failure=error.stack;entry.lastState=state;await page.screenshot({path:path.join(out,test.name+'-failure.png')}).catch(()=>{});}
  finally{await context.close();fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2))}
  console.log(JSON.stringify({case:test.name,result:entry.result,checks:entry.checks.length,errors:entry.errors.length,out}));
  if(entry.result!=='PASS')break;
 }}finally{await browser.close();report.finishedAt=new Date().toISOString();report.result=report.cases.length&&report.cases.every(c=>c.result==='PASS')?'PASS':'FAIL';fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2))}
 if(report.result!=='PASS')process.exitCode=1;
}
main().catch(error=>{console.error(error);process.exitCode=1});
