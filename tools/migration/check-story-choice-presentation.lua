package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local now,checks,samples=0,0,0
NOW=0;Time={GetSystemTime=function() return NOW end}
local function Check(ok,label) checks=checks+1;assert(ok,label) end
local function Near(a,b,label) Check(math.abs(a-b)<.002,label..' '..a..' / '..b) end
local State=require 'ui.MissionChoiceState'
for _,test in ipairs(SOURCE.cases) do
    now=0;NOW=0
    local state=State.New();local choices={};local current;local replies,cues=0,{}
    for i,op in ipairs(test.ops) do
        if op.at then now=op.at;NOW=now end
        if op.op=='open' then
            current={id=op.id,prompt=op.prompt,options={{label='继续'},{label='先看看'},{label='拒绝'}}};choices[op.id]=current
            state:Open(current,now);cues[#cues+1]='open'
        elseif op.op=='pick' or op.op=='click' then
            if state:Pick(current,op.index,now) then replies=replies+1;cues[#cues+1]='pickup' end
        elseif op.op=='cancel' then state:Cancel(now) end
        local actual=state:State(now);local wanted=test.trace[i];samples=samples+1
        Check((actual~=nil)==wanted.hasChoice,test.name..' retained DOM')
        if actual then
            Check(actual.choice.id==wanted.id,test.name..' choice identity')
            Check(actual.on==wanted.on,test.name..' on')
            Check(actual.choosing==wanted.choosing,test.name..' immediate logical resolution')
            Check((actual.picked or 0)==wanted.picked,test.name..' chosen row')
            Near(actual.alpha,wanted.alpha,test.name..' CSS opacity')
            Near(actual.x,wanted.x,test.name..' CSS transform')
            Check(actual.visible==(wanted.on or wanted.alpha>0 or wanted.x> -16),test.name..' exit visibility')
        end
        Check(replies==wanted.replyCount,test.name..' one reply immediately')
        Check(#cues==#wanted.cues,test.name..' cue count')
        for n,cue in ipairs(cues) do Check(cue==wanted.cues[n],test.name..' cue order') end
    end
    state:Dispose();state:Open(current);state:Pick(current,1);state:Cancel();Check(state:State()==nil,test.name..' disposed cannot revive')
end
-- Real production rule payload and Mission.Events, including same-drain timeout.
for _,name in ipairs({'combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'}) do package.loaded[name]={} end
package.loaded['story.MissionData']={}
local Mission=require 'story.Mission'
local Rules=require 'story.MissionRules'
local level={steps={{id='talk',kind='talk',title='聊聊',start={}}},spawn={pos={0,0,0}}}
local rules=Rules.New(level);local events={}
local m=setmetatable({rules=rules,choiceView=State.New(),player={alive=true},level=level,voice={Say=function(_,lines,urgent) events[#events+1]={kind='say',lines=lines,urgent=urgent} end},
    radio={Play=function(_,cue) events[#events+1]={kind='radio',cue=cue} end},view={Objective=function() end}},Mission)
local choice={id='reply',prompt='如何回答',timeout=0,options={{label='一',reply={'first'}},{label='二',reply={'second'}}}}
now=0;NOW=0;rules:Ask(choice);rules:Choose(2);m:Events()
local s=m.choiceView:State();Check(s.choice==choice and s.picked==2 and not s.choosing,'same drain Ask/Pick keeps original choice')
Check(rules.choice==nil and rules.flags.reply==1,'real flags zero based and immediate')
Check(#events==3 and events[1].cue=='open' and events[2].cue=='pickup' and events[3].lines==choice.options[2].reply and events[3].urgent,'radio/reply ordering unchanged')
Check(not rules:Choose(1),'duplicate selection rejected by actual rules')
now=499;NOW=now;Check(m.choiceView:State().on,'confirmation remains at499')
now=500;NOW=now;Check(not m.choiceView:State().on,'confirmation exits at500')
now=1000;NOW=now;rules:Ask(choice);m:Events();rules:Go(1);m:Events();Check(not m.choiceView:State().on and not m.choiceView:State().choosing,'actual next objective cancels choice')
now=2000;NOW=now;rules:Ask(choice);m:Events();rules:UpdateChoices();m:Events();Check(m.choiceView:State().picked==1 and rules.flags.reply==0,'actual default selects and displays confirmation')
now=3000;NOW=now;rules:Ask(choice);m:Events();rules:Fail('失败',{});m.Banner=function() end;m:Events();Check(m.choiceView:State().choosing,'failure itself does not cancel source choice')
-- Execute the actual production UI attachment, callback and custom Render.
local calls={};local function Noop() end
for _,name in ipairs({'nvgFill','nvgStroke','nvgStrokeWidth','nvgStrokeColor','nvgBeginPath','nvgRect','nvgFillColor'}) do _G[name]=Noop end
NVG_ALIGN_CENTER=1
local Base={};Base.__index=Base
function Base:Extend() local class=setmetatable({},self);class.__index=class;return setmetatable(class,{__index=self,__call=function(t,props) return setmetatable({props=props,state={},children={},style={}},t) end}) end
function Base:AddChild(child) child.parent=self;self.children[#self.children+1]=child end
function Base:SetVisible(visible) self.visible=visible end
function Base:SetStyle(style) for k,v in pairs(style) do self.style[k]=v end end
function Base:SetText(text) self.props.text=text end
function Base:GetAbsoluteLayout() return {x=186,y=628,w=self.parent and self.parent.style and self.parent.style.width or self.style.width or 480,h=self.props.height or self.style.height or 168} end
package.loaded['urhox-libs/UI']={Panel=Base,GetViewportSize=function() return 1920,1080 end}
package.loaded['ui.ActionButton']=Base
package.loaded['ui.SourceDraw']={Begin=Noop,Path=Noop,Gradient=Noop,Color=function(c) return c end,Rect=Noop,
    Width=function(_,text,size) return utf8.len(text)*size*.5 end,Text=function(_,text,x,y,size,color,font,align,spacing) calls[#calls+1]={text=text,color=color,font=font,spacing=spacing} end}
local root={children={},AddChild=Base.AddChild};local resumes=0
local update=require('ui.MissionChoice').Attach({story=m,touch=false,Resume=function() resumes=resumes+1 end},root)
update();local panel=root.children[1];Check(panel.visible and panel.style.top==674 and panel.style.height==122,'actual two-option panel bottom284 and source prompt height')
panel:Render({});Check(panel.naturalWidth==300,'actual render computes natural minimum300')
Check(panel.children[1].props.text=='一' and panel.children[2].props.text=='二' and not panel.children[3].visible,'actual authored labels and option count')
now=3300;NOW=now;panel.children[2].props.onClick();update()
Check(m.choiceView:State().picked==2 and resumes==1,'actual UI click chooses and resumes once')
panel.children[2]:Render({});local text=calls[#calls];Check(text.text=='二' and text.color[1]==4 and text.color[2]==18 and text.color[3]==31 and text.spacing==1,'actual selected text darkink and source tracking')
panel.children[1].props.onClick();Check(resumes==1 and rules.flags.reply==1,'actual duplicate UI click ignored')
now=3800;NOW=now;update();Check(panel.visible and panel.style.pointerEvents=='none','actual exit remains drawn while input disabled')
now=4100;NOW=now;update();Check(not panel.visible,'actual exit hides after transition')
return {status='PASS',checks=checks,cases=#SOURCE.cases,samples=samples,boundary='Frozen full StoryHud class plus CSS easing oracle / actual production state, rules and Mission.Events. Native rendering, full story and phone remain unverified.'}
