-- Frozen H5 UI._modeBadge and final new-ui-utility.css surface.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local Config=require 'Config'
local source=require('core.ResourceData').Read('UI/SourceBuildModeLayout.json')
local Badge=Panel:Extend('VoxBuildModeBadge')
local specs={paint={'brush','上色','P'},erase={'erase','删除','X'},select={'select','选择','Q'},stretch={'ruler','拉伸','J'},paste={'copy','粘贴',''}}
local textColor={244,245,247,255}
local muted={174,196,218,255}
local brand={155,215,250,255}
local function Tween(v) return {value=v,start=v,target=v,elapsed=0,duration=0} end
function Badge:Init(props)
    Panel.Init(self,props)
    self.fadeTween=Tween(0);self.offsetTween=Tween(-12);self.popTime=.3
    self.mode=false;self.contentKey='';self.parts={};self.layoutKey=''
end
function Badge.Mode(session)
    local e=session.editor
    return e.pasting and 'paste' or session.selecting and 'select' or e.tool
end
function Badge.Color(session)
    local mode=Badge.Mode(session);local e=session.editor
    if mode=='paint' then local c=e.autoColor and 0xc9ced6 or e.color;return {(c>>16)&255,(c>>8)&255,c&255,255} end
    if mode=='erase' then return {255,59,48,255} end
    if mode=='select' then return {46,168,255,255} end
    return brand
end
function Badge:Sync()
    local s=self.session;local e=s.editor;local mode=Badge.Mode(s)
    local active=specs[mode] and mode or false
    local key=active and (mode..(mode=='paint' and e.paintChannel or '')) or false
    if key~=self.mode then if active then self.popTime=0 end;self.mode=key end
    local count=0;for _ in pairs(e.selection) do count=count+1 end
    local contentKey=key and table.concat({key,e.autoColor and 'auto' or e.color,count},':') or ''
    if active and contentKey~=self.contentKey then
        self.contentKey=contentKey;self.layoutKey='';self.renderMode=mode
        self.color=Badge.Color(s);self.parts={}
        local function Add(kind,text,size,extra) self.parts[#self.parts+1]={kind=kind,text=text,size=size,extra=extra or 0} end
        local spec=specs[mode];Add('icon',spec[1],18);Add('title',spec[2],20)
        if mode=='paint' then
            Add('chip',e.paintChannel=='accent' and '装饰色' or '主色',14);Add('swatch','',16)
            local name=e.autoColor and '原色' or ''
            if not e.autoColor then for _,c in ipairs(Config.PALETTE) do if c.hex==e.color then name=c.name;break end end end
            Add('text',name,15);Add('key','Tab',11);Add('small','换主色 / 装饰色',12,2)
        elseif mode=='erase' then Add('text','左键 / 右键删一格',15)
        elseif mode=='select' then Add('text',count>0 and ('已选 '..count..' 个') or '点选 · 按住拖动框选',15)
        elseif mode=='stretch' then Add('text','定起点 → 定长宽 → 定高度',15)
        else Add('text','左键放下 · R 旋转',15) end
        Add('divider','',0,6)
        if spec[3]~='' then Add('exitKey',spec[3],11) end
        Add('exitKey','Esc',11);Add('exitSmall','退出',12,2)
    end
end
function Badge:Update(dt)
    Motion.Step(self.fadeTween,self.mode and 1 or 0,.2,dt,'ease')
    Motion.Step(self.offsetTween,self.mode and 0 or -12,.25,dt,false)
    self.popTime=math.min(.3,self.popTime+math.max(0,dt))
end
function Badge:Layout(vg)
    if self.layoutKey==self.contentKey then return end
    local x=14
    for i,p in ipairs(self.parts) do
        local exit=p.kind=='exitKey' or p.kind=='exitSmall'
        x=x+(i>1 and (exit and (self.parts[i-1].kind=='divider' and 0 or 4) or 8) or 0)+p.extra
        p.x=x
        if p.kind=='icon' or p.kind=='swatch' then p.w=p.size
        elseif p.kind=='divider' then p.w=11
        elseif p.kind=='chip' then p.w=D.Width(vg,p.text,p.size)+16
        elseif p.kind=='key' or p.kind=='exitKey' then p.w=math.max(18,D.Width(vg,p.text,p.size,nil,.5)+12)
        elseif p.kind=='small' or p.kind=='exitSmall' then p.w=source.smallWidths[p.text] or D.Width(vg,p.text,p.size,'vox-body')
        else p.w=D.Width(vg,p.text,p.size,(p.kind=='small' or p.kind=='exitSmall') and 'vox-body' or nil,p.kind=='title' and 1 or 0) end
        x=x+p.w
    end
    self.badgeWidth=x+12;self.layoutKey=self.contentKey
end
local function Key(vg,p,x,y)
    nvgBeginPath(vg);nvgRoundedRect(vg,x,y,p.w,19,2);nvgFillColor(vg,nvgRGBA(0,0,0,89));nvgFill(vg)
    nvgBeginPath(vg);nvgRoundedRect(vg,x+.5,y+.5,p.w-1,18,1.5);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(105,137,167,255));nvgStroke(vg)
    D.Text(vg,p.text,x+p.w/2,y+1,11,D.white,nil,NVG_ALIGN_CENTER,.5,false,17)
end
function Badge:Render(vg)
    if self.fadeTween.value<=0 or not self.renderMode or self.session.inventoryPanel then return end
    D.Begin(vg);self:Layout(vg)
    local r=self:GetAbsoluteLayout();local w=self.badgeWidth;local x=r.x+(r.w-w)/2;local y=r.y+72+self.offsetTween.value
    local scale=.86+.14*Motion.Ease(self.popTime/.3,true)
    nvgSave(vg);nvgGlobalAlpha(vg,self.fadeTween.value)
    nvgTranslate(vg,x+w/2,y+19);nvgScale(vg,scale,scale);nvgTranslate(vg,-x-w/2,-y-19)
    D.Path(vg,{x,y,x+w-12,y,x+w,y+12,x+w,y+38,x,y+38});nvgFillColor(vg,nvgRGBA(23,46,69,255));nvgFill(vg)
    D.Rect(vg,x,y,3,38,self.color)
    for _,p in ipairs(self.parts) do
        local px=x+p.x;local kind=p.kind
        if kind=='icon' then D.Icon(vg,p.text,px,y+10,18,self.color)
        elseif kind=='swatch' then
            D.Rect(vg,px,y+11,16,16,self.color)
            nvgBeginPath(vg);nvgRect(vg,px+.5,y+11.5,15,15);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,255,255,128));nvgStroke(vg)
        elseif kind=='chip' then D.Rect(vg,px,y+8,p.w,22,brand);D.Text(vg,p.text,px+8,y+10,14,{16,38,60,255},nil,nil,0,false,18)
        elseif kind=='divider' then D.Rect(vg,px,y+9.5,1,19,{255,255,255,26})
        elseif kind=='key' or kind=='exitKey' then Key(vg,p,px,y+9.5)
        else
            local small=kind=='small' or kind=='exitSmall'
            D.Text(vg,p.text,px,y+(kind=='title' and 7 or small and 11.5 or 10),p.size,kind=='title' and textColor or muted,small and 'vox-body' or nil,nil,kind=='title' and 1 or 0,false,kind=='title' and 24 or small and 15 or 18)
        end
    end
    nvgRestore(vg)
end
return Badge
