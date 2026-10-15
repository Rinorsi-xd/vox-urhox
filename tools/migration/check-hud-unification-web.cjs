// Real public inputs; source VM values are the geometry oracle, not injected state.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE;
if(!base)throw Error('VOX_QA_BASE must identify the immutable QA server');
const output=process.env.VOX_QA_OUTPUT_DIR||path.join(root,'docs/migration/evidence','hud-unification-web-'+new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(output,{recursive:true});
const source=JSON.parse(fs.readFileSync(path.join(__dirname,'source-hud-unification.json'))),sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});let failures=0;
 try{for(const test of [{name:'pc',width:1920,height:1080},{name:'20x9-touch',width:840,height:378,dpr:3,touch:true}].filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE===t.name)){
  const report={identity,test,route:process.env.VOX_QA_ROUTE||'trial-story',baseline:source.commit,sourceInputs:source.inputs,checks:[],errors:[],httpFailures:[],samples:[],boundary:'Actual trial and mission-four entry using public inputs. No HP/phase/position injection. Screenshots require visual review. Not complete combat, pixel-perfect equivalence or real-phone performance acceptance.'};
  let state,sequence=0;
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{isMobile:true,hasTouch:true}:{})});
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(output,test.name+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(line.slice(at+14));sequence++;}catch{}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Browser renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function key(k){await page.keyboard.down(k);await sleep(75);await page.keyboard.up(k);}
  async function wait(fn,label,timeout=240000){const begin=Date.now();let last=begin;
   while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors[0]);if(Date.now()-begin>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
    if(Date.now()-last>1000){last=Date.now();await key('F8');}await sleep(100);
   }return state;
  }
  async function dump(){const before=sequence;await key('F8');return wait(()=>sequence>before,'fresh state',15000);}
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function button(id){await dump();const r=state.touchRects?.[id];check(r?.[2]>0&&r?.[3]>0,'real touch button '+id);await tap((r[0]+r[2]/2)/state.width*test.width,(r[1]+r[3]/2)/state.height*test.height);}
  async function widget(text){await dump();await wait(s=>s.widgets.some(w=>w.text===text&&w.rect[2]>0&&w.rect[3]>0),'laid out '+text,30000);
   const r=state.widgets.find(w=>w.text===text&&w.rect[2]>0&&w.rect[3]>0).rect;await tap((r[0]+r[2]/2)/state.width*test.width,(r[1]+r[3]/2)/state.height*test.height);
  }
  async function shot(name){await dump();report.samples.push({name,state:structuredClone(state)});await page.screenshot({path:path.join(output,test.name+'-'+name+'.png')});}
  async function capture(){await tap(test.width/2,test.height/2);await wait(s=>s.pointer.captured,'actual input capture');}
  function geometry(label){
   const golden=source.scaleCases.find(c=>c.w===test.width&&c.h===test.height&&c.compact===!!test.touch);
   check(golden,'frozen source scale fixture exists '+label);const css=state.reticle.layout.radius/state.width*test.width;
   report.checks.push({label:'source geometry sample '+label,sourceCssRadius:270*golden.k,targetCssRadius:css});
   check(Math.abs(css-270*golden.k)<.3,'actual rendered radius follows frozen reticleScale '+label);
   check(!state.reticle.legacyMeter,'obsolete meter hidden '+label);
  }
  async function exerciseWeapons(prefix){
   const count=state.reticle.groups;check(count>0,'mounted weapon groups '+prefix);
   for(let i=1;i<=count;i++){
    if(test.touch){if(i>1)await button('weapon');}else await key(String(i));
    await wait(s=>s.reticle.selected===i,'actual weapon selection '+prefix+' '+i);await dump();
    const kind=state.missile.group;check(source.zoom[kind]>0,'known actual source optic '+kind);await shot(prefix+'-'+kind+'-free');
    if(test.touch)await button('scope');else await page.mouse.down({button:'right'});
    const expected=2*Math.atan(Math.tan(48*Math.PI/360)/source.zoom[kind])*180/Math.PI;
    await wait(s=>s.reticle.scope&&Math.abs(s.reticle.fov-expected)<.25,'actual source optical FOV '+kind,30000);await shot(prefix+'-'+kind+'-scope');
    check(state.camera.firstPerson,'actual scoped first-person camera '+kind);
    if(test.touch)await button('scope');else await page.mouse.up({button:'right'});
    await wait(s=>!s.reticle.scope,'scope release '+kind);
   }
  }
  try{
   const begin=Date.now();await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'first actionable hall');report.hallMs=Date.now()-begin;
   if(process.env.VOX_QA_ROUTE!=='story'){
    await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'actual trial');await capture();await shot('trial');geometry('trial');
    check(state.practice?.alive===true,'real practice player alive');await exerciseWeapons('trial');
    if(!test.touch){const before=state.weapons.shots;await key('1');await page.mouse.down();await wait(s=>s.weapons.shots>before,'actual weapon fires');await shot('trial-fire');await page.mouse.up();check(state.weapons.shots>before,'actual fire updates HUD state');}
    await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'trial releases to hall');check(!state.reticle,'trial HUD released');
   }
   await widget('出战');await widget('剧情模式');await wait(s=>s.tab==='story'&&s.story?.ready,'story selector');
   await widget('04  偷家');await wait(s=>s.story?.level===4&&s.story.ready,'mission four briefing');await widget('开始任务');
   await wait(s=>s.mode==='trial'&&s.story?.id==='s4'&&!s.loadingFlow.active,'actual mission four');await capture();
   await wait(s=>s.story?.step==='A'&&s.story.marker&&s.story.beaconModelsVisible>0,'natural first mission objective');await shot('story-objective');geometry('story');
   check(state.story.marker?.enemy===false,'actual first story objective marker');check(state.story.beaconModelsVisible>0,'real authored objective scene rendered');
   await exerciseWeapons('story');await shot('story-final');
   await key('Escape');await wait(s=>!s.pointer.captured,'story input release');await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'story return');check(!state.reticle,'story HUD released');
   check(report.errors.length===0,'no runtime errors');report.result='PASS';
  }catch(e){failures++;report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(output,test.name+'-failure.png')}).catch(()=>{});}
  finally{await page.close();report.gameHttpFailures=report.httpFailures.filter(f=>!f.url.includes('/cached-engine-source/')||!f.url.includes('assets@windows.7z'));fs.writeFileSync(path.join(output,test.name+'.json'),JSON.stringify(report,null,2));}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length,manifest:identity.servedManifest}));
 }}finally{await browser.close();}
 console.log(output);if(failures)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
