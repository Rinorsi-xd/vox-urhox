import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
source=json.loads(subprocess.check_output(['node','tools/migration/source-scoreboard-copy.cjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().sourceMetrics=lua.table_from(json.loads((ROOT/'assets/UI/SourceFontMetrics.json').read_text(encoding='utf-8')),recursive=True)
lua.execute('''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['core.ResourceData']={Read=function() return sourceMetrics end}
package.loaded['ui.SourceFonts']={GetBodyFace=function() return nil end}
records={}
local D={white={},orange={}}
function D.Text(vg,text,x,y,size,color,font) records[#records+1]={text=tostring(text),font=font,size=size} end
function D.Width(vg,text,size) return #tostring(text)*size*.4 end
D.Advance=D.Width
function D.Number(value) return tostring(value) end
function D.Color(value) return value end
for _,name in ipairs({'Path','Rect','Gradient'}) do D[name]=function() end end
package.loaded['ui.SourceDraw']=D
package.loaded['ui.WorkshopPaint']={Glow=function() end,Image=function() end}
package.loaded['combat.MvpMotion']={Score=function() return 0 end}
package.loaded['ui.SourceButtonMotion']={Ease=function(t) return t end}
for _,name in ipairs({'nvgSave','nvgRestore','nvgGlobalAlpha','nvgFillColor','nvgFill'}) do _G[name]=function() end end
nvgRGBA=function() return {} end
NVG_ALIGN_RIGHT=1;NVG_ALIGN_CENTER=2
board=require 'ui.MatchScoreboard'
function recordBoard(mode,en,size,over)
 records={}
 local rules={state=over and 'over' or 'live',score={blue=0,red=0},round=1,half=1,history={}}
 function rules:TimeLeft() return 120 end
 local b={rules=rules,entries={},stats={},clock=0,mode=mode,result=over and {delta=1,xp=5,profile={rating=20,level=1}} or nil}
 board.Draw(nil,{boardAlpha=1},b,1920,1080,1,{name='原模式',en=en,size=size})
 return records
end
''')
checks=0
for case in source['cases']:
    for over in (False,True):
        rows=lua.globals().recordBoard(case['id'],case['en'],case['size'],over)
        texts=[rows[i]['text'] for i in range(1,len(rows)+1)]
        for header in case['headers']:
            assert header in texts,header
            checks+=1
        assert '阵亡' not in texts
        assert (case['subtitle'] in texts)==(not over)
        checks+=2
        if not over:
            item=next(rows[i] for i in range(1,len(rows)+1) if rows[i]['text']==case['subtitle'])
            assert item['font']=='vox-title' and item['size']==12
            checks+=1
production='scripts/ui/MatchScoreboard.lua'
code=(ROOT/production).read_text(encoding='utf-8')
for before,after in [('被毁','阵亡'),(' · 坠舰陨坑 · AI 对战（离线）',' · 坠舰陨坑')]:
    assert before in code
    changed=code.replace(before,after)
    lua.globals().board=lua.execute(changed)
    case=source['cases'][0]
    rows=lua.globals().recordBoard(case['id'],case['en'],case['size'],False)
    texts=[rows[i]['text'] for i in range(1,len(rows)+1)]
    assert any(h not in texts for h in case['headers']) or case['subtitle'] not in texts
    checks+=1
report={'result':'PASS','checks':checks,'rejectedMutations':2,'source':source,'production':{production:hashlib.sha256((ROOT/production).read_bytes()).hexdigest()},'boundary':'Executes frozen JS _rows/_board and real Lua MatchScoreboard.Draw with drawing-recording stubs. Confirms copy and preserved font/size only; no Yoga/NanoVG rasterization, layout fit, natural HUD, Web package or device performance acceptance.'}
(ROOT/'docs/migration/evidence/scoreboard-copy-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
