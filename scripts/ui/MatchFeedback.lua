-- matchHud.js preparation countdown and damage overlay, using the shared UI frame.
local SourceButtonMotion=require("ui.SourceButtonMotion")
local SourceDraw=require("ui.SourceDraw")

local M={}
local function Now() return Time:GetSystemTime()/1000 end
function M.Consume(b,events,now)
    now=now or Now()
    for _,e in ipairs(events) do
        if e.type=='unitDamaged' and e.unit==b.player and e.amount>0 and now*1000-(b.hurtAt or 0)*1000>=350 then
            b.hurtAt=now;b.hurtFrames=2;b.hurtFadeAt=nil
        end
    end
end
function M.Update(b,now,intro)
    now=now or Now()
    if intro==nil then intro=b.intro end
    local r=b.rules
    local count=r.state=='prep' and not intro and math.ceil(r.cfg.prep-r.t) or 0
    count=count>0 and count<=3 and count or 0
    if count~=b.prepCount then b.prepCount=count;b.prepCountAt=now end
    if (b.hurtFrames or 0)>0 then
        b.hurtFrames=b.hurtFrames-1
        if b.hurtFrames==0 then b.hurtFadeAt=now end
    end
end
function M.HurtAlpha(b,now)
    if (b.hurtFrames or 0)>0 then return 1 end
    if not b.hurtFadeAt then return 0 end
    return 1-SourceButtonMotion.Ease(math.max(0,math.min(1,((now or Now())-b.hurtFadeAt)/.5)),'ease')
end
function M.CountState(b,now)
    if not b.prepCount or b.prepCount==0 then return nil end
    local phase=((now or Now())-b.prepCountAt)%1
    local ease=SourceButtonMotion.Ease
    if phase<.2 then
        local t=ease(phase/.2,'css-ease-out')
        return b.prepCount,1.35-.35*t,t
    end
    return b.prepCount,1,1-.15*ease((phase-.2)/.8,'css-ease-out')
end
function M.RepairDisabled(b)
    return b.mode=='elimination' and b.rules.state=='live' and b.rules.sudden and b.player.alive
end
function M.Draw(vg,b,w,h)
    local D=SourceDraw
    local alpha=M.HurtAlpha(b)
    if alpha>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,alpha)
        for _,side in ipairs({{0,0,90,h,0,0,90,0},{w-90,0,90,h,w,0,w-90,0},{0,0,w,90,0,0,0,90},{0,h-90,w,90,0,h,0,h-90}}) do
            nvgBeginPath(vg);nvgRect(vg,side[1],side[2],side[3],side[4])
            nvgFillPaint(vg,nvgLinearGradient(vg,side[5],side[6],side[7],side[8],nvgRGBA(255,26,10,85),nvgRGBA(255,26,10,0)));nvgFill(vg)
        end
        nvgRestore(vg)
    end
    local count,scale,opacity=M.CountState(b)
    if count then
        nvgSave(vg);nvgTranslate(vg,w/2,h*.42);nvgScale(vg,scale,scale);nvgGlobalAlpha(vg,opacity)
        D.Text(vg,count,0,-70,140,{255,255,255,255},'vox-display',NVG_ALIGN_CENTER,0,false,140,
            {{blur=40,color={255,106,19,136}},{y=5,color={0,0,0,255}}})
        nvgRestore(vg)
    end
    if M.RepairDisabled(b) then
        local text='决胜时刻 · 维修失效';local width=D.Width(vg,text,13,'vox-body',3)+28
        local x=(w-width)/2;local y=h-118-21
        D.Path(vg,{x,y,x+width/2,y,x+width/2,y+21,x,y+21})
        D.Gradient(vg,x,y,width/2,21,{26,12,11,0},{26,12,11,176},true)
        D.Path(vg,{x+width/2,y,x+width,y,x+width,y+21,x+width/2,y+21})
        D.Gradient(vg,x+width/2,y,width/2,21,{26,12,11,176},{26,12,11,0},true)
        D.Text(vg,text,w/2,y+4,13,{255,138,106,255},'vox-body',NVG_ALIGN_CENTER,3)
    end
end
return M
