// Evaluate the unchanged frozen H5 presenter to produce future Lua goldens.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const commit = 'b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/baselines', `${commit}.json`), 'utf8'));
const relative = 'three/src/battle/endlessView.js';
const sourcePath = path.join(baseline.snapshot, relative);
const source = fs.readFileSync(sourcePath, 'utf8');
const hash = crypto.createHash('sha256').update(source).digest('hex');
if (hash !== baseline.files[relative].sha256) throw new Error('Frozen source hash drift');

class Group {
  add() {}
}

async function main() {
  const context = vm.createContext({});
  const three = new vm.SyntheticModule(['Group'], function () { this.setExport('Group', Group); }, {context});
  const module = new vm.SourceTextModule(source, {context, identifier: sourcePath});
  await module.link(specifier => {
    if (specifier !== 'three') throw new Error(`Unexpected source dependency ${specifier}`);
    return three;
  });
  await module.evaluate();
  const View = module.namespace.EndlessView;
  const rows = [];
  const times = [0, 0.119999999, 0.12, 0.120000001, 0.239999999, 0.24, 0.36, 0.48,
    0.599999999, 0.6, 0.600000001, 1, 2.879999999, 2.88, 2.999999999, 3, 3.000000001, 4];
  for (const height of [0, 1, 3, 20.5]) {
    for (const started of [0, 1.2, 72.37]) {
      const drive = {sim: {time: started}, scene3: {add() {}}, track: {},
        combat: {units: new Map()}, spec: {bounds: {min: [-1, -0.5, -2], max: [1, height - 0.5, 2]}},
        visual: {root: {position: {y: 19.25}, visible: true}}};
      const view = new View(drive);
      view.rise(started);
      for (const delta of times) {
        const now = started + delta;
        drive.sim.time = now;
        // The actual DriveView restores physics pose every frame before the
        // source EndlessView subtracts its presentation-only rise offset.
        drive.visual.root.position.y = 19.25;
        view.update({run: {shield: {hp: 0, max: 1}}, invulnerableUntil: started + 3});
        rows.push({name: `h${height}-start${started}-dt${delta}`, height, started, now,
          invulnerableUntil: started + 3, riseUntil: view.riseUntil,
          offset: 19.25 - drive.visual.root.position.y, visible: drive.visual.root.visible});
      }
      const restarted = started + 0.3;
      view.rise(restarted);
      drive.sim.time = restarted;
      drive.visual.root.position.y = 19.25;
      view.update({run: {shield: {hp: 0, max: 1}}, invulnerableUntil: restarted + 3});
      rows.push({name: `restart-h${height}-start${started}`, height, started: restarted, now: restarted,
        invulnerableUntil: restarted + 3, riseUntil: view.riseUntil,
        offset: 19.25 - drive.visual.root.position.y, visible: drive.visual.root.visible});
    }
  }
  const result = {sourceCommit: commit, sourceFile: relative, sourceHash: hash, rows,
    boundary: 'Unchanged frozen EndlessView.rise/update executed in vm.SourceTextModule. Only THREE.Group and inactive scene/shield boundaries are stubs. Golden timing and visual offsets only; no target production change, browser, GPU or rendered acceptance.'};
  const out = path.join(root, '.tmp/source-endless-spawn-fixtures.json');
  fs.writeFileSync(out, JSON.stringify(result, null, 2) + '\n');
  process.stdout.write(JSON.stringify({result: 'PASS', sourceCommit: commit, cases: rows.length, out}) + '\n');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
