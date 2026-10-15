const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const cache=require('./cached-engine-sources.cjs');
const root=path.resolve(__dirname,'../..');
const snapshot=cache.snapshots['engine-res'];
const manifest=JSON.parse(fs.readFileSync(path.join(root,'.tmp/web-engine/http-cache',snapshot.manifest)));
const base='https://tapcode-sce.spark.xd.com/src/engine-res/'+snapshot.client+'/';
function asset(virtualPath){
 const file=manifest.files.find(file=>file.fs_path===virtualPath);
 assert.ok(file,'Pinned engine manifest contains '+virtualPath);
 const response=cache.read(base+'assets/'+file.uuid+'-'+file.hash+file.ext);
 assert.ok(response,'Downloaded engine fixture contains '+virtualPath);
 assert.equal(response.body.length,file.size,'Asset response retains its own byte length');
 return response.body;
}
const blocking=JSON.parse(asset('Strings/RenderBlockingTypes.json'));
assert.ok(blocking.blocking_exts.includes('.lua'));
assert.equal(blocking.files,undefined,'JSON assets must not receive a manifest body');
const config=JSON.parse(asset('i18n.json'));
assert.ok(config.source_lang,'Translation config retains its actual language');
assert.equal(config.files,undefined);
assert.match(asset('urhox-libs/Engine/init.lua').toString(),/require\("i18n"\)/);
const resolved=JSON.parse(cache.read(base+'manifest-'+snapshot.client+'.json').body);
assert.equal(resolved.files.length,manifest.files.length,'Versioned manifest routing remains valid');
assert.equal(cache.read('https://example.com/src/engine-res/stable.json'),null);
console.log('PASS: pinned engine manifests, JSON assets and initialization scripts resolve independently');
