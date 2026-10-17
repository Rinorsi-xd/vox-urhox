'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),target=path.resolve(root,process.argv[2]||'.tmp/native-engine-profiler-capability-1017-c');
const runtime=path.join(root,'.tmp/perf-effects-runtime-beta40/UrhoXRuntime.exe');
const resources=path.join(root,'.tmp/perf-effects-zap-native-1017-v2/resources');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert(target.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(target),'Fresh isolated target required');
assert(fs.existsSync(runtime));assert(fs.existsSync(resources));
fs.mkdirSync(path.join(target,'scripts'),{recursive:true});fs.mkdirSync(path.join(target,'.project'),{recursive:true});
fs.mkdirSync(path.join(target,'assets/Fonts'),{recursive:true});
const font=fs.readFileSync(path.join(root,'assets/Fonts/MiSans-Regular.ttf'));
fs.writeFileSync(path.join(target,'assets/Fonts/MiSans-Regular.ttf'),font);
const probe=fs.readFileSync(path.join(__dirname,'native-engine-profiler-capability.lua'));
fs.writeFileSync(path.join(target,'scripts/native-engine-profiler-capability.lua'),probe);
fs.writeFileSync(path.join(target,'.project/settings.json'),JSON.stringify({'@runtime':{multiplayer:{enabled:false}},build:{asset_dirs:['../scripts','../assets']}})+'\n');
const args=['native-engine-profiler-capability.lua','-tapcode_dir='+target,'-pp',resources+path.sep,
 '-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info','-probe-output='+path.join(target,'capability.json')];
const identity={status:'PREPARED_NOT_RUN',target,runtime,runtimeSha256:sha(fs.readFileSync(runtime)),resources,
 probeSha256:sha(probe),fontSha256:sha(font),args,workingDirectory:root,externalDeadlineSeconds:20,
 boundary:'Root-only actual launch. Empty scene capability with one native dump after20frames and exit after22frames; external20seconddeadline, no Time clock, HUD, GPU queries, memory sampling/fullGC or production scripts. Native capability cannot symbolize Web WASM or establish combat timing.'};
fs.writeFileSync(path.join(target,'identity.json'),JSON.stringify(identity,null,2)+'\n');
console.log(JSON.stringify(identity,null,2));
