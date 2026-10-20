local SourceRelief=require("ui.SourceRelief")
local SalvagePaint=require("ui.SalvagePaint")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Theme=require 'ui.VoxTheme'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local M=require('ui.ActionButton'):Extend('VoxSalvageItem')
local function CountLabel(n)
    if not n or n<=1 then return nil end
    if n<10000 then return '×'..string.format('%.0f',n) end
    -- JavaScript toFixed rounds binary ties up; printf uses ties-to-even.
    local value=n/10000;local exponent=math.floor(math.log(value,2))+1
    local significand=math.tointeger(value/2^exponent*2^53)
    local divisor=1<<(52-exponent);local numerator=significand*5
    local rounded=numerator//divisor+(numerator%divisor>=divisor//2 and 1 or 0)
    return '×'..(rounded//10)..'.'..(rounded%10)..'万'
end
function M:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local it=self.props.item
    local hex=Data.rarity[it.rarity+1].color;local c={tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255}
    local tint={};for i=1,3 do tint[i]=math.floor(c[i]*.13+({32,58,84})[i]*.87) end;tint[4]=255
    D.Rect(vg,r.x,r.y,r.w,r.h,tint);D.Rect(vg,r.x,r.y+r.h-2,r.w,2,c)
    SourceRelief.Halftone(vg,r.x,r.y,r.w,r.h)
    local compact=self.props.compact;local inset=compact and 5 or 6;local top=compact and 17 or 18
    if it.part then self:RenderBackgroundImage(vg,Theme.Thumbnail(it.part),{x=r.x+inset,y=r.y+top,w=r.w-inset*2,h=r.h-top-inset},'contain',nil)
    else D.Icon(vg,it.icon,r.x+r.w/2-18,r.y+r.h/2-14,36,c) end
    local fontSize=compact and 12 or 13;local title=it.name
    -- 手机上字号被抬大时，先把字号往回收让名字放下，实在放不下再截断（PC 上不收字号）
    if D.Readable(vg,fontSize,title)~=fontSize then fontSize=D.FitSize(vg,title,fontSize,'vox-body',0,r.w-12,fontSize*.75) end
    if D.Width(vg,title,fontSize,'vox-body')>r.w-12 then
        repeat local offset=utf8.offset(title,-1);title=offset and title:sub(1,offset-1) or '' until title=='' or D.Width(vg,title..'...',fontSize,'vox-body')<=r.w-12
        title=title..'...'
    end
    D.Text(vg,title,r.x+6,r.y+4,fontSize,D.white,'vox-body')
    if self.props.price then
        local value=D.Number(self.props.price);local width=D.Width(vg,value,14,'vox-tabular')+20
        D.Rect(vg,r.x,r.y+r.h-18,width,18,{9,10,12,200});SalvagePaint.Credit(vg,r.x+4,r.y+r.h-16,12);D.Text(vg,value,r.x+17,r.y+r.h-18,14,nil,'vox-tabular')
    end
    local count=CountLabel(self.props.count)
    if count then
        local x,y,size=r.x+r.w-5,r.y+r.h-(compact and 18 or 20),compact and 15 or 17
        D.Text(vg,count,x,y+1,size,{0,0,0,255},'vox-tabular',NVG_ALIGN_RIGHT)
        D.Text(vg,count,x,y,size,nil,'vox-tabular',NVG_ALIGN_RIGHT)
    end
    if self.props.bad then
        local red={255,59,48,255}
        D.Rect(vg,r.x,r.y,r.w,2,red);D.Rect(vg,r.x,r.y+r.h-2,r.w,2,red)
        D.Rect(vg,r.x,r.y+2,2,r.h-4,red);D.Rect(vg,r.x+r.w-2,r.y+2,2,r.h-4,red)
    end
    if self.props.selected then for _,p in ipairs({{r.x+2,r.y+2,1,1},{r.x+r.w-2,r.y+2,-1,1},{r.x+2,r.y+r.h-2,1,-1},{r.x+r.w-2,r.y+r.h-2,-1,-1}}) do
        D.Line(vg,p[1],p[2],p[1]+p[3]*14,p[2],D.white,3);D.Line(vg,p[1],p[2],p[1],p[2]+p[4]*14,D.white,3)
    end end
end
return M
