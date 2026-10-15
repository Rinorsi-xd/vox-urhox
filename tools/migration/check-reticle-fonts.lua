local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Sample=Panel:Extend('ReticleFontAcceptance')
local captured=false
function Sample:Render(vg)
    D.HudFont(vg);D.Rect(vg,0,0,1000,600,{35,52,65,255});R.SetTextScale(1)
    local face;local calls={}
    local originalFace,originalText=nvgFontFace,nvgText
    if not captured then
        nvgFontFace=function(ctx,name) face=name;return originalFace(ctx,name) end
        nvgText=function(ctx,x,y,text) calls[#calls+1]={font=face,text=text,x=x,y=y};return originalText(ctx,x,y,text) end
    end
    R.Text(vg,'HP 100',80,100,44,R.hp,nil,false)
    R.Text(vg,'就绪 READY',80,165,21,R.white,nil,false,false,4)
    R.Text(vg,'结构 75%',80,215,14,R.muted,nil,true)
    R.Text(vg,'冷却中 / COOLING',80,265,13,R.muted,nil,false,true,2)
    local pause=require('ui.SourceButton'){sourceKind='pause',text='继续',subtitle='回到机库',icon='play',position='absolute',left=80,top=320,width=424,height=66}
    local pauseTop=pause:GetAbsoluteLayout().y
    pause:Render(vg);pause:Destroy()
    if not captured then
        nvgFontFace,nvgText=originalFace,originalText;captured=true
        local title,hud,medium,storyTitle,fill=0,0,0,0,0
        for _,call in ipairs(calls) do
            if call.text=='就绪' and call.font=='vox-title' then title=title+1 end
            if call.text==' READY' and call.font=='vox-hud' then hud=hud+1 end
            if call.text==' / COOLING' and call.font=='vox-hud-medium' then medium=medium+1 end
            if call.text=='结构' and call.font=='vox-title' then storyTitle=storyTitle+1 end
            if call.text=='HP 100' then fill=fill+1 end
        end
        V.assert(title==9,'Chinese HUD selects actual Industrial glyph font')
        V.assert(hud==9,'Latin HUD selects Chakra bold glyph font')
        V.assert(medium==9,'HUD subtitle selects Chakra medium glyph font')
        V.assert(storyTitle==9,'Story reticle uses same final source Chinese font')
        V.assert(fill==9,'Source 3px centered stroke uses eight edges then fill')
        V.assert(calls[1].x==78.5 and calls[1].y==100,'Outline radius is half source stroke width')
        V.assert(math.abs(R.Width(vg,'HP 100',44)-D.Width(vg,'HP 100',44,'vox-hud',1))<.001,'HUD measure uses same face and tracking as draw')
        R.SetTextScale(.5)
        V.assert(math.abs(R.Width(vg,'就绪 READY',21)-D.Width(vg,'就绪 READY',21,'vox-hud',.5))<.001,'Scaled HUD measure preserves tracking')
        R.SetTextScale(1)
        local ascent,descent=D.FontMetrics(vg,22,'vox-title');local pauseBaseline
        for _,call in ipairs(calls) do if call.text=='继续' then pauseBaseline=call.y end end
        V.assert(pauseBaseline==pauseTop+12.5+(22-ascent-descent)/2+ascent,'Actual pause button uses frozen 22px linebox baseline')
        local textCalls={};local originalDraw=D.Text
        D.Text=function(ctx,text,x,y,size,color,font,align,spacing,baseline,lineHeight,...)
            textCalls[text]={spacing=spacing,lineHeight=lineHeight,font=font}
            return originalDraw(ctx,text,x,y,size,color,font,align,spacing,baseline,lineHeight,...)
        end
        local visual=require('ui.LiveryVisual').Panel{side='left',width=304,height=900}
        visual.owner={session={sel=0,List=function() return {} end},propHeight=134};visual:Render(vg);visual:Destroy()
        local group=require('ui.LiveryWidgets').Button{kind='group',text='角色',english='CHARACTER',group='character',width=90,height=42}
        group.owner={group='none',session={}};group:Render(vg);group:Destroy();D.Text=originalDraw
        V.assert(textCalls['贴纸库'].spacing==1 and textCalls['贴纸库'].lineHeight==19,'Original livery Chinese heading tracking and linebox')
        V.assert(textCalls.STICKERS.spacing==2.5 and textCalls.STICKERS.font=='vox-body','Original livery English heading tracking and face')
        V.assert(textCalls.CHARACTER.spacing==1.5 and textCalls.CHARACTER.lineHeight==8.5,'Original livery group subtitle tracking and linebox')
    end
end
V.atFrame(2,function()
    local paths=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DPR,fonts={{family='sans',weights={normal=paths.body,bold=paths.bold}}}})
    UI.SetRoot(Sample{width='100%',height='100%'})
end)
V.atFrame(8,function()
    V.assert(captured,'Actual shared UI NanoVG renderer executed')
    local image=Image();V.assert(graphics:TakeScreenShot(image),'Actual font rendering screenshot')
    image:SavePNG('docs/migration/evidence/reticle-fonts-native.png');image:Dispose();V.finish()
end)
