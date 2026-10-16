"""Opening uses actual shared feedback, rather than only timeout advancement."""
import hashlib,json,os,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
paths=['scripts/ui/IntroSortieUi.lua','scripts/ui/DriveOverlay.lua',
       'scripts/ui/CombatFeedbackMotion.lua','scripts/intro/IntroBattle.lua','scripts/intro/IntroSortie.lua',
       'scripts/app/OpeningHost.lua','scripts/ui/ReticleTarget.lua','scripts/ui/ReticleFocus.lua']
fixture=(root/'tools/migration/check-intro-sortie-feedback.lua').read_text(encoding='utf-8')
old=LuaRuntime(unpack_returned_tuples=True)
old.globals().OLD_UI=(root/'.tmp/outgame-cached-1792095367698/scripts/ui/IntroSortieUi.lua').read_text(encoding='utf-8')
old.execute("package.preload['ui.IntroSortieUi']=function()return assert(load(OLD_UI))()end")
try:old.execute(fixture)
except Exception as error:before=str(error)
else:raise AssertionError('Old missing feedback did not fail regression')
assert 'opening binds shared battle feedback' in before,before
result=LuaRuntime(unpack_returned_tuples=True).execute(fixture)
report={'result':'PASS','checks':result['count'],'cases':list(result['checks'].values()),
        'reproduced14f':before,'productionHashes':{p:hashlib.sha256((root/p).read_bytes()).hexdigest()for p in paths},
        'boundary':'Actual opening UI constructor/update/dispose, IntroBattle.AfterStep, DriveOverlay damage/kill/audio routing, TrialMetrics, CombatFeedbackMotion, real ReticleTarget/Focus after player disposal, and OpeningHost.Update command/digit/lost-capture/death branches. Engine widgets/camera/render/audio/input boundaries doubled. No native damage, GPU pixels, real shooting or performance acceptance.'}
output=root/'docs/migration/evidence/intro-sortie-feedback-offline.json'
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':report['checks'],'evidence':str(output)}))
