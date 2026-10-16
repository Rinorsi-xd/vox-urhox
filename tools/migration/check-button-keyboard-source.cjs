// Execute frozen source propagation and shell handlers. DOM default is an adapter.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const home=fs.readFileSync(path.join(baseline.snapshot,'shared/ui/home.js'),'utf8');
const shell=fs.readFileSync(path.join(baseline.snapshot,'shared/ui/shell.js'),'utf8');
const listener=home.match(/root\.addEventListener\( 'keydown', \( e \) => \{([\s\S]*?)\n\t\t\} \);/)[1];
const method=shell.match(/\n\t_key\( e \) \{([\s\S]*?)\n\t\}/)[1];
const handlers=vm.runInNewContext(`({home:function(e){${listener}},shell:function(e){${method}}})`,{isTyping:e=>e.target.typing});
let checks=0;
function check(v){checks++;assert(v);}
function run(code,{focused=false,disabled=false,tab='hangar',typing=false,repeat=1,release=true}={}){
 const log=[];
 const h={tab},s={screen:'home',home:h,ui:{modalOpen:false,showHelpOpen:false,showHelp(){log.push('help');return true;}},storyPage:{visible:false},
  go:page=>log.push(page),tab:page=>log.push(page),editor:{testDrive:()=>log.push('trial')},_startMatch:()=>{log.push('match');return true;},pauseMenu:()=>log.push('pause')};
 let armed=false;
 for(let i=0;i<repeat;i++){
  const e={code,target:{typing,closest:selector=>focused&&selector==='button, summary'?{}:null},stopped:false,prevented:false,
   stopPropagation(){this.stopped=true;},preventDefault(){this.prevented=true;}};
  handlers.home.call(h,e);if(!e.stopped)handlers.shell.call(s,e);
  if(focused&&!disabled&&!e.prevented){if(code==='Space')armed=true;else if(code==='Enter'||code==='NumpadEnter')log.push('button');}
 }
 if(release&&armed)log.push('button');return log.join(',');
}
for(const key of ['Enter','NumpadEnter']){
 check(run(key,{focused:true})==='button');check(run(key,{focused:true,repeat:3})==='button,button,button');
 check(run(key,{focused:true,disabled:true})==='');check(run(key)==='edit');check(run(key,{typing:true})==='');
 check(run(key,{tab:'battle',focused:true})==='match');
}
check(run('Space',{focused:true,release:false})==='');check(run('Space',{focused:true,repeat:5})==='button');
check(run('Space',{focused:true,disabled:true})==='');check(run('KeyF',{focused:true})==='battle');
check(run('Escape')==='pause');check(run('KeyH')==='help');
process.stdout.write(JSON.stringify({result:'PASS',checks}));
