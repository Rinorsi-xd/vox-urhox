import json,pathlib
from lupa.lua54 import LuaRuntime
root=pathlib.Path(__file__).resolve().parents[3];lua=LuaRuntime(unpack_returned_tuples=True)
null=lua.table();lua.globals().cjson=lua.table_from({"null":null})
def table(v):
 if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([table(x) for x in v])
 return null if v is None else v
lua.globals().readData=lambda path:table(json.loads((root/'assets'/path).read_text()))
import os;os.chdir(root)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path; package.loaded['core.ResourceData']={Read=readData}")
lua.execute((root/'docs/migration/tests/delta-20261018.lua').read_text())
