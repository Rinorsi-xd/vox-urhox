const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))),source=baseline.snapshot;
(async()=>{
 const links=fs.readFileSync(path.join(source,'three/index.html'),'utf8').match(/<link rel="stylesheet"[^>]+>/g).join('\n').replaceAll('../shared/','/shared/');
 const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://local');
  if(url.pathname==='/fixture.html'){res.setHeader('Content-Type','text/html');return res.end('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+links+'<script type="importmap">{"imports":{"@shared/":"/shared/"}}</script><body class="screen-drive"><div id="ui"></div>');}
  const file=path.resolve(source,'.'+decodeURIComponent(url.pathname));if(!file.startsWith(source+path.sep)||!fs.existsSync(file))return res.writeHead(404).end();
  res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'application/octet-stream');res.end(fs.readFileSync(file));
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:'chrome'});
 const report={baseline:baseline.commit,fixture:'actual frozen MatchHud.result with production stylesheet cascade and UiScaling',layouts:[]};
 try{for(const viewport of [{width:1920,height:1080},{width:840,height:378},{width:800,height:450},{width:1024,height:768}]){
  const page=await browser.newPage({viewport});await page.goto('http://127.0.0.1:'+server.address().port+'/fixture.html');
  await page.evaluate(async()=>{
   const {MatchHud}=await import('/shared/ui/matchHud.js');const {installUiScaling}=await import('/shared/ui/uiScale.js');installUiScaling();
   const rows=Array.from({length:6},(_,i)=>({name:i===0?'你':'机修师 '+i,member:{level:i+1,role:'heavy',avatar:i===0?'me':'a02'},team:i<3?'blue':'red',me:i===0,dead:false,rating:1000,kills:i===0?12:0,assists:i===0?5:0,deaths:1,damage:i===0?28640:0}));
   const hud=new MatchHud({mode:{id:'elimination',name:'歼灭战',en:'ELIMINATION',size:3,winRounds:2},roster:{blue:[],red:[]}});
   window.matchFixture={hud,rows};
   hud.result({winner:'blue',score:{blue:2,red:0},history:[{winner:'blue'},{winner:'blue'}],rows,mvp:rows[0],delta:16,xp:410,profile:{rating:1016,level:1}});await document.fonts.ready;
  });await page.waitForTimeout(500);
  const layout=await page.evaluate(()=>Object.fromEntries(['.mh-result','.mh-res-head','.mh-res-head b','.mh-teams','.mh-tsec h3','.mh-row.hd','.mh-row.me','.mh-row .nm','.mh-res-foot','.gain','.mvpn','.home','.again','.mh-ai'].map(selector=>{
   const el=document.querySelector('#match-hud '+selector),r=el.getBoundingClientRect(),c=getComputedStyle(el);return [selector,{rect:[r.x,r.y,r.width,r.height],font:c.font,spacing:c.letterSpacing,background:c.background,shadow:c.boxShadow,grid:c.gridTemplateColumns,padding:c.padding}];
  })));
  await page.screenshot({path:path.join(root,'docs/migration/evidence/source-match-'+viewport.width+'x'+viewport.height+'.png')});
  await page.evaluate(()=>{const {hud,rows}=window.matchFixture;hud.$('.mh-result').classList.remove('on');hud.statOf=unit=>unit.stat;
   hud._board(rows.map(row=>({member:{...row.member,name:row.name,rating:row.rating,player:row.me},unit:{team:row.team,alive:!row.dead,name:row.name,stat:row}})),{mode:'elimination',round:2,sudden:true,score:{blue:1,red:0},timeLeft:59});hud.board(true);});
  await page.waitForTimeout(250);
  const board=await page.evaluate(()=>Object.fromEntries(['.mh-board','.mh-bh','.mh-bh .md','.mh-bh .md small','.mh-bh .sc','.mh-bh .tm','.mh-bh .tm b'].map(selector=>{
   const el=document.querySelector('#match-hud '+selector),r=el.getBoundingClientRect(),c=getComputedStyle(el);return [selector,{rect:[r.x,r.y,r.width,r.height],font:c.font,text:el.textContent}];
  })));
  report.layouts.push({viewport,layout,board});await page.screenshot({path:path.join(root,'docs/migration/evidence/source-board-'+viewport.width+'x'+viewport.height+'.png')});await page.close();
 }fs.writeFileSync(path.join(root,'docs/migration/evidence/source-match-ui.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report.layouts[0]));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
