import hashlib,json,sys,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
import os
os.chdir(root)
result=LuaRuntime(unpack_returned_tuples=True).execute((root/'tools/migration/bake-match-map-check.lua').read_text(encoding='utf-8'))
node_checks=r'''
const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto'),cp=require('child_process');
const tool=require('./tools/migration/bake-match-map.cjs'),meta=JSON.parse(fs.readFileSync('assets/Crater/Minimap.json'));
const original=JSON.parse(cp.execFileSync('git',['show','48ef15f2:assets/Crater/Minimap.json'],{encoding:'utf8'}));
const fixedBaseline='f94827b26fc12b707e6d6904d093e16358caaf41';
const hoistedScripts={
 'scripts/render/CraterEffects.lua':'5f1aec08cf67f7386c2806876f503af6e3d16a6cf964ef018ddca04c11a6674d',
 'scripts/render/MatchMapShot.lua':'7da9501093c1faab6ae584f0c4eaba2f6d3623db02c725dc3c8c9d39a7006910',
 'scripts/scene/Crater.lua':'7205aab7bfee0f87db6a91421a1e324544b8feaf3b1d1e61ab387f96d4795f98'
};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function checksum(b){let h=0;for(const value of b)h=(Math.imul(h,65599)+value)>>>0;return h;}
function runtimeSignature(b){
 const own={bytes:b.length,checksum:checksum(b)},variants=[],lf=b.toString('latin1').replace(/\r\n/g,'\n');
 for(const text of [lf,lf.replace(/\n/g,'\r\n')]){
  const bytes=Buffer.from(text,'latin1'),v={bytes:bytes.length,checksum:checksum(bytes)};
  if((v.bytes!==own.bytes||v.checksum!==own.checksum)&&!variants.some(x=>x.bytes===v.bytes&&x.checksum===v.checksum))variants.push(v);
 }
 return {checksum:own.checksum,bytes:own.bytes,variants};
}
const checks=[];function check(ok,label){assert(ok,label);checks.push(label)}
async function main(){
const current=tool.inputs(),expected=structuredClone(original.inputs);delete expected['scripts/render/RenderTargetLifetime.lua'];
const changed=Object.keys(current).filter(p=>JSON.stringify(current[p])!==JSON.stringify(expected[p]));
check(JSON.stringify(changed.sort())===JSON.stringify(['assets/Crater/albedo.xml','assets/Crater/material-1.xml','assets/Crater/nra.xml',...Object.keys(hoistedScripts),'tools/migration/bake-match-map-runtime.lua'].sort()),'Actual capture differs from historical map only in linear filters, terrain flow control, three fixed require hoists and signed bake configuration');
for(const [file,expectedHash]of Object.entries(hoistedScripts)){
 const fixed=cp.execFileSync('git',['show',fixedBaseline+':'+file]),actual=fs.readFileSync(file);
 check(hash(Buffer.from(fixed.toString('latin1').replace(/\r\n/g,'\n'),'latin1'))===expectedHash,'Fixed baseline SHA is pinned for '+file);
 check(hash(Buffer.from(actual.toString('latin1').replace(/\r\n/g,'\n'),'latin1'))===expectedHash,'Current require hoist matches fixed baseline, permitting only EOL variants: '+file);
}
const material=fs.readFileSync('assets/Crater/material-1.xml','utf8');
const historicalMaterial=cp.execFileSync('git',['show','48ef15f2:assets/Crater/material-1.xml'],{encoding:'utf8'});
check(material.replaceAll('\r\n','\n').replace('  <shader psdefines="FLOW_CONTROL" />\n','').trimEnd()===historicalMaterial.replaceAll('\r\n','\n').trimEnd(),'Terrain flow control is the sole terrain material change');
check(Object.keys(expected).every(p=>current[p]),'No original pixel input was omitted during recapture');
check(JSON.stringify(meta.inputs)===JSON.stringify(current),'New metadata signs every actual current pixel input');
// Retain the original reclassification contract as a historical regression.
const classified=tool.reclassifyLifetime(original,expected);
const runtimeExpected=structuredClone(original.runtimeChecks);delete runtimeExpected['render/RenderTargetLifetime.lua'];
check(JSON.stringify(classified.runtimeChecks)===JSON.stringify(runtimeExpected),'Historical reclassification preserves non-lifetime runtime checks');
const recapturedRuntimeExpected=structuredClone(runtimeExpected);
for(const file of Object.keys(hoistedScripts))recapturedRuntimeExpected[file.replace(/^scripts\//,'')]=runtimeSignature(fs.readFileSync(file));
check(JSON.stringify(meta.runtimeChecks)===JSON.stringify(recapturedRuntimeExpected),'Actual recapture retains unchanged checks and signs actual bytes and EOL variants of three fixed require hoists');
check(meta.runtimeChecks['render/MatchMapShot.lua']!==undefined,'Full original capture/tone algorithm remains runtime signed');
check(classified.captureImplementationInputs['scripts/render/RenderTargetLifetime.lua'].sha256===original.inputs['scripts/render/RenderTargetLifetime.lua'].sha256,'Historical captured lifecycle provenance retained');
check(classified.captureInputSha256===original.inputSha256,'Historical full capture manifest hash retained');
const bytes=fs.readFileSync('assets/Crater/Minimap.bin');
const native=JSON.parse(fs.readFileSync(meta.nativeEvidence,'utf8').replace(/\0+$/,''));
const validation=JSON.parse(fs.readFileSync(meta.validationEvidence,'utf8'));
const request=JSON.parse(fs.readFileSync(require('path').join(require('path').dirname(meta.nativeEvidence),'request.json')));
check(meta.nativeEvidence.startsWith('docs/migration/evidence/minimap-bake-')&&meta.validationEvidence.startsWith('docs/migration/evidence/minimap-bake-'),'Published native evidence survives cleanup of temporary capture output');
check(JSON.stringify(request.inputs)===JSON.stringify(current),'Native request freezes the exact currently published pixel inputs');
check(JSON.stringify(request.source)===JSON.stringify(meta.source),'Native request and metadata share frozen H5 baseline');
check(JSON.stringify(request.runtime)===JSON.stringify(tool.runtimeIdentity(request.runtime.executable)),'Frozen Runtime executable identity matches actual executable bytes');
check(JSON.stringify(meta.capture.runtime)===JSON.stringify(request.runtime),'Published metadata records actual executable path, SHA and byte count');
const launch=JSON.parse(fs.readFileSync(meta.capture.runtimeLaunchEvidence,'utf8').replace(/^\uFEFF/,''));
check(JSON.stringify(launch.runtime)===JSON.stringify(request.runtime),'Runtime launch evidence matches frozen executable identity');
check(launch.arguments.includes('-tool_mode')&&launch.arguments.includes('-validate')&&launch.arguments.includes('-quality=mobile'),'Actual runtime launch retains capture validation and mobile quality');
if(require('path').resolve(request.runtime.executable)!==require('path').resolve('.cli/UrhoXRuntime.exe'))check(launch.arguments.includes('-pp')&&launch.arguments.includes('-skip_login')&&launch.arguments.includes('-skip_isolation'),'External runtime launch includes project resources and native login/isolation flags');
check(native.result==='PASSED'&&validation.test_result==='PASSED'&&validation.test_assertions.total===6&&validation.test_assertions.failed===0,'Actual renderer capture passes all six pixel, settings and release assertions');
check(validation.summary.lua_errors===0&&validation.summary.resource_errors===0&&!validation.missing_resources.length&&!validation.missing_engine_resources.length,'Native capture has no Lua or missing-resource failures');
check(Object.values(validation.phases).flatMap(p=>p.errors||[]).every(e=>e.category==='engine'&&/^Frame time spike:/.test(e.message)),'Any remaining overall validation failures are retained frame spikes, not hidden functionality errors');
check(meta.capture.textureFilter==='trilinear'&&meta.capture.textureAnisotropy===1&&native.textureFilter==='trilinear'&&native.textureAnisotropy===1,'Native settings and published metadata match production linear filtering');
const archivedImage=require('path').join(require('path').dirname(meta.nativeEvidence),'base.png');
check(bytes.equals(fs.readFileSync(archivedImage))&&hash(bytes)===meta.imageSha256,'Published lossless image is byte-identical to archived newly rendered native output');
if(fs.existsSync(request.image))check(bytes.equals(fs.readFileSync(request.image)),'Existing original temporary native output remains byte-identical to published image');
for(const file of ['stdout.log','stderr.log','runtime-launch.json'])check(fs.existsSync(require('path').join(require('path').dirname(meta.nativeEvidence),file)),'Actual native process evidence archived: '+file);
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
check(info.width===1024&&info.height===1024&&hash(data)===meta.pixelsSha256,'Decoded actual native pixels match published pixel signature and dimensions');
check(meta.pixelsSha256!==original.pixelsSha256,'Linear sampler migration really regenerated changed image pixels');
assert.throws(()=>tool.reclassifyLifetime(original,current));checks.push('Reject reusing historical image for actual changed sampler inputs');
for(const path of ['assets/Scenes/Crater.xml','assets/Crater/material-1.xml','scripts/render/MatchMapShot.lua','scripts/scene/Crater.lua']){
 const candidate=structuredClone(expected);candidate[path]={...candidate[path],sha256:'changed-pixel-input'};
 assert.throws(()=>tool.reclassifyLifetime(original,candidate));checks.push('Reject pixel input change '+path);
}
const missing=structuredClone(expected);delete missing['scripts/render/MatchMapShot.lua'];assert.throws(()=>tool.reclassifyLifetime(original,missing));checks.push('Reject omitted capture algorithm');
const corrupt=structuredClone(original);corrupt.inputSha256='corrupt';assert.throws(()=>tool.reclassifyLifetime(corrupt,expected));checks.push('Reject invalid original capture manifest hash');
check(!Object.keys(current).some(key=>tool.lifetimeInputs.has(key)),'Lifetime module and its GC dependency never enter pixel signature');
console.log(JSON.stringify({checks,fixedBaseline,runtime:request.runtime,nativeEvidence:meta.nativeEvidence,validationEvidence:meta.validationEvidence,validationResult:validation.result,maxFrameTimeMs:validation.max_frame_time_ms}));
}main().catch(e=>{console.error(e.stack);process.exitCode=1});
'''
node_run=subprocess.run(['node','-e',node_checks],cwd=root,capture_output=True,text=True,encoding='utf-8')
if node_run.returncode:
    sys.stderr.write(node_run.stderr)
    node_run.check_returncode()
