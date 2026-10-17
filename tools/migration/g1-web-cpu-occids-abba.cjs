'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const args = process.argv.slice(2);
assert.ok(args.length===4 || (args.length===6 && args[4]==='--out'), 'Pass four report.json paths in A1 B1 B2 A2 order, optional --out summary.json');
const paths = args.slice(0,4);
const runs = paths.map(file => JSON.parse(fs.readFileSync(file, 'utf8')));
const labels = ['A1', 'B1', 'B2', 'A2'];
const changed = 'construction/TurretRange.lua';
for (const [index, run] of runs.entries()) {
    assert.equal(run.status, 'PASS', labels[index]);
    assert.equal(run.shutdown, 'CLOSED', labels[index]);
    assert.equal(run.errors.length, 0);assert.equal(run.httpErrors.length, 0);
    assert.deepEqual(run.runtimeHashes, runs[0].runtimeHashes, 'Same Web Runtime');
    assert.equal(run.result.configuration.mode, 'timing');
    assert.equal(run.result.configuration.scenario, 'damage');
    assert.deepEqual(run.result.configuration, runs[0].result.configuration);
    const scripts = run.identity.identity.scripts;
    const initialScripts = runs[0].identity.identity.scripts;
    assert.deepEqual(Object.keys(scripts), Object.keys(initialScripts));
    for (const name of Object.keys(scripts)) if (name !== changed) assert.equal(scripts[name], initialScripts[name], name);
    assert.equal(run.result.damage.fixtures.length, 5);
    assert.equal(run.damageProgress.length, 12);
    assert.deepEqual(run.result.damage.randomTail, runs[0].result.damage.randomTail, 'RNG tail');
    assert.equal(run.result.damage.stateDigest, runs[0].result.damage.stateDigest, 'Aggregate state');
}
assert.equal(runs[0].identity.identity.scripts[changed], runs[3].identity.identity.scripts[changed]);
assert.equal(runs[1].identity.identity.scripts[changed], runs[2].identity.identity.scripts[changed]);
assert.notEqual(runs[0].identity.identity.scripts[changed], runs[1].identity.identity.scripts[changed]);
const rows = [];
for (let fixtureIndex=0;fixtureIndex<5;fixtureIndex++) {
    const fixtures=runs.map(run=>run.result.damage.fixtures[fixtureIndex]);
    const first=fixtures[0];
    for (const fixture of fixtures) {
        assert.equal(fixture.name,first.name);assert.equal(fixture.combat,first.combat);
        assert.match(fixture.initialRangesDigest,/^[a-f0-9]{16}$/);
        assert.equal(fixture.initialRangesDigest,first.initialRangesDigest);
        assert.equal(fixture.initialBuildScopes,false,'No profile wrappers');
        assert.equal(fixture.stages.length,first.stages.length);
    }
    rows.push({name:first.name,combat:first.combat,kind:'initial build',ms:fixtures.map(f=>f.initialBuildMs)});
    for (let stageIndex=0;stageIndex<first.stages.length;stageIndex++) {
        const stages=fixtures.map(f=>f.stages[stageIndex]);
        for(const stage of stages) {
            for(const key of ['kind','target','amount','partsBefore','partsAfter','alive','budgetBefore','budgetAfter','debrisPieces','stateDigest','rangeDigest'])
                assert.deepEqual(stage[key],stages[0][key],key);
            assert.match(stage.rangeDigest,/^[a-f0-9]{16}$/);
            assert.equal(stage.damageScopes,false);assert.equal(stage.flushScopes,false);
        }
        const times=stages.map(s=>s.flushMs);
        rows.push({name:first.name,combat:first.combat,kind:stages[0].kind,ms:times,
            baselineMeanMs:(times[0]+times[3])/2,candidateMeanMs:(times[1]+times[2])/2});
    }
}
const target=rows.filter(row=>row.name==='megaMech' && !row.combat && /^part [123]$/.test(row.kind));
assert.equal(target.length,3);
const targetA=target.reduce((sum,row)=>sum+row.baselineMeanMs,0),targetB=target.reduce((sum,row)=>sum+row.candidateMeanMs,0);
const summary={status:'EQUIVALENT_RESULTS',order:labels,paths,rows,
    equivalence:{sameRuntime:true,onlyTargetModuleDiffers:true,configuration:true,initialRanges:true,stageRanges:true,state:true,randomTail32:true},
    shutdowns:runs.map((run,index)=>({label:labels[index],shutdown:run.shutdown,runtimeErrors:run.errors.length,httpErrors:run.httpErrors.length})),
    target:{name:'megaMech noncombat three single-part Flush sum',baselineMeanMs:targetA,candidateMeanMs:targetB,
        decision:targetB>=targetA?'REJECT_NO_TARGET_BENEFIT':'REQUIRES_MORE_VALIDATION',productionModified:false},
    boundary:'Two repeated measurements per variant. No mobile, sustained FPS or statistical improvement claim.'};
const text=JSON.stringify(summary,null,2)+'\n';
if(args[5]){fs.mkdirSync(path.dirname(args[5]),{recursive:true});fs.writeFileSync(args[5],text)}
console.log(text);
