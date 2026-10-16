-- Frozen #match-comm geometry, subtitle wrapping and source entrance curve.
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Paragraph=require 'ui.SourceParagraph'
local M={}
local orange={255,106,19,255}
function M.Draw(vg,layer,b,w,h)
    local voice=b.voice;local card=voice and voice.card;if not card then return end
    local age=voice.time-card.at;local left=card.untilAt-voice.time;local alpha=math.min(1,age/.18,left/.18)
    local k=require('ui.SourceButtonMotion').Ease(math.min(1,age/.28),false);local x=16-18*(1-k)
    local y=math.max(282,h*.24+168);local width=340
    layer.commText=layer.commText or Paragraph.New(15,21.75)
    local layout=layer.commText:Measure(vg,{{text=card.text,font='vox-title',size=15,color={238,243,246,255}}},255)
    local height=math.max(69,layout.height+34)
    nvgSave(vg);nvgGlobalAlpha(vg,math.max(0,alpha))
    D.Path(vg,{x,y,x+width,y,x+width,y+height,x+12,y+height,x,y+height-12})
    nvgFillPaint(vg,nvgLinearGradient(vg,x,y,x+width,y,nvgRGBA(8,9,12,240),nvgRGBA(8,9,12,0)));nvgFill(vg)
    D.Rect(vg,x,y,3,height,orange)
    local fx,fy=x+7,y+7;local points={fx+8,fy,fx+54,fy,fx+54,fy+46,fx+46,fy+54,fx,fy+54,fx,fy+8}
    Paint.Image(vg,require('ui.CommsPortrait').Path('nono','smile'),{x=fx,y=fy,w=54,h=54},1.72,.17,points,nil,.45)
    for i=1,18 do D.Rect(vg,fx,fy+i*3,54,1,{0,0,0,80}) end
    D.Text(vg,'诺诺',x+71,y+7,12,orange,'vox-title',nil,3)
    D.Text(vg,'战术领航员 · 频道 07',x+115,y+8,11,{255,255,255,112},'vox-title',nil,2)
    for i=1,5 do local bar=3+9*(.5+.5*math.sin(age*math.pi/.42+i*.9));D.Rect(vg,x+296+(i-1)*5,y+20-bar,3,bar,orange) end
    layer.commText:Draw(vg,{{text=card.text,font='vox-title',size=15,color={238,243,246,255}}},x+71,y+27,255)
    nvgRestore(vg)
end
return M
