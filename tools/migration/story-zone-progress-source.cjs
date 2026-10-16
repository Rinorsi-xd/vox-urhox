// CPU oracle: execute frozen task kinds and zone methods with scene/HUD adapters.
const fs = require('fs'), path = require('path'), vm = require('vm'), crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json')));
const hashes = {};
function read(p) {
  const bytes = fs.readFileSync(path.join(baseline.snapshot, p));
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  if (hash !== baseline.files[p].sha256) throw Error('Frozen source drift: ' + p);
  hashes[p] = hash;
  return bytes.toString('utf8');
}
const context = vm.createContext({radio() {}, BOSS_KIND: {}, COLOR: {install: 0xff6a13}});
const kinds = read('three/src/battle/storyKinds.js');
vm.runInContext(kinds.replace(/^import .*;\r?\n/gm, '').replace('export const KINDS', 'globalThis.KINDS'), context);
for (const id of [3, 4]) {
  const level = read(`shared/story/level${id}.js`);
  vm.runInContext(level.replace(`export const LEVEL${id}`, `globalThis.LEVEL${id}`), context);
}
const view = read('three/src/battle/storyView.js');
const methods = view.slice(view.indexOf('\tshowZone( pos,'), view.indexOf('\n\taddIntel('));
if (!methods.includes('hideZone()')) throw Error('Zone method extraction drift');
vm.runInContext('globalThis.ZoneView = class {' + methods + '}', context);
const mission = read('three/src/battle/storyMission.js');
const installSec = mission.match(/const INSTALL_SEC = ([\d.]+);/)[1];
const installCall = mission.match(/this\.view\.setZoneProgress\( this\.install \/ INSTALL_SEC \);/)[0];
vm.runInContext('globalThis.installUpdate = function(){ const INSTALL_SEC=' + installSec + ';' + installCall + '}', context);
const nav = JSON.parse(fs.readFileSync(path.join(root, 'assets/Crater/Layout.json'))).nav;
const noop = () => {}, trace = [];
const flat = (a, b) => Math.hypot(a[0] - b[0], a[2] - b[2]);
function host(s) {
  const view = new context.ZoneView();
  const position = {set(x, y, z) {this.values = [x, y, z];}};
  view.zone = {visible: false, position, scale: {set(x, y, z) {this.values = [x, y, z];}},
    material: {uniforms: {uProgress: {value: .73}, uColor: {value: {setHex(v) {this.hex = v;}}}}}};
  Object.assign(view, {hideBeacon: noop, siteCaptured: noop, scrub: noop});
  const player = {pos: [...s.pos], alive: true, heal: noop, restoreMissing: () => [], flush: noop};
  const enemies = new Map();
  const m = {drive: {player, input: {}, _syncPlayer: noop}, view, enemies, stats: {}, progress: 0, stepT: 0,
    hud: {clock: noop, row: noop, banner: noop, say: noop, prompt: noop, retitle: noop}, fail: noop,
    near: (p, t, r, up = 6) => flat(p, t) < r && t[1] > p[1] - 1.5 - up && t[1] < p[1] + 1.5 + up,
    alive: tag => [...enemies.values()].filter(e => !tag || e.tag === tag).length,
    spawn(list, tag) {for (const e of list) {
      const at = typeof e.at === 'string' ? nav.nodes[e.at] : e.at, off = e.off || [0, 0];
      enemies.set({alive: true, pos: [at[0] + off[0], at.length === 3 ? at[1] : s.pos[1], (at.length === 3 ? at[2] : at[1]) + off[1]]}, {tag});
    }}
  };
  return m;
}
function record(m, s, label, input) {
  const z = m.view.zone;
  trace.push(JSON.parse(JSON.stringify({kind: s.kind, step: s, label, input,
    expected: {ring: z.material.uniforms.uProgress.value, visible: z.visible,
      position: z.position.values, scale: z.scale.values, color: z.material.uniforms.uColor.value.hex,
      hold: m.hold, cap: m.cap}})));
}
function enter(m, s, label) {context.KINDS[s.kind].enter(m, s); record(m, s, label, {enter: true});}
function sample(m, s, dt, pos, enemies, interact, label, alive = true) {
  m.drive.player.pos = pos; m.drive.player.alive = alive; m.holdG = interact; m.stepT += dt;
  m.enemies.clear();
  for (const e of enemies) m.enemies.set({alive: true, pos: e.pos}, {tag: e.tag});
  context.KINDS[s.kind].update(m, s, dt, !alive);
  record(m, s, label, {dt, pos, enemies, interact, alive, stepT: m.stepT});
}
const hold = context.LEVEL3.steps.find(s => s.kind === 'hold'), h = host(hold);
enter(h, hold, 'hold-entry');
sample(h, hold, 1, hold.pos, [], false, 'hold-delay');
sample(h, hold, 3.1, hold.pos, [], false, 'hold-active');
sample(h, hold, 37, hold.pos, [], false, 'hold-partial');
sample(h, hold, .3, hold.pos, [{pos: hold.pos, tag: 'wave'}], false, 'hold-drain');
sample(h, hold, 1, hold.pos, [], false, 'hold-dead', false);
sample(h, hold, 80, hold.pos, [], false, 'hold-complete');
enter(h, hold, 'hold-retry');
for (const s of context.LEVEL4.steps.filter(s => s.kind === 'capture')) {
  const m = host(s), at = s.pos;
  enter(m, s, `site-${s.site}-entry`);
  sample(m, s, .1, [at[0] + s.trigger, at[1], at[2]], [], false, 'trigger-boundary');
  sample(m, s, .1, at, [], false, 'guards-spawn');
  sample(m, s, 1, at, [], false, 'capture-fill');
  sample(m, s, .5, at, [{pos: at, tag: 'guard'}], false, 'capture-contested');
  sample(m, s, .5, [at[0] + s.r, at[1], at[2]], [], false, 'capture-leave');
  sample(m, s, .5, [at[0], at[1] + 20, at[2]], [], false, 'capture-height');
  for (let i = 0; i < 100 && m.cap.phase === 'cap'; i++) sample(m, s, .1, at, [], false, 'capture-filling');
  sample(m, s, .2, at, [{pos: at, tag: 'counter'}], false, 'counter-hold');
  sample(m, s, .1, at, [], false, 'scrub-entry');
  sample(m, s, .8, at, [], true, 'scrub-half');
  sample(m, s, .2, at, [], false, 'scrub-release');
  sample(m, s, 1, at, [], true, 'scrub-complete');
  enter(m, s, `site-${s.site}-restart-reset`);
}
const s = {kind: 'install', pos: [10, 3, -8], r: 12}, i = host(s);
i.view.showZone(s.pos, s.r); record(i, s, 'install-entry', {enter: true});
for (const value of [0, .4, 1.2, 2.4, 2.5, .3]) {
  i.install = value; context.installUpdate.call(i); record(i, s, 'install-progress', {install: value});
}
process.stdout.write(JSON.stringify({baseline: {commit: baseline.commit, branch: baseline.branch}, hashes, trace}));
