local phase='boot';local a=nil ---@type table|nil
local b=nil ---@type table|nil
local pausedAt=0;local elapsed=0;local sample=0
local C=require 'audio.StoryComms'
local UI=require 'urhox-libs/UI'
local Card=require 'ui.CommsCard'
local Layer=UI.Widget:Extend('CommsAcceptance')
function Layer:Render(vg)
    require('ui.SourceDraw').Begin(vg)
    local card=b and b.card
    if card then Card.Draw(vg,card,40,300,646,Card.Height(vg,card,646),1,b.time) end
end
local function Logic()
    local scene=VOX_HANGAR.app.scene;local data={voices={}}
    a=C.New(scene,data,true);a:Say({{'nono','第一句测试文本。','nono_talk'}});a:Update(.1,true)
    V.assert(a:Owns() and a.card~=nil,'initial owner claims retained singleton')
    local card=a.card;a:Say({{'huhu','追加台词。'}},true,true)
    V.assert(a.card==card and #a.queue==1,'append never interrupts urgent dialogue')
    a:SkipLine();V.assert(a.card.finishedTyping and a.card.age<card.length,'first skip finishes text without advancing voice clock')
    a:SkipLine();a:Update(.01,true);a:Update(.01,true)
    V.assert(a.card.who=='huhu','second skip advances to appended line')
    b=C.New(scene,data,true);b:Say({{'boss','董事长文字。'}});b:Update(.01,true)
    V.assert(not a:Owns() and a.card==nil and #a.queue==0,'previous owner loses readable card and queue')
    local boss=b.card;a:Hide();a:Dispose();V.assert(b.card==boss,'stale release cannot hide new owner')
    V.assert(math.abs(b.card.typing-utf8.len(b.card.text)*.12)<1e-6,'chairman uses source slow typing')
    b:Update(20,true);V.assert(b.card==boss,'keepOpen retains last line')
    b:Say({{'nono','新台词。'}},true);b:Update(.01,true)
    V.assert(b.card~=boss and #b.queue==0,'urgent batch replaces old card immediately')
    local realSource=b.source
    b.source={playing=true,timePosition=0};b.card.started=true;b.card.lead=.26
    local before=b.card.age;b:Update(.5,true)
    V.assert(math.abs(b.card.age-before-.5)<1e-6,'frozen Web audio cursor cannot stall the source subtitle clock')
    b.source=realSource
    local age=b.card.age;b:Update(1,false);V.assert(b.card.age==age,'focus pause preserves dialogue clock')
    b:Dispose()
    local original=require('core.ResourceData').Read('UI/Tutorial.json');b=C.New(scene,original,true)
    b:Say({original.steps[1].lines[1]},true)
    UI.RegisterGlobalComponent('comms-acceptance',Layer{pointerEvents='none'})
end
local function Poll()
    if phase=='boot' and VOX_HANGAR then
        Logic();phase='voice';elapsed=0
    elseif phase=='voice' then
        b:Update(.05,true);elapsed=elapsed+.05
        if b.source.playing then
            V.assert(#b.log==1 and b.card.id~=nil,'source tutorial sentence resolves and plays once')
            V.assert(b.source.frequency==b.card.sound.frequency,'voice uses original sample rate')
            V.assert(b.card.lead==.26 and b.card.length>b.card.sound.length+.8,'voice subtitle clock includes source lead and tail')
            phase='playing';sample=0
        elseif elapsed>6 then V.assert(false,'original voice became ready');V.finish() end
    elseif phase=='playing' then
        b:Update(.05,true);sample=sample+1
        if sample==5 then pausedAt=b.source.timePosition;b:Update(0,false);phase='paused';sample=0 end
    elseif phase=='paused' then
        b:Update(.05,false);sample=sample+1
        if sample==5 then
            V.assert(math.abs(b.source.timePosition-pausedAt)<.06,'native audio cursor holds while unfocused')
            b:Update(0,true);phase='resumed';sample=0
        end
    elseif phase=='resumed' then
        b:Update(.05,true);sample=sample+1
        if sample==5 then
            V.assert(b.source.timePosition>pausedAt and #b.log==1,'focus resume continues same playback without restart')
            local old=b.source;b:Say({{'huhu','拦截信号测试。','huhu_talk'}},true);b:Update(.01,true)
            V.assert(b.card.who=='huhu' and old.playing,'new subtitles appear during old voice fade')
            phase='fade';sample=0
        end
    elseif phase=='fade' then
        b:Update(.05,true);sample=sample+1
        if sample==30 then
            V.assert(not b.source.playing,'interrupted voice completes fade')
            local portrait=Card.GetPortrait('huhu')
            for i,texture in ipairs(portrait.textures) do
                local pixels=texture:GetImage();local visible=0
                for y=0,pixels.height-1,8 do for x=0,pixels.width-1,8 do local p=pixels:GetPixel(x,y);if p.a>.05 and p.r+p.g+p.b>.05 then visible=visible+1 end end end
                V.assert(visible>20,'GPU portrait target '..i..' contains visible original face pixels')
                pixels:SavePNG('docs/migration/evidence/comms-target-'..i..'.png');pixels:Dispose()
            end
            local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/comms-native.png');image:Dispose()
            UI.UnregisterGlobalComponent('comms-acceptance');b:Dispose();phase='done';V.finish()
        end
    end
end
for frame=40,180 do V.atFrame(frame,Poll) end
V.atFrame(185,function() V.assert(phase=='done','shared comms ownership, audio and GPU render complete');V.finish() end)
