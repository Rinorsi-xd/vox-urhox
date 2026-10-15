import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {createHash, randomBytes} from 'node:crypto';

const root = path.resolve(import.meta.dirname, '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json')));
const load = relative => import(pathToFileURL(path.join(baseline.snapshot, relative)).href);
const {HUD_THREAT_CUES, HUD_THREAT_BASE} = await load('shared/audio/hudThreatCues.js');
const {BATTLE_FLOW_CUES, BATTLE_FLOW_BASE} = await load('shared/audio/battleFlowCues.js');
const {MIX_TRIM} = await load('shared/audio/mixTrim.js');
const target = path.join(root, 'assets/Combat/FeedbackSounds.json');
const data = JSON.parse(fs.readFileSync(target));
for (const [id, cue, base] of [
  ['score_tick', {...HUD_THREAT_CUES.score_tick, variant: 'a'}, HUD_THREAT_BASE],
  ['objective_gain', BATTLE_FLOW_CUES.objective_gain, BATTLE_FLOW_BASE],
]) {
  const source = fileURLToPath(new URL(`${id}_${cue.variant}.wav`, base));
  const bytes = fs.readFileSync(source);
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE') throw Error(source);
  const relative = `Sounds/CombatFeedback/${id}_${cue.variant}.wav`;
  const dest = path.join(root, 'assets', relative);
  fs.writeFileSync(dest, bytes);
  if (!fs.existsSync(dest + '.meta')) fs.writeFileSync(dest + '.meta', JSON.stringify({uuid: randomBytes(18).toString('base64url')}, null, 2) + '\n');
  data.cues[id] = {path: relative, gain: cue.gain * 10 ** ((MIX_TRIM[id] || 0) / 20), gap: cue.gap / 1000,
    loop: false, spatial: false, jitter: false, source: path.relative(baseline.snapshot, source).replaceAll('\\', '/'),
    sha256: createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length};
}
data.killFeedbackSource = {branch: baseline.branch, commit: baseline.commit};
fs.writeFileSync(target, JSON.stringify(data));
console.log(JSON.stringify({source: data.killFeedbackSource, imported: ['score_tick', 'objective_gain']}));
