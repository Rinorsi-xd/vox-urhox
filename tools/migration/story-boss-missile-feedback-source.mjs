import fs from 'node:fs';
import crypto from 'node:crypto';
import vm from 'node:vm';

const baseline = JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json', 'utf8'));
class Vector3 { constructor(...v) { this.v = v; } normalize() { return this; } }
const context = vm.createContext({ THREE: { Vector3 }, Blueprint: class {}, buildDrillTank: () => ({ toJSON: () => ({}) }), radio() {}, setTimeout() {} });
const source = { commit: baseline.commit, files: {} };
for (const [path, names] of [['three/src/battle/storyBoss.js', ['FoxBoss']], ['shared/story/level5.js', ['LEVEL5']]]) {
  const bytes = fs.readFileSync(`${baseline.snapshot}/${path}`);
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  if (hash !== baseline.files[path].sha256) throw Error('Frozen source drift: ' + path);
  source.files[path] = hash;
  vm.runInContext(`(()=>{${bytes.toString('utf8').replace(/^import .*;\r?\n/gm, '').replace(/^export /gm, '')}\n${names.map(n => `globalThis.${n}=${n};`).join('\n')}})()`, context);
}
function run(test) {
  const calls = [], rays = [], boss = Object.create(context.FoxBoss.prototype);
  let step;
  const unit = name => ({ name, alive: name !== 'player' || !test.dead, pos: [test.distance ?? 4, 0, 0], vehicle: { body: name },
    explode: (at, radius, damage) => calls.push(['explode', name, radius, damage]), flush: () => calls.push(['flush', name]) });
  const player = unit('player'), ally = unit('ally');
  const sim = { attacker: null, castRay(o, d, len, exclude) {
    const up = d[1] === 1;
    rays.push([up ? 'roof' : 'los', exclude ?? null]);
    const kind = up ? step.roof : step.los;
    if (!kind || kind === 'none') return null;
    const ref = kind === 'boss' ? boss.unit : kind === 'player' ? player : kind === 'ally' ? ally : {};
    return { dist: kind === 'far' ? 100 : 0, owner: kind === 'unknown' ? undefined : { ref } };
  }};
  const drive = { player, vehicle: player.vehicle, sim, trauma: test.trauma ?? 0, _syncPlayer() {} };
  const m = { drive, stats: {}, hud: { talking: false, say(lines, urgent, append) { calls.push(['say', lines, urgent, append]); } },
    fx: { explode(at, size, big) { calls.push(['fx', size, big]); } } };
  Object.assign(boss, { m, time: 10, L: context.LEVEL5.steps.find(s => s.kind === 'boss').lines, said: new Set(),
    allies: test.ally ? [{ unit: ally }] : [], unit: { vehicle: { body: 'boss' } }, missiles: [] });
  if (test.synthetic) boss.L = { ...boss.L, outside: ['nono', 'controlled missing-cue gate', 'nono_neutral'] };
  const frames = [];
  for (step of test.steps) {
    m.hud.talking = !!step.talking;
    boss._storyUntil = step.busy ? 11 : 0;
    boss.missiles.push({ from: [0, 0, 0], mid: [0, 0, 0], to: [0, 0, 0], prev: [0, 0, 0], t: 0, T: 1, r: 7.5, dmg: 340,
      hist: [], mesh: { position: { set() {} }, quaternion: { setFromUnitVectors() {} } }, trail: { geometry: { attributes: { position: { setXYZ() {} } } } } });
    boss._removeMissile = () => {};
    boss._missiles(1);
    frames.push({ trauma: drive.trauma, hits: m.stats.missileHits ?? 0, said: boss.said.has('outside'), remaining: boss.missiles.length });
  }
  return { calls, rays, frames };
}
const cases = [];
const add = test => cases.push({ test, expected: run(test) });
for (const trauma of [0, .2, .7]) for (const roof of ['none', 'environment', 'boss', 'unknown'])
  add({ name: `roof-${roof}-${trauma}`, trauma, steps: [{ roof }, { roof }] });
for (const los of ['environment', 'unknown', 'far', 'player'])
  add({ name: `line-of-sight-${los}`, steps: [{ los, roof: 'none' }] });
add({ name: 'voice-occupied-then-retry', synthetic: true, steps: [{ talking: true }, { busy: true }, {}, {}] });
for (const roof of ['none', 'environment', 'boss', 'unknown'])
  add({ name: `synthetic-outside-gate-${roof}`, synthetic: true, steps: [{ roof }, { roof }] });
add({ name: 'both-teammates', ally: true, steps: [{}] });
add({ name: 'only-ally', dead: true, ally: true, steps: [{}] });
add({ name: 'dead-player-only', dead: true, steps: [{}] });
add({ name: 'inside-radius', distance: 9.4, steps: [{}] });
add({ name: 'outside-radius', distance: 9.6, steps: [{}] });
console.log(JSON.stringify({ source, cases }));
