"""Frozen JS damage presentation versus actual Lua event/restore consumers."""
import hashlib,json,os,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
def sha(name):return hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
def run(fixtures,overlay,unit):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def convert(v):
        if isinstance(v,dict):return lua.table_from({k:convert(x) for k,x in v.items() if x is not None})
        if isinstance(v,list):return lua.table_from([convert(x) for x in v])
        return v
    def plain(v):
        if hasattr(v,'items'):
            keys=list(v.keys())
            return [plain(v[k]) for k in sorted(keys)] if all(isinstance(k,int) for k in keys) else {k:plain(x) for k,x in v.items()}
        return v
    lua.globals().fixtures=convert(fixtures)
    lua.globals().READ_RESOURCE=lambda name:convert(json.loads((ROOT/'assets'/name).read_text(encoding='utf-8-sig')))
    lua.globals().OVERLAY_MODULE=overlay;lua.globals().UNIT_MODULE=unit
    return plain(lua.execute((ROOT/'tools/migration/check-player-damage-feedback.lua').read_text(encoding='utf-8')))
def main():
    subprocess.run(['node','tools/migration/source-player-damage-feedback.mjs'],check=True)
    fixture=json.loads((ROOT/'.tmp/player-damage-source.json').read_text(encoding='utf-8'))
    assert fixture['commit']=='b276064942ae09c0227ec28d4cfda1d5ff006455'
    overlay='scripts/ui/DriveOverlay.lua';unit='scripts/combat/CarUnit.lua'
    old='.tmp/outgame-cached-1792140646894/'
    names=[overlay,unit,'scripts/ui/PlayerDamageFeedback.lua','scripts/ui/CombatFeedbackMotion.lua','scripts/controls/CameraFeedback.lua',
           'tools/migration/source-player-damage-feedback.mjs','tools/migration/check-player-damage-feedback.lua','tools/migration/check-player-damage-feedback.py']
    before={p:sha(p) for p in names}
    result=run(fixture,overlay,unit)
    assert result['passed'],json.dumps(result,indent=2)
    negatives={}
    for label,o,u,prefix in [('old-overlay',old+overlay,unit,'trauma '),('old-restore-cache',overlay,old+unit,'restore cache timing ')]:
        rejected=run(fixture,o,u)
        assert not rejected['passed'] and any(x.startswith(prefix) for x in rejected['failures']),label
        if label=='old-overlay':assert any(x.startswith('horizontal angle ') for x in rejected['failures'])
        negatives[label]={'moduleHashes':{p:sha(p) for p in [o,u]},'failures':rejected['failures'][:10],'failureCount':len(rejected['failures'])}
    assert before=={p:sha(p) for p in names},'Concurrent production drift'
    report={'result':'PASS','checks':result['checks'],'sourceCommit':fixture['commit'],'sourceHashes':fixture['sourceHashes'],
        'scenarios':len(fixture['scenarios']),'events':sum(len(s['events']) for s in fixture['scenarios']),'restoreCases':len(fixture['restores']),
        'inputs':before,'negative':negatives,'boundary':'Actual frozen _hud player clause/_viewAngle and CarUnit.restoreMissing; actual DriveOverlay.Consume, PlayerDamageFeedback, CombatFeedbackMotion and CarUnit.RestoreMissing with CPU engine/blueprint adapters. Source coordinate conversion, pitch/roll/height, 0.1s damage rate limit, zero damage, death, source/point fallback, other-unit exclusion and exact lazy HP cache early returns. No GPU, native camera motion, Web screenshot, audible feedback, visual parity or performance acceptance.'}
    timestamp=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ')
    dated=ROOT/'docs/migration/evidence'/('player-damage-feedback-'+timestamp);dated.mkdir(parents=True)
    payload=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    (dated/'report.json').write_text(payload,encoding='utf-8')
    out=ROOT/'docs/migration/evidence/player-damage-feedback-offline.json';out.write_text(payload,encoding='utf-8')
    print(json.dumps({'result':'PASS','checks':result['checks'],'negative':len(negatives),'evidence':str(dated/'report.json')}))
if __name__=='__main__':main()
