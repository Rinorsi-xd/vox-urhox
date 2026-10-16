const fs = require('node:fs');
const assert = require('node:assert/strict');
const {heightAt, evaluateTerrainConnector, findRoadConnector} = require('./story-road-connector.cjs');
const layout = JSON.parse(fs.readFileSync('assets/Crater/Layout.json', 'utf8'));
layout.terrain.heights = [];
for (const part of layout.dataParts.parts.filter(p => p.field === 'heights')) {
 const values = JSON.parse(fs.readFileSync('assets/' + part.path, 'utf8'));
 for (let i = 0; i < values.length; i++) layout.terrain.heights[part.first - 1 + i] = values[i];
}
const from = [-30.242109298706055, 4.737438201904297, -222.00038146972656];
const bad = evaluateTerrainConnector(from, layout.nav.nodes.bEt, layout.terrain);
assert.equal(bad.reachable, false);
assert.equal(bad.reason, 'steep-terrain');
assert.ok(bad.maxSlopeDeg > 15);
assert.equal(bad.startHeight, 6);
assert.equal(bad.endHeight, 6);
const selected = findRoadConnector(from, layout);
assert.equal(selected.id, 'bP');
assert.equal(selected.profile.reachable, true);
assert.ok(selected.profile.maxSlopeDeg < 1e-8);
assert.ok(selected.rejected.some(p => p.id === 'bEt' && p.reason === 'steep-terrain'));
assert.equal(evaluateTerrainConnector([0, 6, -234], layout.nav.nodes.bY, layout.terrain).reachable, true);
assert.equal(evaluateTerrainConnector([0, 6, -252], layout.nav.nodes.bEt, layout.terrain).reachable, true);
assert.equal(evaluateTerrainConnector(from, layout.nav.nodes.k2, layout.terrain).reason, 'node-not-on-terrain');
assert.equal(findRoadConnector(from, layout, {maxDistance: 1}), null);
assert.equal(heightAt(layout.terrain, 321, 0), null);
assert.equal(heightAt({}, 0, 0), null);
assert.equal(evaluateTerrainConnector(from, [1000, 0, 0], layout.terrain).reachable, false);
// The interior peak is crossed even though start/end height and grade are zero.
const peak = {size: 4, n: 2, heights: [0, 0, 0, 0, 2, 0, 0, 0, 0]};
assert.equal(evaluateTerrainConnector([-2, 0, 0], [2, 0, 0], peak).reachable, false);
assert.throws(() => evaluateTerrainConnector([NaN, 0, 0], [0, 0, 0], peak));
assert.throws(() => evaluateTerrainConnector([0, 0, 0], [0, 0, 0], peak, {maxSlopeDeg: 90}));
console.log(JSON.stringify({result: 'PASS', checks: 20, rejectedS4: {id: 'bEt', maxSlopeDeg: bad.maxSlopeDeg, low: Math.min(...bad.profile.map(p => p.height))}, selectedS4: {id: selected.id, maxSlopeDeg: selected.profile.maxSlopeDeg}, boundary: 'Actual source-coordinate crater 2m terrain and S4 runtime position. Pure terrain connector only; no chassis clearance, static-hull/rock clearance, bridge traversal, driving dynamics, GPU or natural completion acceptance. Original nav edges untouched.'}, null, 2));
