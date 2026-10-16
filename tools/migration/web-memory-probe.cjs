// Browser diagnostics only: no allocator, game state or resource lifetime edits.
async function read(page) {
 const result = await page.evaluate(() => {
  const heap = typeof HEAPU8 !== 'undefined' ? HEAPU8 : null;
  const result = { at: performance.now(), heapBytes: heap?.byteLength ?? null,
   jsHeap: performance.memory ? { used: performance.memory.usedJSHeapSize, total: performance.memory.totalJSHeapSize, limit: performance.memory.jsHeapSizeLimit } : null,
   files: 0, fileBytes: 0, fileBytesInWasm: null, largestFiles: [], fsErrors: [], fsGroups: {},
   recentTransfers: performance.getEntriesByType('resource').slice(-20).map(entry => ({ name: entry.name, startedAt: entry.startTime,
    duration: entry.duration, encodedBytes: entry.encodedBodySize, decodedBytes: entry.decodedBodySize })) };
  if (typeof FS === 'undefined') return result;
  result.opfsHandles = {
   access: typeof wasmfsOPFSAccessHandles === 'undefined' ? null : wasmfsOPFSAccessHandles.allocated.filter(Boolean).length,
   files: typeof wasmfsOPFSFileHandles === 'undefined' ? null : wasmfsOPFSFileHandles.allocated.filter(Boolean).length,
   blobs: typeof wasmfsOPFSBlobs === 'undefined' ? null : wasmfsOPFSBlobs.allocated.filter(Boolean).length,
   directories: typeof wasmfsOPFSDirectoryHandles === 'undefined' ? null : wasmfsOPFSDirectoryHandles.allocated.filter(Boolean).length,
  };
  if (typeof Fetch !== 'undefined' && Fetch.xhrs?.allocated) {
   const requests = Fetch.xhrs.allocated.filter(Boolean);
   result.xhrs = { count: requests.length, responseBytes: 0, requests: [] };
   for (const xhr of requests) {
    const bytes = xhr.responseType === 'arraybuffer' ? xhr.response?.byteLength ?? 0 : null;
    result.xhrs.responseBytes += bytes ?? 0;
    result.xhrs.requests.push({ url: xhr.url_, readyState: xhr.readyState, bytes, streamData: xhr._streamData });
   }
  }
  if (!FS.root && typeof FS.readdir === 'function' && typeof FS.lstat === 'function') {
   result.fsKind = 'WasmFS';
   // lstat/readdir do not copy file contents. readFile/analyzePath would allocate.
   const pending = ['/']; const started = performance.now(); let visited = 0;
   while (pending.length && visited < 30000 && performance.now() - started < 500) {
    const path = pending.pop(); visited++;
    if (path === '/dev' || path === '/proc') continue;
    try {
     const stat = FS.lstat(path), mode = stat.mode & 61440;
     if (mode === 16384) {
      for (const name of FS.readdir(path)) if (name !== '.' && name !== '..') pending.push((path === '/' ? '' : path) + '/' + name);
     } else if (mode === 32768) {
      const bytes = stat.size; result.files++; result.fileBytes += bytes;
      result.largestFiles.push({ path, bytes });
      const group = path.split('/').slice(0, 4).join('/'); result.fsGroups[group] = (result.fsGroups[group] ?? 0) + bytes;
     }
    } catch (error) { if (result.fsErrors.length < 10) result.fsErrors.push({ path, message: error.message }); }
   }
   result.fsVisited = visited; result.fsTruncated = pending.length > 0; result.fsScanMs = performance.now() - started;
   result.largestFiles.sort((a, b) => b.bytes - a.bytes); result.largestFiles.length = Math.min(15, result.largestFiles.length);
   return result;
  }
  result.fsKind = FS.root ? 'MEMFS' : 'unavailable'; result.fileBytesInWasm = 0;
  const visit = (node, path) => {
   if (!node) return;
   if (FS.isDir(node.mode)) {
    for (const [name, child] of Object.entries(node.contents ?? {})) visit(child, path + '/' + name);
   } else if (FS.isFile(node.mode)) {
    const bytes = node.usedBytes ?? node.contents?.byteLength ?? node.contents?.length ?? 0;
    result.files++; result.fileBytes += bytes;
    if (node.contents?.buffer === heap?.buffer) result.fileBytesInWasm += bytes;
    result.largestFiles.push({ path, bytes, inWasm: node.contents?.buffer === heap?.buffer });
   }
  };
  visit(FS.root, '');
  result.largestFiles.sort((a, b) => b.bytes - a.bytes); result.largestFiles.length = Math.min(15, result.largestFiles.length);
  return result;
 });
 // OPFS and downloads may live in pthread realms; count JS handles only there.
 result.workerRealms = await Promise.all(page.workers().map(async worker => {
  try {
   return await Promise.race([worker.evaluate(() => {
    const count = handles => handles.allocated.filter(Boolean).length;
    const requests = typeof Fetch === 'undefined' ? [] : (Fetch.xhrs?.allocated ?? []).filter(Boolean);
    return { pthread: typeof ENVIRONMENT_IS_PTHREAD === 'undefined' ? null : ENVIRONMENT_IS_PTHREAD,
     opfs: { access: typeof wasmfsOPFSAccessHandles === 'undefined' ? null : count(wasmfsOPFSAccessHandles),
      files: typeof wasmfsOPFSFileHandles === 'undefined' ? null : count(wasmfsOPFSFileHandles),
      blobs: typeof wasmfsOPFSBlobs === 'undefined' ? null : count(wasmfsOPFSBlobs),
      directories: typeof wasmfsOPFSDirectoryHandles === 'undefined' ? null : count(wasmfsOPFSDirectoryHandles) },
     requests: requests.map(xhr => ({ url: xhr.url_, readyState: xhr.readyState,
      bytes: xhr.responseType === 'arraybuffer' ? xhr.response?.byteLength ?? 0 : null })) };
   }), new Promise(resolve => setTimeout(() => resolve({ unavailable: 'busy-worker' }), 750))]);
  } catch (error) { return { unavailable: error.message }; }
 }));
 return result;
}
async function installAbort(page) {
 await page.evaluate(() => {
  if (globalThis.voxMemoryAbortProbe || typeof abortOnCannotGrowMemory !== 'function') return;
  globalThis.voxMemoryAbortProbe = true;
  const previous = abortOnCannotGrowMemory;
  abortOnCannotGrowMemory = requested => {
   console.error('WASM_OOM ' + JSON.stringify({ requested, heapBytes: typeof HEAPU8 === 'undefined' ? null : HEAPU8.byteLength, stack: new Error().stack }));
   return previous(requested);
  };
 });
}
async function install(page) {
 await installAbort(page);
 return read(page);
}
module.exports = { install, installAbort, read };
