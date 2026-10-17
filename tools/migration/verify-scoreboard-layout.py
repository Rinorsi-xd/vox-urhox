"""Source DOM boxes + real Lua drawing/ScrollView; host supplies Yoga rectangles."""
import hashlib,json,os,runpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
fixture=runpy.run_path(str(ROOT/'tools/migration/verify-scoreboard-style.py'))
lua=fixture['lua']
lua.globals().board=lua.execute((ROOT/'scripts/ui/MatchScoreboard.lua').read_text(encoding='utf-8'))
lua.execute('''
local D=package.loaded['ui.SourceDraw'];D.Begin=function() end
local function Noop() end
for _,name in ipairs({'nvgTranslate','nvgScale'}) do _G[name]=Noop end
clips={};nvgIntersectScissor=function(vg,x,y,w,h) clips[#clips+1]={x=x,y=y,w=w,h=h} end
local Typography=require 'ui.SourceTextLayout'
function D.Width(vg,text,size,font,spacing)
 local layout=Typography.Get(tostring(text),font or 'vox-title')
 assert(layout,'Missing source metrics: '..tostring(text));return Typography.Width(layout,size,spacing)
end
D.Advance=D.Width
function makeBattle(over,n)
 local rules={state=over and 'over' or 'live',score={blue=50,red=40},round=1,half=1,history={}}
 function rules:TimeLeft() return 120 end
 local b={rules=rules,entries={},stats={},clock=0,mode='conquest',boardOn=true,
  result=over and {delta=5,xp=10,profile={rating=1200,level=7}} or nil}
 for _,team in ipairs({'blue','red'}) do for i=1,n do
  local u={team=team,alive=true,name='长名字工程师'..i}
  b.entries[#b.entries+1]={unit=u,member={avatar='me',level=7,role='heavy',rating=1200}}
  b.stats[u]={kills=2,assists=3,deaths=4,damage=123456}
 end end
 b.player=b.entries[1].unit;return b
end
cfg={name='站点争夺',en='CONQUEST',size=4}
function layoutBoard(w,h,over,n)
 local b=makeBattle(over,n);local c={name=cfg.name,en=cfg.en,size=n}
 local m=board.Layout(w,h,b,c,w>h and h<=600)
 records={};paths={};gradients={};board.Draw(nil,{boardAlpha=1},b,w,h,1,c,m)
 return m,records
end
local Widget={};Widget.__index=Widget
local function Class(base)
 local cls={};cls.__index=cls
 setmetatable(cls,{__index=base,__call=function(c,props) local obj=setmetatable({},c);obj:Init(props or {});return obj end})
 return cls
end
function Widget:Extend() return Class(self) end
function Widget:Init(props) self.props=props;self.children={};self.state=self.state or {};self.styleWrites=0;self.node=self end
YGNodeLayoutGetTop=function(node) return node:GetLayout().y end
function Widget:AddChild(c) self.children[#self.children+1]=c;c.parent=self;return self end
function Widget:SetStyle(styles) for k,v in pairs(styles) do self.props[k]=v end;self.styleWrites=self.styleWrites+1 end
function Widget:SetVisible(value) self.props.visible=value end
function Widget:IsVisible() return self.props.visible~=false and (not self.parent or self.parent:IsVisible()) end
function Widget:GetLayout()
 local p=self.props;local pl=self.parent and self.parent:GetLayout() or {w=hostW,h=hostH}
 return {x=p.left or 0,y=p.top or 0,w=p.width=='100%' and pl.w or p.width or 0,h=p.height=='100%' and pl.h or p.height or 0}
end
function Widget:GetAbsoluteLayout()
 local r=self:GetLayout();if self.parent then local p=self.parent:GetAbsoluteLayout();r.x=r.x+p.x;r.y=r.y+p.y end;return r
end
function Widget:GetAbsoluteLayoutForHitTest()
 local r=self:GetAbsoluteLayout();local p=self.parent
 while p do if p.GetScroll then local x,y=p:GetScroll();r.x=r.x-x;r.y=r.y-y end;p=p.parent end;return r
end
function Widget:GetRenderChildren() return self.children end
function Widget:HitTest(x,y) local r=self:GetAbsoluteLayoutForHitTest();return x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end
Widget.OnPointerDown=Noop;Widget.OnPointerUp=Noop
function Widget:OnClick() self.props.onClick() end
local UI={Widget=Class(Widget),GetScale=function() return hostScale end,CancelPointer=Noop}
package.loaded['urhox-libs/UI/Core/Widget']=Widget
package.loaded['urhox-libs/UI/Core/Theme']={};package.loaded['urhox-libs/UI/Core/Style']={}
package.loaded['urhox-libs/UI/Core/UI']=UI
package.loaded['urhox-libs/UI/Core/PointerEvent']={PointerTypes={Mouse='mouse'}}
package.loaded['urhox-libs/UI']=UI
UI.ScrollView=require 'urhox-libs/UI/Widgets/ScrollView'
package.loaded['ui.ActionButton']=UI.Widget
package.loaded['ui.SourceButton']=UI.Widget
package.loaded['ui.SourceRelief']={Draw=Noop}
package.loaded['ui.MatchBanner']={Scale=function() return 1 end,Update=Noop,Draw=Noop}
for _,name in ipairs({'MatchTop','MatchObjectives','MatchFeed','MatchComms','MatchFeedback','MatchSpectator'}) do
 package.loaded['ui.'..name]={Update=Noop,Draw=Noop}
end
package.loaded['ui.MatchMinimap']={New=function() return {Update=Noop,Dispose=Noop} end}
package.loaded['combat.MatchActions']={Again=function(b) b.again=true end,ConfirmLeave=Noop}
package.loaded['combat.ArenaData']={modes={conquest=cfg}}
package.loaded['ui.MatchScoreboard']=board
graphics={GetDPR=function() return hostDpr end}
GetPlatform=function() return 'Web' end
hud=require 'ui.MatchHud'
local originalLayout=board.Layout
layoutCalls=0
board.Layout=function(...) layoutCalls=layoutCalls+1;return originalLayout(...) end
function attachBoard(w,h,dpr,scale,over)
 hostW=w;hostH=h;hostDpr=dpr;hostScale=scale
 local root=UI.Widget{width=w,height=h};local s={battle=makeBattle(over,4),touch=false}
 local result=hud.Attach(s,root);result.Update(.2);result.scoreboardScroll:Update(1/60)
 return result,s,root
end
function pointerHit(widget,x,y)
 if not widget:IsVisible() or widget.props.pointerEvents=='none' then return nil end
 if widget.GetScroll and not widget:HitTest(x,y) then return nil end
 for i=#widget.children,1,-1 do local hit=pointerHit(widget.children[i],x,y);if hit then return hit end end
 if widget.props.pointerEvents~='box-none' and widget:HitTest(x,y) then return widget end
end
''')
checks=0
cases=[]
source=json.loads((ROOT/'docs/migration/evidence/scoreboard-source-dom.json').read_text(encoding='utf-8'))
for row in source['cases']:
    m,draw=lua.globals().layoutBoard(row['width'],row['height'],row['over'],4)
    assert abs(m['w']-row['card']['w'])<.02
    assert abs(m['viewH']-row['card']['h'])<.02
    assert abs(m['header']-row['head']['h'])<.02,(row['width'],m['header'],row['head']['h'])
    assert abs(m['h']-row['scrollHeight'])<1
    assert abs(m['row']-row['row']['h'])<.02
    assert abs(m['avatar']-row['avatar']['w'])<.02
    assert abs(m['contentW']-row['scrollWidth'])<1
    checks+=7
    if row['over']:
        assert abs(m['footer']-row['foot']['h'])<.02
        assert abs(m['buttonBack']-row['button']['w'])<.02
        assert abs(m['buttonH']-row['button']['h'])<.02
        checks+=3
        title=next(draw[i] for i in range(1,len(draw)+1) if draw[i]['text']=='平局')
        score=next(draw[i] for i in range(1,len(draw)+1) if draw[i]['text']=='50%:40%')
        source_title=row['headerChildren'][0]['rect'];source_score=row['headerChildren'][1]['rect']
        for actual,expected in [(title,source_title),(score,source_score)]:
            assert abs(actual['x']-(expected['x']-row['card']['x']))<.02
            assert abs(actual['y']-(expected['y']-row['card']['y']))<.02
            assert actual['size']==float(expected['fontSize'].replace('px',''))
            assert abs(actual['lineHeight']-expected['h'])<.02
            checks+=4
        assert score['spacing']==2 and title['spacing']==10
        assert score['font']=='vox-display' and title['font']=='vox-title'
        assert abs(title['y']+title['lineHeight']-score['y']-score['lineHeight'])<.02
        assert abs(m['scoreWidth']-source_score['w'])<.02
        assert not any(draw[i]['text']==':' for i in range(1,len(draw)+1))
        checks+=5
    first_name=next(draw[i] for i in range(1,len(draw)+1) if draw[i]['text'].startswith('长名字'))
    expected_y=row['name']['y']-row['card']['y']
    assert abs(first_name['y']-expected_y)<.02
    assert first_name['size']==float(row['name']['fontSize'].replace('px',''))
    checks+=2
    cases.append({'width':row['width'],'height':row['height'],'over':row['over'],'header':m['header'],'viewHeight':m['viewH'],'contentHeight':m['h'],'contentWidth':m['contentW'],'compact':m['compact']})
