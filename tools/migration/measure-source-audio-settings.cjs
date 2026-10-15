// Execute the frozen public settings method with its real UI/CSS and UI scaling.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const snapshot=path.resolve(root,baseline.snapshot);
const pause=process.argv.includes('--pause');
const index=fs.readFileSync(path.join(snapshot,'three/index.html'),'utf8');
const styles=[...index.matchAll(/<link rel="stylesheet" href="([^\"]+)"/g)].map(m=>m[1].replace('../','/'));
const html=`<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
${styles.map(href=>'<link rel="stylesheet" href="'+href+'">').join('')}
<script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","three/addons/":"/three/vendor/three/addons/"}}</script>
<body class="screen-home"><div id="ui"><div id="modal"></div><div id="help"></div></div>
<script type="module">
import {UI} from '/shared/ui/ui.js';
import {GameMusic} from '/shared/audio/gameMusic.js';
import {installUiScaling} from '/shared/ui/uiScale.js';
installUiScaling();
const ui=new UI({});ui.modal=document.querySelector('#modal');
const player={enabled:true,volume:.75,userPaused:false,snapshot(){return {enabled:this.enabled,volume:this.volume,userPaused:this.userPaused,title:'工坊地板'};},setPaused(value){this.userPaused=value;},setEnabled(value){this.enabled=value;},setVolume(value){this.volume=value;},next(){}};
const game={player,ui,shell:{},_refreshHomeMusic(){},_refresh:GameMusic.prototype._refresh};
if(${pause}){
 const {Shell}=await import('/shared/ui/shell.js');
 const screen=new URLSearchParams(location.search).get('screen')||'home';
 document.body.className='screen-'+screen;
 Shell.prototype.pauseMenu.call({ui,screen,editor:{save(){}},tutorial:{start(){}},onAudioSettings(){},go(){},touch:{openSettings(){}}});
}else GameMusic.prototype.openSettings.call(game);
await document.fonts.ready;
window.sourceFixture={game,ui};window.ready=true;
</script>`;
const output=path.join(root,'docs/migration/evidence/source-'+(pause?'pause-menu':'audio-settings')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(output,{recursive:true});
const server=http.createServer((req,res)=>{
 const uri=new URL(req.url,'http://localhost').pathname;
 if(uri==='/'){res.setHeader('Content-Type','text/html;charset=utf-8');res.end(html);return;}
 const file=path.resolve(snapshot,'.'+decodeURIComponent(uri));
 if(!file.startsWith(snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return;}
 const relative=path.relative(snapshot,file).replaceAll('\\','/');
 const registered=baseline.files[relative],bytes=fs.readFileSync(file);
 if(!registered||crypto.createHash('sha256').update(bytes).digest('hex')!==registered.sha256){res.writeHead(409).end();return;}
 res.setHeader('Content-Type',({'.js':'text/javascript','.css':'text/css','.woff2':'font/woff2','.png':'image/png','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.end(bytes);
});
(async()=>{let browser;try{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 browser=await chromium.launch({headless:true,channel:'chrome'});
const report={baseline:baseline.commit,sourceContentSha256:baseline.contentSha256,scope:pause?'original public Shell.pauseMenu, real UI/CSS/scaling, backend callbacks fixture':'original public GameMusic.openSettings, real UI/CSS/scaling, player backend fixture',cases:[]};
 for(const viewport of [{width:1920,height:1080},{width:1440,height:900},{width:840,height:378}]){for(const screen of pause?['home','edit']:['home']){
  const context=await browser.newContext({viewport,hasTouch:viewport.width===840,isMobile:viewport.width===840,deviceScaleFactor:1});
  const page=await context.newPage();const errors=[];page.on('pageerror',error=>errors.push(String(error)));
  await page.goto('http://127.0.0.1:'+server.address().port+'/?screen='+screen);await page.waitForFunction(()=>window.ready);await page.waitForTimeout(350);
  const metrics=await page.evaluate(()=>{
   const selector=['#modal .card','#modal h2','#modal h2 small','.gfx-row','.gfx-row > span','.gfx-row > b','.gfx-row input','.actions','[data-now-playing]','.actions button','.set-list button','.set-list button b','.set-list button small','.set-list button > i'];
   return Object.fromEntries(selector.map(s=>[s,[...document.querySelectorAll(s)].map(e=>{const r=e.getBoundingClientRect(),c=getComputedStyle(e);return {text:e.textContent,rect:[r.x,r.y,r.width,r.height],font:c.fontFamily,fontSize:c.fontSize,lineHeight:c.lineHeight,color:c.color,background:c.backgroundColor,backgroundImage:c.backgroundImage,grid:c.gridTemplateColumns};})]));
  });
  await page.screenshot({path:path.join(output,viewport.width+'x'+viewport.height+(pause?'-'+screen:'')+'.png')});
  report.cases.push({viewport,screen,metrics,errors});await context.close();
 }}
 fs.writeFileSync(path.join(output,'result.json'),JSON.stringify(report,null,2));console.log(output);
 if(report.cases.some(c=>c.errors.length))process.exitCode=1;
}finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}})().catch(error=>{console.error(error);process.exitCode=1;});