node_result=json.loads(node_run.stdout)
lua=LuaRuntime(unpack_returned_tuples=True)
real_metadata=json.loads((root/'assets/Crater/Minimap.json').read_text(encoding='utf-8'))
lua.globals().realMetadata=lua.table_from(real_metadata,recursive=True)
inspected=[]
def resource_file(path):
    file=root/('assets' if path.startswith('Scenes/') else 'scripts')/path
    data=file.read_bytes();checksum=0
    for byte in data: checksum=(checksum*65599+byte)&0xffffffff
    inspected.append(path)
    return lua.table_from({'size':len(data),'GetChecksum':lambda *args:checksum,'Dispose':lambda *args:None})
lua.globals().realResourceFile=resource_file
real_runtime=lua.execute(r'''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['core.ResourceData']={Read=function()return realMetadata end}
cache={Exists=function()return true end,GetFile=function(_,path)return realResourceFile(path)end,
 GetResource=function()return {compressed=false,width=1024,height=1024}end}
Time={GetSystemTime=function()return 10 end};FILTER_BILINEAR=1
local cameras,uploads=0,0
Texture2D={new=function()return {SetNumLevels=function()end,SetSRGB=function()end,
 SetData=function()uploads=uploads+1;return true end,SetFilterMode=function()end,Dispose=function()end}end}
local scene={CreateChild=function()cameras=cameras+1;error('Unexpected fallback capture')end}
local Map=require 'render.MatchMapShot'
local shot=Map.New(scene,{scene='Scenes/Crater.xml'});shot:Update()
assert(shot.baked and shot.ready and cameras==0 and uploads==1,'Actual metadata must take existing baked route')
local texture,half=shot:Take();assert(texture and half==320);shot:Dispose();texture:Dispose()
return {baked=true,cameras=cameras,uploads=uploads}
''')
assert 'render/MatchMapShot.lua' in inspected and 'render/RenderTargetLifetime.lua' not in inspected
report={'result':'PASSED','assertions':result['assertions'],'classification':node_result,
        'actualMetadataRuntime':{'baked':real_runtime['baked'],'cameras':real_runtime['cameras'],'uploads':real_runtime['uploads'],'checkedResources':inspected},
        'productionSha256':hashlib.sha256((root/'scripts/render/MatchMapShot.lua').read_bytes()).hexdigest(),'resourceGateSha256':hashlib.sha256((root/'scripts/app/ResourceGate.lua').read_bytes()).hexdigest(),
        'inputs':{str(path.relative_to(root)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest() for path in [root/'tools/migration/bake-match-map.cjs',root/'assets/Crater/Minimap.json',Path(__file__)]},
        'scope':'Actual Lua ResourceGate modern/legacy/cached/synchronous/throw paths; optional baked validation/fallback; exact 10 second cancellation; late callbacks; Process upload/filter failure release and transferred ownership. Real unchanged production LoadBaked against actual recaptured metadata and current resource bytes/checksums. Newly generated native renderer pixels/provenance/settings and historical old-main classification negative controls. Native overall validation frame spikes retained separately; no Web or gameplay performance acceptance.'}
(root/'docs/migration/evidence/match-map-bake-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
