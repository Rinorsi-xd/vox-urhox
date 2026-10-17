import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
source=json.loads(subprocess.check_output(['node','tools/migration/source-scoreboard-style.cjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().sourceMetrics=lua.table_from(json.loads((ROOT/'assets/UI/SourceFontMetrics.json').read_text(encoding='utf-8')),recursive=True)
lua.execute('''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['core.ResourceData']={Read=function() return sourceMetrics end}
package.loaded['ui.SourceFonts']={GetBodyFace=function() return nil end}
records={};paths={};gradients={}
local D={white={237,246,255,255},orange={122,216,255,255}}
function D.Text(vg,text,x,y,size,color,font,align,spacing,atBaseline,lineHeight) records[#records+1]={text=tostring(text),x=x,y=y,size=size,color=color,font=font,align=align,spacing=spacing,atBaseline=atBaseline,lineHeight=lineHeight} end
function D.Width(vg,text,size) return utf8.len(tostring(text))*size*.5 end
D.Advance=D.Width
function D.Number(value) return string.format('%.0f',value) end
function D.Color(value) return value end
function D.Path(vg,points) paths[#paths+1]=points end
function D.Gradient(vg,x,y,w,h,a,b,horizontal) gradients[#gradients+1]={x=x,y=y,w=w,h=h,a=a,b=b,horizontal=horizontal} end
D.Rect=function() end
package.loaded['ui.SourceDraw']=D
package.loaded['ui.WorkshopPaint']={Glow=function() end,Image=function() end}
package.loaded['combat.MvpMotion']={Score=function(st) return st.kills*300+st.assists*120+st.damage*.02 end}
package.loaded['ui.SourceButtonMotion']={Ease=function(t) return t end}
for _,name in ipairs({'nvgSave','nvgRestore','nvgGlobalAlpha','nvgFillColor','nvgFill'}) do _G[name]=function() end end
nvgRGBA=function() return {} end
NVG_ALIGN_RIGHT=1;NVG_ALIGN_CENTER=2
board=require 'ui.MatchScoreboard'
function recordBoard(w,h,k,over,n,damage)
 records={};paths={};gradients={}
 local rules={state=over and 'over' or 'live',score={blue=0,red=0},round=1,half=1,history={}}
 function rules:TimeLeft() return 120 end
 local b={rules=rules,entries={},stats={},clock=0,mode='conquest',result=over and {delta=1,xp=5,profile={rating=20,level=1}} or nil}
 for _,team in ipairs({'blue','red'}) do for i=1,n do
  local u={team=team,alive=true,name='very long source mechanic name '..i}
  b.entries[#b.entries+1]={unit=u,member={avatar='me',level=7,role='heavy',rating=1200}}
  b.stats[u]={kills=2,assists=3,deaths=4,damage=damage}
 end end
 b.player=b.entries[1].unit
 local layer={boardAlpha=1};board.Draw(nil,layer,b,w,h,k,{name='source mode',en='CONQUEST',size=n})
 return records,paths,gradients,layer.resultRect
end
''')
checks=0
cases=[]
def check_draw(over,n,w,h,k,damage):
    global checks
    rows,paths,gradients,result_rect=lua.globals().recordBoard(w,h,k,over,n,damage)
    values=[rows[i] for i in range(1,len(rows)+1)]
    damage_rows=[r for r in values if r['text']==str(damage) and r['size']==source['damageSize']]
    assert len(damage_rows)==2*n
    for row in damage_rows:
        assert [row['color'][i] for i in range(1,5)]==source['damageColor']
        assert row['font']=='vox-display' and row['align']==2
        checks+=3
    # Fixed CSS grid tracks leave the mechanic name as the only flexible column.
    bw=min(1440,w*.94);left=(w-bw)/2+34;rw=bw-68
    grid=source['gridWidths'];name_width=rw-sum(grid)
    expected_x=left+grid[0]+name_width+sum(grid[1:5])+grid[5]/2
    assert all(abs(r['x']-expected_x)<1e-9 for r in damage_rows)
    assert name_width>0
    assert bool(result_rect)==over
    assert all(r['size']==19 for r in damage_rows)
    checks+=4
    first=paths[1];board_top=first[2];board_bottom=first[8]
    cases.append({'w':w,'h':h,'scale':k,'over':over,'teamSize':n,'damage':damage,
                  'boardWidth':bw,'boardTop':board_top,'boardBottom':board_bottom,
                  'withinVirtualHeight':board_top>=0 and board_bottom<=h,'damageColumnCenter':expected_x})
for w,h,k in [(1920,1080,1),(2400,1080,1),(1920,1080,5/6),(2400/1.44,1080/1.44,1.44)]:
    for over in (False,True):
        for n in (3,4):
            for damage in (0,123456): check_draw(over,n,w,h,k,damage)
production='scripts/ui/MatchScoreboard.lua'
code=(ROOT/production).read_text(encoding='utf-8')
old=code.replace(' or i==5 and damageColor','')
assert old!=code
lua.globals().board=lua.execute(old)
mutated=lua.globals().recordBoard(1920,1080,1,False,4,123456)[0]
damages=[mutated[i] for i in range(1,len(mutated)+1) if mutated[i]['text']=='123456' and mutated[i]['size']==19]
assert damages and any([row['color'][i] for i in range(1,5)]!=source['damageColor'] for row in damages)
checks+=1
report={'result':'PASS','checks':checks,'cases':cases,'rejectedMutations':1,'source':source,
        'production':{production:hashlib.sha256((ROOT/production).read_bytes()).hexdigest()},
        'boundary':'Runs real Lua Draw and frozen JS _rows offline. Verifies source damage color, size, font routing and desktop fixed column arithmetic at virtual 16:9/20:9 and existing scaled hosts. Uses source font metrics for Layout but draw-recording width stubs for Fit; does not certify raster fit. The viewport height limit is checked as drawing geometry only. Dedicated scoreboard-layout evidence covers original DOM boxes and native ScrollView methods. No game Web package, rendered parity or device acceptance.'}
(ROOT/'docs/migration/evidence/scoreboard-style-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':checks,'cases':len(cases),'rejectedMutations':1,'overflowCases':sum(not row['withinVirtualHeight'] for row in cases),'production':report['production']},ensure_ascii=False,indent=2))
