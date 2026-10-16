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
const checks=[];function check(ok,label){assert(ok,label);checks.push(label)}
async function main(){
const current=tool.inputs(),expected=structuredClone(original.inputs);delete expected['scripts/render/RenderTargetLifetime.lua'];
const changed=Object.keys(current).filter(p=>JSON.stringify(current[p])!==JSON.stringify(expected[p]));
check(JSON.stringify(changed.sort())===JSON.stringify(['assets/Crater/albedo.xml','assets/Crater/material-1.xml','assets/Crater/nra.xml','tools/migration/bake-match-map-runtime.lua']),'Actual capture differs from historical map only in linear filters, terrain flow control and signed bake configuration');
const material=fs.readFileSync('assets/Crater/material-1.xml','utf8');
const historicalMaterial=cp.execFileSync('git',['show','48ef15f2:assets/Crater/material-1.xml'],{encoding:'utf8'});
check(material.replaceAll('\r\n','\n').replace('  <shader psdefines="FLOW_CONTROL" />\n','').trimEnd()===historicalMaterial.replaceAll('\r\n','\n').trimEnd(),'Terrain flow control is the sole terrain material change');
check(Object.keys(expected).every(p=>current[p]),'No original pixel input was omitted during recapture');
check(JSON.stringify(meta.inputs)===JSON.stringify(current),'New metadata signs every actual current pixel input');
// Retain the original reclassification contract as a historical regression.
const classified=tool.reclassifyLifetime(original,expected);
const runtimeExpected=structuredClone(original.runtimeChecks);delete runtimeExpected['render/RenderTargetLifetime.lua'];
check(JSON.stringify(classified.runtimeChecks)===JSON.stringify(runtimeExpected),'Historical reclassification preserves non-lifetime runtime checks');
check(JSON.stringify(meta.runtimeChecks)===JSON.stringify(runtimeExpected),'Actual recapture retains all unchanged runtime Lua checks and EOL variants');
check(meta.runtimeChecks['render/MatchMapShot.lua']!==undefined,'Full original capture/tone algorithm remains runtime signed');
check(classified.captureImplementationInputs['scripts/render/RenderTargetLifetime.lua'].sha256===original.inputs['scripts/render/RenderTargetLifetime.lua'].sha256,'Historical captured lifecycle provenance retained');
check(classified.captureInputSha256===original.inputSha256,'Historical full capture manifest hash retained');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const bytes=fs.readFileSync('assets/Crater/Minimap.bin');
const native=JSON.parse(fs.readFileSync(meta.nativeEvidence,'utf8').replace(/\0+$/,''));
const validation=JSON.parse(fs.readFileSync(meta.validationEvidence,'utf8'));
const request=JSON.parse(fs.readFileSync(require('path').join(require('path').dirname(meta.nativeEvidence),'request.json')));
check(JSON.stringify(request.inputs)===JSON.stringify(current),'Native request freezes the exact currently published pixel inputs');
check(JSON.stringify(request.source)===JSON.stringify(meta.source),'Native request and metadata share frozen H5 baseline');
check(native.result==='PASSED'&&validation.test_result==='PASSED'&&validation.test_assertions.total===6&&validation.test_assertions.failed===0,'Actual renderer capture passes all six pixel, settings and release assertions');
check(validation.summary.lua_errors===0&&validation.summary.resource_errors===0&&!validation.missing_resources.length&&!validation.missing_engine_resources.length,'Native capture has no Lua or missing-resource failures');
check(Object.values(validation.phases).flatMap(p=>p.errors||[]).every(e=>e.category==='engine'&&/^Frame time spike:/.test(e.message)),'Any remaining overall validation failures are retained frame spikes, not hidden functionality errors');
check(meta.capture.textureFilter==='trilinear'&&meta.capture.textureAnisotropy===1&&native.textureFilter==='trilinear'&&native.textureAnisotropy===1,'Native settings and published metadata match production linear filtering');
check(bytes.equals(fs.readFileSync(request.image))&&hash(bytes)===meta.imageSha256,'Published lossless image is byte-identical to newly rendered native output');
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
console.log(JSON.stringify({checks,nativeEvidence:meta.nativeEvidence,validationEvidence:meta.validationEvidence,validationResult:validation.result,maxFrameTimeMs:validation.max_frame_time_ms}));
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
