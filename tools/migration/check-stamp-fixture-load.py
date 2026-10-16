"""Execute the generated native fixture's registration code without a renderer."""
from pathlib import Path
import sys

fixture = Path(sys.argv[1]).read_bytes()
root = Path(sys.argv[2])
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def load(source):
    lua = LuaRuntime(encoding=None)
    lua.execute(b"V={frames={},finish=function()end}; function V.atFrame(n,f) assert(type(f)=='function'); V.frames[#V.frames+1]=n end")
    lua.execute(source)
    return lua.eval(b"#V.frames==3 and V.frames[1]==43 and V.frames[2]==46 and V.frames[3]==49")


assert not fixture.startswith(b'\xef\xbb\xbf'), 'Generated fixture contains a UTF-8 BOM'
assert load(fixture), 'Generated fixture did not register its real three frame callbacks'
try:
    load(b'\xef\xbb\xbf' + fixture)
except Exception:
    pass
else:
    raise AssertionError('BOM negative control unexpectedly loaded')
print('Actual generated fixture Lua 5.4 execution: 3 callbacks PASS; BOM negative rejected.')
