const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4204);
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const page=await browser.newPage({viewport:{width:1440,height:900}});let state,sequence=0;
 const prepared=await fetch(base+'/identity.json').then(r=>r.json());
 const tag=process.env.VOX_QA_TAG||new Date().toISOString().replaceAll(':','-').replaceAll('.','-');
 const evidence=name=>path.resolve('docs/migration/evidence/'+name+'-'+tag);
 const wheels=[],errors=[],probeErrors=[],report={identity:prepared,buildDirectory:prepared.source_directory,manifest:prepared.manifest_path};
 page.on('console',m=>{const t=m.text();let i=t.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(t.slice(i+14));sequence++;}catch(e){if(t.trimEnd().endsWith('}'))probeErrors.push(e.message);}}
  i=t.indexOf('OUTGAME_WHEEL ');if(i>=0)wheels.push(JSON.parse(t.slice(i+14)));
  if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))errors.push(t);
 });page.on('pageerror',e=>errors.push(e.message));
 async function wait(p){const start=Date.now();while(!state||!p(state)){if(errors.length)throw Error(errors.join('\n'));if(Date.now()-start>120000)throw Error('Camera state timeout');await delay(100);}}
 async function dump(){const before=sequence;await page.keyboard.down('F8');await delay(100);await page.keyboard.up('F8');await wait(()=>sequence>before);return JSON.parse(JSON.stringify(state));}
 async function click(text){await dump();const w=state.widgets.find(w=>w.text===text&&!w.disabled);assert.ok(w,'Clickable '+text);
  await page.mouse.click((w.rect[0]+w.rect[2]/2)*1440/state.width,(w.rect[1]+w.rect[3]/2)*900/state.height);await delay(400);}
 try{
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active);console.log('Camera QA: hall ready');
  await page.mouse.click(720,350);await delay(300);
  await page.keyboard.press('F9');await delay(1500);await page.mouse.move(720,350);await delay(400);
  report.before=await dump();await page.mouse.wheel(0,100);await delay(1000);report.out=await dump();
  await page.mouse.wheel(0,-100);await delay(1000);report.back=await dump();
  assert.ok(Math.abs(report.out.camera.desiredDist/report.before.camera.desiredDist-1.0012**100)<1e-7,'Web wheel matches source pixel zoom');
  assert.ok(Math.abs(report.back.camera.desiredDist-report.before.camera.desiredDist)<1e-7,'Reverse wheel returns to original distance');
  if(!process.env.VOX_WHEEL_ONLY){
   const r=state.homeRects.edit;console.log('Camera QA: enter build',state.width,state.height,r);
   await page.mouse.click((r[0]+r[2]/2)*1440/state.width,(r[1]+r[3]/2)*900/state.height);await wait(s=>s.build);console.log('Camera QA: build ready');
   await delay(600);report.build=await dump();
   await page.mouse.click(720,350);await delay(500);report.captured=await dump();
   await page.mouse.move(745,355,{steps:4});await page.mouse.move(775,370,{steps:4});await delay(300);report.look=await dump();
   await page.keyboard.down('w');await delay(350);await page.keyboard.up('w');await delay(300);report.move=await dump();
   await page.keyboard.press('Tab');await delay(300);report.tab=await dump();
   await page.mouse.wheel(0,100);await delay(300);report.paintWheel=await dump();
   await page.keyboard.press('Escape');await delay(300);report.escape=await dump();
   assert.equal(report.build.buildInput.mode,'fp');assert.equal(report.captured.buildInput.captured,true);
   assert.ok(report.look.camera.forward.some((v,i)=>Math.abs(v-report.captured.camera.forward[i])>.01),'Real pointer lock mouse changes view');
   assert.ok(report.move.camera.position.some((v,i)=>Math.abs(v-report.look.camera.position[i])>.1),'Held WASD moves free camera');
   assert.equal(report.tab.buildInput.tool,'paint');assert.equal(report.tab.buildInput.mode,'fp');
   assert.equal(report.paintWheel.buildInput.channel,report.tab.buildInput.channel);assert.notEqual(report.paintWheel.buildInput.color,report.tab.buildInput.color);
   assert.equal(report.escape.buildInput.captured,false);assert.equal(report.escape.dialog,false);assert.equal(errors.length,0);
   await delay(2000);await page.mouse.click(720,350);await delay(500);report.recapture=await dump();
   assert.equal(report.recapture.buildInput.captured,true,'real click after Esc recaptures the construction camera');
   assert.ok(await page.evaluate(()=>!!document.pointerLockElement),'re-capture owns genuine browser pointer lock');
   await page.keyboard.press('Escape');await delay(300);await dump();
   await page.screenshot({path:evidence('build-camera-web')+'.png'});
   await click('机库');await wait(s=>!s.build);
   await click('涂装');await wait(s=>s.livery);await delay(1000);await page.mouse.move(720,350);
   report.liveryBefore=await dump();await page.mouse.wheel(0,100);await delay(600);report.liveryOut=await dump();
   assert.ok(Math.abs(report.liveryOut.camera.desiredDist/report.liveryBefore.camera.desiredDist-1.0012**100)<1e-7,'Livery wheel uses source pixels');
   await page.mouse.wheel(0,-100);await delay(600);report.liveryBack=await dump();
   assert.ok(Math.abs(report.liveryBack.camera.desiredDist-report.liveryBefore.camera.desiredDist)<1e-7,'Livery wheel reverses');
   await click('创意工坊');await wait(s=>s.workshop?.view==='feature');await delay(800);
   await page.keyboard.press('F4');await wait(s=>s.workshop?.selected==='megaMech'&&s.preview?.complete);await delay(1800);
   report.mega=await dump();const p=report.mega.camera.position;
   assert.ok(p[0]>=-28.16&&p[0]<=28.16&&p[1]>=.64&&p[1]<=29.66&&p[2]>=-32.16&&p[2]<=34.16,'Actual MEGA preview stays clear of room walls');
   await page.screenshot({path:evidence('mega-camera-web')+'.png'});
   assert.equal(errors.length,0);
  }
  assert.equal(probeErrors.length,0,'complete QA state messages parse without errors');report.passed=true;
  console.log(JSON.stringify({passed:true,wheels,errors,zoom:[report.before.camera.desiredDist,report.out.camera.desiredDist,report.back.camera.desiredDist],
   build:report.build?.buildInput,mega:report.mega?.camera.position},null,2));
 }catch(error){report.passed=false;report.failure=error.message;throw error;}
 finally{report.wheels=wheels;report.errors=errors;report.probeErrors=probeErrors;fs.writeFileSync(evidence('web-camera-input')+'.json',JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
