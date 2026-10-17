'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const frozen=process.argv[2]||'.tmp/outgame-cached-1792171171463/identity.json';
const identity=JSON.parse(fs.readFileSync(path.join(root,frozen),'utf8'));
const out=path.join(root,'.tmp/g1-web-cpu-local-sections-candidates');fs.mkdirSync(out,{recursive:true});
const records=[];
function transform(relative,edit){
 const bytes=fs.readFileSync(path.join(identity.source_directory,'scripts',relative));
 const hash=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(hash,identity.identity.scripts[relative]);
 let source=bytes.toString('utf8').replaceAll('\r\n','\n');
 function replace(before,after){assert.equal(source.split(before).length,2,'Single anchor: '+before);source=source.replace(before,after)}
 replace("local M=", "local G1Local=assert(rawget(_G,'G1_WEB_CPU_LOCAL_SECTIONS'),'Isolated local profile missing')\nlocal M=");
 edit(replace);
 const file=path.join(out,path.basename(relative));fs.writeFileSync(file,source);
 records.push({module:relative,baselineSha256:hash,variantSha256:crypto.createHash('sha256').update(source).digest('hex'),file});
}
transform('construction/TurretRange.lua',replace=>{
 for(const [name,next,label]of [['Prepare','local function MissesBounds','TurretRange.Prepare'],['Evaluate','function M.Compute','TurretRange.Evaluate'],['SameContext','function M.For','TurretRange.SameContext']]){
  replace('local function '+name+'(', 'local function '+name+'Raw(');
  replace('\n'+next, '\nlocal function '+name+'(...)\n    local mark=G1Local.Begin('+JSON.stringify(label)+')\n    local result=table.pack('+name+'Raw(...))\n    G1Local.Finish(mark)\n    return table.unpack(result,1,result.n)\nend\n'+next);
 }
 replace('function M.For(bp,owner,checkpoint)\n', 'function M.For(bp,owner,checkpoint)\n    local signatureMark=G1Local.Begin("TurretRange.For.Signatures")\n');
 replace('    local entries,result={},{}', '    G1Local.Finish(signatureMark)\n    local entries,result={},{}');
 replace('        local previous=old and old.entries[p.id]', '        local invalidationMark=G1Local.Begin("TurretRange.For.Invalidations")\n        local previous=old and old.entries[p.id]');
 replace('        if not changed or unaffected then', '        G1Local.Finish(invalidationMark)\n        if not changed or unaffected then');
});
transform('drive/VehicleSpec.lua',replace=>{
 replace('function M.MergeBoxes(cells,checkpoint)\n', 'function M.MergeBoxes(cells,checkpoint)\n    local indexMark=G1Local.Begin("MergeBoxes.Index")\n');
 replace('    table.sort(order,function(a,b)', '    G1Local.Finish(indexMark)\n    local sortMark=G1Local.Begin("MergeBoxes.Sort")\n    table.sort(order,function(a,b)');
 replace('    local m0=0', '    G1Local.Finish(sortMark)\n    local sweepMark=G1Local.Begin("MergeBoxes.Sweep")\n    local m0=0');
 replace('    return boxes\nend\nfunction M.Debris', '    G1Local.Finish(sweepMark)\n    return boxes\nend\nfunction M.Debris');
});
fs.writeFileSync(path.join(out,'variants.json'),JSON.stringify({frozen,records,boundary:'Instrumentation only. No production edits or timing evidence.'},null,2)+'\n');
console.log(JSON.stringify({status:'PREPARED_VARIANTS_NOT_RUN',frozen,records}));
