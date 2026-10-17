const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const directory = path.resolve(root, process.argv[2] || '.tmp/g4-boss-missile-native-c074-b');
const log = fs.readFileSync(path.join(directory, 'stdout.log'), 'utf8');
const rows = [];
for (const [index, line] of log.split(/\r?\n/).entries()) {
  const m = line.match(/^\[(\d{4})-(\d\d)-(\d\d) (\d\d)_(\d\d)_(\d\d)_(\d{3})\]\[(\d+)\](.*)$/);
  if (!m) continue;
  rows.push({line: index + 1, frame: Number(m[8]), timestamp: m[0].split(']')[0].slice(1),
    ms: Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6], +m[7]), message: m[9]});
}
const shaderIntervals = [];
let pending = null;
for (const row of rows) {
  if (row.message.includes('ShaderCacheManager::RecordCompiledTarget:')) pending = row;
  const loaded = row.message.match(/Loaded (vertex|pixel|compute) shader (.*)/);
  if (!loaded) continue;
  if (pending && pending.frame === row.frame) shaderIntervals.push({kind: loaded[1], shader: loaded[2], frame: row.frame,
    elapsedMs: row.ms - pending.ms, beforeLine: pending.line, loadedLine: row.line,
    beforeTimestamp: pending.timestamp, loadedTimestamp: row.timestamp});
  pending = null;
}
const frame23 = rows.filter(row => row.frame === 23);
const long = shaderIntervals.filter(row => row.elapsedMs > 1000).sort((a, b) => b.elapsedMs - a.elapsedMs);
const completionFile = path.join(directory, 'completion.json');
const report = {status: fs.existsSync(completionFile) ? 'EXIT_RECORD_PRESENT' : 'OBSERVATION_WHILE_RUN_PENDING',
  input: path.join(directory, 'stdout.log'), inputSha256: crypto.createHash('sha256').update(log).digest('hex'),
  observedAt: new Date().toISOString(), completion: fs.existsSync(completionFile) ? JSON.parse(fs.readFileSync(completionFile, 'utf8').replace(/^\uFEFF/, '')) : null,
  loggedRows: rows.length, nativeErrors: rows.filter(row => row.message.includes('ERROR:')).length,
  lastFrame: rows.at(-1)?.frame, lastTimestamp: rows.at(-1)?.timestamp,
  frame23: {firstTimestamp: frame23[0]?.timestamp, lastTimestamp: frame23.at(-1)?.timestamp,
    loggedSpanMs: frame23.length ? frame23.at(-1).ms - frame23[0].ms : 0,
    loadedShaderCount: frame23.filter(row => row.message.includes('Loaded ') && row.message.includes(' shader ')).length},
  longShaderIntervals: long, longShaderIntervalsTotalMs: long.reduce((sum, row) => sum + row.elapsedMs, 0),
  pendingRecord: pending && {line: pending.line, frame: pending.frame, timestamp: pending.timestamp, message: pending.message},
  loadingMessages: rows.filter(row => /\[LoadingFlow\]|\[SceneLoader\]|\[Validate\]/.test(row.message)).map(({line, frame, timestamp, message}) => ({line, frame, timestamp, message})),
  boundary: 'Log timestamps bracket shader-loaded messages with preceding RecordCompiledTarget messages. These are wall-clock intervals surrounding resource/shader loading, not direct compiler CPU timers or proof that all elapsed time is compilation. Same-frame gaps establish a blocked frame. This diagnostic Native desktop startup cannot quantify Web/Mobile costs or combat FPS. A 0-matched record alone does not prove shader cache misses.'};
const output = path.join(directory, 'startup-log-derived.json');
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({output, ...report}, null, 2));
