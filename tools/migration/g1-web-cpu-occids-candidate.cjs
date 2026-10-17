'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const identityPath = path.join(root, '.tmp/outgame-cached-1792169432758/identity.json');
const source = JSON.parse(fs.readFileSync(identityPath, 'utf8'));
const relative = 'construction/TurretRange.lua';
const original = fs.readFileSync(path.join(source.source_directory, 'scripts', relative));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha(original), source.identity.scripts[relative]);
let candidate = original.toString('utf8');
function replaceOnce(before, after) {
    assert.equal(candidate.split(before).length, 2, 'Exact single patch anchor');
    candidate = candidate.replace(before, after);
}
replaceOnce('    return {def=def,samples=samples,pv=pv,reach=reach,owner=mine,occ=occ,rot=part.rot,bounds=',
    '    local occIds={};for _,id in pairs(occ) do occIds[id]=true end\n' +
    '    return {def=def,samples=samples,pv=pv,reach=reach,owner=mine,occ=occ,occIds=occIds,rot=part.rot,bounds=');
replaceOnce('if unaffected then for _,id in pairs(context.occ) do if invalidated[id] then unaffected=false;break end end end',
    'if unaffected then for id in pairs(context.occIds) do if invalidated[id] then unaffected=false;break end end end');
const output = path.join(root, '.tmp/g1-web-cpu-occids-candidate');
fs.mkdirSync(output, { recursive: true });
const candidatePath = path.join(output, 'TurretRange.lua');
fs.writeFileSync(candidatePath, candidate);
const info = { status: 'OFFLINE_CANDIDATE_NOT_BENCHMARKED', source: identityPath,
    module: relative, baselineSha256: sha(original), candidateSha256: sha(candidate), candidatePath,
    boundary: 'Only derived temporary candidate; production and source freeze unchanged.' };
fs.writeFileSync(path.join(output, 'candidate.json'), JSON.stringify(info, null, 2) + '\n');
console.log(JSON.stringify(info));
