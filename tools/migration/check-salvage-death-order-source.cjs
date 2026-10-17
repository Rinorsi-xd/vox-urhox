const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const {pathToFileURL} = require('node:url');
const root = path.resolve(__dirname, '../..');
const commit = 'b276064942ae09c0227ec28d4cfda1d5ff006455';

(async () => {
  const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/baselines', commit + '.json')));
  const sourceHashes = {};
  function read(name) {
    const bytes = fs.readFileSync(path.join(baseline.snapshot, name));
    const sha = crypto.createHash('sha256').update(bytes).digest('hex');
    if (sha !== baseline.files[name].sha256) throw Error('Frozen source drift: ' + name);
    sourceHashes[name] = sha;
    return bytes.toString('utf8');
  }
  for (const name of ['shared/salvage/items.js', 'shared/salvage/salvageLoot.js', 'shared/salvage/salvageGameplay.js']) read(name);
  const load = name => import(pathToFileURL(path.join(baseline.snapshot, name)).href);
  const {fromTable, roomFor} = await load('shared/salvage/salvageLoot.js');
  const {ITEMS, RARITY, sellPrice} = await load('shared/salvage/items.js');
  const {rollLoot} = await load('shared/salvage/salvageGameplay.js');
  const context = vm.createContext({URLSearchParams, location: {search: ''}, CARGO_SLOTS: 20,
    fromTable, roomFor, ITEMS, RARITY, sellPrice, rollLoot, CONTAINERS: {},
    THREE: {Color: class {constructor(color) {this.color=color;} getHex() {return parseInt(this.color.slice(1),16);}}}});
  vm.runInContext(read('three/src/salvage/salvageRun.js').replace(/^import .*;\r?\n/gm, '').replace(/^export /gm, '') + '\nglobalThis.Run=SalvageRun;', context);
  const kinds = ['rat', 'ratT2', 'hedgehog', 'dozer', 'dozerT3', 'rocket', 'pole', 'spider', 'kite', 'warden', 'wrecker', 'hunter'];
  const cases = [];
  // Every six-car death mask, with all twelve authored drop tables and several RNG streams.
  for (const mode of ['dead', 'fall']) for (const offset of [0, 6]) for (let mask = 0; mask < 64; mask++) {
    const trace = [], units = [], groups = Array.from({length: 3}, (_,i) => ({name: 'post-' + i, kind: 'camp', units: []}));
    let draws = 0;
    const run = Object.assign(Object.create(context.Run.prototype), {
      drive: {player: {alive: true, pos: [10000,2,10000]}, sim: {units}}, units: new Map(), extras: [], kills: 7,
      deadAt: null, finished: false, sessions: new Map(),
      rand() { return ((draws++ * 37 + mask * 11 + offset) % 100) / 100; },
      fx: {explode(...args) { trace.push(['explode', ...args]); }, loot() {}},
      hud: {feed(...args) { trace.push(['feed', ...args]); }, reveal() {}, jackpot() {}},
      _heat(n) { trace.push(['heat', n]); }, _press() {}
    });
    const input = [];
    for (let i = 0; i < 6; i++) {
      const item = {key: 'u' + i, alive: !(mask & (1 << i)), elite: i % 2 === 1,
        name: 'enemy-' + i, pos: [i * 3, mode === 'fall' ? ((mask & (1 << i)) ? -300.001 : (i % 2 ? -300 : -299.999)) : 2, i * -7],
        radius: [0.5, 2, 4, 6, 8, 10][i], kind: kinds[offset + i],
        why: mode === 'fall' ? '' : ['', '动不了了', '武器全被打掉'][i % 3], group: i % 3};
      input.push(item);
      const u = {...item, spec: {bounds: {radius: item.radius}}};
      const enc = groups[item.group]; enc.units.push(u); units.push(u);
      run.units.set(u, {def: {name: item.name}, why: item.why, type: item.kind, enc});
    }
    run.afterStep();
    const first = JSON.parse(JSON.stringify(trace));
    run.afterStep();
    if (JSON.stringify(trace) !== JSON.stringify(first)) throw Error('Source repeated death settlement');
    const remaining = run.drive.sim.units.map(u => u.key);
    // Open the actual generated remnants in order; this binds K identity, type, RNG and loot.
    const loot = run.extras.map(o => {
      const s = run._session(o);
      return {id: o.id, name: o.name, elite: o.elite, g: o.g,
        items: s.items.map(({id, n, r, t}) => ({id, n, r, t}))};
    });
    const initialCargo = mask % 2 ? {scrap: 380} : {};
    run.cargo = new Map(Object.entries(initialCargo));
    const picked = run.extras.map(o => {
      const s = run._session(o);
      for (const item of s.items) run._reveal(s,item);
      return {id:o.id,value:s.value,items:s.items.map(({id,n,state,left})=>({id,n,state,left}))};
    });
    cases.push({mode, offset, mask, input, trace, remaining, kills: run.kills, loot, draws,
      initialCargo, picked, cargo:Object.fromEntries(run.cargo)});
  }
  const out = path.join(root, '.tmp/source-salvage-death-order.json');
  fs.writeFileSync(out, JSON.stringify({commit, sourceHashes, cases}, null, 2) + '\n');
  console.log(JSON.stringify({out, cases: cases.length}));
})().catch(error => { console.error(error); process.exitCode = 1; });
