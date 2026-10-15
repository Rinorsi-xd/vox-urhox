import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
source=json.loads(subprocess.check_output(['node','tools/migration/source-match-objectives-golden.cjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def convert(v):
    if isinstance(v,dict):return lua.table_from({k:convert(x) for k,x in v.items() if x is not None})
    if isinstance(v,list):return lua.table_from([convert(x) for x in v])
    return v
lua.globals().MATCH_OBJECTIVE_CASES=convert(source)
result=lua.execute((ROOT/'tools/migration/check-match-hud-detail-offline.lua').read_text(encoding='utf-8'))
files=['scripts/ui/MatchFeed.lua','scripts/ui/MatchObjectives.lua','scripts/ui/MatchMinimap.lua','scripts/ui/MatchHud.lua','scripts/ui/CombatFeedbackMotion.lua','scripts/ui/DriveOverlay.lua','scripts/ui/DriveHud.lua','scripts/combat/BattleController.lua','scripts/drive/TrackWorld.lua']
report={'result':'PASSED','assertions':result['assertions'],'sourceCases':result['sourceCases'],'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files},'scope':'Actual frozen MatchSession._objectives versus Lua. Minimap visibility/clamp/draw state, kill feed lifecycle, and22score tick callbacks. No engine/Web screenshot or mobile performance claim.'}
(ROOT/'docs/migration/evidence/match-hud-detail-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
