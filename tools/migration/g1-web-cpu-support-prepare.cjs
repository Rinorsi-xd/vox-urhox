'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),frozen='.tmp/outgame-cached-1792174992428/identity.json';
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
function once(source,before,after){assert.equal(source.split(before).length,2,'Unique support anchor: '+before);return source.replace(before,after)}
function suspension(source){
 source="local Probe=assert(rawget(_G,'G1_WEB_CPU_SUPPORT_SCOPE'))\n"+source;
 source=once(source,'    local grounded=0\n','    local grounded=0\n    Probe.Enter("apply.support")\n');
 source=once(source,'    -- Calculate all contact impulses before applying any, matching the source order.','    Probe.Switch("apply.contact")\n    -- Calculate all contact impulses before applying any, matching the source order.');
 source=once(source,'    for i,w in ipairs(v.wheels) do\n        local s=self.states[i]\n        if s.grounded then\n            body.applyImpulseAtPoint(ScaledVec(s.forward',
  '    Probe.Switch("apply.impulses")\n    for i,w in ipairs(v.wheels) do\n        local s=self.states[i]\n        if s.grounded then\n            body.applyImpulseAtPoint(ScaledVec(s.forward');
 source=once(source,'    end\nend\nreturn M','    end\n    Probe.Leave()\nend\nreturn M');return source;
}
function space(source){
 source="local Probe=assert(rawget(_G,'G1_WEB_CPU_SUPPORT_SCOPE'))\n"+source;
 source=once(source,'    local ray=Ray(', '    local caller=Probe.Caller()\n    Probe.Enter("ray."..caller..".construct")\n    local ray=Ray(');
 source=once(source,'    local results=self.world:Raycast(', '    Probe.Switch("ray."..caller..".native")\n    local results=self.world:Raycast(');
 source=once(source,'    for _,hit in ipairs(results) do', '    Probe.Switch("ray."..caller..".filter")\n    for _,hit in ipairs(results) do');
 source=once(source,'            return {dist=hit.distance','            local result={dist=hit.distance');
 source=once(source,'collider=id}\n            end','collider=id}\n            Probe.Leave();return result\n            end');
 source=once(source,'    return nil\nend\nfunction Space:Step','    Probe.Leave();return nil\nend\nfunction Space:Step');return source;
}
function build(){
 const identity=JSON.parse(fs.readFileSync(path.join(root,frozen),'utf8'));
 const out=path.join(root,'.tmp/g1-web-cpu-support-candidates');fs.mkdirSync(out,{recursive:true});
 const variants={};
 for(const [relative,transform]of [['drive/RaySuspension.lua',suspension],['physics/Space.lua',space]]){
  const bytes=fs.readFileSync(path.join(identity.source_directory,'scripts',relative));assert.equal(sha(bytes),identity.identity.scripts[relative]);
  const file=path.join(out,path.basename(relative)),value=transform(bytes.toString('utf8').replaceAll('\r\n','\n'));fs.writeFileSync(file,value);
  variants[relative]={file,baseline:sha(bytes),instrumented:sha(value)};
 }
 const scope=fs.readFileSync(path.join(__dirname,'perf-drive-sections-scope.lua'),'utf8');
 let prefix=fs.readFileSync(path.join(__dirname,'g1-web-cpu-support-profile.lua'),'utf8');prefix=once(prefix,'-- SUPPORT_SCOPE_FACTORY',scope);
 let probe=fs.readFileSync(path.join(__dirname,'g1-web-cpu-probe.lua'),'utf8');
 const start=probe.indexOf('local function Instrument()\n'),end=probe.indexOf('local function Fixture()\n',start);assert(start>=0&&end>start);
 probe=probe.slice(0,start)+'local function Instrument()return SupportInstrument(Vehicle,Space,Gait,Legs,Suspension,clock)end\n'+probe.slice(end);
 probe=once(probe,' local fixture=Fixture();',' PrepareSupportResources()\n local fixture=Fixture();');
 probe=once(probe,'samplesMs=samples,scopes=rows,metadata=', 'samplesMs=samples,scopes=rows,supportScopes=SupportRows,supportPreload=SupportPreload,metadata=');
 const file=path.join(out,'probe.lua');fs.writeFileSync(file,prefix+'\n'+probe);
 const record={status:'PREPARED_NOT_RUN',frozen,variants,probe:{file,sha256:sha(prefix+'\n'+probe)},
  boundary:'Instrumentation only. Three Apply loops and caller-labelled Raycast phases. Reuses G1 fixture and existing nested scope engine; no production changes or timing evidence.'};
 fs.writeFileSync(path.join(out,'candidate.json'),JSON.stringify(record,null,2)+'\n');return record;
}
module.exports={suspension,space,build};if(require.main===module)console.log(JSON.stringify(build()));
