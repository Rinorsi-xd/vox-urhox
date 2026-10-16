// Execute the actual browser callback hook without launching another GPU client.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const file=fs.readFileSync(require('node:path').join(__dirname,'check-intro-natural-web.cjs'),'utf8');
const source=file.slice(file.indexOf('function AudioMeter(){'),file.indexOf('\nfunction Wave('));
let now=0,checks=0;const pass=(condition,label)=>{assert.ok(condition,label);checks++;};
class Processor{
 constructor(size){this.bufferSize=size;}
 set onaudioprocess(fn){this.nativeCallback=fn;}
 get onaudioprocess(){return this.nativeCallback;}
}
class Context{
 constructor(){this.currentTime=1;this.state='running';this.listeners={};}
 createScriptProcessor(size){return new Processor(size);}
 addEventListener(event,callback){this.listeners[event]=callback;}
}
const window={AudioContext:Context};
vm.runInNewContext(source+'\nAudioMeter();',{window,performance:{now:()=>now,timeOrigin:1000},requestAnimationFrame:()=>{},Date,WeakMap,Int16Array,Math});
const q=window.__introNaturalQA,ctx=new Context(),first=ctx.createScriptProcessor(4096,0,2),second=ctx.createScriptProcessor(4096,0,2);
const buffer={duration:4096/48000,sampleRate:48000,getChannelData:()=>new Float32Array(4096).fill(.25)};
let calls=0,receiver;
function mix(){receiver=this;calls++;now+=12;ctx.currentTime+=.012;}
first.onaudioprocess=mix;q.marker={shot:'sortie-play'};now=100;
first.nativeCallback({outputBuffer:buffer,playbackTime:1.0853333333333});
pass(calls===1,'Original mixer called exactly once');
pass(receiver===first,'Native callback receiver preserved');
pass(first.onaudioprocess===mix,'Getter returns original callback');
const a=q.audio[0];
for(const [key,expected]of Object.entries({begin:100,end:112,mixMs:12,contextBegin:1,contextEnd:1.012,id:1,contextId:1,at:112,peak:.25,rms:.25,rate:48000,shot:'sortie-play',context:'running'}))pass(a[key]===expected,key+' recorded');
pass(Math.abs(a.scheduledLeadMs-85.3333333333)<1e-7,'Audio scheduled lead records original context clock');
pass(q.processors.length===2&&q.processors[1].id===2,'Each processor receives a unique ID');
pass(q.processors[0].contextId===q.processors[1].contextId,'Same AudioContext remains identifiable');
pass(q.contexts.length===1&&q.contexts[0].state==='running','Initial context state recorded once');
second.onaudioprocess=()=>{now+=3;};second.nativeCallback({outputBuffer:buffer,playbackTime:1.0853333333333});
pass(q.audio[1].id===2&&q.audio[1].playbackTime===a.playbackTime,'Duplicate playback time remains separated by processor');
now=600;first.nativeCallback({outputBuffer:buffer,playbackTime:1.6});
pass(q.audio[2].begin-q.audio[0].end===488,'Delivery wait is distinct from 12 ms mixer work');
first.onaudioprocess=()=>{calls++;now+=5;};first.nativeCallback({outputBuffer:buffer,playbackTime:1.7});
pass(calls===3&&q.audio[3].mixMs===5,'Replacing the original handler does not nest old handlers');
first.onaudioprocess=null;pass(first.nativeCallback===null&&first.onaudioprocess===null,'Clearing native handler remains supported');
ctx.state='suspended';ctx.listeners.statechange();pass(q.contexts.length===2&&q.contexts[1].state==='suspended','Context state transitions retained');
const other=new Context();other.createScriptProcessor(2048,0,1);pass(q.processors[2].contextId===2,'Separate audio contexts remain identifiable');
pass(file.includes('dt>Math.max(250,during[i].duration*3000)')&&file.includes('gaps.length===0&&report.audioContinuity.rafFreezes.length===0'), 'Original continuity thresholds retained');
console.log(JSON.stringify({result:'PASS',checks,scope:'actual AudioMeter callback hook; no browser/GPU, no audible-output claim'}));
