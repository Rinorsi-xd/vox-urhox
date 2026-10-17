'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert(opts.frozen&&opts.out&&opts.candidate);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8').replace(/^\uFEFF/,''));
 const baseline=fs.readFileSync(path.join(frozen.source_directory,'scripts/render/ObjectiveView.lua'),'utf8');
 const candidate=fs.readFileSync(path.resolve(root,opts.candidate),'utf8'),probe=fs.readFileSync(path.join(__dirname,opts.native==='1'?'objective-web-native-probe.lua':'objective-web-cpu-probe.lua'),'utf8');
 assert.equal(sha(baseline),frozen.identity.scripts['render/ObjectiveView.lua']);
 assert(!baseline.includes(']====]')&&!candidate.includes(']====]'));
 const steps=Number(opts.steps||300);assert(Number.isInteger(steps)&&steps>=100&&steps<=600);
 const prepared=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--scenario','lanes','--steps','600','--warmup','0']);
 const configuration={seed:17102026,steps,warmup:30,dt:1/60,order:['A1','B1','B2','A2'],cases:['conquest','escort']};
 if(opts.native==='1'){configuration.nativeReadback=true;configuration.order=['A','B'];}
 const sourceIdentity={beforeSha256:sha(baseline),candidateSha256:sha(candidate),probeSha256:sha(probe),frozenFingerprint:frozen.identity.scriptFingerprint};
 const entry=Buffer.from('G1_OBJECTIVE_CONFIG=cjson.decode([====['+JSON.stringify(configuration)+']====])\nG1_OBJECTIVE_IDENTITY=cjson.decode([====['+JSON.stringify(sourceIdentity)+']====])\nG1_OBJECTIVE_BEFORE=[====['+baseline+']====]\nG1_OBJECTIVE_CANDIDATE=[====['+candidate+']====]\n'+probe);
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path)),row=manifest.files.find(r=>r.fs_path==='main.lua');
 row.hash=require('node:zlib').crc32(entry).toString(16).padStart(8,'0');row.size=entry.length;
 fs.writeFileSync(path.join(prepared.source_directory,'dist/assets',row.uuid+'-'+row.hash+row.ext),entry);
 fs.writeFileSync(path.join(prepared.source_directory,'scripts/main.lua'),entry);
 const latest=JSON.parse(fs.readFileSync(path.join(prepared.source_directory,'dist/latest.json'))),bytes=Buffer.from(JSON.stringify(manifest));
 latest.client=require('node:zlib').crc32(bytes).toString(16).padStart(8,'0');
 prepared.manifest_path=path.join(prepared.source_directory,'dist',latest.version,'manifest-'+latest.client+'.json');fs.writeFileSync(prepared.manifest_path,bytes);
 for(const name of ['latest.json',latest.version+'/version.json',latest.version.split('.')[0]+'.x.x.json'])fs.writeFileSync(path.join(prepared.source_directory,'dist',name),JSON.stringify(latest));
 prepared.identity.scripts['main.lua']=sha(entry);prepared.identity.scriptFingerprint=sha(JSON.stringify(Object.entries(prepared.identity.scripts).sort()));
 prepared.g1WebCpu.entrySha256=sha(entry);prepared.objectiveWebCpu={configuration,sourceIdentity,entrySha256:sha(entry),isolated:true};
 fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');return prepared;
}
module.exports={prepare};
if(require.main===module){try{const r=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(r.source_directory,'identity.json'),objective:r.objectiveWebCpu}))}catch(e){console.error(e.stack);process.exitCode=1}}
