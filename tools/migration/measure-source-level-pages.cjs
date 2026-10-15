const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
async function main(){
 const out=path.join(root,'docs/migration/evidence/level-page-source-'+new Date().toISOString().replaceAll(':','-'));fs.mkdirSync(out,{recursive:true});
 const report={baseline:baseline.commit,url:'http://localhost:5173/three/',boundary:'Actual 5173 StoryPage module and stylesheet cascade in isolated DOM harness; source 3D holo and game bootstrap are intentionally absent. Not natural gameplay or target acceptance.',css:[],pages:[],errors:[]};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  for(const [name,width,height,touch]of[['pc',1920,1080,false],['20x9',840,378,true]]){
   const page=await browser.newPage({viewport:{width,height},hasTouch:touch,deviceScaleFactor:1});page.on('pageerror',e=>report.errors.push({name,message:e.message}));
   await page.route('**/three/src/main.js',r=>r.abort());await page.goto(report.url);
   await page.evaluate(async({touch})=>{
    document.documentElement.toggleAttribute('data-ui-compact',touch);
    localStorage.setItem('vox.story.voiced','1');localStorage.setItem('vox.story.progress',JSON.stringify({s1:{grade:'S',time:125.9,clears:1},s3:{grade:'A',time:189.2,clears:2}}));
    const {StoryPage}=await import('/shared/ui/storyPage.js');
    const view=new StoryPage(document.body,{onBack(){},onStart(){},toast(){}});
    view.holo={resize(){},start(){},stop(){},setLevel(){}};view.open();window.levelPage=view;
    for(const el of document.body.children)if(el!==view.root&&el.tagName!=='SCRIPT'&&el.tagName!=='STYLE')el.style.display='none';
   },{touch});
   await page.evaluate(()=>document.fonts.ready);
   if(!report.css.length){
    for(const href of await page.evaluate(()=>[...document.querySelectorAll('link[rel="stylesheet"]')].map(el=>el.href))){
     const response=await page.request.get(href),text=await response.text(),relative=new URL(href).pathname.replace(/^\//,'');
     const frozen=path.join(baseline.snapshot,relative),hash=s=>crypto.createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
     report.css.push({path:relative,status:response.status(),sha256:hash(text),sameAsFrozen:fs.existsSync(frozen)&&hash(text)===hash(fs.readFileSync(frozen,'utf8'))});
    }
   }
   for(let index=0;index<5;index++){
    await page.evaluate(i=>window.levelPage.select(i,{quiet:true}),index);await page.waitForTimeout(1700);
    const evidence=await page.evaluate(()=>{
     const selectors=['.st-ui','.st-top','.st-title b','.st-kicker','.st-title small','.st-route','.st-rhead b','.st-lv.on','.st-lv.on .st-tx b','.st-lv.on .st-tx small','.st-grade','.st-brief','.st-btype','.st-btype em','.st-bhead h2','.st-ben','.st-story','.st-bin h3','.st-goals li','.st-enemy b','.st-enemy span','.st-intercept span','.st-intercept p','.st-facts dt','.st-facts dd','.st-best','.st-go','.st-go b','.st-go small','.st-comms','.st-say','.st-who','.st-play','.st-hints'];
     return {index:window.levelPage.i,viewport:[innerWidth,innerHeight],scale:window.levelPage.k,items:selectors.flatMap(selector=>[...document.querySelectorAll(selector)].map(el=>{
      const c=getComputedStyle(el),r=el.getBoundingClientRect();return {selector,text:el.textContent.trim(),rect:[r.x,r.y,r.width,r.height],font:c.fontFamily,size:c.fontSize,weight:c.fontWeight,style:c.fontStyle,synthesis:c.fontSynthesis,spacing:c.letterSpacing,lineHeight:c.lineHeight,color:c.color,background:c.background,shadow:c.textShadow,animation:c.animation};
     }))};
    });
    const screenshot=path.join(out,name+'-level-'+(index+1)+'.png');await page.screenshot({path:screenshot});report.pages.push({name,...evidence,screenshot});
   }
   await page.close();
  }
  report.result='CAPTURED';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1;}
 finally{await browser.close();fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));fs.writeFileSync(path.join(root,'.tmp/source-level-pages.json'),JSON.stringify(report));console.log(JSON.stringify({result:report.result,out,pages:report.pages.length,cssDifferent:report.css.filter(c=>!c.sameAsFrozen),errors:report.errors,failure:report.failure},null,2));}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
