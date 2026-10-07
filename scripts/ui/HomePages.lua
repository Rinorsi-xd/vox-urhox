-- The source Home's battle/workshop/shop surfaces, not a separate game state.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Button=require 'ui.SourceButton'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Page=Panel:Extend('VoxHomePage')
local presets=require 'ui.HomePresets'
local importText={{text='粘贴别人分享的 '},{text='FKZC1:',font='vox-inline-code'},{text=' 蓝图码，放进一个新车位。'}}
function Page:Render(vg)
    D.Begin(vg);local s=self.owner;local r=self:GetAbsoluteLayout();local w=r.w;local y=r.y
    if s.tab=='workshop' or s.tab=='shop' then
        D.Rect(vg,0,y,w,r.h,{12,13,16,140});local pw=math.min(1040,w*.92);local x=(w-pw)/2;local top=y+94
        nvgBeginPath(vg);nvgRect(vg,x,top,pw,s.tab=='workshop' and 594.984375 or 370);D.Gradient(vg,x,top,pw,595,{35,39,45,255},{21,23,27,255})
        D.Rect(vg,x,top,4,74,D.orange);D.Rect(vg,x,top+73,pw,1,{53,58,66,255});D.Icon(vg,s.tab=='shop' and 'shop' or 'workshop',x+30,top+22,30,D.orange)
        D.Text(vg,s.tab=='shop' and '商店' or '创意工坊',x+72,top+18,32);D.Text(vg,s.tab=='shop' and '还在设计' or '预制车、蓝图码分享',x+(s.tab=='shop' and 155 or 190),top+28,13,D.muted,'vox-body')
        if s.tab=='workshop' then
            local cw=(pw-76)/3
            for i,p in ipairs(presets) do local cx=x+26+((i-1)%3)*(cw+12);local cy=top+94+math.floor((i-1)/3)*253.390625
                nvgSave(vg);if i==6 then nvgGlobalAlpha(vg,.55) end
                D.Panel(vg,cx,cy,cw,i<=3 and 241.390625 or 221.59375,14);D.Rect(vg,cx+18,cy+18,52,52,{42,46,53,255});D.Icon(vg,p[4],cx+30,cy+30,28,i==6 and D.dim or D.blue)
                D.Text(vg,p[2],cx+18,cy+80,22);self.paragraphs[i]:Draw(vg,i==4 and importText or p[3],cx+18,cy+117,cw-36);nvgRestore(vg)
            end
        else
            D.Rect(vg,w/2-44,top+125,88,88,{42,46,53,255});D.Icon(vg,'shop',w/2-23,top+146,46,D.blue)
            D.Text(vg,'商店还没开张',w/2,top+238,28,D.white,nil,NVG_ALIGN_CENTER)
            self.paragraphs[1]:Draw(vg,'以后这里卖零件、涂装和装饰件。原型阶段所有零件都已开放，直接去编辑页用就行。',x+36,top+281,pw-72,nil,true)
        end
    end
end
local M={}
function M.Create(s)
    if s.tab=='battle' then return require('ui.HomeBattle').Create(s) end
    local page=Page{position='absolute',left=0,top=60,width=s.width,height=s.height-60};page.owner=s
    page.paragraphs={}
    for i=1,6 do
        local size=13
        page.paragraphs[i]=Paragraph.New(size,math.floor(size*(s.tab=='shop' and 1.7 or 1.6)*64)/64)
    end
    if s.tab=='workshop' then
        local pw=math.min(1040,s.width*.92);local x=(s.width-pw)/2;local cw=(pw-76)/3
        for i,p in ipairs(presets) do
            page:AddChild(s.Track(Button{text=i<=3 and '放进新车位' or i==4 and '导入' or i==5 and '导出蓝图码' or '开发中',icon=i<=3 and 'plus' or p[4],sourceKind='flat',sourceOpacity=i==6 and .55 or 1,
                position='absolute',left=x+44+((i-1)%3)*(cw+12),top=94+94+(i<=3 and 189.390625 or 169.59375)+math.floor((i-1)/3)*253.390625,width=i==4 and 80.609375 or i==6 and 93.90625 or 120.5,height=34,disabled=i==6 or i<=3 and s.usedCount==20,
                onClick=function() if i<=3 then s.CreateVehicle(p[1]) else require('ui.GarageDialogs').Code(s,i==4) end end}))
        end
    end
    return page
end
return M
