// Technical clipping masks from the frozen source Canvas path, not artwork.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  const page=await browser.newPage();const dir=path.resolve(__dirname,'../../assets/UI/Match');fs.mkdirSync(dir,{recursive:true});
  for(const square of [false,true]){
   const result=await page.evaluate(square=>{
    const cv=document.createElement('canvas');cv.width=cv.height=472;const g=cv.getContext('2d');
    g.beginPath();
    if(!square)g.arc(236,236,212,0,Math.PI*2);
    else{g.moveTo(24,24);g.lineTo(422,24);g.lineTo(448,50);g.lineTo(448,448);g.lineTo(50,448);g.lineTo(24,422);g.closePath();}
    g.clip();g.fillStyle='#fff';g.fillRect(0,0,472,472);return cv.toDataURL('image/png').split(',')[1];
   },square);
   const file=path.join(dir,`minimap-mask-${square?'square':'round'}.png`),bytes=Buffer.from(result,'base64');fs.writeFileSync(file,bytes);
   console.log(path.relative(process.cwd(),file),bytes.length,crypto.createHash('sha256').update(bytes).digest('hex'));
  }
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
