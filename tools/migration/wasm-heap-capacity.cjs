// Pass readWasmHeapCapacity directly to page.evaluate. No native allocator calls.
function readWasmHeapCapacity(){
 const probes=[['Module.HEAPU8',globalThis.Module?.HEAPU8],['Module.HEAP8',globalThis.Module?.HEAP8],
  ['globalThis.HEAPU8',globalThis.HEAPU8],['globalThis.HEAP8',globalThis.HEAP8]];
 const available=[];
 for(const [source,view] of probes){
  if(!ArrayBuffer.isView(view))continue;
  const buffer=view.buffer;
  available.push({source,capacityBytes:buffer.byteLength,viewBytes:view.byteLength,
   shared:typeof SharedArrayBuffer!=='undefined'&&buffer instanceof SharedArrayBuffer});
 }
 const capacities=[...new Set(available.map(p=>p.capacityBytes))];
 const js=globalThis.performance?.memory;
 return {at:globalThis.performance?.now?.()??null,available:available.length>0,
  capacityBytes:capacities.length===1?capacities[0]:null,probes:available,
  jsHeap:js?{usedBytes:js.usedJSHeapSize,totalBytes:js.totalJSHeapSize,limitBytes:js.jsHeapSizeLimit}:null,
  boundary:'WASM linear-memory buffer capacity only; neither allocated bytes nor free bytes. JS heap is separate and may be approximate.'};
}
module.exports={readWasmHeapCapacity};
