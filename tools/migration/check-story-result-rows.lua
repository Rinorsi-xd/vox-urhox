package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local Rows=require 'story.MissionResultRows'
local classes={}
local base={}
function base:Extend(name)
    local class=setmetatable({},{__index=self,__call=function(c,props)
        return setmetatable({props=props,state={},children={}},{__index=c})
    end})
    class.__index=class;classes[name]=class;return class
end
function base:AddChild(child) self.children[#self.children+1]=child end
function base:SetVisible(value) self.visible=value end
function base:SetStyle(style) self.style=style end
function base:OnClick(event) return self.props.onClick(self,event) end
local width,height=1920,1080
function base:GetAbsoluteLayout() return {x=0,y=0,w=width,h=height} end
package.preload['urhox-libs/UI']=function() return {Panel=base,Button=base} end
package.preload['urhox-libs/UI/Widgets/Button']=function() return base end
local drawn,frameHeight,stackDepth={},0,0
package.preload['ui.SourceDraw']=function() return {
    Text=function(_,text,x,y) drawn[#drawn+1]={text=tostring(text),x=x,y=y} end,
    Begin=function() end,Rect=function() end,Line=function() end,Path=function() end,Color=function() end,
} end
package.preload['ui.WorkshopPaint']=function() return {Image=function() end} end
package.preload['ui.SourceParagraph']=function() return {New=function() return {Draw=function() end} end} end
package.preload['ui.MissionFrame']=function() return {Draw=function(_,_,_,_,h) frameHeight=h end} end
for _,name in ipairs({'nvgTranslate','nvgScale','nvgGlobalAlpha','nvgFillColor','nvgFill','nvgScissor'}) do _G[name]=function() end end
nvgSave=function() stackDepth=stackDepth+1 end
nvgRestore=function() stackDepth=stackDepth-1;Check(stackDepth>=0,'render save/restore balanced') end
local Result=require 'ui.MissionResult'
for _,sample in ipairs(SOURCE.cases) do
    local level=LEVELS[sample.level]
    local rules={time=sample.time,stats=sample.stats,flags=sample.flags,grade='S',finished=true}
    local actual=Rows.Build(level,rules)
    Check(#actual==#sample.rows,'authored row count for mission '..sample.level)
    for i,row in ipairs(sample.rows) do for j,value in ipairs(row) do
        Check(tostring(actual[i][j])==value,'actual frozen source result row '..sample.level..' / '..i..' / '..j)
    end end
    for _,viewport in ipairs({{1920,1080},{2400,1080},{840,378}}) do
        width,height=viewport[1],viewport[2]
        local story={level=level,rules=rules,Quote=function() return '' end}
        local session={story=story,app={},map={id='story'..sample.level}}
        local root=setmetatable({children={}},{__index=base})
        local ui=Result.Attach(session,root);ui.Update(1)
        drawn={};frameHeight=0;ui.result:Render(nil)
        Check(stackDepth==0 and ui.result.visible,'actual result renderer balanced and visible')
        Check(frameHeight==(sample.level==5 and 602 or 640),'Boss result compacts one authored row')
        for i,row in ipairs(sample.rows) do
            local rowY=216+(i-1)*38;local found={}
            for _,text in ipairs(drawn) do
                if text.y==rowY+4 and text.x==62 then found[1]=text.text end
                if text.y==rowY+9 and text.x==160 then found[2]=text.text end
                if text.y==rowY+3 and text.x==678 then found[3]=text.text end
            end
            for j,value in ipairs(row) do Check(found[j]==value,'actual UI renders authored result value') end
        end
        local scale=math.min(1,(width-40)/728,(height-36)/(frameHeight+20))
        local top=(height-frameHeight*scale)/2
        for _,button in ipairs(ui.result.children) do
            Check(button.style.top>=0 and button.style.top+button.style.height<=height,'result commands fit viewport')
            Check(math.abs(button.style.top-(top+(sample.level==5 and 488 or 526)*scale))<.00001,'buttons follow compact result')
        end
        ui.result.children[1]:OnClick({IsPrimaryAction=function() return false end})
        Check(not session.wantsReturn and not session.app.restartStory,'secondary click cannot replay result')
        ui.result.children[1]:OnClick({IsPrimaryAction=function() return true end})
        Check(session.wantsReturn and session.app.restartStory==session.map.id,'replay command retains current map')
        session.wantsReturn=false
        ui.result.children[2]:OnClick({IsPrimaryAction=function() return false end})
        Check(not session.wantsReturn and session.app.restartStory==session.map.id,'secondary click cannot exit result')
        ui.result.children[2]:OnClick({IsPrimaryAction=function() return true end})
        Check(session.wantsReturn and not session.app.restartStory,'back command clears replay')
    end
end
return {result='PASS',checks=checks,scenarios=#SOURCE.cases,viewports=3,
 boundary='Actual Lua result rows and UI Render/Attach against actual frozen JS level resultRows and StoryHud.result HTML. Native-free drawing/UI doubles; no rendered font, GPU, natural Boss gameplay or Web acceptance.'}
