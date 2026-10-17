'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

function analyze(directory, outputName = 'independent-allocation-stacks.json') {
  assert.equal(path.basename(outputName), outputName);
  const input = path.join(directory, 'drive.cpuprofile');
  const bytes = fs.readFileSync(input);
  const profile = JSON.parse(bytes);
  const nodes = new Map(profile.nodes.map(node => [node.id, node]));
  const parents = new Map();
  for (const node of profile.nodes) for (const child of node.children || []) {
    assert(!parents.has(child), 'CPU profile nodes must form a tree');
    parents.set(child, node.id);
  }
  assert.equal(profile.samples.length, profile.timeDeltas.length);
  const nodeStack = id => {
    const result = [];
    const visited = new Set();
    while (id !== undefined) {
      assert(!visited.has(id), 'Cycle in CPU profile');
      visited.add(id);
      const node = nodes.get(id);
      assert(node, `Missing CPU profile node ${id}`);
      result.push(node.callFrame.functionName);
      id = parents.get(id);
    }
    return result;
  };
  const sortedRows = (rows, total) => [...rows.values()]
    .sort((a, b) => b.weightUs - a.weightUs)
    .map(({weightUs, ...row}) => ({...row, sampledWeightMs: weightUs / 1000, share: weightUs / total}));
  const targets = new Map([
    ['wasm-function[767]', {confirmedName: '_malloc', exportName: 'yk'}],
    ['wasm-function[629]', {confirmedName: '_free', exportName: 'xk'}],
  ]);
  for (const entry of targets.values()) Object.assign(entry, {
    samples: 0, weightUs: 0, directParents: new Map(), parentPaths: new Map(), ancestors: new Map(),
  });
  let totalUs = 0;
  const invalidDeltas = [];
  for (let i = 0; i < profile.samples.length; i++) {
    const raw = profile.timeDeltas[i];
    const valid = Number.isFinite(raw) && raw >= 0;
    if (!valid) invalidDeltas.push({index: i, value: raw, nodeId: profile.samples[i]});
    const weight = valid ? raw : 0;
    totalUs += weight;
    const stack = nodeStack(profile.samples[i]);
    const entry = targets.get(stack[0]);
    if (!entry) continue;
    entry.samples++;
    entry.weightUs += weight;
    const add = (map, key, data) => {
      const row = map.get(key) || {...data, samples: 0, weightUs: 0};
      row.samples++;
      row.weightUs += weight;
      map.set(key, row);
    };
    add(entry.directParents, stack[1], {name: stack[1] || null});
    const prefix = stack.slice(1, 9);
    add(entry.parentPaths, JSON.stringify(prefix), {parentsFromLeaf: prefix});
    for (const ancestor of new Set(stack.slice(1))) add(entry.ancestors, ancestor, {name: ancestor});
  }
  const result = {
    status: 'ORIGINAL_ALLOCATION_SELF_SAMPLE_STACKS_ANALYZED',
    boundary: 'Offline aggregation only. Confirmed malloc/free names come from the exact runtime export mapping in independent-wasm-profile-v2.json. Other WASM numbers are not assigned source names. Samples are statistical self weights, not invocation counts, allocated bytes, or exact durations. Ancestor rows overlap and must not be summed.',
    input: {path: path.resolve(input), sha256: crypto.createHash('sha256').update(bytes).digest('hex')},
    totalSamples: profile.samples.length, nonnegativeDeltaSumMs: totalUs / 1000, invalidDeltas,
    targets: [...targets].map(([functionName, entry]) => ({
      functionName, confirmedName: entry.confirmedName, exportName: entry.exportName,
      samples: entry.samples, sampledWeightMs: entry.weightUs / 1000, profileShare: entry.weightUs / totalUs,
      directParents: sortedRows(entry.directParents, entry.weightUs),
      parentPaths: sortedRows(entry.parentPaths, entry.weightUs),
      ancestors: sortedRows(entry.ancestors, entry.weightUs),
    })),
  };
  const mapping = JSON.parse(fs.readFileSync(path.join(directory, 'independent-wasm-profile-v2.json'), 'utf8'));
  for (const entry of result.targets) {
    const row = mapping.top.find(row => row.name === entry.functionName);
    assert(row?.bindings.some(binding => binding.local === entry.confirmedName && binding.exportName === entry.exportName));
    assert.equal(entry.sampledWeightMs, row.sampledWeightMs);
    assert.equal(entry.samples, row.samples);
    assert.equal(entry.directParents.reduce((sum, row) => sum + row.samples, 0), entry.samples);
  }
  assert.equal(result.nonnegativeDeltaSumMs, mapping.profile.nonnegativeDeltaSumMs);
  assert.deepEqual(result.invalidDeltas, mapping.profile.invalidDeltas);
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex'), result.input.sha256);
  fs.writeFileSync(path.join(directory, outputName), JSON.stringify(result, null, 2) + '\n', {flag: 'wx'});
  return result;
}

module.exports = {analyze};
if (require.main === module) {
  const result = analyze(path.resolve(process.argv[2]), process.argv[3]);
  console.log(JSON.stringify({status: result.status, input: result.input,
    targets: result.targets.map(({parentPaths, ancestors, ...entry}) => ({...entry,
      parentPaths: parentPaths.slice(0, 5), ancestors: ancestors.slice(0, 8)}))}, null, 2));
}
