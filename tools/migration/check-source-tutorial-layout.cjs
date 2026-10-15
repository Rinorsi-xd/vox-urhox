// Render the frozen H5 CSS and markup without booting or changing the H5 game.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const snapshot=path.resolve(baseline.snapshot),out=path.join(root,'docs/migration/evidence');
const source=fs.readFileSync(path.join(snapshot,'shared/ui/nonoComms.js'),'utf8');
const markup=source.match(/el\.innerHTML = `([\s\S]*?)`;/)[1];
const html=`<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/shared/css/style.css"><link rel="stylesheet" href="/shared/css/new-ui-tokens.css"><link rel="stylesheet" href="/shared/css/storyHud.css"><link rel="stylesheet" href="/shared/css/tutorial.css">
<style>body{background:#080f1c}#tutorial .tu-card{transform:translate(630px,500px)}</style>
<div id="tutorial" class="on sh-scope"><div class="tu-card"><div class="sh-comms on nono">${markup}</div><div class="tu-hint on"></div><div class="tu-ctl"><span class="tu-step"><b>04</b> / 04 · 先做哪件事</span><span class="tu-wait"><i></i>等你操作</span><span class="tu-picks"><button class="tu-pick">先学改车</button><button class="tu-pick">先上前线</button></span><button class="tu-skip">跳过引导</button></div></div></div>
<script type="module">import {TUTORIAL} from '/shared/story/tutorial.js';import {mechFrame} from '/shared/ui/mechFrame.js';
const s=TUTORIAL.find(s=>s.id==='choose');document.querySelector('.sh-cbox p').textContent=s.lines[0][1];document.querySelector('.tu-hint').innerHTML=s.hint;
document.querySelector('.sh-ctabt').textContent='INCOMING';document.querySelector('.sh-cwho').innerHTML='· 诺诺<em>战术领航员</em>';document.querySelector('.sh-cch').textContent='CH-07 · 加密频道';document.querySelector('.sh-cfoot span').textContent='CH-07 · 64 KBPS · ENC';document.querySelector('.sh-cview img').src='/shared/assets/intro/raw/nono_talk.png';
mechFrame(document.querySelector('.sh-cport'),{cut:[0,14,0,14],tri:['tl','br'],glint:'tr',plus:false,grip:false,triSize:10});mechFrame(document.querySelector('.sh-cbox'),{cut:[12,0,12,0],tri:['tr','bl'],glint:'tl'});window.ready=true;</script>`;
const server=http.createServer((req,res)=>{
 const uri=new URL(req.url,'http://localhost').pathname;
 if(uri==='/'){res.setHeader('Content-Type','text/html;charset=utf-8');res.end(html);return;}
 const file=path.resolve(snapshot,'.'+uri);
 if(!file.startsWith(snapshot+path.sep)||!fs.existsSync(file)){res.writeHead(404).end();return;}
 res.setHeader('Content-Type',({'.css':'text/css','.js':'text/javascript','.png':'image/png','.woff2':'font/woff2'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
});
(async()=>{let browser;try{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const page=await browser.newPage({viewport:{width:1920,height:1080}});await page.goto('http://127.0.0.1:'+server.address().port);await page.waitForFunction(()=>window.ready);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(500);
 const selectors=['.tu-card','.sh-cbox','.sh-cbox p','.sh-ctab','.tu-hint','.tu-ctl','.tu-step','.tu-picks','.tu-skip'];
 const metrics=await page.evaluate(selectors=>Object.fromEntries(selectors.map(s=>{const e=document.querySelector(s),r=e.getBoundingClientRect(),c=getComputedStyle(e);return [s,{rect:[r.x,r.y,r.width,r.height],font:c.fontFamily,size:c.fontSize,lineHeight:c.lineHeight}]})),selectors);
 const clip=await page.evaluate(()=>{const c=document.querySelector('.tu-card').getBoundingClientRect(),p=document.querySelector('.sh-comms').getBoundingClientRect();return {x:c.x-8,y:Math.min(c.y,p.y)-8,width:c.width+16,height:c.bottom-Math.min(c.y,p.y)+16}});
 await page.screenshot({clip,path:path.join(out,'tutorial-source-choice.png')});fs.writeFileSync(path.join(out,'tutorial-source-layout.json'),JSON.stringify({sourceCommit:baseline.commit,metrics},null,2));console.log(JSON.stringify(metrics));
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}})().catch(e=>{console.error(e);process.exitCode=1});
