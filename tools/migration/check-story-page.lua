local UI=require 'urhox-libs/UI'
local Page=require 'ui.StoryPage'
local D=require 'ui.SourceDraw'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local s=nil ---@type table?
local root=nil ---@type Widget?
local texts={};local titles={};local level=1;local fixture={};local output=''
local function Capture(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'story page actual GPU capture '..name)
    V.assert(image:SavePNG(output..'/'..name..'.png'),'story page PNG saved '..name);image:Dispose()
end
local function Create(index)
    if root then root:Destroy() end
    level=index;s.storyLevel=index;root=Page.Create(s);UI.SetRoot(root)
end
function HoldStoryPageRoot() if root then UI.SetRoot(root) end end
V.atFrame(2,function()
    local f=assert(io.open('.tmp/story-page-evidence.txt'));output=f:read('*a');f:close()
    f=assert(io.open('.tmp/source-level-pages.json'));fixture=cjson.decode(f:read('*a'));f:close()
    V.assert(fixture.baseline=='2b169a9964645f5f346a7158bcb14447f040814a','frozen StoryPage source identity')
    for _,css in ipairs(fixture.css) do V.assert(css.sameAsFrozen,'actual 5173 CSS equals frozen '..css.path) end
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DESIGN_RESOLUTION(1920,1080),fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    local stored={['story-progress']={s1={grade='S',time=125.9,clears=1},s3={grade='A',time=189.2,clears=2}},['vox.story.voiced']=true}
    s={width=1920,height=1080,Track=function(w)return w end,SetTab=function()end,
        app={store={Read=function(_,key)return stored[key]end,Write=function(_,key,value)stored[key]=value;return true end},
        EnterTrial=function(_,mode)s.started=mode end,toasts={Push=function()end}},
        storyHolo={ready=false,Select=function(self,n)self.level=n end,Dispose=function()end,Update=function()end}}
    local original=D.Text
    D.Text=function(vg,text,x,y,size,color,font,...)
        texts[level]=texts[level] or {};texts[level][tostring(text)]={font=font,size=size,x=x,y=y}
        if text==Data.levels[level].name and font=='vox-legacy-display' and size==56 then titles[level]=true end
        return original(vg,text,x,y,size,color,font,...)
    end
    Create(1);SubscribeToEvent('PostUpdate','HoldStoryPageRoot')
    V.assert(Data.levels[5].ready and Data.levels[5].place=='主引擎坑' and Data.levels[5].map=='enginePit','latest fifth-level metadata')
    local Cloud=require 'storage.CloudStorage';local key='vox-save-v1-vox-garage-vox.story.voiced'
    for _,value in ipairs({true,false}) do V.assert(Cloud.Decode(cjson.encode({v=1,generation=1,data=value}),key)~=nil,'voiced boolean accepted '..tostring(value)) end
    for _,value in ipairs({{},'true',1}) do V.assert(Cloud.Decode(cjson.encode({v=1,generation=1,data=value}),key)==nil,'voiced wrong shape rejected '..type(value)) end
    V.assert(Cloud.Decode(cjson.encode({v=1,generation=1,data=true}),'vox-save-v1-vox-garage-slot1')==nil,'ordinary slot boolean rejected')
    for i=1,5 do s.storyVoice:Load(string.format('C-%02d',i*2-1));s.storyVoice:Load(string.format('C-%02d',i*2)) end
end)
for i=1,5 do
    V.atFrame(4+(i-1)*3,function()
        local row=texts[i] or {};local l=Data.levels[i]
        V.assert(titles[i]==true,'source mixed Chinese Latin story title '..i)
        V.assert(row['开始任务'] and row['开始任务'].size==32,'ready task button '..i)
        V.assert(row[l.place or Data.chapter.name]~=nil,'source location '..i)
        local rec=s.storyProgress[l.id]
        if rec then V.assert(row[rec.grade]~=nil and row['最佳记录']~=nil,'source grade badge and best record '..i) end
        local source=fixture.pages[i];local brief
        for _,item in ipairs(source.items) do if item.selector=='.st-brief' then brief=item.rect end end
        local expected={}
        for _,item in ipairs(source.items) do
            if item.selector=='.st-bin h3' then expected[#expected+1]=item.rect[2]-brief[2] end
        end
        local flow=s.storyBrief.flow
        V.assert(math.abs(flow.objectives-expected[1])<1,'actual source story paragraph height '..i)
        V.assert(math.abs(flow.hostiles-expected[2])<1,'actual source goals flow height '..i)
        Page.Start(s);V.assert(s.started=='story'..i,'production enter task '..i)
        Capture('level-'..i)
        if i<5 then Create(i+1) end
    end)
end
V.atFrame(18,function()
    for n=1,10 do local id=string.format('C-%02d',n);local sound=s.storyVoice.loaded[id]
        V.assert(sound and sound.length>0,'actual original audio decoded '..id)
    end
    local voice=s.storyVoice;voice:Play(5,Data.levels[5].nono[2]);voice:Update(.3,true)
    V.assert(voice.log[#voice.log]=='C-09' and voice.card.sound and voice.card.started,'real replay starts nono fifth-level voice')
    voice:Update(voice.card.duration+.35,true)
    V.assert(voice.log[#voice.log]=='C-10' and voice.card.intercept,'nono hands off to intercepted huhu')
    voice:Select(2,Data.levels[2].nono[2],false);voice:Update(.056,true)
    V.assert(utf8.len(voice:Text())==2 and voice.card.talking,'source silent 28ms typing')
    voice:Update(10,true);V.assert(voice:Text()==Data.levels[2].nono[2] and not voice.card.talking,'silent typing completes')
    Page.Leave(s);V.assert(s.storyVoice==nil and s.storyHolo==nil,'leave disposes page-owned audio and holo')
    UI.SetRoot(nil);root:Destroy();root=nil;V.finish()
end)
