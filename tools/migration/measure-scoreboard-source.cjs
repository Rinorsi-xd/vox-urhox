// Isolated frozen DOM/CSS with software and hardware graphics disabled.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=require('../../docs/migration/outgame-baseline.json'),inputs={};
function bytes(name){const data=fs.readFileSync(path.resolve(baseline.snapshot,name));const sha=crypto.createHash('sha256').update(data).digest('hex');assert.equal(sha,baseline.files[name].sha256,name);inputs[name]=sha;return data;}
const js=bytes('shared/ui/matchHud.js').toString('utf8'),css=js.match(/const CSS = `([\s\S]*?)`;/)[1];
function inlineFonts(css){return css.replace(/url\("\.\.\/fonts\/([^"\)]+)"\)/g,(_,name)=>`url("data:font/woff2;base64,${bytes('shared/fonts/'+name).toString('base64')}")`);}
const base=inlineFonts(bytes('shared/css/style.css').toString('utf8')),tokens=inlineFonts(bytes('shared/css/new-ui-tokens.css').toString('utf8')),utility=bytes('shared/css/new-ui-utility.css').toString('utf8'),responsive=bytes('shared/css/new-ui-responsive.css').toString('utf8');
const code=js.replace(/^import .*;\r?\n/gm,'').replace(/export class /g,'class ');
const args=['--disable-gpu','--disable-webgl','--disable-webgl2','--disable-software-rasterizer'];
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args});try{
 const page=await browser.newPage();const cases=[];
 for(const [w,h]of [[1920,1080],[2400,1080],[960,540],[800,360],[1200,700]]){
  await page.setViewportSize({width:w,height:h});
  await page.setContent(`<!doctype html><html><head><style>${base}\n${tokens}\n${css}\n${utility}\n${responsive}</style></head><body><div id="match-hud"><button class="mh-leave"></button><div class="mh-board on"></div><div class="mh-result"></div></div></body></html>`);
  await page.addScriptTag({content:`const escapeHtml=s=>String(s),avatarUrl=()=>'';${code};window.Hud=MatchHud;`});
  await page.evaluate(async()=>{await document.fonts.load('700 24px VoxIndustrial');await document.fonts.load('700 22px VoxNum');await document.fonts.ready;});
  for(const over of [false,true]){
   const metrics=await page.evaluate(({over})=>{
    const hud=Object.assign(Object.create(Hud.prototype),{mode:{id:'conquest',name:'站点争夺',en:'CONQUEST',size:4},h:{}});
    hud.root=document.querySelector('#match-hud');hud.clearBanners=()=>{};hud.$=s=>hud.root.querySelector(s);
    const rows=[];for(const team of ['blue','red'])for(let i=0;i<4;i++)rows.push({team,name:'长名字工程师'+i,member:{avatar:'me',level:7,role:'heavy'},rating:1200,kills:2,assists:3,deaths:4,damage:123456,me:team==='blue'&&i===0});
    const units=rows.map(r=>({unit:{team:r.team,alive:true,name:r.name},member:r.member}));hud.statOf=()=>({kills:2,assists:3,deaths:4,damage:123456});
    if(over){hud.root.querySelector('.mh-board').classList.remove('on');hud.result({winner:'blue',score:{blue:50,red:40},history:[],rows,mvp:null,delta:5,xp:10,profile:{rating:1200,level:7}});}
    else{hud.root.querySelector('.mh-result').classList.remove('on');hud._board(units,{mode:'conquest',state:'live',round:1,half:1,timeLeft:120,score:{blue:50,red:40}});hud.root.querySelector('.mh-board').classList.add('on');}
    for(const a of document.getAnimations()){a.finish();}
    const el=hud.$(over?'.mh-result':'.mh-board'),rect=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,fontSize:s.fontSize,lineHeight:s.lineHeight,font:s.fontFamily,grid:s.gridTemplateColumns,padding:s.padding};};
    return {width:innerWidth,height:innerHeight,over,card:rect(el),scrollHeight:el.scrollHeight,scrollWidth:el.scrollWidth,maxHeight:getComputedStyle(el).maxHeight,
      head:rect(el.firstElementChild),headerChildren:[...el.firstElementChild.children].map(e=>({text:e.textContent,rect:rect(e),children:[...e.children].map(c=>({text:c.textContent,rect:rect(c)}))})),teams:rect(el.querySelector('.mh-teams')),team:rect(el.querySelector('.mh-tsec')),teamHeading:rect(el.querySelector('h3')),
      tableHead:rect(el.querySelector('.mh-row.hd')),row:rect(el.querySelector('.mh-row:not(.hd)')),avatar:rect(el.querySelector('.mh-row:not(.hd) .av')),
      name:rect(el.querySelector('.mh-row:not(.hd) .nm b')),small:rect(el.querySelector('.mh-row:not(.hd) .nm small')),damage:rect(el.querySelector('.dmg')),
      foot:over?rect(el.querySelector('.mh-res-foot')):null,button:over?rect(el.querySelector('.home')):null,ai:over?rect(el.querySelector('.mh-ai')):null,
      canvases:document.querySelectorAll('canvas').length};
   },{over});assert.equal(metrics.canvases,0);cases.push(metrics);
  }
 }
 const report={result:'PASS',browser:await browser.version(),args,source:{branch:baseline.branch,commit:baseline.commit,inputs},cases,
 boundary:'Actual frozen CSS cascade and original MatchHud _board/result DOM with vendor fonts in GPU-disabled isolated Chrome. No game, engine, WebGL, rendered parity or performance acceptance.'};
 fs.writeFileSync(path.join(root,'docs/migration/evidence/scoreboard-source-dom.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({result:report.result,cases:cases.map(c=>({w:c.width,h:c.height,over:c.over,card:c.card,scrollHeight:c.scrollHeight,head:c.head.h,team:c.team.h,row:c.row.h,name:c.name.fontSize,foot:c.foot?.h}))},null,2));
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
