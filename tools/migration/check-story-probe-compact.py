"""Execute the probe's actual history selector; replay existing Web JSON only."""
import hashlib
import json
import subprocess
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

probe = ROOT / 'tools/migration/probe-outgame-web.lua'
runner = ROOT / 'tools/migration/check-story-presentation-web.cjs'
source = probe.read_text(encoding='utf-8')
actual = source[source.index('local function PresentationHistory('):source.index('local function ObserveStoryPresentation(')]
lua = LuaRuntime(unpack_returned_tuples=True)
select = lua.execute(actual + '\nreturn PresentationHistory')
checks = []

def check(label, condition):
    assert condition, label
    checks.append(label)

check('Entire updated actual probe compiles as Lua 5.4 without running it', lua.eval('function(text) local f,err=load(text); return f~=nil,err end')(source)[0])

ring = lua.table()
for serial in range(1, 241):
    ring[(serial - 1) % 180 + 1] = lua.table_from([serial, 'existing sample'])
full = select(ring, 60, 180, True)
last = select(ring, 60, 180, False)
check('Actual full selector retains all 180 rows in chronological order', len(full) == 180 and [full[i][1] for i in range(1, 181)] == list(range(61, 241)))
check('Actual default selector contains only the final observed frame', len(last) == 1 and last[1][1] == 240)
check('Rows retain exact identity rather than inventing presenter state', lua.eval('function(a,b) return rawequal(a,b) end')(last[1], ring[60]))
for name, before, after in [('always full', 'full and 1 or math.max(1,count)', '1'), ('stale final frame', '(head-count+i-1)%180+1', '(head-count+i-2)%180+1')]:
    mutant = lua.execute(actual.replace(before, after) + '\nreturn PresentationHistory')
    result = mutant(ring, 60, 180, False)
    check('Reject history selector negative control: ' + name, len(result) != 1 or result[1][1] != 240)
for count in [0, 1, 17, 179, 180]:
    r = lua.table_from([lua.table_from([n]) for n in range(1, count + 1)])
    check(f'Unwrapped count {count} full/compact boundaries', len(select(r, count, count, True)) == count and len(select(r, count, count, False)) == min(1, count))
check('Default and full requests are explicitly distinguished', "historyMode=full and 'full' or 'last'" in source and 'historyCount=#history,historyAvailable=presentationCount,historyLimit=180' in source)
check('Explicit history request is consumed exactly once', 'local full=pendingPresentationHistory;pendingPresentationHistory=false' in source)
check('F13 requests a real post-update dump without gameplay action', 'app.trial and app.trial.story and input:GetKeyPress(KEY_F13)' in source and "or pendingPresentationHistory or pendingSceneObjects then previous=key;pendingTrialDump=app" in source)
check('Default automatic sampling and explicit F8 remain available; route mode suppresses automatic duplicates', 'frames%30==0 and not G0_StoryRouteState or input:GetKeyPress(KEY_F8) or pendingPresentationHistory' in source)
runner_source = runner.read_text(encoding='utf-8')
check('Presentation runner explicitly requires full mode only in a presentation', "full=!!state?.story?.presentation" in runner_source and "await key(full?'F13':'F8')" in runner_source and "(!full||state.story?.presentation?.historyMode==='full')" in runner_source)
runtime = subprocess.check_output(['node', '-e', r'''
const fs=require('fs'),assert=require('assert/strict'),text=fs.readFileSync(process.argv[1],'utf8');
const start=text.indexOf('async function dump()'),end=text.indexOf('\n',start),actual=text.slice(start,end);
(async()=>{
 const cases=[];
 for(const [name,initial,want]of [['hangar',{},'F8'],['trial without presentation',{story:{}},'F8'],['story presentation',{story:{presentation:{historyMode:'last'}}},'F13']]){
  let state=initial,sequence=7,keys=[];
  const key=async k=>{keys.push(k);sequence++;if(k==='F13')state.story.presentation.historyMode='full';};
  const wait=async predicate=>{assert.equal(predicate(),true,name+' resolves actual fresh dump predicate');return state;};
  const dump=eval('('+actual+')');await dump();assert.deepEqual(keys,[want]);cases.push(name);
 }
 process.stdout.write(JSON.stringify(cases));
})().catch(e=>{console.error(e);process.exitCode=1});
''', str(runner)], encoding='utf-8')
for name in json.loads(runtime):
    check('Actual dump function resolves with correct key in ' + name, True)
check('F13 uses explicit Chrome key delivery beyond bundled Playwright F12 table', "key:'F13',code:'F13',windowsVirtualKeyCode:124,nativeVirtualKeyCode:124" in runner.read_text(encoding='utf-8') and "type:'rawKeyDown',...event" in runner.read_text(encoding='utf-8') and "type:'keyUp',...event" in runner.read_text(encoding='utf-8'))
for field in ['saved={data=saved,generation=generation,time=time}', 'data.salvageRun.extraction=ex and {id=ex.e.id,left=ex.left}', 'data.story.boss.cockpit=boss:Cockpit();data.story.boss.braced=boss.rules:Braced()']:
    check('Preserves root read-only probe addition: ' + field.split('=')[0], field in source)

replays = []
for directory in ['story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-55-04-396Z', 'story-natural-s1-manifest-5b8cf21c-2026-10-16T01-18-07-151Z']:
    log = ROOT / 'docs/migration/evidence' / directory / 'runtime.log'
    original_bytes = compact_bytes = history_bytes = states = 0
    tail = []
    with log.open(encoding='utf-8') as stream:
        for line_number, line in enumerate(stream, 1):
            if 'OUTGAME_STATE ' not in line:
                continue
            try:
                state = json.loads(line.split('OUTGAME_STATE ', 1)[1])
            except json.JSONDecodeError:
                continue
            presentation = state.get('story', {}).get('presentation')
            if not presentation:
                continue
            original_bytes += len(json.dumps(state, ensure_ascii=False, separators=(',', ':')).encode())
            frames = presentation.get('frames', [])
            frames = list(frames.values()) if isinstance(frames, dict) else frames
            history_bytes += len(json.dumps(frames, ensure_ascii=False, separators=(',', ':')).encode())
            presentation['frames'] = frames[-1:]
            compact_bytes += len(json.dumps(state, ensure_ascii=False, separators=(',', ':')).encode())
            states += 1
            tail.append({'line': line_number, 'time': state['story']['time'], 'performance': {k: state['performance'][k] for k in ['resourceBytes', 'modelBytes', 'soundBytes', 'arrayBytes', 'imageBytes', 'luaKiB']}})
            tail = tail[-100:]
    check('Real history replay reduces bytes and retains real final rows: ' + directory, compact_bytes < original_bytes * .7)
    replays.append({'directory': directory, 'states': states, 'originalJsonBytes': original_bytes, 'compactJsonBytes': compact_bytes, 'historyJsonBytes': history_bytes, 'tailFirst': tail[0], 'tailLast': tail[-1]})

report = {'result': 'PASS', 'checks': checks, 'inputs': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in [probe, runner, Path(__file__)]}, 'replays': replays,
          'boundary': 'QA-only CPU selector execution, source wiring and old real-state serialization replay. Does not establish allocator attribution, prove an OOM fix, or verify browser F13 delivery. No engine log deletion, production changes, GPU, clock or gameplay mutations.'}
output = ROOT / 'docs/migration/evidence/story-probe-compact-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(checks), 'replays': replays, 'output': str(output)}, ensure_ascii=False))