interactions=[]
for w,h,dpr,scale in [(1920,1080,1,1),(2400,1080,1,1),(960,432,1,1),(800,360,1,1),(1200,540,3,2),(600,270,2,1),(640,360,1,1)]:
    for over in [False,True]:
        result,session,root=lua.globals().attachBoard(w,h,dpr,scale,over)
        scroll=result['scoreboardScroll'];content=result['scoreboardContent'];m=result['scoreboardLayout']
        r=scroll.GetAbsoluteLayout(scroll);cw,ch=scroll.GetContentSize(scroll)
        assert r['x']>=0 and r['y']>=0 and r['x']+r['w']<=w+.001 and r['y']+r['h']<=h+.001
        assert abs(cw-m['contentW']*dpr/scale)<.001 and abs(ch-m['h']*dpr/scale)<.001,(w,h,over,cw,ch,m['contentW'],m['h'])
        assert m['compact']==(w>h and h*scale/dpr<=600)
        before=lua.globals().layoutCalls
        writes=scroll['styleWrites']+content['styleWrites']
        for _ in range(120): result.Update(1/60)
        assert lua.globals().layoutCalls==before
        assert writes==scroll['styleWrites']+content['styleWrites']
        checks+=5
        max_y=max(0,ch-r['h']);max_x=max(0,cw-r['w'])
        scroll.OnWheel(scroll,-100000,-100000)
        x,y=scroll.GetScroll(scroll)
        assert x==max_x and y==max_y
        scroll.OnWheel(scroll,100000,100000)
        assert scroll.GetScroll(scroll)==(0,0)
        assert scroll.OnPanStart(scroll,lua.table_from({'pointerType':'mouse'})) is False
        assert scroll.OnPanStart(scroll,lua.table_from({'pointerType':'touch','pointerId':1})) is True
        scroll.OnPanMove(scroll,lua.table_from({'totalDeltaX':-100000,'totalDeltaY':-100000,'deltaX':-4,'deltaY':-4}))
        scroll.OnPanEnd(scroll,lua.table_from({}))
        assert scroll.GetScroll(scroll)==(max_x,max_y)
        checks+=5
        scroll['props']['showScrollbar']=False
        scroll.CustomRenderChildren(scroll,None,lua.eval('function() end'))
        scroll['props']['showScrollbar']=True
        clip=lua.globals().clips[len(lua.globals().clips)]
        assert clip['x']==r['x'] and clip['y']==r['y'] and clip['w']==r['w'] and clip['h']==r['h']
        checks+=1
        if over:
            for button_name in ['back','retry']:
                button=result[button_name];raw=button.GetAbsoluteLayout(button)
                scroll.SetScroll(scroll,raw['x']-r['x'],raw['y']-r['y']-r['h']/2)
                br=button.GetAbsoluteLayoutForHitTest(button)
                assert br['y']>=r['y'] and br['y']+br['h']<=r['y']+r['h']+.001,(w,h,button_name,dict(br),dict(r),max_y)
                hit=lua.globals().pointerHit(root,br['x']+br['w']/2,br['y']+br['h']/2)
                assert lua.eval('function(a,b) return a==b end')(hit,button)
                button.OnClick(button)
                checks+=3
            assert session['wantsReturn'] and session['battle']['again'];checks+=1
        else:
            session['battle']['boardOn']=False;result.Update(1/60)
            assert not scroll.IsVisible(scroll) and scroll.GetScroll(scroll)==(0,0)
            before=lua.globals().layoutCalls;writes=scroll['styleWrites']+content['styleWrites']
            bounds_before=scroll.GetContentSize(scroll)
            for _ in range(120):
                result.Update(1/60)
                scroll.Update(scroll,1/60)
            assert lua.globals().layoutCalls==before and writes==scroll['styleWrites']+content['styleWrites']
            assert scroll.GetContentSize(scroll)==bounds_before
            session['battle']['boardOn']=True;result.Update(.2)
            assert scroll.IsVisible(scroll) and scroll.GetScroll(scroll)==(0,0)
            checks+=3
        result.Dispose()
        assert not scroll.IsVisible(scroll) and scroll.GetScroll(scroll)==(0,0)
        assert scroll['state']['velocityX']==0 and scroll['state']['velocityY']==0
        checks+=2
        interactions.append({'host':[w,h],'dpr':dpr,'uiScale':scale,'over':over,'compact':m['compact'],'scrollX':max_x,'scrollY':max_y})
production=['scripts/ui/MatchScoreboard.lua','scripts/ui/MatchHud.lua','scripts/ui/MatchResultButton.lua']
report={'result':'PASS','checks':checks,'sourceDomCases':cases,'interactions':interactions,
        'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in production},
        'boundary':'Actual frozen source DOM box measurements and source font metrics; executes real MatchScoreboard Draw/Layout, MatchHud Attach/Update, MatchResultButton and bundled ScrollView wheel/pan/clipping/state methods. Minimal widget host supplies rectangles and pointer traversal, so this does not certify Yoga layout, engine input dispatch, raster parity, game Web package, mobile device FPS or optimization gain.'}
(ROOT/'docs/migration/evidence/scoreboard-layout-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':checks,'sourceDomCases':len(cases),'interactionCases':len(interactions),'production':report['production']},indent=2))
