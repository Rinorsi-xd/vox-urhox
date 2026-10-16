"""Conservative layout candidate; native compiled-shader equality remains required."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source=ROOT/'scripts/render/WarmupSignature.lua'
fixture=ROOT/'tools/migration/check-combat-warmup-signature.lua'
text=source.read_text(encoding='utf-8')

def run(candidate):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().SIGNATURE_SOURCE=candidate
    lua.globals().print=lambda *args:None
    lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['render.WarmupSignature']=function()return assert(load(SIGNATURE_SOURCE))()end")
    return dict(lua.execute(fixture.read_text(encoding='utf-8')).items())

result=run(text)
negative=[]
for before,after,label in [
    ("local key={'shader-layout',layout,tostring(drawable.zone)}", "local key={'shader-layout',tostring(drawable.zone)}",'omit complete vertex layout'),
    ('elseif #group.items>#existing.items then','elseif false then','discard actual instanced source atom'),
    ("if not material:GetSurfaceShader() and material:GetNumTechniques()~=1 then return nil,nil,'material-technique-lod' end","if false then return nil,nil,'material-technique-lod' end",'allow unknown material technique LOD'),
    ('for _,key in ipairs(group.singleKeys) do if used[key] then return false end end','for _,key in ipairs(group.singleKeys) do end','allow native single re-instancing'),
]:
    assert before in text,label
    try:run(text.replace(before,after,1))
    except Exception as error:negative.append({'case':label,'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Mutation incorrectly passed '+label)

paths=['scripts/render/CombatWarmup.lua','scripts/render/WarmupSignature.lua']
tools=['tools/migration/check-combat-warmup-signature.lua','tools/migration/verify-combat-warmup-signature.py','tools/migration/check-combat-warmup.lua']
assert source.read_text(encoding='utf-8')==text,'Source changed during verification'
report={**result,'negativeControls':negative,
        'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        'testInputs':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in tools}}
out=ROOT/'docs/migration/evidence/combat-warmup-signature-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
