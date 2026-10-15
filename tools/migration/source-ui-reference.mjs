// Read-only source UI reference host. Never writes to the H5 checkout or storage.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const toolDir=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(process.argv[2] || 'D:/Rino_Project/Vox');
const port=Number(process.argv[3] || 43186);
const page=await fs.readFile(path.join(root,'three/index.html'),'utf8');
const stats=page.match(/<aside id="stats">[\s\S]*?<\/aside>/)?.[0];
if(!stats)throw Error('Original stats markup not found');
const html=`<!doctype html><meta charset="utf-8"><title>原版 PC 弹窗对照</title>
<link rel="stylesheet" href="/source/shared/css/style.css">
<script type="importmap">{"imports":{"three":"/source/three/vendor/three/build/three.module.js","three/addons/":"/source/three/vendor/three/addons/","@shared/":"/source/shared/"}}</script>
<div id="ui">${stats}<div id="modal"></div><div id="help"></div></div>
<nav style="position:fixed;right:8px;top:8px;z-index:99"><button id="load">载入蓝图库</button><button id="save">保存蓝图库</button><button id="populated">有存档的蓝图库</button><button id="graphics">画面设置</button><button id="diagnostics">建造检查</button><button id="motion">测量原版弹窗入场</button><output id="focus"></output></nav>
<output id="motion-results" style="position:fixed;top:40px;left:8px;z-index:99;white-space:pre;font:12px monospace"></output>
<script type="module">
import {UI} from '/source/shared/ui/ui.js';
import {Blueprint} from '/source/shared/build/blueprint.js';
import {buildRaceCar} from '/source/shared/build/prefab.js';
import {TIERS} from '/source/shared/config.js';
import {icon} from '/source/shared/ui/icons.js';
const bp=buildRaceCar(new Blueprint());bp.add({type:'cube',pos:[25,5,0],color:0xffffff});
const ui=new UI({setTier(id){ui.updateStats(bp.diagnose(TIERS[id-1]),TIERS[id-1]);},
focusWarning(w,move){document.querySelector('#focus').textContent=w?(move?'定位 ':'高亮 ')+w.ids.length+' 个零件':'';}});
ui.modal=document.querySelector('#modal');ui._stats();ui.updateStats(bp.diagnose(TIERS[2]),TIERS[2]);
for(const e of document.querySelectorAll('[data-ic]'))e.insertAdjacentHTML('afterbegin',icon(e.dataset.ic));
document.querySelector('#diagnostics').onclick=()=>ui.closeModal();
ui._help();
const helpButton=document.createElement('button');helpButton.textContent='操作说明对照';document.querySelector('nav').append(helpButton);
helpButton.onclick=()=>{ui.closeModal();ui.showHelp(true);};
const symbolsButton=document.createElement('button');symbolsButton.textContent='测量箭头字体';document.querySelector('nav').append(symbolsButton);
symbolsButton.onclick=()=>{
 const ctx=document.createElement('canvas').getContext('2d');
 document.querySelector('#motion-results').textContent=JSON.stringify(['var','Segoe UI Symbol','Segoe UI','Arial','Noto Sans SC','Noto Serif SC','Yu Gothic'].map(face=>{
  ctx.font='12.5px '+(face==='var'?getComputedStyle(document.body).getPropertyValue('--body'):'"'+face+'"');
  const m=ctx.measureText('⇄');const e=document.createElement('div');e.style.cssText='position:fixed;font:'+ctx.font+';';e.textContent='第一人称 ⇄ 环绕视角';document.body.append(e);
  const height=e.getBoundingClientRect().height;e.remove();
  return {face,width:m.width,ascent:m.fontBoundingBoxAscent,descent:m.fontBoundingBoxDescent,height};
 }));
};
// Fixture content; all shape/layout comes from unmodified original UI/CSS.
const slots=Array.from({length:20},()=>null);
const open=mode=>ui.openLibrary(slots,{onLoad(){},onSave(){},onDelete(){}},mode);
document.querySelector('#load').onclick=()=>open('load');document.querySelector('#save').onclick=()=>open('save');
document.querySelector('#populated').onclick=()=>{
 // Transparent fixture: tests original metadata/layout, not thumbnail parity.
 const thumb='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==';
 for(const [i,name,count] of [[0,'原版长名称战车测试 ABC 0123456789',209],[1,'赤焰 GT',209],[2,'新战车',1]])slots[i]={name,time:new Date(2026,9,6,10,5).getTime(),data:{parts:Array(count)},thumb};open('load');
};
document.querySelector('#graphics').onclick=()=>ui.openGraphics({bloom:.18,mist:.04,exposure:1.1,vignette:.3,grain:0,ao:true},'high',{onChange(){},onQuality(){},onReset(){}});
const closeMeasure=document.createElement('button');closeMeasure.textContent='测量原版弹窗退场';document.querySelector('nav').append(closeMeasure);
closeMeasure.onclick=()=>{
 const result=[30,300].map(entryTime=>{
  document.querySelector('#graphics').click();
  const modal=document.querySelector('#modal'),card=modal.querySelector('.card');
  for(const a of modal.getAnimations({subtree:true})){a.pause();a.currentTime=entryTime;}
  const before={overlay:Number(getComputedStyle(modal).opacity),card:Number(getComputedStyle(card).opacity)};
  ui.closeModal();
  const animations=modal.getAnimations({subtree:true});for(const a of animations)a.pause();
  const samples=[0,20,40,80,120,159,160].map(time=>{
   for(const a of animations)a.currentTime=time;
   const m=getComputedStyle(modal),c=getComputedStyle(card);
   return {time,overlay:Number(m.opacity),card:Number(c.opacity),translate:c.translate,pointerEvents:m.pointerEvents,modalOpen:ui.modalOpen};
  });
  return {entryTime,before,samples};
 });document.querySelector('#motion-results').textContent=JSON.stringify(result);
};
document.querySelector('#motion').onclick=()=>{
 const hidden=document.querySelector('#modal');hidden.classList.remove('show');void hidden.offsetWidth;
 document.querySelector('#graphics').click();
 const modal=document.querySelector('#modal'),card=modal.querySelector('.card');
 const animations=modal.getAnimations({subtree:true});
 for(const a of animations)a.pause();
 const samples=[0,30,60,90,125,180,220,260].map(time=>{
  for(const a of animations)a.currentTime=time;
  const m=getComputedStyle(modal),c=getComputedStyle(card),box=card.getBoundingClientRect();
  return {time,overlay:Number(m.opacity),card:Number(c.opacity),translate:c.translate,y:box.y};
 });
 document.querySelector('#motion-results').textContent=JSON.stringify(samples);
};
open('save');
</script>`;
const mime={'.css':'text/css','.js':'text/javascript','.json':'application/json','.woff2':'font/woff2','.ttf':'font/ttf','.png':'image/png'};
http.createServer(async(req,res)=>{try{
 const url=new URL(req.url,'http://127.0.0.1:'+port);
 const capture=url.pathname.match(/^\/panel-evidence\/(race|renamed|edited|tank|empty)\/(stats|blueprint|mark|bay)$/);
 if(req.method==='POST'&&capture){
  let body='';for await(const chunk of req){body+=chunk;if(body.length>20000000)throw Error('Capture too large');}
  if(!body.startsWith('data:image/png;base64,'))throw Error('Expected canvas PNG');
  await fs.writeFile(path.resolve(toolDir,'../../docs/migration/evidence/h5-panel-'+capture[2]+'-'+capture[1]+'.png'),Buffer.from(body.slice(22),'base64'));
  res.end('saved');return;
 }
 if(req.method!=='GET') {res.writeHead(405);res.end();return;}
 if(url.pathname==='/home-camera'){
  const controls=`<nav style="position:fixed;right:10px;top:65px;z-index:999;background:#111;padding:6px"><button id="reference-hangar">冻结机库镜头</button><button id="reference-battle">冻结战斗镜头</button><button id="reference-workshop">冻结工坊镜头</button><button id="reference-shop">冻结商店镜头</button></nav><script>
  for(const tab of ['hangar','battle','workshop','shop'])document.getElementById('reference-'+tab).onclick=()=>{
   const v=window.__vox;if(!v)return;
   v.shell.tab(tab);v.rig.update(.65);v.rig.autoSpin=false;
   document.querySelector('nav:has(#reference-hangar)').style.display='none';
  };</script>`;
  res.setHeader('Content-Type','text/html; charset=utf-8');res.end(page.replace('<head>','<head><base href="/source/three/">').replace('</body>',controls+'</body>'));return;
 }
 if(url.pathname==='/panels'){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(await fs.readFile(path.join(toolDir,'source-panel-reference.html')));return;}
 if(url.pathname==='/fonts'){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(await fs.readFile(path.join(toolDir,'source-font-reference.html')));return;}
 if(url.pathname==='/paragraphs'){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(await fs.readFile(path.join(toolDir,'source-paragraph-reference.html')));return;}
 if(url.pathname==='/controls'){
  const dock=page.match(/<div id="dock">[\s\S]*?<div id="colorPop"><\/div>/)?.[0];
  if(!dock)throw Error('Original dock markup not found');
  res.setHeader('Content-Type','text/html; charset=utf-8');res.end((await fs.readFile(path.join(toolDir,'source-controls-reference.html'),'utf8')).replace('__SOURCE_DOCK__',dock));return;
 }
 if(url.pathname==='/'){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html);return;}
 if(!url.pathname.startsWith('/source/'))throw Error('Unknown path');
 const relative=decodeURIComponent(url.pathname.slice(8));const file=path.resolve(root,relative);
 if(!/^(shared|three)\//.test(relative)||!file.startsWith(root+path.sep))throw Error('Invalid path');
 const bytes=await fs.readFile(file);res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(bytes);
}catch(e){res.writeHead(404);res.end(e.message);}}).listen(port,'127.0.0.1',()=>console.log('Read-only original UI: http://127.0.0.1:'+port));
