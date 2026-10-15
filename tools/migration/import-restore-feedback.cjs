const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const snapshot=path.join(root,'.tmp/outgame-source-2026-10-14T10-09-50-505Z');
const source=fs.readFileSync(path.join(snapshot,'shared/ui/reticle.js'),'utf8');
if(!source.includes('animation: rtBlink .35s steps(2) 4')||!source.includes('sepia(1) saturate(5) hue-rotate(-14deg) brightness(1.1)'))throw Error('Frozen chip CSS changed');
(async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  const page=await browser.newPage();
  await page.setContent('<style>@keyframes rtBlink {50% {opacity:.3}} #chip{animation:rtBlink .35s steps(2) 4}</style><div id="chip"></div>');
  const samples=await page.evaluate(()=>{
   const el=document.querySelector('#chip'),anim=el.getAnimations()[0];anim.pause();
   return [0,43.75,87.5,131.25,175,218.75,262.5,306.25,349,350,1399,1400].map(ms=>{anim.currentTime=ms;return {ms,opacity:Number(getComputedStyle(el).opacity)};});
  });
  const output=path.join(root,'assets/UI/WeaponIcons/Hurt');fs.mkdirSync(output,{recursive:true});
  const files=fs.readdirSync(path.join(root,'assets/UI/WeaponIcons')).filter(n=>n.endsWith('.png'));const icons=[];
  for(const name of files){
   const input=fs.readFileSync(path.join(root,'assets/UI/WeaponIcons',name));
   const png=await page.evaluate(async data=>{
    const img=new Image();img.src='data:image/png;base64,'+data;await img.decode();
    const c=document.createElement('canvas');c.width=img.width;c.height=img.height;
    const ctx=c.getContext('2d');ctx.filter='sepia(1) saturate(5) hue-rotate(-14deg) brightness(1.1)';ctx.drawImage(img,0,0);
    return c.toDataURL('image/png').split(',')[1];
   },input.toString('base64'));
   const target=path.join(output,name);const bytes=Buffer.from(png,'base64');fs.writeFileSync(target,bytes);
   if(!fs.existsSync(target+'.meta'))fs.writeFileSync(target+'.meta',JSON.stringify({uuid:crypto.randomBytes(18).toString('base64url')},null,2)+'\n');
   icons.push({name,sourceSha256:crypto.createHash('sha256').update(input).digest('hex'),filteredSha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  }
  const report={sourceCommit:'2b169a9964645f5f346a7158bcb14447f040814a',css:'rtBlink .35s steps(2) 4',filter:'sepia(1) saturate(5) hue-rotate(-14deg) brightness(1.1)',samples,icons};
  fs.writeFileSync(path.join(__dirname,'source-restore-feedback.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({icons:icons.length,samples}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
