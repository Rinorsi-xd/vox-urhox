-- Original .slotcard / .meta / .del; storage and preview ownership stay outside.
local Button=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local Card=Button:Extend('VoxLibraryCard')
function Card:Update(dt)
    if not self.libraryMotion then
        self.libraryMotion={lift={value=0,start=0,target=0,elapsed=0,duration=0},
            delete={value=0,start=0,target=0,elapsed=0,duration=0}}
    end
    local m=self.libraryMotion;local del=self.deleteButton
    local hovered=self.state.hovered or del and (del.state.hovered or del.state.pressed)
    Motion.Step(m.lift,hovered and -3 or 0,.2,dt,false)
    Motion.Step(m.delete,hovered and 1 or 0,.12,dt,'ease')
    if self.props.translateY~=m.lift.value then self:SetStyle({translateY=m.lift.value}) end
end
function Card.Metadata(data)
    local text=#data.parts..' 个零件';local time=data.savedTime
    -- Pre-migration slots have no date: preserve them without inventing one.
    if type(time)=='number' and time==time and time>=0 and time<=253402300799000 then
        local ok,date=pcall(os.date,'*t',math.floor(time/1000))
        if ok and date then text=text..string.format(' · %d/%d %02d:%02d',date.month,date.day,date.hour,date.min) end
    end
    return text
end
function Card:Title(vg,width)
    local text=self.props.data.name or ''
    if self.titleText==text and self.titleWidth==width then return self.fittedTitle end
    local fitted=text
    if D.Width(vg,text,17)>width then
        local ends={};for position in utf8.codes(text) do ends[#ends+1]=position end
        ends[#ends+1]=#text+1
        local lo,hi=0,#ends-1
        while lo<hi do
            local mid=math.ceil((lo+hi)/2)
            if D.Width(vg,text:sub(1,ends[mid+1]-1)..'…',17)<=width then lo=mid else hi=mid-1 end
        end
        fitted=text:sub(1,ends[lo+1]-1)..'…'
    end
    self.titleText=text;self.titleWidth=width;self.fittedTitle=fitted
    return fitted
end
function Card:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    D.Panel(vg,r.x,r.y,r.w,r.h,12,{42,46,53,255},{27,29,34,255})
    local picture=p.pictureHeight
    D.Path(vg,{r.x,r.y,r.x+r.w-12,r.y,r.x+r.w,r.y+12,r.x+r.w,r.y+picture,r.x,r.y+picture})
    nvgFillColor(vg,D.Color(p.data and {14,15,18,255} or {0,0,0,64}));nvgFill(vg)
    if not p.data then D.Text(vg,p.mode=='save' and '＋ 保存到这里' or '空位',r.x+r.w/2,r.y+(picture-20.4)/2,17,D.muted,nil,NVG_ALIGN_CENTER) end
    nvgSave(vg);nvgIntersectScissor(vg,r.x+10,r.y+picture+8,r.w-20,r.h-picture-8)
    if p.data then
        D.Text(vg,self:Title(vg,r.w-20),r.x+10,r.y+picture+8,17)
        if self.metaData~=p.data then self.metaData=p.data;self.metaText=Card.Metadata(p.data) end
        D.Text(vg,self.metaText,r.x+10,r.y+picture+32,12,D.muted,'vox-body')
    else D.Text(vg,'位置 '..p.slot,r.x+10,r.y+picture+8,12,D.muted,'vox-body') end
    nvgRestore(vg)
end
local Delete=Button:Extend('VoxLibraryDelete')
function Delete:Render(vg)
    local card=self.props.card
    local alpha=card.libraryMotion and card.libraryMotion.delete.value or 0
    if alpha<=0 then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    D.Rect(vg,r.x,r.y,r.w,r.h,{255,59,48,255});D.Icon(vg,'trash',r.x+7,r.y+7,16,{255,255,255,255})
    nvgRestore(vg)
end
Card.Delete=Delete
return Card
