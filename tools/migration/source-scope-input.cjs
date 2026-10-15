const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{createHash}=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const name='three/src/drive/testDrive.js',source=fs.readFileSync(path.join(baseline.snapshot,name),'utf8');
const hash=createHash('sha256').update(source).digest('hex');
if(hash!==baseline.files[name].sha256)throw Error('Frozen input changed: '+name);
const normalized=source.replace(/\r\n/g,'\n');
const start=normalized.indexOf("\t\tthis.dom.addEventListener( 'pointerdown'"),end=normalized.indexOf('\n\t}\n\n\t// ── 进入 / 退出',start);
if(start<0||end<0)throw Error('Frozen input registration block not found');
const cases=[],sequences=[];
for(const held of [0,1,249,250,251,1000])for(const initial of [false,true])sequences.push({name:`right-${held}ms-initial-${initial}`,initial,events:[{at:0,type:'down',button:2},{at:held,type:'up',button:2}]});
sequences.push({name:'two-clicks-between-frames',events:[{at:0,type:'down',button:2},{at:10,type:'up',button:2},{at:20,type:'down',button:2},{at:30,type:'up',button:2}]});
sequences.push({name:'left-fire-while-right-held',events:[{at:0,type:'down',button:2},{at:30,type:'down',button:0},{at:70,type:'up',button:0},{at:300,type:'up',button:2}]});
sequences.push({name:'right-while-left-held',events:[{at:0,type:'down',button:0},{at:30,type:'down',button:2},{at:50,type:'up',button:2},{at:70,type:'up',button:0}]});
sequences.push({name:'lock-loss-while-scoped-and-firing',events:[{at:0,type:'down',button:2},{at:30,type:'down',button:0},{at:60,type:'unlock'},{at:500,type:'up',button:2},{at:510,type:'up',button:0}]});
for(const sequence of sequences){
 let now=0;const handlers={};
 const target=label=>({addEventListener:(type,fn)=>{handlers[label+':'+type]=fn;}});
 const state={active:true,scope:!!sequence.initial,firing:false,input:{locked:true,controlling:true},ui:{},hud:{setPaused(){}},dom:target('dom')};
 vm.runInNewContext('(function(){'+normalized.slice(start,end)+'}).call(state)',{state,window:target('window'),document:target('document'),performance:{now:()=>now},edgeGestureTip:()=>{}});
 const events=[];
 for(const event of sequence.events){
  now=event.at;
  if(event.type==='unlock'){state.input.locked=false;state.input.controlling=false;handlers['document:pointerlockchange']();}
  else handlers[(event.type==='down'?'dom:mousedown':'window:mouseup')]({button:event.button});
  events.push({...event,scope:state.scope,fire:state.firing});
 }
 cases.push({name:sequence.name,initial:!!sequence.initial,events});
}
const matchName='three/src/battle/matchSession.js',matchSource=fs.readFileSync(path.join(baseline.snapshot,matchName),'utf8');
const matchHash=createHash('sha256').update(matchSource).digest('hex');
if(matchHash!==baseline.files[matchName].sha256)throw Error('Frozen match input changed: '+matchName);
const pauseLine=matchSource.split('\n').find(line=>line.includes("e.code === 'Escape'")&&line.includes("'PAUSED'"));
const pauseArgs=pauseLine?.match(/this\.hud\.banner\( (.+) \); return true/);
if(!pauseArgs)throw Error('Frozen match pause banner not found');
const pauseBanner=vm.runInNewContext('['+pauseArgs[1]+']');
const output=path.join(root,'.tmp/source-scope-input.json');fs.writeFileSync(output,JSON.stringify({commit:baseline.commit,provenance:{[name]:hash,[matchName]:matchHash},cases,pauseBanner}));
console.log(JSON.stringify({output,cases:cases.length,edges:cases.reduce((n,c)=>n+c.events.length,0)}));
