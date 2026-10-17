'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),frozen='.tmp/outgame-cached-1792171171463/identity.json';
const identity=JSON.parse(fs.readFileSync(path.join(root,frozen),'utf8'));
const relative='drive/VehicleSpec.lua',bytes=fs.readFileSync(path.join(identity.source_directory,'scripts',relative));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(sha(bytes),identity.identity.scripts[relative]);
const source=bytes.toString('utf8').replaceAll('\r\n','\n');
const start=source.indexOf('function M.MergeBoxes(cells,checkpoint)\n'),end=source.indexOf('function M.Debris(parts)\n',start);
assert(start>=0&&end>start);const original=source.slice(start,end);let numeric=original;
function replace(before,after){assert.equal(numeric.split(before).length,2,'Exact single anchor');numeric=numeric.replace(before,after)}
replace('    for key,c in pairs(cells) do left[key]=c.mass;order[#order+1]=c.pos end',`    for key,c in pairs(cells) do
        local p=c.pos
        if type(p)~='table' or type(c.mass)~='number' then return MergeBoxesString(cells,checkpoint) end
        for k=1,3 do
            if math.type(p[k])~='integer' then return MergeBoxesString(cells,checkpoint) end
        end
        if key~=Key(p[1],p[2],p[3]) then return MergeBoxesString(cells,checkpoint) end
        local layer=left[p[2]]
        if not layer then layer={};left[p[2]]=layer end
        local row=layer[p[3]]
        if not row then row={};layer[p[3]]=row end
        if row[p[1]]~=nil then return MergeBoxesString(cells,checkpoint) end
        row[p[1]]=c.mass;order[#order+1]=p
    end`);
replace('    local m0=0',`    local function Get(x,y,z)
        local layer=left[y];local row=layer and layer[z]
        return row and row[x]
    end
    local m0=0`);
replace('local mass=left[Key(x,y,z)]','local mass=Get(x,y,z)');
replace('local seed=left[Key(x0,y0,z0)]','local seed=Get(x0,y0,z0)');
replace('local key=Key(x,y,z);mass=mass+left[key];left[key]=nil','local row=left[y][z];mass=mass+row[x];row[x]=nil');
const backup=original.replace('function M.MergeBoxes(cells,checkpoint)','local function MergeBoxesString(cells,checkpoint)');
const candidate=source.slice(0,start)+backup+numeric+source.slice(end);
const out=path.join(root,'.tmp/g1-web-cpu-merge-numeric-candidate');fs.mkdirSync(out,{recursive:true});
const file=path.join(out,'VehicleSpec.lua');fs.writeFileSync(file,candidate);
const record={status:'OFFLINE_CANDIDATE_NOT_BENCHMARKED',frozen,module:relative,baselineSha256:sha(bytes),candidateSha256:sha(candidate),file,
 boundary:'Sparse numeric y/z/x index with exact baseline fallback. No production edits.'};
fs.writeFileSync(path.join(out,'candidate.json'),JSON.stringify(record,null,2)+'\n');console.log(JSON.stringify(record));
