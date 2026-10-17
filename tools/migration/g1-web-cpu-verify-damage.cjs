'use strict';
const fs = require('node:fs');
const assert = require('node:assert/strict');

const reportPath = process.argv[2];
if (!reportPath) throw new Error('Usage: node g1-web-cpu-verify-damage.cjs report.json');
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
assert.equal(report.status, 'PASS');
assert.equal(report.shutdown, 'CLOSED');
assert.equal(report.errors.length, 0);
assert.equal(report.httpErrors.length, 0);
const fixtures = report.result.damage.fixtures;
assert.equal(fixtures.length, 5);
assert.equal(report.damageProgress.length, 12);
const checks = [];
let progressIndex = 0;
const sumSelf = scopes => scopes.reduce((sum, scope) => sum + scope.selfMs, 0);
function verifyScopes(scopes, outerMs, context) {
    assert.equal(scopes.length, 23, context);
    assert.equal(new Set(scopes.map(scope => scope.name)).size, 23, context);
    for (const scope of scopes) {
        assert.ok(scope.selfMs >= 0 && scope.ms >= scope.selfMs, context + ': ' + scope.name);
        assert.ok(Number.isInteger(scope.calls) && scope.calls >= 0, context + ': calls');
    }
    const selfMs = sumSelf(scopes);
    assert.ok(selfMs <= outerMs, `${context}: scopes ${selfMs} > outer ${outerMs}`);
    return { outerMs, selfMs, residualMs: outerMs - selfMs };
}
for (const fixture of fixtures) {
    checks.push({ fixture: fixture.name, combat: fixture.combat, kind: 'initial build',
        ...verifyScopes(fixture.initialBuildScopes, fixture.initialBuildMs, fixture.name + ': initial') });
    for (const stage of fixture.stages) {
        const progress = report.damageProgress[progressIndex++];
        assert.equal(progress.name, fixture.name);
        assert.equal(progress.combat, fixture.combat);
        const { stateDigest, ...transportStage } = stage;
        assert.deepEqual(progress.stage, transportStage);
        checks.push({ fixture: fixture.name, combat: fixture.combat, kind: stage.kind,
            damage: verifyScopes(stage.damageScopes, stage.damageMs, fixture.name + ': damage'),
            flush: verifyScopes(stage.flushScopes, stage.flushMs, fixture.name + ': flush') });
    }
}
assert.equal(progressIndex, 12);
console.log(JSON.stringify({ status: 'PASS', source: reportPath, fixtures: 5, stages: progressIndex,
    scopesPerMeasurement: 23, progressMatchesFinal: true, checks }, null, 2));
