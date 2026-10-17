import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path('.tmp/nav-python-deps').resolve()))
from lupa.lua54 import LuaRuntime

SOURCE = pathlib.Path('tools/migration/endless-edit-stock-web-observer.lua').read_text(encoding='utf8')


def plain(value):
    if hasattr(value, 'items'):
        rows = dict(value.items())
        if rows and set(rows) == set(range(1, len(rows) + 1)):
            return [plain(rows[i]) for i in range(1, len(rows) + 1)]
        return {k: plain(v) for k, v in rows.items()}
    return value


def run(width=200, text='ready', broken_codec=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    emitted = []
    lua.globals().print = lambda value: emitted.append(value)
    lua.globals().testWidth = width
    lua.globals().testText = text
    lua.globals().cjson = lua.table_from({
        'encode': lambda value: '{"partial":' if broken_codec else json.dumps(plain(value), ensure_ascii=False, allow_nan=False, separators=(',', ':')),
        'decode': lambda value: lua.table_from(json.loads(value), recursive=True),
    })
    lua.execute('''
        local widget={node=true,props={text=testText,onClick=true},children={}}
        function widget:IsVisible() return true end
        function widget:GetAbsoluteLayoutForHitTest() return {x=0,y=0,w=testWidth,h=60} end
        local ui={GetViewportSize=function() return 1600,900 end,GetRoot=function() return widget end}
        require=function(name)
            if name=='urhox-libs/UI' then return ui end
            if name=='ui.GarageHud' then return {GetState=function() return {tab='hangar'} end} end
            return {}
        end
        VOX_HANGAR={app={loadingFlow={active=false}}}
        input={GetKeyPress=function() return true end};KEY_F8=1
        HandlePostUpdate=function() end
    ''')
    lua.execute(SOURCE)
    lua.globals().HandlePostUpdate()
    packets = [json.loads(line.split('ENDLESS_STOCK_CHUNK ', 1)[1]) for line in emitted if line.startswith('ENDLESS_STOCK_CHUNK ')]
    assert packets and len(packets) == packets[0]['count']
    payload = ''.join(p['data'] for p in packets)
    assert len(payload.encode()) == packets[0]['bytes']
    checksum = 2166136261
    for byte in payload.encode():
        checksum = ((checksum ^ byte) * 16777619) & 0xffffffff
    assert all(p['checksum'] == checksum for p in packets)
    return json.loads(payload), len(packets)


checks = 0
for number in [math.nan, math.inf, -math.inf]:
    state, _ = run(width=number)
    assert state['widgets'][0]['rect'] is False
    assert state['widgets'][0]['layoutPending'] is True
    checks += 1
state, _ = run()
assert state['widgets'][0]['rect'] == [0, 0, 200, 60]
assert state['widgets'][0]['layoutPending'] is False
checks += 1
state, chunks = run(text='激光炮' * 300)
assert chunks > 1 and state['widgets'][0]['text'] == '激光炮' * 300
checks += 1
for options, expected in [({'text': math.nan}, 'Non-finite endless observer number'), ({'broken_codec': True}, 'Incomplete endless observer JSON')]:
    try:
        run(**options)
        raise AssertionError('Invalid snapshot was accepted')
    except Exception as error:
        assert expected in str(error), str(error)
        checks += 1
print(json.dumps({'status': 'PASS', 'checks': checks, 'boundary': 'Actual Lua observer with UI/codec adapters; no Runtime, browser or production state modified'}))
