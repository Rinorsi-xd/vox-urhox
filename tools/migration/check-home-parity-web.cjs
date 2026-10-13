// Geometry comes from the frozen H5 DOM; clicks use the actual WASM widget tree.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const source=JSON.parse(fs.readFileSync(path.join(out,'home-parity-source.json')));
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  for(const test of source.cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
   const [width,height]=test.viewport,touch=test.name.startsWith('phone')||test.name==='tablet';
   const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:touch?3:1,hasTouch:touch,isMobile:touch});
   let state;const states=[],errors=[],checks=[];const log=path.join(out,'home-parity-web-'+test.name+'.log');fs.writeFileSync(log,'');
   page.on('console',msg=>{
    const text=msg.text();fs.appendFileSync(log,text+'\n');
    const index=text.indexOf('OUTGAME_STATE ');
    if(index>=0){try{state=JSON.parse(text.slice(index+14));states.push(state);}catch(e){errors.push('Incomplete probe: '+e.message);}}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))errors.push(text);
   });
   page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>errors.push(r.url()+' '+r.failure()?.errorText));
   async function wait(predicate,label,timeout=240000){const started=Date.now();while(!state||!predicate(state)){if(Date.now()-started>timeout)throw Error(test.name+' timeout '+label);await sleep(100);}return state;}
   async function dump(){const count=states.length;await page.keyboard.press('F8',{delay:100});return wait(()=>states.length>count,'probe',10000);}
   async function click(text){await dump();const widget=state.widgets.find(w=>w.text===text&&!w.disabled);assert.ok(widget,'Live command '+text);const [x,y,w,h]=widget.rect,canvas=await page.locator('canvas').boundingBox();const px=canvas.x+(x+w/2)/state.width*canvas.width,py=canvas.y+(y+h/2)/state.height*canvas.height;if(touch)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await sleep(350);await dump();checks.push('Clicked '+text);}
   function bounds(nodes,keys){
    for(const key of keys){const expected=nodes[key].rect,actual=state.homeRects[key];assert.ok(actual,'Live rectangle '+key);
     const tolerance=Math.max(.51,state.width/state.physical[0]+.05);
     actual.forEach((v,i)=>assert.ok(Math.abs(v-expected[i])<=tolerance,`${test.name} ${key}[${i}] ${v} != H5 ${expected[i]}`));checks.push(key+' matches source DOM');
    }
   }
   let report;
   try{
    await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
    await wait(s=>s.tab==='hangar','home');await sleep(5000);await dump();
    assert.ok(Math.abs(state.width-test.home.width)<1&&Math.abs(state.height-test.home.height)<1,'Source reference canvas');
    bounds(test.home.nodes,['nav','info','loadout','cta','edit','battle','trial','mode','strip','card','new','save','music']);
    await page.mouse.move(width-4,height-4);await page.screenshot({path:path.join(out,'home-parity-web-'+test.name+'.png')});const home=state;
    await click('新战车');bounds(test.menu.nodes,['menu','menuHeader','menuEmpty','menuImport','menuWorkshop']);
    await page.mouse.move(width-4,height-4);await page.screenshot({path:path.join(out,'home-parity-web-'+test.name+'-menu.png')});const menu=state;
    if(!touch){
     const [x,y,w,h]=state.homeRects.menuEmpty,canvas=await page.locator('canvas').boundingBox();
     await page.mouse.move(canvas.x+(x+w/2)/state.width*canvas.width,canvas.y+(y+h/2)/state.height*canvas.height);
     await sleep(350);await dump();
     assert.ok(state.menuVisuals.empty.hovered&&state.menuVisuals.empty.hover===1&&state.menuVisuals.empty.bar===1&&state.menuVisuals.empty.arrow===1,'Source hover transitions settle');
     for(const [key,parts] of Object.entries(test.menuHover))for(const [part,expected] of Object.entries(parts)){
      const actual=state.menuVisuals[key].layout[part],tolerance=Math.max(.51,state.width/state.physical[0]+.05);
      assert.ok(actual,'Source menu part '+key+'.'+part);
      actual.forEach((v,i)=>assert.ok(Math.abs(v-expected.rect[i])<=tolerance,`${test.name} ${key}.${part}[${i}] ${v} != H5 ${expected.rect[i]}`));
      checks.push(key+'.'+part+' matches source DOM');
     }
     await page.screenshot({path:path.join(out,'home-parity-web-'+test.name+'-menu-hover.png')});
    }
    await click('导入蓝图');assert.ok(state.widgets.some(w=>w.text==='导入'),'Import opens source dialog');
    await click('取消');await click('出战');await wait(s=>s.tab==='battle','mode page');
    assert.ok(!state.widgets.some(w=>w.text==='改装'&&w.kind==='cta-left'),'Home CTA hidden on mode page');
    await click('机库');await wait(s=>s.tab==='hangar','return');
    assert.equal(errors.length,0,errors.join('\n'));
    report={result:'PASS',baseline:source.baseline,build:prepared.source_directory,viewport:test.viewport,touch,checks,errors,home,menu};
   }catch(e){report={result:'FAIL',baseline:source.baseline,build:prepared.source_directory,viewport:test.viewport,checks,errors,failure:e.message,state};await page.screenshot({path:path.join(out,'home-parity-web-'+test.name+'-failure.png')});}
   fs.writeFileSync(path.join(out,'home-parity-web-'+test.name+'.json'),JSON.stringify(report,null,2));
   await page.close();console.log(test.name+' '+report.result+' '+checks.length+' checks');if(report.result!=='PASS')throw Error(report.failure);
  }
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
