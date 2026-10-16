-- Frozen #selBar, including utility/controls skin and landscape overflow rules.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Base=require 'ui.ActionButton'
local D=require 'ui.SourceDraw'
local Text=require 'ui.SourceTextLayout'
local Motion=require 'ui.SourceButtonMotion'
local Shadow=require 'ui.SourceBoxShadow'
local M={}
local specs={{'move','move','移动','方向键'},{'copy','copy','复制','Ctrl+C'},
    {'join','cube','连块 / 拆开','F'},{'stretch','ruler','拉伸','J'},
    {'paint','brush','涂当前色',''},{'delete','trash','删除','Del'},{'clear','close','取消','Esc'}}
local function Width(text,size,font,spacing)
    return Text.Width(assert(Text.Get(text,font),'Missing source selection text metrics'),size,spacing or 0)
end
function M.Layout(width,height,count)
    local compact=width>height and height<=600;local keys=width>1440
    local countWidth=10+Width(tostring(count),26,'vox-tabular')+5+Width('已选',12,'vox-title')+12+1
    local content=8+countWidth+4;local items={}
    for i,s in ipairs(specs) do
        local key=keys and s[4] or '';local keyWidth=key~='' and Width(key,10.5,'vox-title',.3) or 0
        local w=20+16+6+Width(s[3],14,'vox-title')+(key~='' and 6+keyWidth or 0)
        items[i]={width=w,key=key,keyWidth=keyWidth};content=content+2+w
    end
    return {width=compact and math.min(content,math.max(1,width-24)) or content,content=content,
        countWidth=countWidth,items=items,buttonHeight=compact and 44 or 40,height=compact and 52 or 48,bottom=compact and 108 or 128}
end
local Bar=Panel:Extend('VoxSelectionBar')
function Bar:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    self.owner.shadow:Draw(vg,r.x,r.y+3,r.w,r.h,8,nvgRGBA(8,15,28,64))
    D.Rect(vg,r.x,r.y,r.w,r.h,{22,45,67,255});D.Rect(vg,r.x,r.y,3,r.h,{46,168,255,255})
end
function Bar:Update(dt)
    if not self.owner.shown or self.owner.age>=.18 then return end
    self.owner.age=math.min(.18,self.owner.age+math.max(0,dt))
    local t=Motion.Ease(self.owner.age/.18,false);self:SetStyle({opacity=t,translateY=10*(1-t)})
end
local Count=Panel:Extend('VoxSelectionCount')
function Count:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local number=tostring(self.owner.count)
    D.Text(vg,number,r.x+10,r.y+(r.h-31.2)/2,26,{46,168,255,255},'vox-tabular')
    D.Text(vg,'已选',r.x+15+D.Width(vg,number,26,'vox-tabular'),r.y+(r.h-14.4)/2+5,12,{174,196,218,255},'vox-title')
    D.Rect(vg,r.x+r.w-1,r.y,1,r.h,{255,255,255,20})
end
local Button=Base:Extend('VoxSelectionButton')
function Button:Update(dt)
    self.hover=self.hover or {value=0,start=0,target=0,elapsed=0,duration=0}
    Motion.Step(self.hover,self.state.hovered and 1 or 0,.12,dt,'ease')
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local hover=self.hover and self.hover.value or 0
    local focus=self.state.focused;local base=p.action=='delete' and {174,196,218,255} or {228,243,255,255}
    local to=p.action=='delete' and {255,59,48,255} or base
    local color={};for i=1,4 do color[i]=math.floor(base[i]+(to[i]-base[i])*hover+.5) end
    if p.action~='delete' then D.Rect(vg,r.x,r.y,r.w,r.h,{25,62,110,255})
    elseif hover>0 then D.Rect(vg,r.x,r.y,r.w,r.h,{255,255,255,math.floor(15*hover)}) end
    D.Rect(vg,r.x,r.y,r.w,1.5,{142,198,249,128});D.Rect(vg,r.x,r.y+r.h-1.5,r.w,1.5,{11,36,75,128})
    if focus then D.Rect(vg,r.x,r.y+r.h-3,r.w,3,D.orange);D.Rect(vg,r.x,r.y,r.w,1,{219,238,255,204}) end
    local iconColor=color;if p.action=='paint' then local c=self.owner.brush;iconColor={c>>16&255,c>>8&255,c&255,255} end
    D.Icon(vg,p.icon,r.x+10,r.y+(r.h-16)/2,16,iconColor)
    D.Text(vg,p.text,r.x+32,r.y+(r.h-16.8)/2,14,color,'vox-title')
    if p.key~='' then D.Text(vg,p.key,r.x+r.w-10-p.keyWidth,r.y+(r.h-10.5)/2,10.5,{127,154,180,255},'vox-title',nil,.3) end
end
function M.Create(session,parent)
    local self={session=session,buttons={},count=0,brush=0xc9ced6,shown=false,age=0,shadow=Shadow.New()}
    self.root=Bar{position='absolute',height=48,visible=false};self.root.owner=self;parent:AddChild(self.root)
    self.scroll=UI.ScrollView{width='100%',height='100%',scrollX=true,scrollY=false,bounces=false,showScrollbar=true,scrollbarInteractive=true}
    self.root:AddChild(self.scroll)
    self.row=UI.Panel{height='100%',flexDirection='row',alignItems='stretch',gap=2,padding=4,flexShrink=0};self.scroll:AddChild(self.row)
    self.counter=Count{height='100%',marginRight=4,flexShrink=0,pointerEvents='none'};self.counter.owner=self;self.row:AddChild(self.counter)
    for _,s in ipairs(specs) do
        local b=Button{action=s[1],icon=s[2],text=s[3],height=40,flexShrink=0,onClick=function()session:SelectionAction(s[1])end}
        b.owner=self;self.buttons[s[1]]=b;self.row:AddChild(b)
    end
    function self:Sync()
        if self.disposed then return end
        local width,height=UI.GetViewportSize();local e=session.editor
        self.count=#e:Selected();self.brush=e.autoColor and 0xc9ced6 or e.color
        local shown=self.count>0 and not e.pasting and not session.inventoryPanel and not session.dialog
        if shown~=self.shown then
            self.shown=shown;self.age=0;self.root:SetVisible(shown)
            if shown then self.root:SetStyle({opacity=0,translateY=10}) end
        end
        local key=width..':'..height..':'..self.count
        if self.layoutKey~=key then
            self.layoutKey=key;local l=M.Layout(width,height,self.count);self.layout=l
            self.root:SetStyle({width=l.width,height=l.height,left=(width-l.width)/2,bottom=l.bottom})
            self.row:SetStyle({width=l.content,height=l.height});self.counter:SetWidth(l.countWidth)
            for i,s in ipairs(specs) do local b=self.buttons[s[1]];local item=l.items[i]
                b:SetStyle({width=item.width,height=l.buttonHeight});b.props.key=item.key;b.props.keyWidth=item.keyWidth
            end
        end
    end
    function self:Dispose() if self.disposed then return end;self.disposed=true;self.shadow:Dispose() end
    return self
end
return M
