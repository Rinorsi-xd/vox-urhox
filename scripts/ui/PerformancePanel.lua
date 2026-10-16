local UI=require 'urhox-libs/UI'
local M={};M.__index=M
local white={219,231,239,255}
local muted={159,179,194,255}
local cyan={110,214,255,255}
local red={255,112,112,255}
local ink={4,14,24,235}
local refreshInterval=.25
local slowMs=80

local function Number(value)
    local n=tonumber(value)
    if not n or n~=n or n==math.huge or n==-math.huge then return 0 end
    return math.max(0,n)
end
local function Text(value)
    if value==nil or value=='' then return '-' end
    return tostring(value):gsub('[\r\n\t]',' ')
end
local function SetText(widget,text)
    if widget.props.text~=text then widget:SetText(text) end
end
local function Label(text,height)
    return UI.Label{text=text,width='100%',height=height or 18,fontSize=11,
        fontFamily='sans',fontColor=muted,verticalAlign='middle',maxLines=1,
        flexShrink=0,pointerEvents='none',overflow='hidden'}
end

function M.New(app)
    local self=setmetatable({},M);self:init(app);return self
end
function M:init(_app)
    self.disposed=false;self.elapsed=refreshInterval;self.snapshot={}
    self.width=0;self.top=0;self.right=0;self.alert=false;self.stageAlert=false
    self.enabled=false;self.visible=true
    local w,h=UI.GetViewportSize()
    self.open=w>=640 and h>=600
    self.summary=Label('PERF  -- FPS',30)
    self.summary:SetStyle{paddingLeft=9,paddingRight=28,fontColor=cyan}
    self.symbol=Label(self.open and '-' or '+',30)
    self.symbol:SetStyle{position='absolute',right=5,top=0,width=18,textAlign='center',fontColor=cyan,fontSize=15}
    self.toggle=UI.Button{text='',position='absolute',right=0,top=0,
        width='100%',height=30,padding=0,
        backgroundColor=ink,hoverBackgroundColor={18,38,59,245},
        pressedBackgroundColor={33,59,85,245},textColor=cyan,
        borderRadius=0,borderWidth=0,boxShadow=false,focusable=false,
        onClick=function()
            if self.disposed then return end
            self.open=not self.open;self.body:SetVisible(self.open)
            self.symbol:SetText(self.open and '-' or '+')
            self.elapsed=refreshInterval
        end}
    self.timing=Label('P95 -  Max -')
    self.slow=Label('>80ms -  Steps -')
    self.cpu=Label('Lua - ms  Mem - MiB')
    self.stage=Label('Top -')
    self.stage:SetFontColor(white)
    self.counts=Label('Units -  Shots -  FX -')
    self.event=Label('Event -',30)
    self.event:SetStyle{whiteSpace='normal',wordBreak='break-word',maxLines=2,lineHeight=1.2}
    self.path=Label('Log -',30)
    self.path:SetStyle{whiteSpace='normal',wordBreak='break-word',maxLines=2,lineHeight=1.2}
    self.fileError=false
    self.body=UI.Panel{width='100%',padding={4,9,7,9},backgroundColor=ink,
        pointerEvents='none',visible=self.open,overflow='hidden',children={
            self.timing,self.slow,self.cpu,self.stage,self.counts,self.event,self.path}}
    local header=UI.Panel{width='100%',height=30,pointerEvents='box-none',children={self.toggle,self.summary,self.symbol}}
    self.panel=UI.Panel{position='absolute',right=12,top=116,width=274,
        pointerEvents='box-none',overflow='hidden',children={header,self.body}}
    self.root=UI.Panel{width='100%',height='100%',pointerEvents='box-none',children={self.panel}}
    -- Global components render their own independent Yoga tree.
    self.root.Render=function(_,vg)
        if self.disposed or not self.visible then return end
        local vw,vh=UI.GetViewportSize()
        YGNodeCalculateLayout(self.root.node,vw,vh,YGDirectionLTR)
        UI.RenderWidgetSubtree(self.panel,vg)
    end
    self.root.HitTest=function(_,x,y)
        return not self.disposed and self.visible and self.toggle:HitTest(x,y)
    end
    UI.RegisterGlobalComponent('vox-performance',self.root);UI.PushOverlay(self.root)
    self:Layout()
end

function M:Layout()
    local w=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
    local right=math.max(12,safe.right or 0)
    -- Keep even the expanded panel entirely to the right of the reticle.
    local width=math.max(1,math.min(274,w*.44-right))
    local top=116+(safe.top or 0)
    if width~=self.width or right~=self.right or top~=self.top then
        self.width=width;self.right=right;self.top=top
        self.panel:SetStyle{width=width,right=right,top=top}
    end
end

function M:Update(snapshot,dt)
    if self.disposed then return end
    self.snapshot=snapshot or self.snapshot
    if not self.visible then return end
    self.elapsed=self.elapsed+Number(dt)
    if self.elapsed<refreshInterval then return end
    self.elapsed=0;self:Layout()
    local s=self.snapshot
    local enabled=s.enabled~=false
    local frame=Number(s.frameMs);local top=Number(s.topMs)
    local alert=enabled and frame>slowMs
    local stageAlert=enabled and top>slowMs
    SetText(self.summary,enabled and string.format('PERF %.0f FPS  %.1f ms',Number(s.fps),frame) or 'PERF OFF')
    if alert~=self.alert or enabled~=self.enabled then
        self.alert=alert;self.enabled=enabled
        self.summary:SetFontColor(not enabled and muted or alert and red or cyan)
    end
    if not self.open then return end
    SetText(self.timing,string.format('P95 %.1f  Max %.1f ms',Number(s.p95Ms),Number(s.maxMs)))
    SetText(self.slow,string.format('>80ms %.0f  Steps %.0f',Number(s.slowFrames),Number(s.steps)))
    SetText(self.cpu,string.format('Lua %.1f ms  Mem %.1f MiB',Number(s.cpuMs),Number(s.luaKiB)/1024))
    SetText(self.stage,string.format('Top %s  %.1f ms',Text(s.topStage),top))
    if stageAlert~=self.stageAlert then
        self.stageAlert=stageAlert;self.stage:SetFontColor(stageAlert and red or white)
    end
    SetText(self.counts,string.format('Units %.0f  Shots %.0f  FX %.0f',Number(s.units),Number(s.projectiles),Number(s.effects)))
    SetText(self.event,'Event '..Text(s.lastEvent))
    local fileError=s.fileError~=nil and s.fileError~=false and s.fileError~=''
    SetText(self.path,fileError and 'Log ERROR '..Text(s.fileError) or 'Log '..Text(s.logPath))
    if fileError~=self.fileError then
        self.fileError=fileError;self.path:SetFontColor(fileError and red or muted)
    end
end

function M:SetVisible(visible)
    if self.disposed then return end
    local nextVisible=visible==true
    if self.visible==nextVisible then return end
    self.visible=nextVisible;self.root:SetVisible(self.visible)
    if self.visible then UI.PushOverlay(self.root);self.elapsed=refreshInterval
    else UI.PopOverlay(self.root) end
end

function M:Dispose()
    if self.disposed then return end
    self.disposed=true;UI.PopOverlay(self.root);UI.UnregisterGlobalComponent('vox-performance')
    self.root:Destroy();self.snapshot={}
end
return M
