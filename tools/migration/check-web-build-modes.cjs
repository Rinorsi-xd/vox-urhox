const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const source=JSON.parse(fs.readFileSync(path.join(out,'source-build-modes.json')));
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={commit:source.commit,buildDirectory:prepared.source_directory,manifest:prepared.manifest_path,cases:{},passed:false};
 try{
  for(const [name,width,height] of [['pc',1920,1080],['pc-16-10',1440,900],['phone-landscape',840,378],['tablet',1024,768]]){
   const page=await browser.newPage({viewport:{width,height}});let state;const errors=[],httpErrors=[];
   const item=report.cases[name]={viewport:[width,height],modes:{},errors,httpErrors};
   page.on('console',m=>{const t=m.text(),i=t.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(t.slice(i+14));}catch(e){errors.push('Invalid QA state: '+e.message);}}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))errors.push(t);
   });page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)httpErrors.push({status:r.status(),url:r.url()});});
   async function wait(fn){const start=Date.now();while(!state||!fn(state)){if(errors.length)throw Error(errors.join('\n'));if(Date.now()-start>120000)throw Error(name+' mode state timeout');await delay(100);}}
   async function dump(){await page.keyboard.press('F8');await delay(300);assert.ok(state);return structuredClone(state);}
   async function snapshot(mode){await delay(650);const s=await dump(),b=s.buildBadge,v=source.cases[name].modes[mode];item.modes[mode]=b;
    assert.ok(b,mode+' badge state');assert.equal(b.active,mode!=='build');assert.equal(b.opacity,mode==='build'?0:1);
    if(mode!=='build'){
     assert.equal(b.offset,0);assert.equal(b.popTime,.3);
     const scale=width/s.width;
     const actual=[b.rect[0]*scale,b.rect[1]*scale,b.rect[2]*scale,b.rect[3]*scale];
     b.cssRect=actual;assert.ok(actual.every((n,i)=>Math.abs(n-v.badge.rect[i])<=1.1),name+' '+mode+' source badge rectangle: '+JSON.stringify(actual)+' vs '+JSON.stringify(v.badge.rect));
     const png=await page.screenshot({path:path.join(out,'build-mode-web-'+name+'-'+mode+'.png')});
     const sample=await sharp(png).extract({left:Math.floor(actual[0]+6*scale),top:Math.floor(actual[1]+18*scale),width:1,height:1}).removeAlpha().raw().toBuffer();
     assert.ok([23,46,69].every((v,i)=>Math.abs(sample[i]-v)<=1),'mode badge blue surface pixels');
     if(s.buildInput.mode==='fp'){
      const center=await sharp(png).extract({left:width/2,top:height/2,width:1,height:1}).removeAlpha().raw().toBuffer();
      assert.ok(b.color.slice(0,3).every((v,i)=>Math.abs(center[i]-v)<=1),'actual tool crosshair color pixels');
     }
     const stats=await sharp(png).stats();assert.ok(stats.channels.slice(0,3).some(c=>c.stdev>15),'nonblank 3D composition');
    }
   }
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar');
   await dump();const r=state.homeRects.edit;await page.mouse.click((r[0]+r[2]/2)*width/state.width,(r[1]+r[3]/2)*height/state.height);await wait(s=>s.build);
   await page.keyboard.press('1');await snapshot('build');
   await page.keyboard.press('Alt+1');await page.keyboard.press('Tab');await snapshot('paint');
   await page.keyboard.press('Tab');await snapshot('accent');
   await page.keyboard.press('x');await snapshot('erase');
   await page.keyboard.press('Escape');await delay(300);await dump();assert.equal(state.dialog,false);assert.equal(state.buildInput.tool,'build');
   await page.keyboard.press('q');await snapshot('select');
   await page.keyboard.press('p');await delay(300);await dump();assert.equal(state.buildBadge.mode,'paint');
   await page.keyboard.press('Escape');await snapshot('build');
   await page.keyboard.press('Control+a');await page.keyboard.press('Control+c');await page.keyboard.press('Control+v');await snapshot('paste');
   await page.keyboard.press('Escape');await delay(300);await dump();assert.equal(state.dialog,false);assert.equal(state.buildBadge.active,false);
   await page.keyboard.press('Tab');await dump();if(state.buildInput.channel==='accent')await page.keyboard.press('Tab');await snapshot('paint');
   await page.keyboard.press('b');await wait(s=>s.inventory);await dump();assert.equal(state.build,true);await page.keyboard.press('b');await wait(s=>!s.inventory);
   await snapshot('paint');assert.equal(errors.length,0);item.passed=true;console.log('Build mode source parity PASS '+name);
   await page.close();
  }
  report.passed=true;
 }catch(e){report.failure=e.message;throw e;}
 finally{fs.writeFileSync(path.join(out,'build-modes-web.json'),JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
