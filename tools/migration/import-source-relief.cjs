// Rasterize the frozen SVG material, preserving its CSS repeat-x sizing.
const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  for(const name of ['side','primary','side-compact','primary-compact','halftone-soft-dark','halftone-soft-light']){
   const halftone=name.startsWith('halftone-');
   const compact=name.endsWith('compact'),height=compact?44:100;
   const page=await browser.newPage({viewport:{width:halftone?640:5,height:halftone?320:height},deviceScaleFactor:halftone?1:4});
   const svg=fs.readFileSync(path.join(baseline.snapshot,'shared/assets/ui/new-ui/'+(halftone?name:'relief-'+name)+'.svg'),'utf8');
   const background=name.startsWith('primary')?'#2d7acb':'#193e6e';
   await page.setContent('<style>html,body{margin:0;background:'+(halftone?'transparent':background)+'}svg{display:block}</style>'+svg);
   await page.screenshot({path:path.join(root,'assets/UI/'+(halftone?(name.endsWith('light')?'HalftoneSoftLight':'HalftoneSoftDark'):'Relief-'+name)+'.png'),omitBackground:halftone});
   await page.close();
  }
 }finally{await browser.close();}
 console.log('Imported frozen SVG button materials at 4x and source halftone.');
})().catch(error=>{console.error(error);process.exitCode=1;});
