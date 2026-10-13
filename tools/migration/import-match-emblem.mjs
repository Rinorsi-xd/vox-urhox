import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const source=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8')).snapshot;
const url=p=>pathToFileURL(path.join(source,p)).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url('three/vendor/three/build/three.module.js'):s,c);}});
const {emblem}=await import(url('shared/ui/matchLobby.js'));
const {chromium}=createRequire(import.meta.url)('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const dest=path.join(root,'assets/UI/Match');fs.mkdirSync(dest,{recursive:true});
const browser=await chromium.launch({headless:true,channel:'chrome'});
try{
 const page=await browser.newPage({viewport:{width:440,height:440}});
 const font=fs.readFileSync(path.join(root,'assets/Fonts/VoxIndustrial-Bold.otf')).toString('base64');
 await page.setContent(`<style>@font-face{font-family:vox;src:url(data:font/otf;base64,${font})}body{margin:0;background:transparent}svg{width:440px;height:440px}line{stroke:#ffffff66;stroke-width:1.4}.seg{fill:none;stroke:#ff6a13;stroke-width:5;stroke-dasharray:70 55.6}.prog{display:none}text{font:400 6.4px vox;letter-spacing:2.6px;fill:#ffffff80}.hexf{fill:#0d0f13e6;stroke:#ffffff3a;stroke-width:1.5}.bolt{fill:#2a2e35;stroke:#ffffff55;stroke-width:.8}.bolt-h{fill:#0b0c0f}.gear{fill:#2a2e35}.gear-b{fill:#1c1f24;stroke:#ffffff30;stroke-width:1}.cross-c{fill:none;stroke:#ff6a13;stroke-width:2}.cross{stroke:#ff6a13;stroke-width:2.4}.wrench{fill:#f4f5f7}.dot{fill:#ff6a13}</style>${emblem()}`);
 await page.evaluate(()=>document.fonts.ready);
 for(const layer of ['base','core','ring-t','ring-s','ring-txt','gear']){
  await page.evaluate(layer=>{for(const child of document.querySelector('svg').children){if(child.tagName==='defs')continue;const base=child.classList.contains('hexf')||child.tagName==='g'&&child.querySelector('.bolt');const core=['cross-c','cross','wrench','dot'].some(c=>child.classList.contains(c));child.style.display=(layer==='base'?base:layer==='core'?core:child.classList.contains(layer))?'':'none';}},layer);
  await page.screenshot({path:path.join(dest,'emblem-'+layer+'.png'),omitBackground:true});
 }
 fs.copyFileSync(path.join(source,'shared/assets/ui/brand/division-insignia.png'),path.join(dest,'division-insignia.png'));
 console.log(JSON.stringify({source:'shared/ui/matchLobby.js',layers:6}));
}finally{await browser.close();}
