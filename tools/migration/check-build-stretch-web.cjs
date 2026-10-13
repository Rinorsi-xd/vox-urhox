const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={buildDirectory:prepared.source_directory,manifest:prepared.manifest_path,cases:{},passed:false};
 try{
  for(const [name,width,height,touch] of [['pc',1920,1080,false],['phone-landscape',840,378,true],['tablet',1024,768,true]].filter(c=>!process.env.VOX_STRETCH_CASE||c[0]===process.env.VOX_STRETCH_CASE)){
   const page=await browser.newPage({viewport:{width,height},hasTouch:touch,deviceScaleFactor:touch?2:1});
   let state;const errors=[],httpErrors=[];const item=report.cases[name]={viewport:[width,height],errors,httpErrors,checks:0};
   let aimX=width*.5,aimY=height*.5;
   page.on('console',m=>{const t=m.text(),i=t.indexOf('OUTGAME_STATE ');if(i>=0)state=JSON.parse(t.slice(i+14));
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))errors.push(t);
   });page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)httpErrors.push({status:r.status(),url:r.url()});});
   async function wait(fn){const start=Date.now();while(!state||!fn(state)){if(errors.length)throw Error(errors.join('\n'));if(Date.now()-start>90000)throw Error(name+' stretch timeout');await delay(100);}}
   async function dump(){await page.keyboard.press('F8');await delay(350);assert.equal(errors.length,0);return structuredClone(state);}
   function check(value,message){if(!value)item.failureState=structuredClone(state);assert.ok(value,message);item.checks++;}
   async function chord(key){await page.keyboard.down('Control');await page.keyboard.down(key);await delay(180);await page.keyboard.up(key);await page.keyboard.up('Control');await delay(180);}
   async function rectClick(rect){const x=(rect[0]+rect[2]/2)*width/state.width,y=(rect[1]+rect[3]/2)*height/state.height;
    if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await delay(200);}
   async function click(){if(touch)await page.touchscreen.tap(aimX,aimY);else {await page.mouse.down();await delay(50);await page.mouse.up();}await delay(200);}
   async function shot(suffix){const png=await page.screenshot({path:path.join(out,`build-stretch-web-${name}-${suffix}.png`)});const stats=await sharp(png).stats();check(stats.channels.some(c=>c.stdev>15),'rendered nonblank '+suffix);}
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar');
   await dump();console.log(name+' source home ready');await rectClick(state.homeRects.edit);await wait(s=>s.build);await dump();
   item.initial=structuredClone(state);
   if(!touch){await page.mouse.move(width*.5,height*.5);await click();await dump();check(state.buildInput.captured,'actual playfield capture');}
   else check(state.buildInput.mode==='orbit'&&state.touch,'touch uses existing orbit input');
   await page.keyboard.press('1');
   if(touch){const button=state.widgets.find(w=>w.text==='拉伸');check(button,'source stretch dock button present');await rectClick(button.rect);}
   else await page.keyboard.press('j');
   await dump();check(state.buildInput.tool==='stretch','actual source stretch tool selected');
   if(touch){await page.mouse.move(width*.5,height*.5);await delay(200);await dump();}
   let mx=width*.5,my=height*.5;
   for(let i=0;i<28;i++){
    if(state.buildInput.preview?.ok)break;
    if(touch){aimX=width*(.4+.025*(i%7));aimY=height*(.55+.06*Math.floor(i/7));await page.mouse.move(aimX,aimY);await delay(100);}
    else{mx-=3;my+=2;await page.mouse.move(mx,my,{steps:2});await delay(60);}
    await dump();
   }
   check(state.buildInput.preview?.ok,'actual camera ray has attachable source cube preview');
   const before=state.parts,revision=state.buildSelection.revision,slot=state.buildInput.slot;
   await click();await dump();item.anchor=structuredClone(state);
   check(state.buildStretch?.phase==='rect'&&state.parts===before,'first click records rectangle without editing');
   if(!touch){await page.mouse.move(mx+20,my+12,{steps:8});await delay(200);await dump();}
   await shot('rectangle');await click();await dump();
   check(state.buildStretch?.phase==='height'&&state.parts===before,'second click records height without editing');
   await page.mouse.wheel(0,100);await delay(200);await dump();item.height=structuredClone(state);
   check(state.buildStretch.h>=1&&state.buildStretch.h<=48&&state.buildInput.slot===slot,'wheel adjusts height within source limit and keeps hotbar');
   await shot('height');
   // Return to a one-cell rectangle before commit, so the check does not depend
   // on accidental aim through a cannon's reserved clearance in the source car.
   if(!touch){await page.mouse.down({button:'right'});await delay(50);await page.mouse.up({button:'right'});await dump();check(state.buildStretch.phase==='rect','actual right click returns to rectangle');
    await page.mouse.down({button:'right'});await delay(50);await page.mouse.up({button:'right'});await dump();check(!state.buildStretch&&state.parts===before,'second right click cancels without editing');
    await page.mouse.move(mx,my,{steps:8});await delay(200);await dump();
    for(let i=0;i<20&&!state.buildInput.preview?.ok;i++){my-=2;await page.mouse.move(mx,my,{steps:2});await delay(100);await dump();}
    check(state.buildInput.preview?.ok,'restored camera ray offers a valid start');
    await click();await dump();check(state.buildStretch.phase==='rect','restart uses current real preview');
    await click();await dump();
   }
   for(let i=0;i<50&&state.buildStretch.h>1;i++){await page.mouse.wheel(0,-10000);await delay(100);await dump();}
   if(state.buildStretch.bad){await page.keyboard.press('Escape');await dump();check(!state.buildStretch&&state.parts===before,'invalid volume cancels atomically');}
   else{
    await click();await dump();item.commit=structuredClone(state);
    check(!state.buildStretch&&state.parts>before&&state.buildSelection.revision===revision+1,'confirmation adds entire rectangle as one command');
    const added=state.parts;await chord('z');await dump();check(state.parts===before,'one actual Ctrl+Z undoes entire rectangle');
    await chord('y');await dump();check(state.parts===added,'one actual Ctrl+Y restores entire rectangle');
    await chord('z');await dump();
   }
   await page.keyboard.press('Escape');await dump();
   if(state.buildInput.captured) {await page.keyboard.press('Escape');await dump();}
   item.final=structuredClone(state);check(!state.buildStretch&&state.parts===before,'exit leaves no transient plan or stray blocks');
   item.passed=true;console.log('Web stretch PASS '+name+' '+item.checks);await page.close();
  }
  report.passed=true;
 }catch(e){report.failure=e.message;throw e;}
 finally{fs.writeFileSync(path.join(out,'build-stretch-web.json'),JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
