import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

if (!vm.SourceTextModule) {
  const result = spawnSync(process.execPath, ['--experimental-vm-modules', import.meta.filename, ...process.argv.slice(2)], { stdio: 'inherit' });
  process.exit(result.status ?? 1);
}
const root = path.resolve(import.meta.dirname, '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json')));
if (baseline.commit !== '2b169a9964645f5f346a7158bcb14447f040814a') throw Error('Unexpected frozen baseline');
const match = await import(pathToFileURL(path.join(baseline.snapshot, 'shared/battle/match.js')));
const shield = await import(pathToFileURL(path.join(baseline.snapshot, 'shared/battle/shieldQuery.js')));
const file = path.join(root, 'assets/Combat/Arena.json');
const data = JSON.parse(fs.readFileSync(file));
const differences = [];
function Compare(before, after, key) {
  if (JSON.stringify(before) === JSON.stringify(after)) return;
  if (before && after && typeof before === 'object' && typeof after === 'object' && !Array.isArray(before)) {
    for (const name of new Set([...Object.keys(before), ...Object.keys(after)])) Compare(before[name], after[name], key + '.' + name);
  } else differences.push({ path: key, before, after });
}
Compare(data.modes, match.MATCH_MODES, 'modes');
const sourceFile = path.join(baseline.snapshot, 'three/src/battle/matchSession.js');
const source = fs.readFileSync(sourceFile, 'utf8');
const bindings = ['BattleFlowMix','sfx','cameraListener','Blueprint','CarUnit','EnemyDriver','hasLineOfSight','findPath','createEnemyBlueprint','centeredSpawn','shieldContains','shieldRay','createRules','MATCH_MODES','TEAMS','other','ESCORT','findMatch','recordResult','codename','MatchHud','MatchLobby','TIERS','ZoneMarker','Reactor','PayloadCart','RouteLine','mapShot','prepareMapShot','MatchIntro','introSeen','markIntroSeen','MvpShow','MatchVoice','Radio','MATCH_FOUND_VOICE','MATCH_FOUND_SFX','Vector3'];
const context = vm.createContext({ console });
const forbidden = () => { throw Error('Unexpected renderer call in source rules'); };
const module = new vm.SourceTextModule(source + '\nexport { inPoint, breathe, EliminationMode, ConquestMode, EscortMode };', { context });
await module.link(async specifier => {
  const values = { ...match, ...shield, Vector3: class {} };
  const stub = new vm.SyntheticModule(bindings, function () { for (const key of bindings) this.setExport(key, values[key] ?? forbidden); }, { context });
  await stub.link(() => { throw Error('Unexpected nested import ' + specifier); });
  return stub;
});
await module.evaluate();
const ref = module.namespace;
const zones = [];
for (const radius of [1, 5, 20]) for (const distance of [0, 20, 22, 24, 31, 33]) for (const height of [0, 8, 12, 28]) {
  const pos = [distance, height, 0];
  zones.push({ radius, pos, point: { pos: [0, 0, 0], radius: 22 }, inside: ref.inPoint({ pos, spec: { bounds: { radius } } }, { pos: [0, 0, 0], radius: 22 }) });
}
const recovery = [];
for (const mode of ['elimination', 'conquest', 'escort']) for (const sudden of [false, true]) for (const hurtAge of [4.99, 5, 8]) for (const home of [false, true]) {
  const log = []; const unit = { health: .5, _hurtAt: 10 - hurtAge, team: 'blue', pos: [100, 10, 100],
    spec: { bounds: { radius: 5 } }, heal: f => log.push(['heal', f]), restoreMissing: n => { log.push(['restore', n]); return []; } };
  const state = { cfg: match.MATCH_MODES[mode], rules: { sudden, attack: 'blue', shield: { blue: false, red: false } }, drive: { sim: { time: 10 } } };
  const entry = { unit, repair: .45 };
  if (mode === 'elimination') ref.EliminationMode.prototype.unitTick.call({ s: state }, entry, .1);
  else if (mode === 'escort') ref.EscortMode.prototype.unitTick.call({ s: state, cart: { pos: home ? [100,10,100] : [0, 0, 0] } }, entry, .1);
  else ref.ConquestMode.prototype.unitTick.call({ s: state, base: {
    blue: { zone: {pos:home?[100,10,100]:[0,0,0],rx:30,rz:30,h:30} },
    red: { zone: {pos:[10000,0,10000],rx:30,rz:30,h:30} }
  } },entry,.1);
  recovery.push({ mode, sudden, hurtAge, home, repairBefore: .45, dt: .1, repairAfter: entry.repair, regen: entry.regen, log });
}
const fixture = { baseline: baseline.commit, sourceSha256: createHash('sha256').update(source).digest('hex'), modes: match.MATCH_MODES, differences, zones, recovery };
const evidence = path.join(root, 'docs/migration/evidence/arena-unification');
fs.mkdirSync(evidence, { recursive: true });
const stamp = new Date().toISOString().replaceAll(':', '-');
fs.writeFileSync(path.join(evidence, 'source-' + stamp + '.json'), JSON.stringify(fixture, null, 2));
fs.writeFileSync(path.join(root, '.tmp/source-arena-unification.json'), JSON.stringify(fixture));
console.log(JSON.stringify({ action: process.argv.includes('--write') ? 'targeted-write' : 'dry-run', differences, zones: zones.length, recovery: recovery.length }));
if (process.argv.includes('--write')) {
  data.modes = match.MATCH_MODES;
  data.source.modeBaseline = { commit: baseline.commit, file: 'shared/battle/match.js' };
  fs.writeFileSync(file, JSON.stringify(data));
}
