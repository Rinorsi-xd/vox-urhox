const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const baseline = JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceHashes = {};
function read(file) {
  const bytes = fs.readFileSync(path.join(baseline.snapshot, file));
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  if (hash !== baseline.files[file].sha256) throw Error('Frozen source drift: ' + file);
  sourceHashes[file] = hash;
  return bytes.toString('utf8');
}
const node = () => ({gain: parameter(), connect(target) { return target; }});
function parameter() {
  return {value: 1, setValueAtTime(value) { this.value = value; },
    linearRampToValueAtTime(value) { this.value = value; }, cancelScheduledValues() {}};
}
let context;
class AudioContext {
  constructor() { context = this; this.currentTime = 0; this.destination = node(); this.sources = []; }
  createGain() { return node(); }
  createDynamicsCompressor() {
    return Object.assign(node(), Object.fromEntries(['threshold', 'knee', 'ratio', 'attack', 'release'].map(key => [key, parameter()])));
  }
  createAnalyser() { return Object.assign(node(), {getFloatTimeDomainData() {}}); }
  createBufferSource() {
    const source = Object.assign(node(), {playbackRate: parameter(), start() { this.started = true; }, stop(at) { this.stopAt = at; }});
    this.sources.push(source); return source;
  }
}
const document = {addEventListener() {}, removeEventListener() {}};
const sandbox = vm.createContext({URL, window: {AudioContext}, document,
  sfx: {onVolume(callback) { callback(.65); return () => {}; }},
  levels: {on(key, callback) { callback(key === 'voice' ? .6 : .75); return () => {}; }},
  DEFAULT_LEVELS: {voice: .6, music: .75}, musicGain: value => value,
  IntroStory: class {}, V: {}, GalaxyMap: class { draw() {} },
  wipe: () => ({covered: Promise.resolve()}),
});
const audioText = read('three/src/intro/introAudio.js');
vm.runInContext(audioText.replace(/^import .*;\r?\n/gm, '').replace(/^export /gm, '')
  .replaceAll('import.meta.url', JSON.stringify('file:///D:/Rino_Project/Vox/three/src/intro/introAudio.js'))
  + '\nglobalThis.Audio = IntroAudio;', sandbox);
const introText = read('three/src/intro/intro.js');
vm.runInContext(introText.replace(/^import .*;\r?\n/gm, '').replace(/^export /gm, '')
  .replaceAll('import.meta.url', JSON.stringify('file:///D:/Rino_Project/Vox/three/src/intro/intro.js'))
  + '\nglobalThis.IntroClass = Intro;', sandbox);
(async () => {
  const audio = new sandbox.Audio(); audio.buf.set('vo_n04', {duration: 5}); audio.buf.set('sfx_blip', {duration: 1});
  const cues = [], handles = [], tasks = [];
  const original = audio.sfx;
  audio.sfx = function(id, opt) {
    const handle = original.call(this, id, opt); handles.push(handle);
    cues.push({id, opt, frequency: 48000 * handle.src.playbackRate.value,
      gain: handle.g.gain.value * this.sfxBus.gain.value * this.master.gain.value});
    return handle;
  };
  const target = Object.create(sandbox.IntroClass.prototype);
  Object.assign(target, {root: {}, audio, L: {bars: {classList: {add() {}}}, panels: {}},
    mark() {}, clearTasks() {}, task(fn) { tasks.push(fn); }, say: async () => {}});
  await target.actGalaxy();
  // Execute the original task once after a delayed frame reaches the narrated duration.
  context.currentTime = 5;
  for (const task of tasks) task(1, 5, 5);
  if (cues.length !== 40 || new Set(handles.map(handle => handle.src)).size !== 40) throw Error('Original galaxy cue ownership changed');
  if (context.sources.some(source => source.stopAt !== undefined)) throw Error('Original galaxy burst steals a source');
  process.stdout.write(JSON.stringify({commit: baseline.commit, sourceHashes, sequence: 'actual Intro.actGalaxy task at t=d=5 after no prior task ticks',
    delaySeconds: 5, cues, independentSources: new Set(handles.map(handle => handle.src)).size, interruptedSources: 0}));
})().catch(error => { console.error(error); process.exitCode = 1; });
