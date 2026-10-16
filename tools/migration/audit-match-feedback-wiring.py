"""Read-only production MatchHud.Attach().Update() integration replay."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute(r'''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local now=10000;Time={GetSystemTime=function()return now end}
local function Widget(props)
 local self={props=props or {},children={}}
 function self:AddChild(child) self.children[#self.children+1]=child end
 function self:SetVisible(value) self.visible=value end
 function self:SetStyle(value) self.style=value end
 return self
end
local UI={Widget={Extend=function()
 local class={};return setmetatable(class,{__call=function(_,props) return setmetatable(Widget(props),{__index=class}) end})
end}}
package.preload['urhox-libs/UI']=function()return UI end
for _,name in ipairs({'ui.SourceDraw','ui.WorkshopPaint'})do package.preload[name]=function()return {} end end
for _,name in ipairs({'ui.SourceButton','ui.MatchResultButton'})do package.preload[name]=function()return Widget end end
for _,name in ipairs({'ui.MatchBanner','ui.MatchFeed','ui.MatchObjectives'})do package.preload[name]=function()return {Update=function()end}end end
package.preload['ui.MatchMinimap']=function()return {New=function()return {Update=function()end,Dispose=function()end}end}end
package.preload['ui.MatchScoreboard']=function()return {Update=function(layer)layer.boardAlpha=0 end}end
local MatchHud=require 'ui.MatchHud'
local b={mode='elimination',rules={state='prep',cfg={prep=10},t=7.1},player={alive=true}}
local session={battle=b};local hud=MatchHud.Attach(session,Widget())
local checks=0
local function Check(value,label)checks=checks+1;assert(value,label)end
Check(b.intro==nil,'production battle does not need invented intro field')
hud.Update(.016);Check(b.prepCount==3,'real HUD update shows ordinary preparation countdown')
session.intro={done=false};now=10016;hud.Update(.016)
Check(b.prepCount==0,'real session intro object hides countdown without battle.intro')
session.intro.done=true;now=10032;hud.Update(.016)
Check(b.prepCount==3,'completed retained session intro object allows countdown')
session.intro=nil;b.intro=true;now=10048;hud.Update(.016)
Check(b.prepCount==3,'explicit inactive session intro overrides stale battle-only field')
b.intro=nil;b.rules.t=8.1;now=11000;hud.Update(.016)
Check(b.prepCount==2 and b.prepCountAt==11,'actual update restarts countdown animation on numeral transition')
local F=require 'ui.MatchFeedback';local count,scale,alpha=F.CountState(b,11)
Check(count==2 and scale==1.35 and alpha==0,'new numeral starts exact source keyframe')
b.rules.state='live';b.rules.sudden=true;hud.Update(.016)
Check(b.prepCount==0 and F.RepairDisabled(b),'live sudden death hides countdown and disables repair')
session.intro={done=false};b.rules.state='prep';b.rules.t=7.1;hud.Update(.016)
Check(b.prepCount==0,'subsequent actual intro suppresses a previously live HUD')
hud.Dispose();return {pass=true,checks=checks}
''')
report = dict(result)
report['production'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in
                        ['scripts/ui/MatchFeedback.lua', 'scripts/ui/MatchHud.lua']}
report['boundary'] = 'Actual Lua MatchHud.Attach/Update and MatchFeedback, UI/native doubles only; no rendered acceptance.'
out = ROOT / 'docs/migration/evidence/match-feedback-wiring-audit.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
