(function(){
 'use strict';
 if(window.__voxPerfCollector)return;
 const pageId='browser-'+(globalThis.crypto?.randomUUID?.()||Date.now().toString(36)+'-'+Math.random().toString(36).slice(2));
 const send=window.fetch.bind(window),encoder=new TextEncoder(),maxBytes=1024*1024,maxRecords=2000,batchBytes=250*1024;
 const queue=[];let bytes=0,sequence=0,sent=0,dropped=0,oversized=0,parseErrors=0,failures=0,pending=null,stopped=false,lastContext=null,lastSession=null,reportedDrops=0,reportedParseErrors=0;
 function status(){return {pageId,queuedRecords:queue.length,queuedBytes:bytes,inFlightRecords:pending?.length||0,sentRecords:sent,droppedRecords:dropped,oversizedRecords:oversized,parseErrors,sendFailures:failures}}
 function enqueue(record){
  const value={...record,_collector:{pageId,sequence:++sequence}},text=JSON.stringify(value),size=encoder.encode(text).length+1;
  if(size>batchBytes-128){dropped++;oversized++;return false}
  if(queue.length>=maxRecords||bytes+size>maxBytes){dropped++;return false}
  queue.push({value,text,size});bytes+=size;return true;
 }
 function browserEvent(type,fields={}){enqueue({type,session:pageId,atMs:performance.now(),linkedSession:lastSession,context:lastContext,...fields})}
 function dropNotice(){if(dropped!==reportedDrops||parseErrors!==reportedParseErrors){const current=dropped;if(enqueue({type:'collector_drop',session:pageId,atMs:performance.now(),droppedRecords:current,oversizedRecords:oversized,parseErrors})){queue.unshift(queue.pop());reportedDrops=current;reportedParseErrors=parseErrors}}}
 function take(limit=batchBytes,cap=500){const batch=[];let size=14;while(queue.length&&batch.length<cap&&size+queue[0].size<limit){const item=queue.shift();bytes-=item.size;size+=item.size;batch.push(item)}return batch}
 function restore(batch){for(let i=batch.length-1;i>=0;i--){const item=batch[i];if(queue.length>=maxRecords||bytes+item.size>maxBytes){dropped++;continue}queue.unshift(item);bytes+=item.size}}
 function body(batch){return '{"records":['+batch.map(item=>item.text).join(',')+']}' }
 async function flush(){
  if(stopped||pending)return;dropNotice();if(!queue.length)return;
  const batch=take();pending=batch;
  const abort=new AbortController(),timeout=setTimeout(()=>abort.abort(),10000);
  try{const response=await send('/__vox_perf',{method:'POST',headers:{'Content-Type':'application/json'},body:body(batch),credentials:'same-origin',signal:abort.signal});if(!response.ok)throw Error('HTTP '+response.status);sent+=batch.length}
  catch{failures++;restore(batch)}finally{clearTimeout(timeout);pending=null}
 }
 function capture(args,level){
  for(const arg of args){
   if(typeof arg!=='string')continue;
   const index=arg.indexOf('VOX_PERF ');
   if(index>=0){try{
    const record=JSON.parse(arg.slice(index+9));if(!record||typeof record!=='object'||Array.isArray(record)||typeof record.session!=='string'||typeof record.type!=='string')throw Error('Invalid record');
    lastSession=record.session;lastContext=record.context||lastContext;enqueue(record);
   }catch{parseErrors++}}
   else if(level==='error'&&/Aborted\(|\bOOM\b|out of memory|RuntimeError|unreachable|Execute Lua|stack traceback/i.test(arg))browserEvent('browser_error',{source:'console',message:arg.slice(0,4000)});
  }
 }
 const originals={};
 for(const name of ['log','info','warn','error','debug']){const original=console[name];originals[name]=original;console[name]=function(...args){try{capture(args,name)}catch{parseErrors++}return original.apply(this,args)}}
 const visibility=()=>{browserEvent('browser_visibility',{state:document.visibilityState});void flush()};
 const onError=event=>browserEvent('browser_error',{source:'error',message:String(event.message||'Resource error').slice(0,4000),filename:String(event.filename||event.target?.src||'').slice(0,1000),line:event.lineno||0,column:event.colno||0,stack:String(event.error?.stack||'').slice(0,6000)});
 const onRejection=event=>browserEvent('browser_error',{source:'unhandledrejection',message:String(event.reason?.message||event.reason).slice(0,4000),stack:String(event.reason?.stack||'').slice(0,6000)});
 function pagehide(event){
  browserEvent('browser_pagehide',{persisted:event.persisted});dropNotice();
  // An unacknowledged fetch may already be on disk; analyzer deduplicates its IDs.
  const repeatsPending=!!pending&&pending.length<500&&encoder.encode(body(pending)).length<58*1024;
  const batch=repeatsPending?pending.slice():take(58*1024,499);
  const summary={type:'collector_pagehide',session:pageId,atMs:performance.now(),persisted:event.persisted,unflushedRecords:queue.length,inFlightRecords:pending?.length||0,droppedRecords:dropped,sendFailures:failures,_collector:{pageId,sequence:++sequence}};
  const summaryText=JSON.stringify(summary);batch.push({value:summary,text:summaryText,size:encoder.encode(summaryText).length+1});
  if(navigator.sendBeacon('/__vox_perf',new Blob([body(batch)],{type:'application/json'})))sent+=repeatsPending?0:batch.length-1;
  else {failures++;if(!repeatsPending)restore(batch.slice(0,-1))}
 }
 document.addEventListener('visibilitychange',visibility);window.addEventListener('error',onError,true);window.addEventListener('unhandledrejection',onRejection);window.addEventListener('pagehide',pagehide);
 let observer;try{observer=new PerformanceObserver(list=>{for(const entry of list.getEntries())if(entry.duration>80)browserEvent('browser_longtask',{atMs:entry.startTime,durationMs:entry.duration,name:entry.name})});observer.observe({type:'longtask',buffered:true})}catch{}
 const timer=setInterval(flush,1000);
 window.__voxPerfCollector={status,flush,stop(){stopped=true;clearInterval(timer);observer?.disconnect();document.removeEventListener('visibilitychange',visibility);window.removeEventListener('error',onError,true);window.removeEventListener('unhandledrejection',onRejection);window.removeEventListener('pagehide',pagehide);for(const [name,original] of Object.entries(originals))console[name]=original}};
 browserEvent('browser_session',{url:location.pathname,visibility:document.visibilityState,userAgent:navigator.userAgent});
})();
