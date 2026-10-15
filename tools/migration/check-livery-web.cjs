const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const source=JSON.parse(fs.readFileSync(path.join(out,'source-livery.json')));
const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'phone-16-9',width:800,height:450,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});let failed=false;
 try{for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  let state;const errors=[],checks=[],states=[];const logFile=path.join(out,'livery-web-'+test.name+'.log');fs.writeFileSync(logFile,'');
  page.on('console',m=>{const text=m.text();fs.appendFileSync(logFile,text+'\n');const i=text.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(text.slice(i+14));states.push(state);}catch{}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))errors.push(text);});
  page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>errors.push('NETWORK '+r.url()+' '+r.failure()?.errorText));
  async function wait(fn,label,ms=120000){const start=Date.now();let probe=start;while(!state||!fn(state)){if(Date.now()-start>ms)throw Error('Timeout '+label);if(Date.now()-probe>1000){probe=Date.now();await page.keyboard.down('F8');await sleep(70);await page.keyboard.up('F8');}await sleep(100);}return state;}
  async function dump(){const n=states.length;await page.keyboard.down('F8');await sleep(70);await page.keyboard.up('F8');await wait(()=>states.length>n,'probe',10000);return state;}
  const point=(x,y)=>[x*test.width/state.width,y*test.height/state.height];
  async function tap(x,y){const p=point(x,y);if(test.touch)await page.touchscreen.tap(...p);else await page.mouse.click(...p);await sleep(180);await dump();}
  async function click(text){await dump();const w=state.widgets.find(w=>w.text===text&&!w.disabled);assert.ok(w,'Live control '+text);await tap(w.rect[0]+w.rect[2]/2,w.rect[1]+w.rect[3]/2);}
  async function key(k){await page.keyboard.down(k);await sleep(100);await page.keyboard.up(k);await sleep(120);await dump();}
  const check=(c,message)=>{assert.ok(c,message);checks.push(message);};
  function rectMatch(name,cls,selected=false){const wanted=source.states[test.name+(selected?'-selected':'-empty')].elements.find(e=>e.class===cls).rect;
   check(state.livery.rects[name].every((v,i)=>Math.abs(v-wanted[i])<=1),'Original H5 bounds '+cls+' within native pixel rounding');}
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar','home');await click('涂装');await wait(s=>s.livery?.surfaces.length>0,'livery surface');await sleep(600);await dump();
   check(state.physical[0]/state.dpr===test.width&&state.physical[1]/state.dpr===test.height,'Actual landscape viewport and DPR');
   rectMatch('lib','lv-lib');rectMatch('props','lv-props');rectMatch('grid','lv-grid');rectMatch('layers','lv-layers');
   check(state.widgets.filter(w=>w.kind==='sticker').length===7,'Original seven character stickers');
   await page.screenshot({path:path.join(out,'livery-web-'+test.name+'-empty.png')});
   await click('图形');check(state.livery.group==='图形','Original graphic category');await click('爆炸框');check(state.livery.pick==='burst','Original sticker pick');
   const [x,y]=state.livery.surfaces[0];await tap(x,y);await wait(s=>s.livery?.meshes===1,'native projected decal');await dump();
   check(state.livery.count===1&&state.livery.selected===1&&!state.livery.pick,'Real surface click places and selects decal');
   check(state.livery.vertices>0&&state.livery.vertices%3===0,'Actual rendered native decal triangles');
   check(state.livery.propHeight===362.9375,'Original selected two-color properties');rectMatch('layers','lv-layers',true);
   await page.screenshot({path:path.join(out,'livery-web-'+test.name+'-selected.png')});
   await click('翻转');check(state.livery.list[0].f===1,'Original flip control');await click('翻转');check(!state.livery.list[0].f,'Flip restores original orientation');
   await click('左右对称');check(state.livery.count===2&&state.livery.list[0].m===state.livery.list[1].m,'Mirror control creates paired decal');
   await click('左右对称');check(state.livery.count===1&&!state.livery.list[0].m,'Mirror control removes paired decal');
   const slider=state.livery.rects.size;await tap(slider[0]+slider[2]*.4,slider[1]+slider[3]/2);
   check(state.livery.list[0].w>3,'Actual size slider edits native sticker width');
   await click('撤销');check(state.livery.list[0].w===3,'Slider edit participates in original undo');
   await click('复制');await wait(s=>s.livery.count===2,'duplicate');check(state.livery.count===2,'Duplicate button');
   await click('撤销');check(state.livery.count===1,'Undo button');await click('重做');check(state.livery.count===2,'Redo button');
   await click('全部撕掉');check(state.livery.count===0&&state.livery.meshes===0,'Clear removes native meshes');
   await click('撤销');check(state.livery.count===2,'Undo clear restores stickers');
   await click('完成');check(state.tab==='hangar'&&!state.livery,'Done saves and returns to hangar');
   await click('涂装');check(state.livery.count===2,'Saved decals survive page reentry');
   await click('全部撕掉');await click('完成');
  }catch(e){errors.push(e.stack||e.message);await page.screenshot({path:path.join(out,'livery-web-'+test.name+'-failure.png')});}
  fs.writeFileSync(path.join(out,'livery-web-'+test.name+'.json'),JSON.stringify({result:errors.length?'FAIL':'PASS',build:{directory:prepared.source_directory,manifest:path.basename(prepared.manifest_path)},test,checks,errors,states},null,2));
  console.log(test.name+': '+checks.length+' checks; '+errors.length+' errors');if(errors.length)failed=true;await page.close();
 }}finally{await browser.close();}if(failed)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
