import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
gold=json.loads(subprocess.check_output(['node','tools/migration/source-merge-boxes-golden.cjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded.Config={CELL=.5}
for _,name in ipairs({'parts.Defs','parts.PartAssets','combat.WeaponLoadout','parts.MechIK'})do package.loaded[name]={}end
package.loaded['core.ResourceData']={Read=function()return {}end}
""")
new=lua.eval("require('drive.VehicleSpec')")[0]
old_path=ROOT/'.tmp/outgame-cached-1792067264260/scripts/drive/VehicleSpec.lua'
old=lua.execute(old_path.read_text(encoding='utf-8'))
rot=lua.eval("require('core.Rotations')")
assertions=0
def check(ok,message):
    global assertions
    assertions+=1
    if not ok:raise AssertionError(message)
def convert(v):
    if isinstance(v,list):return lua.table_from([convert(x) for x in v])
    if isinstance(v,dict):return lua.table_from({k:convert(x) for k,x in v.items()})
    return v
def plain_boxes(t):return [{'center':[b['center'][i] for i in range(1,4)],'half':[b['half'][i] for i in range(1,4)],'mass':b['mass']} for b in t.values()]
def com(boxes):
    mass=sum(b['mass'] for b in boxes)
    return [sum(b['mass']*b['center'][i] for b in boxes)/mass for i in range(3)] if mass else None
changes=[]
for case in gold['cases']:
    rows=case['rows'];cells={','.join(str(v) for v in r[:3]):{'pos':r[:3],'mass':r[3]} for r in rows}
    before=plain_boxes(old['MergeBoxes'](convert(cells)))
    checkpoints=[0]
    def checkpoint():checkpoints[0]+=1
    actual=plain_boxes(new['MergeBoxes'](convert(cells),checkpoint));want=case['expected']
    check(len(actual)==len(want),case['name']+' box count')
    for a,b in zip(actual,want):
        for key in ['center','half']:
            for i in range(3):check(abs(a[key][i]-b[key][i])<1e-12,case['name']+' '+key)
        check(abs(a['mass']-b['mass'])<1e-10,case['name']+' box mass')
    check(abs(sum(b['mass'] for b in actual)-sum(r[3] for r in rows))<1e-9,case['name']+' total mass')
    ac,wc=com(actual),com(want)
    if ac:
        for a,b in zip(ac,wc):check(abs(a-b)<1e-12,case['name']+' COM')
    check(not rows or checkpoints[0]>0,case['name']+' loading checkpoint retained')
    if before!=actual:changes.append({'name':case['name'],'oldBoxes':len(before),'newBoxes':len(actual),'oldCOM':com(before),'newCOM':ac})
    if case['name'].startswith('negative24rot-'):
        ri=int(case['name'].split('-')[-1]);p=rot['ApplyRot'](ri,convert([-3,-2,-3]))
        check([p[i] for i in range(1,4)]==rows[0][:3],case['name']+' actual Lua rotation')
report={'result':'PASSED','sourceCommit':gold['commit'],'sourceInputs':gold['inputs'],'cases':len(gold['cases']),'assertions':assertions,'productionSha256':hashlib.sha256((ROOT/'scripts/drive/VehicleSpec.lua').read_bytes()).hexdigest(),'previousSha256':hashlib.sha256(old_path.read_bytes()).hexdigest(),'changedCases':len(changes),'changes':changes,'scope':'Actual frozen JS mergeBoxes versus Lua outputs, inclusive seed ratio boundaries, zero, negative coordinates,24rotations, mass/center/half/COM and checkpoints. No native physics, Web performance or driving feel claim.'}
(ROOT/'docs/migration/evidence/merge-boxes-b276-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='changes'},ensure_ascii=False,indent=2))
print(json.dumps(next(x for x in changes if x['name']=='heavyBodyLightDecoration'),indent=2))
