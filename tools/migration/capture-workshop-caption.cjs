// Compare the actual frozen H5 Web Animations against the running WASM page.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');
  fs.createReadStream(file).pipe(res);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={baseline:{branch:baseline.branch,commit:baseline.commit},build:prepared.source_directory,cases:[]};
 try{
  for(const [name,width,height,touch] of [['pc',1920,1080,false],['phone-landscape',840,378,true]]){
   const options={viewport:{width,height},deviceScaleFactor:touch?3:1,isMobile:touch,hasTouch:touch};
   const source=await browser.newPage(options);
   await source.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await source.waitForFunction(()=>window.__vox,{},{timeout:120000});await source.evaluate(()=>document.fonts.ready);
   await source.locator('.home-tabs [data-tab="workshop"]').click();await delay(1500);
   await source.evaluate(()=>{
    const ws=window.__vox.shell.home.ws;clearInterval(ws.heroTimer);ws.view('feature');ws._hero(1,true);clearInterval(ws.heroTimer);
    const elements=[...document.querySelector('#home .wsh-cap').children];
    window.__captionAnimations=elements.map(element=>{
     const animations=element.getAnimations().filter(a=>a.effect.target===element);
     const animation=animations[animations.length-1];animation.pause();return animation;
    });
    window.__shelfAnimations=[...document.querySelectorAll('#home .wsh-row > *, #home .wsh-hacts > *')].map(element=>{
     const animations=element.getAnimations().filter(a=>a.effect.target===element);
     const animation=animations[animations.length-1];animation.pause();return animation;
    });
   });
   let state;const errors=[],httpErrors=[];
   const target=await browser.newPage(options);
   target.on('console',msg=>{const line=msg.text(),i=line.indexOf('OUTGAME_STATE ');if(i>=0)try{state=JSON.parse(line.slice(i+14));}catch(e){errors.push(e.message);}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))errors.push(line);
   });
   target.on('pageerror',e=>errors.push(e.message));target.on('requestfailed',r=>errors.push(r.url()+' '+r.failure()?.errorText));
   target.on('response',r=>{if(r.status()>=400)httpErrors.push({url:r.url(),status:r.status()});});
   async function wait(predicate,label,timeout=240000){const started=Date.now();while(!state||!predicate(state)){if(Date.now()-started>timeout)throw Error(name+' timeout '+label);await delay(100);}}
   async function dump(){state=undefined;await target.keyboard.press('F8',{delay:80});await wait(()=>true,'probe');}
   async function click(text){await dump();const widget=state.widgets.find(w=>w.text===text&&!w.disabled);assert.ok(widget,text+' is clickable');const [x,y,w,h]=widget.rect,box=await target.locator('canvas').boundingBox();const px=box.x+(x+w/2)*box.width/state.width,py=box.y+(y+h/2)*box.height/state.height;if(touch)await target.touchscreen.tap(px,py);else await target.mouse.click(px,py);}
   await target.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar','home');await click('创意工坊');await wait(s=>s.workshop?.view==='feature','workshop');
   await target.mouse.move(width-4,height-4);await target.keyboard.press('ArrowRight',{delay:80});
   await wait(s=>s.workshop?.selected==='fox'&&!s.workshop.pending,'fox art');
   const samples=[];
   for(const time of [.08,.3,.46,.62]){
    const expected=await source.evaluate(time=>{
     return window.__captionAnimations.map(a=>{
      a.currentTime=time*1000;const style=getComputedStyle(a.effect.target),timing=a.effect.getTiming();
      return {opacity:Number(style.opacity),translateX:parseFloat(style.translate)||0,timing:{delay:timing.delay,duration:timing.duration,easing:timing.easing}};
     });
    },time);
    await target.keyboard.press('F12',{delay:80});await delay(250);await dump();
    const actual=state.workshop.caption;assert.equal(actual.elapsed,Math.min(.46,time));
    expected.forEach((group,i)=>{
     assert.ok(Math.abs(group.opacity-actual.groups[i].opacity)<.0001,'Source opacity '+i+' at '+time);
     assert.ok(Math.abs(group.translateX-actual.groups[i].translateX)<.005,'Source translation '+i+' at '+time);
    });
    const shelfExpected=await source.evaluate(time=>window.__shelfAnimations.map(a=>{
     a.currentTime=time*1000;const style=getComputedStyle(a.effect.target),timing=a.effect.getTiming();
     return {opacity:Number(style.opacity),translateY:parseFloat(style.translate.split(' ')[1])||0,timing:{delay:timing.delay,duration:timing.duration,easing:timing.easing}};
    }),time);
    const shelfActual=state.workshop.shelf;assert.equal(shelfActual.elapsed,time);assert.equal(shelfExpected.length,9);
    shelfExpected.forEach((group,i)=>{
     assert.ok(Math.abs(group.opacity-shelfActual.groups[i].opacity)<.0001,'Source shelf opacity '+i+' at '+time);
     assert.ok(Math.abs(group.translateY-shelfActual.groups[i].translateY)<.005,'Source shelf translation '+i+' at '+time);
    });
    const action=state.widgets.find(w=>w.kind==='view');assert.ok(action,'Real action remains mounted');
    await source.screenshot({path:path.join(out,'workshop-caption-source-'+name+'-'+time+'.png')});
    await target.screenshot({path:path.join(out,'workshop-caption-web-'+name+'-'+time+'.png')});
    samples.push({time,expected,actual,shelfExpected,shelfActual,action});
   }
   const headerExpected=await source.evaluate(()=>[...document.querySelectorAll('#home .wsh-hacts > button')].map(button=>{
    const label=button.querySelector(':scope > span'),count=button.querySelector(':scope > b'),arrow=button.classList.contains('wsh-all')&&button.querySelector(':scope > svg');
    const rect=button.getBoundingClientRect(),scale=rect.width/parseFloat(getComputedStyle(button).width);
    const relative=element=>{const r=element.getBoundingClientRect();return {x:(r.x-rect.x)/scale,y:(r.y-rect.y)/scale,w:r.width/scale,h:r.height/scale};};
    const style=getComputedStyle(label);
    return {text:label.textContent,size:parseFloat(style.fontSize),spacing:parseFloat(style.letterSpacing),color:style.color,label:relative(label),
     count:count?{...relative(count),size:parseFloat(getComputedStyle(count).fontSize),spacing:parseFloat(getComputedStyle(count).letterSpacing)}:null,
     arrow:arrow?relative(arrow):null};
   }));
   const headerActual=headerExpected.map(expected=>{
    const widget=state.widgets.find(w=>w.text===expected.text&&w.shelfContent),actual=widget?.shelfContent;assert.ok(actual,expected.text+' content');
    assert.equal(actual.size,expected.size);assert.equal(actual.spacing,expected.spacing);
    assert.equal('rgb('+actual.color.slice(0,3).join(', ')+')',expected.color);
    assert.ok(Math.abs(actual.width-expected.label.w)<.05,expected.text+' measured label width');
    assert.ok(Math.abs(actual.x-expected.label.x)<.05,expected.text+' original label offset');
    assert.ok(Math.abs(actual.y-expected.label.y)<1.1,expected.text+' source vertical pixel snapping');
    if(expected.count){
     assert.equal(actual.count.size,expected.count.size);assert.equal(actual.count.spacing,expected.count.spacing);
     for(const key of ['x','y','w','h'])assert.ok(Math.abs(actual.count[key]-expected.count[key])<1.1,'Count source '+key);
     assert.ok(actual.x+actual.width<actual.count.x,'Label and source count do not overlap');
     for(const key of ['x','y','w','h'])assert.ok(Math.abs(actual.arrow[key]-expected.arrow[key])<1.1,'Arrow source '+key);
    }
    return actual;
   });
   await target.keyboard.press('F12',{delay:80});
   await source.locator('#home .wsh-all').click();assert.equal(await source.evaluate(()=>window.__vox.shell.home.ws.pane.dataset.view),'browse');
   await click('查看全部');await wait(s=>s.workshop?.view==='browse','transformed shelf action click');
   await target.keyboard.press('Backspace',{delay:80});await wait(s=>s.workshop?.view==='feature','feature return');await delay(700);
   await click('查看详情');await wait(s=>s.workshop?.view==='detail','transformed action click');
   assert.equal(errors.length,0,errors.join('\n'));
   report.cases.push({name,viewport:[width,height],samples,headerExpected,headerActual,errors,httpErrors,actionClick:true,shelfActionClick:true});
   await source.close();await target.close();console.log(name+' caption and shelf opacity, translation and clicks PASS');
  }
  fs.writeFileSync(path.join(out,'workshop-caption-parity.json'),JSON.stringify(report,null,2));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
