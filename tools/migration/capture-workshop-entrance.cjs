// Compare browser-computed frozen H5 animations with the actual UrhoX widgets.
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
 const report={baseline:{branch:baseline.branch,commit:baseline.commit},build:prepared.source_directory,manifest:prepared.manifest_path,cases:[]};
 try{
  for(const [name,width,height,touch] of [['pc',1920,1080,false],['phone-landscape',840,378,true]]){
   const options={viewport:{width,height},deviceScaleFactor:touch?3:1,isMobile:touch,hasTouch:touch};
   const source=await browser.newPage(options),target=await browser.newPage(options);
   let state;const errors=[],httpErrors=[];
   target.on('console',msg=>{const line=msg.text(),i=line.indexOf('OUTGAME_STATE ');if(i>=0)state=JSON.parse(line.slice(i+14));
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))errors.push(line);
   });
   target.on('pageerror',e=>errors.push(e.message));target.on('requestfailed',r=>errors.push(r.url()+' '+r.failure()?.errorText));
   target.on('response',r=>{if(r.status()>=400)httpErrors.push({url:r.url(),status:r.status()});});
   async function wait(predicate,label,timeout=240000){const started=Date.now();while(!state||!predicate(state)){if(Date.now()-started>timeout)throw Error(name+' timeout '+label);await delay(100);}}
   async function dump(){state=undefined;await target.keyboard.press('F8',{delay:80});await wait(()=>true,'probe');}
   async function click(text,kind){await dump();const widget=state.widgets.find(w=>(kind?w.kind===kind:w.text===text)&&!w.disabled);assert.ok(widget,text+' is clickable');
    const [x,y,w,h]=widget.rect,box=await target.locator('canvas').boundingBox(),px=box.x+(x+w/2)*box.width/state.width,py=box.y+(y+h/2)*box.height/state.height;
    if(touch)await target.touchscreen.tap(px,py);else await target.mouse.click(px,py);
    await delay(100);await dump();
   }
   await source.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await source.waitForFunction(()=>window.__vox,{},{timeout:120000});await source.evaluate(()=>document.fonts.ready);
   await source.locator('.home-tabs [data-tab="workshop"]').click();await delay(900);
   await target.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar','home');await click('创意工坊');await wait(s=>s.workshop?.view==='feature','workshop');await delay(800);
   console.log(name+' current source and target loaded');
   const views=[];
   for(const kind of ['browse','grid','detail']){
    if(kind==='browse'){
     await source.locator('#home .wsh-all').click();await click('查看全部');await wait(s=>s.workshop?.view==='browse','browse');
    }else if(kind==='grid'){
     await source.locator('#home [data-wsg="mech"]').click();await click('机甲');await wait(s=>s.workshop?.group==='mech','mech filter');
    }else{
     await source.locator('#home [data-detail="scorpion"]').click();await click('蝎型战车');await wait(s=>s.workshop?.view==='detail','detail');
     await wait(s=>s.preview?.complete,'assembled detail');
    }
    await source.mouse.move(width-4,height-4);
    if(!touch)await target.mouse.move(width-4,height-4);
    await delay(650);
    await source.evaluate(kind=>{
     const ws=window.__vox.shell.home.ws;
     if(kind==='detail')ws.detail('scorpion','browse');else if(kind==='grid')ws._grid();else ws.view('browse');
     const selector=kind==='detail'?'.wsd-left > *':kind==='grid'?'.wsb-grid > *':'.wsb-top > *, .wsb-card, .wsb-foot';
     const scope='#home .wsv[data-view="'+(kind==='detail'?'detail':'browse')+'"] ';
     window.__entranceElements=[...document.querySelectorAll(scope+selector.split(', ').join(', '+scope))];
     window.__entranceAnimations=window.__entranceElements.map(element=>{
      const animations=element.getAnimations().filter(a=>a.effect.target===element&&a.effect.getTiming().duration===260);
      const animation=animations.at(-1);if(animation)animation.pause();return animation;
     });
     window.__fillAnimations=kind==='detail'?[...document.querySelectorAll('#home .wsd-bar > i em')].map(element=>{
      const animation=element.getAnimations()[0];animation.pause();return animation;
     }):[];
    },kind);
    const samples=[];
    for(const time of [.08,.3,.5,.74,.9]){
     const expected=await source.evaluate(time=>{
      const groups=window.__entranceElements.map((element,i)=>{
       const animation=window.__entranceAnimations[i];if(animation)animation.currentTime=time*1000;
       const style=getComputedStyle(element),values=style.translate==='none'?[0,0]:style.translate.split(' ').map(parseFloat);
       return {opacity:Number(style.opacity),translateX:values[0]||0,translateY:values[1]||0};
      });
      const fill=window.__fillAnimations.map(animation=>{
       animation.currentTime=Math.min(900,time*1000);
       const style=getComputedStyle(animation.effect.target),clip=style.clipPath,ratio=Number(style.getPropertyValue('--v'));
       const match=clip.match(/inset\(\S+ ([\d.]+)%/);
       if(!match)throw Error('Unparsed source clip-path: '+clip);
       return {progress:ratio?(1-Number(match[1])/100)/ratio:1,clip,ratio};
      });
      return {groups,fill};
     },time);
     await target.keyboard.press('F12',{delay:80});await delay(180);await dump();
     const actual=state.workshop.entrance;assert.equal(actual.kind,kind);
     const groups=kind==='grid'?actual.groups.slice(4):actual.groups;
     expected.groups.forEach((group,i)=>{
      for(const key of ['opacity','translateX','translateY'])assert.ok(Math.abs(group[key]-groups[i][key])<(key==='opacity'?.0001:.005),kind+' '+key+' group '+i+' at '+time);
     });
     for(const fill of expected.fill)assert.ok(Math.abs(fill.progress-actual.fill)<.0001,'Actual CSS wsdFill easing at '+time);
     const control=state.widgets.find(w=>kind==='detail'?w.kind==='go':kind==='browse'?w.kind==='back':w.text==='蝎型战车');
     const index=kind==='detail'?6:kind==='browse'?0:4;
     for(const key of ['opacity','translateX','translateY'])assert.equal(control.entrance[key],actual.groups[index][key],'Mounted widget receives '+key);
     if(time===.3||time===.9){
      await source.screenshot({path:path.join(out,'workshop-entrance-source-'+name+'-'+kind+'-'+time+'.png')});
      await target.screenshot({path:path.join(out,'workshop-entrance-web-'+name+'-'+kind+'-'+time+'.png')});
     }
     if(time===.9&&kind!=='detail'){
      const cardRects=await source.evaluate(()=>{
       const home=document.querySelector('#home'),r=home.getBoundingClientRect(),scale=r.width/parseFloat(getComputedStyle(home).width);
       return [...document.querySelectorAll('#home .wsb-grid [data-detail]')].map(card=>{
        const q=card.getBoundingClientRect(),title=card.querySelector('.wsb-info b');return {name:title.textContent,hero:card.classList.contains('hero'),titleSize:parseFloat(getComputedStyle(title).fontSize),rect:[(q.x-r.x)/scale,(q.y-r.y)/scale,q.width/scale,q.height/scale]};
       });
      });
      for(const card of cardRects){
       const actual=state.widgets.find(w=>w.text===card.name);assert.ok(actual,card.name+' mounted card');
       if(card.hero)assert.equal(actual.heroTitleSize,card.titleSize,'Source media query hero title');
       card.rect.forEach((v,i)=>assert.ok(Math.abs(v-actual.rect[i])<1.1,kind+' '+card.name+' original rectangle '+i+': '+v+' vs '+actual.rect[i]));
      }
      samples.push({cardRects});
      const tabs=await source.evaluate(()=>[...document.querySelectorAll('#home .wsb-tabs button')].map(button=>{
       const b=button.getBoundingClientRect(),scale=b.width/parseFloat(getComputedStyle(button).width),label=button.querySelector('b'),count=button.querySelector('i');
       const r=label.getBoundingClientRect(),c=count.getBoundingClientRect();
       return {text:label.textContent,width:parseFloat(getComputedStyle(button).width),height:parseFloat(getComputedStyle(button).height),size:parseFloat(getComputedStyle(label).fontSize),spacing:parseFloat(getComputedStyle(label).letterSpacing),label:{x:(r.x-b.x)/scale,y:(r.y-b.y)/scale,w:r.width/scale},count:{x:(c.x-b.x)/scale,y:(c.y-b.y)/scale,w:c.width/scale}};
      }));
      for(const tab of tabs){
       const widget=state.widgets.find(w=>w.kind==='tab'&&w.text===tab.text),actual=widget.tabContent;
       assert.equal(actual.size,tab.size);assert.equal(actual.spacing,tab.spacing);
       assert.ok(Math.abs(widget.styleWidth-tab.width)<.05,'Source tab width '+tab.text);
       assert.equal(widget.styleHeight,tab.height);
       for(const [a,b] of [[actual.x,tab.label.x],[actual.y,tab.label.y],[actual.width,tab.label.w],[actual.count.x,tab.count.x],[actual.count.y,tab.count.y],[actual.count.width,tab.count.w]])assert.ok(Math.abs(a-b)<1.1,'Original tab label/count '+tab.text);
      }
      samples.push({tabs});
     }
     samples.push({time,expected,actual,control});
    }
    await target.keyboard.press('F12',{delay:80});
    if(kind==='detail'){
     await click('','pager');await dump();assert.equal(state.workshop.selected,'empty','Previous vehicle uses original prefab order');
     assert.ok(state.workshop.entrance.elapsed<.9,'Changing detail restarts its entry and fill');
     await target.keyboard.press('Backspace',{delay:80});await wait(s=>s.workshop?.view==='browse','return to filtered browse');
     assert.equal(state.workshop.group,'mech','Returning preserves original filter');
    }
    views.push({kind,samples});
    console.log(name+' '+kind+' browser animation comparison PASS');
   }
   assert.equal(errors.length,0,errors.join('\n'));
   report.cases.push({name,viewport:[width,height],views,errors,httpErrors});
   await source.close();await target.close();console.log(name+' source browse, filter, detail entrance and fill PASS');
  }
  fs.writeFileSync(path.join(out,'workshop-entrance-parity.json'),JSON.stringify(report,null,2));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
