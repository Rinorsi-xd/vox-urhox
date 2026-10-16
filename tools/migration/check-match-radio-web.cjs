// Public match route only. F8 reads the QA probe; no gameplay completion hooks.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const radioOf=s=>s?.battle?.radio;
function probeList(value,label){
 if(Array.isArray(value))return value;
 // cjson encodes an empty Lua table as {}; populated maps are not lists.
 if(value&&typeof value==='object'&&Object.getPrototypeOf(value)===Object.prototype&&Object.keys(value).length===0)return [];
 assert.fail('Expected probe list or empty Lua object: '+label);
}
const playing=s=>radioOf(s)?probeList(radioOf(s).jobs,'jobs').filter(j=>j.playing&&j.path?.startsWith('Sounds/BattleRadioDSP/')):[];
const voicePlaying=s=>playing(s).filter(j=>/-voice\.wav$/.test(j.path));
const validRect=r=>Array.isArray(r)&&r.length===4&&r.every(Number.isFinite)&&r[2]>0&&r[3]>0;
const onScreen=(s,r)=>validRect(r)&&r[0]+r[2]/2>=0&&r[1]+r[3]/2>=0&&r[0]+r[2]/2<s.width&&r[1]+r[3]/2<s.height;
function publicWidget(s,text){return s?.widgets&&probeList(s.widgets,'widgets').find(w=>w.text===text&&!w.disabled&&onScreen(s,w.rect));}
function cursorAt(s,rect,tolerance=2){
 const m=s?.mouse,scale=m?.scale;
 return validRect(rect)&&Number.isFinite(scale)&&scale>0&&Number.isFinite(m.x)&&Number.isFinite(m.y)
  &&Math.abs(m.x/scale-(rect[0]+rect[2]/2))<=tolerance&&Math.abs(m.y/scale-(rect[1]+rect[3]/2))<=tolerance;
}
function validateRadio(s){
 const r=radioOf(s);assert(r,'DSP read-only probe');
 const jobs=probeList(r.jobs,'jobs');probeList(r.loading,'loading');probeList(r.fading,'fading');probeList(r.touched,'touched');
 assert(jobs.length<=4,'one current line owns at most four stems');
 if(r.pending)assert(typeof r.pending.id==='string','pending line identity');
 for(const j of jobs){assert(j.path.startsWith('Sounds/BattleRadioDSP/'),'processed source stem');assert(j.untilAt>j.at,'authored stem interval');}
 for(const j of playing(s))assert(j.frequency>30000,'actual sample frequency in Hz');
 return r;
}
function gainMatches(s,level){return playing(s).length>0&&playing(s).every(j=>Math.abs(j.gain-.28*level/.6)<.003);}
function selfTest(){
 const fixture={battle:{radio:{ready:true,jobs:[{path:'Sounds/BattleRadioDSP/a01-voice.wav',at:.26,untilAt:2,playing:true,frequency:48000,gain:.28}],loading:[],fading:[],touched:[],pending:false}}};
 validateRadio(fixture);assert(gainMatches(fixture,.6));let rejected=0;
 for(const mutate of [s=>s.battle.radio.jobs.push(...Array(4).fill(s.battle.radio.jobs[0])),s=>s.battle.radio.jobs[0].path='Sounds/BattleRadio/a01.wav',s=>s.battle.radio.jobs[0].frequency=1,s=>s.battle.radio.jobs[0].untilAt=0,s=>s.battle.radio.loading=null]){
  const candidate=structuredClone(fixture);mutate(candidate);assert.throws(()=>validateRadio(candidate));rejected++;
 }
 const luaEmpty=structuredClone(fixture);for(const key of ['jobs','loading','fading','touched'])luaEmpty.battle.radio[key]={};
 validateRadio(luaEmpty);assert.equal(playing(luaEmpty).length,0);assert(!gainMatches(luaEmpty,.6));
 for(const key of ['jobs','loading','fading','touched']){
  const candidate=structuredClone(fixture);candidate.battle.radio[key]={unexpected:'not an array'};
  assert.throws(()=>validateRadio(candidate));rejected++;
 }
 assert(!gainMatches(fixture,.2));fixture.battle.radio.jobs[0].gain=.28*.2/.6;assert(gainMatches(fixture,.2));
 assert.equal(voicePlaying(fixture).length,1);
 for(const change of [j=>j.path='Sounds/BattleRadioDSP/lead.wav',j=>j.path='Sounds/BattleRadioDSP/a01-hiss.wav',j=>j.playing=false]){
  const candidate=structuredClone(fixture);change(candidate.battle.radio.jobs[0]);assert.equal(voicePlaying(candidate).length,0);rejected++;
 }
 const pageState={width:1920,height:1080,widgets:[{text:'开始匹配',rect:[20,30,150,40]}]};assert(publicWidget(pageState,'开始匹配'));
 for(const change of [s=>s.widgets=[],s=>s.widgets={},s=>s.widgets[0].disabled=true,s=>s.widgets[0].rect[2]=0,s=>s.widgets[0].rect[3]=-1,s=>s.widgets[0].rect[0]=NaN,s=>s.widgets[0].rect[0]=2200]){
  const candidate=structuredClone(pageState);change(candidate);assert(!publicWidget(candidate,'开始匹配'));rejected++;
 }
 const cursor={mouse:{x:190,y:100,scale:2}};assert(cursorAt(cursor,[20,30,150,40]));
 for(const change of [s=>s.mouse.x=960,s=>s.mouse.y=540,s=>s.mouse.scale=0,s=>s.mouse.scale=undefined,s=>s.mouse.x=NaN,s=>s.mouse=undefined]){
  const candidate=structuredClone(cursor);change(candidate);assert(!cursorAt(candidate,[20,30,150,40]));rejected++;
 }
 assert.equal(playing({}).length,0);console.log(JSON.stringify({result:'PASS',scope:'CPU detector controls only; no browser execution',negativeControls:rejected+1}));
}
async function run(){
 const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
 const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4204);
 const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),'utf8').replace(/^\uFEFF/,''));
 const identity=await fetch(base+'/identity.json').then(r=>r.json());
 assert(identity.qa,'read-only QA probe required');assert.equal(identity.source_directory,prepared.source_directory,'selected immutable package');
 assert.equal(identity.servedManifest,path.basename(prepared.manifest_path),'selected immutable manifest');
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
 const byName=new Map(manifest.files.map(f=>[f.uuid+'-'+f.hash+f.ext,f.fs_path]));
 const stamp=new Date().toISOString().replace(/[:.]/g,'-'),tag=process.env.VOX_QA_TAG||identity.servedManifest.replace('.json','');
 const out=path.join(root,'docs/migration/evidence/match-radio-web-'+tag+'-'+stamp);fs.mkdirSync(out,{recursive:true});
 const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 const test=process.env.VOX_QA_CASE==='phone-landscape'?{name:'phone-landscape',width:840,height:378,dpr:3,touch:true}:{name:'pc',width:1920,height:1080,dpr:1,touch:false};
 const report={identity,test,toolSha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),checks:[],errors:[],httpFailures:[],requests:[],samples:[],timings:[],interactions:[],volume:{attempted:false,liveGainChanged:false},boundary:'Public match and settings only. Source scheduling and native source state do not prove audible continuity or sample-accurate playback.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 let page,state,seq=0,closed=false,originalLevel,volumeRestored=false;
 const started=Date.now();
 const check=(value,label)=>{assert(value,label);report.checks.push(label);};
 try{
  page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  page.on('crash',()=>{closed=true;report.errors.push('Renderer crashed');});page.on('close',()=>closed=true);
  page.on('console',message=>{const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;if(radioOf(state))report.samples.push({wallMs:Date.now()-started,state:structuredClone(state)});}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push('Probe '+e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));
  page.on('request',request=>{const url=request.url(),file=byName.get(decodeURIComponent(new URL(url).pathname).split('/').pop());
   if(file?.startsWith('Sounds/BattleRadioDSP/'))report.requests.push({path:file,wallMs:Date.now()-started});
  });page.on('response',response=>{if(response.status()>=400)report.httpFailures.push({status:response.status(),url:response.url()});});
  async function wait(fn,label,timeout=180000){const at=Date.now();let nextDump=0;while(!state||!fn(state)){
   if(closed)throw Error('Renderer closed during '+label);if(report.errors.length)throw Error(report.errors.join('\n'));
   if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
   if(Date.now()>nextDump){nextDump=Date.now()+200;await page.keyboard.press('F8');}await sleep(40);
  }return state;}
  async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'fresh F8',15000);}
  async function unlocked(label){
   await wait(s=>!s.pointer?.captured&&!s.pointer?.pending,label+' Lua pointer released',15000);
   if(!test.touch)await page.waitForFunction(()=>document.pointerLockElement===null,null,{timeout:15000});
  }
  async function captured(label){
   await wait(s=>s.pointer?.captured&&!s.pointer?.pending&&s.pointer?.ready,label+' Lua input ready',15000);
   if(!test.touch)await page.waitForFunction(()=>document.pointerLockElement!==null,null,{timeout:15000});
   report.interactions.push({wallMs:Date.now()-started,label,pointer:structuredClone(state.pointer),domLocked:await page.evaluate(()=>!!document.pointerLockElement)});
  }
  async function tapRect(rect,label){
   assert(onScreen(state,rect),'visible actionable rectangle');
   const x=(rect[0]+rect[2]/2)/state.width*test.width,y=(rect[1]+rect[3]/2)/state.height*test.height;
   if(test.touch){await page.touchscreen.tap(x,y);await dump();return;}
   // Lua capture flags change before the browser's asynchronous unlock finishes.
   await unlocked(label);await page.mouse.move(x,y);
   await dump();await wait(s=>cursorAt(s,rect),label+' engine cursor reaches rectangle',15000);
   report.interactions.push({wallMs:Date.now()-started,label,rect:[...rect],css:{x,y},mouse:structuredClone(state.mouse),pointer:state.pointer,domLocked:await page.evaluate(()=>!!document.pointerLockElement)});
   await page.mouse.click(x,y);await dump();
  }
  async function clickRect(getter,label){await wait(s=>onScreen(s,getter(s)),label+' visible layout',15000);await tapRect(getter(state),label);}
  async function widget(text){await wait(s=>publicWidget(s,text),'public widget '+text,15000);await tapRect(publicWidget(state,text).rect,text);}
  async function shot(name){await page.screenshot({path:path.join(out,name+'.png'),timeout:10000});}
  async function restoreVolume(){
   if(originalLevel===undefined||volumeRestored||!state.audioSettings?.open)return;
   await clickRect(s=>s.audioSettings?.rects?.voice,'voice slider');await page.keyboard.press('Home');
   for(let i=0;i<Math.round(originalLevel*100);i++)await page.keyboard.press('ArrowRight');
   await dump();check(Math.abs(state.audioSettings.levels.voice-originalLevel)<.001,'public slider restores original saved voice setting');volumeRestored=true;
  }
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
  await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow?.active,'hall');
  check(report.requests.length===0,'hall does not download the full battle radio library');
  await widget('出战');await wait(s=>s.tab==='battle','mode picker');await widget('歼灭战');await widget('开始匹配');
  await wait(s=>s.loadingFlow?.match?.stage==='queue'||s.loadingFlow?.match?.stage==='roster','public matchmaking');
  await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow?.active,'production battle',300000);
  report.timings.push({stage:'battle-ready',ms:Date.now()-started});check(state.map==='crater'&&state.battle.mode==='elimination','real crater elimination match');
  // The cinematic pauses simulation; roundPrep is dispatched by AfterStep.
  if(state.intro?.active){await page.keyboard.press('Space');await wait(s=>!s.intro?.active,'public cinematic skip');}
  if(test.touch)await page.touchscreen.tap(test.width*.5,test.height*.5);else await page.mouse.click(test.width*.5,test.height*.5);
  await wait(s=>s.pointer?.captured,'actual input capture');
  if(!test.touch)check(await page.evaluate(()=>!!document.pointerLockElement),'actual browser pointer lock');
  await wait(s=>radioOf(s)&&(radioOf(s).pending||probeList(radioOf(s).jobs,'jobs').length),'on-demand radio preparation',30000);
  validateRadio(state);await wait(s=>radioOf(s)?.ready&&voicePlaying(s).length>0,'processed voice stem reaches real SoundSource playback',60000);
  const first=structuredClone(state);validateRadio(first);
  const firstRequests=[...new Set(report.requests.map(r=>r.path))];
  check(firstRequests.length<=4,'first spoken line downloads at most four processed stems');
  check(probeList(radioOf(first).loading,'loading').length<=4,'first line has at most four background decode jobs');
  check(radioOf(first).speaking===true,'playing radio owns the shared speaking state');
  check(gainMatches(first,first.audioSettings.levels.voice),'processed audio gain applies voice setting once');
  await shot('first-radio');
  await wait(s=>s.battle?.state==='live','real countdown reaches live battle',30000);await shot('live');
  check(report.samples.some(x=>x.state.battle.state==='prep')&&report.samples.some(x=>x.state.battle.state==='live'),'observed prep to live without completion injection');
  if(process.env.VOX_QA_RADIO_VOLUME!=='0'){
   await page.keyboard.press('Escape');await unlocked('release for settings');await widget('设置');
   await clickRect(s=>s.pauseMenu?.rows?.audio?.rect,'shared audio settings');await wait(s=>s.audioSettings?.open,'public audio settings');
   report.volume.attempted=true;originalLevel=state.audioSettings.levels.voice;
   const beforePlaying=voicePlaying(state).map(j=>j.path);await clickRect(s=>s.audioSettings?.rects?.voice,'voice slider');await page.keyboard.press('End');await dump();
   check(state.audioSettings.levels.voice===1,'public voice slider applies maximum setting');
   const retained=voicePlaying(state).filter(j=>beforePlaying.includes(j.path));
   if(retained.length){check(retained.every(j=>Math.abs(j.gain-.28/.6)<.003),'already playing stems update voice gain immediately');report.volume.liveGainChanged=true;}
   else report.volume.boundary='No stem remained active across the public settings interaction; saved setting changed, live rescaling remains unobserved.';
   await restoreVolume();await shot('audio-settings');await clickRect(s=>s.audioSettings?.rects?.done,'audio return button');await clickRect(s=>s.pauseMenu?.rows?.resume?.rect,'shared settings resume');await wait(s=>!s.pauseMenu,'public resume');
  }
  await captured('live input before exit');
  await page.keyboard.press('Escape');await dump();await unlocked('release for exit');
  await widget('退出对局');await wait(s=>s.battle?.leaveConfirm||s.mode==='hangar','public leave confirmation');
  if(state.mode!=='hangar'){await widget('确定');}
  await wait(s=>s.mode==='hangar'&&!s.loadingFlow?.active,'normal battle return',60000);await dump();
  check(!state.battle,'normal return removes battle and radio ownership');check(!state.audioSettings?.introAudioTail?.active,'no intro tail remains after return');
  check(state.performance.arrayBytes===0,'normal return releases terrain arrays');
  check(report.errors.length===0,'no runtime or probe errors');check(report.httpFailures.length===0,'no HTTP resource failures');
  report.result='PASS';report.final=state;await shot('returned');
 }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;if(page&&!closed)await page.screenshot({path:path.join(out,'failure.png'),timeout:10000}).catch(()=>{});throw error;}
 finally{if(originalLevel!==undefined&&!volumeRestored)report.volume.restorePending=true;if(page&&!closed)await page.close();await browser.close();report.shutdown='CLOSED';fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,checks:report.checks.length,samples:report.samples.length,liveGainChanged:report.volume.liveGainChanged,out}));}
}
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run().catch(e=>{console.error(e);process.exitCode=1;});}
module.exports={validateRadio,gainMatches,playing,voicePlaying,probeList,publicWidget,validRect,cursorAt};
