// Rasterize the frozen source canvas functions in Chromium, without redrawing them.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=fs.readFileSync(path.join(baseline.snapshot,'three/src/battle/storyView.js'),'utf8');
const functions=['textSprite','foxFlagTexture'].map(name=>{
 const text=source.match(new RegExp('function '+name+'\\([^]*?\\n\\}'));if(!text)throw Error('Frozen canvas function missing: '+name);return text[0];
}).join('\n');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{const page=await browser.newPage();
  const data=await page.evaluate(code=>{
   class CanvasTexture{constructor(image){this.image=image;}}class SpriteMaterial{constructor(data){Object.assign(this,data);}}
   class Sprite{constructor(material){this.material=material;this.scale={set(){}};}}
   const THREE={CanvasTexture,SpriteMaterial,Sprite,SRGBColorSpace:'srgb'};
   return new Function('THREE',code+";return {pirate:foxFlagTexture(false).image.toDataURL(),company:foxFlagTexture(true).image.toDataURL(),graffiti:textSprite('狐狐到此一游 ★','#ff5a64',1.4).material.map.image.toDataURL()}")(THREE);
  },functions);
  const report={baseline:baseline.commit,functionSha256:crypto.createHash('sha256').update(functions).digest('hex'),files:[]};
  for(const [name,url] of Object.entries(data)){
   const bytes=Buffer.from(url.split(',')[1],'base64'),file='Story/Mission/'+name+'.png';fs.writeFileSync(path.join(root,'assets',file),bytes);
   report.files.push({path:file,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  }
  fs.writeFileSync(path.join(root,'docs/migration/evidence/story-site-textures.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
