-- 触屏局内按钮布局编辑器（仅触屏）：拖动按钮换位置，选中后调大小，保存到触屏设置 prefs.layout。
-- 预览直接复用局内触屏按钮的绘制和 SourceTouchLayout.Drive 的排布，所见即局内所得。
-- 打开期间往 owner.dialog 挂一个占位对象：对局 / 机库照常按「有弹窗」暂停输入、隐藏局内触屏层。
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Layout=require 'ui.SourceTouchLayout'
local Prefs=require 'controls.TouchPreferences'
local DriveWidgets=require 'ui.SourceTouchDriveWidgets'
local W=require 'ui.TouchEditorWidgets'
local Editor=UI.Panel:Extend('VoxTouchLayoutEditor')
local Marks=UI.Widget:Extend('VoxTouchLayoutMarks')
local M={}
local NAMES={stick='移动摇杆',primary='开火',scope='瞄准镜',up='跳跃 / 上升',aux='下降 / 冲刺',weapon='切换武器',
    interact='交互 / 翻正',['rudder-l']='左舵',['rudder-r']='右舵',board='战绩',toggle='菜单'}
local VISUALS={primary={kind='fire',icon='fire'},scope={kind='arc',icon='scope'},up={kind='arc',icon='up'},aux={kind='arc',icon='down'},
    weapon={kind='arc',iconPath='UI/WeaponIcons/laser1.png',weapon=true},interact={kind='context',icon='interact',text='交互'},
    ['rudder-l']={kind='small',icon='rudder'},['rudder-r']={kind='small',icon='rudder',flipX=true},
    board={kind='menu',icon='board'},toggle={kind='menu',icon='menu'}}
local STEP=.1
local function Clamp(v,a,b) return math.max(a,math.min(b,v)) end
-- 按钮是切角八边形，矩形四角是空的：各边内缩 18% 再判重叠，默认弧形排布不会误报
local function Overlaps(a,b)
    local ia,ib=.18,.18
    local ax,ay,aw,ah=a.left+a.width*ia,a.top+a.height*ia,a.width*(1-2*ia),a.height*(1-2*ia)
    local bx,by,bw,bh=b.left+b.width*ib,b.top+b.height*ib,b.width*(1-2*ib),b.height*(1-2*ib)
    return ax<bx+bw and bx<ax+aw and ay<by+bh and by<ay+ah
end
function Editor:Rect(id)
    local l=self.layout
    if id=='stick' then return l.stick elseif id=='toggle' then return l.toggle end
    return l.actions[id]
end
function Editor:Relayout()
    local width,height=UI.GetViewportSize();local dpr=math.max(1,graphics:GetDPR())
    self.width,self.height=width,height
    self.layout=Layout.Drive(width,height,graphics:GetWidth()/dpr,graphics:GetHeight()/dpr,UI.GetSafeAreaInsets(),false,self.prefs.size,self.draft)
    local k=self.layout.k
    for id,widget in pairs(self.previews) do
        widget.props.touchScale=k;widget.props.unit=self.layout.u;widget:SetStyle(self:Rect(id))
    end
    local barWidth=math.min(560*k,width-16*k)
    self.bar:SetStyle({position='absolute',left=(width-barWidth)/2,top=(UI.GetSafeAreaInsets().top or 0)+8*k,width=barWidth,height=84*k})
    self:Sync()
end
function Editor:Sync()
    local id=self.selected;local k=self.layout.k
    local c=id and self.layout.centers[id]
    self.title:SetText(id and (NAMES[id]..string.format('  ·  大小 %d%%',math.floor((c and c.s or 1)*100+.5))) or '拖动按钮调整位置，点选后可调大小')
    self.title:SetFontSize(13*k)
    for _,key in ipairs({'smaller','bigger','reset'}) do self.buttons[key]:SetDisabled(not id) end
    if c then
        self.buttons.smaller:SetDisabled(c.s<=Prefs.layoutScale.min+1e-6);self.buttons.bigger:SetDisabled(c.s>=Prefs.layoutScale.max-1e-6)
        self.buttons.reset:SetDisabled(self.draft[id]==nil)
    end
    self.buttons.resetAll:SetDisabled(next(self.draft)==nil)
end
-- 写回占比。中心夹在安全区里，整颗按钮不出界；摇杆中心不过屏幕中线（浮动摇杆的手势限制）。
function Editor:Place(id,cx,cy,s)
    local l=self.layout;local safe=l.safeRect;local w,h=safe[3],safe[4];local c=l.centers[id];local u=l.u
    s=Clamp(s or c.s,Prefs.layoutScale.min,Prefs.layoutScale.max)
    local hw,hh=c.w*u*s/2,c.h*u*s/2
    local maxX=w-hw
    if id=='stick' then maxX=math.min(maxX,l.cssWidth*.5-safe[1]) end
    cx=Clamp(cx,math.min(hw,maxX),maxX);cy=Clamp(cy,math.min(hh,h-hh),h-hh)
    self.draft[id]={x=Clamp(cx/math.max(1,w),0,1),y=Clamp(cy/math.max(1,h),0,1),s=s}
    self:Relayout()
end
function Editor:Resize(delta)
    local id=self.selected;if not id then return end
    local c=self.layout.centers[id]
    self:Place(id,c.x,c.y,math.floor((c.s+delta)*10+.5)/10)
end
function Editor:Hit(x,y)
    -- 后排的先判（toggle/board 在最上层），手指稍微点歪也算
    local k=self.layout.k;local pad=6*k;local best,bestArea=nil,math.huge
    for _,id in ipairs(Prefs.layoutControls) do
        local r=self:Rect(id)
        if r and x>=r.left-pad and x<=r.left+r.width+pad and y>=r.top-pad and y<=r.top+r.height+pad then
            local area=r.width*r.height
            -- 重叠时优先小按钮，免得大按钮把小按钮整个盖住选不中
            if area<bestArea then best,bestArea=id,area end
        end
    end
    return best
end
function Editor:OnPointerDown(e)
    if self.closed then return end
    if e.StopPropagation then e:StopPropagation() end
    local id=self:Hit(e.x,e.y);self.selected=id
    if id then
        local l=self.layout;local c=l.centers[id];local k=l.k
        self.drag={pointer=e.pointerId,id=id,dx=c.x-e.x/k,dy=c.y-e.y/k,moved=false,ox=e.x,oy=e.y}
    else self.drag=nil end
    self:Sync()
end
function Editor:OnPointerMove(e)
    local drag=self.drag;if self.closed or not drag or drag.pointer~=e.pointerId then return end
    if not drag.moved and (e.x-drag.ox)^2+(e.y-drag.oy)^2<(4*self.layout.k)^2 then return end
    drag.moved=true;local k=self.layout.k
    self:Place(drag.id,e.x/k+drag.dx,e.y/k+drag.dy)
end
function Editor:OnPointerUp(e) if self.drag and self.drag.pointer==e.pointerId then self.drag=nil end end
function Editor:OnPointerCancel(e) self:OnPointerUp(e) end
function Editor:Update(dt)
    if self.closed then return end
    local width,height=UI.GetViewportSize()
    if width~=self.width or height~=self.height then self:Relayout() end
end
function Editor:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local l=self.layout;local k=l.k;local safe=l.safeRect
    D.Rect(vg,r.x,r.y,r.w,r.h,{4,9,18,222})
    local sx,sy,sw,sh=r.x+safe[1]*k,r.y+safe[2]*k,safe[3]*k,safe[4]*k
    for gx=sx,sx+sw,48*k do D.Rect(vg,gx,sy,1,sh,{122,216,255,14}) end
    for gy=sy,sy+sh,48*k do D.Rect(vg,sx,gy,sw,1,{122,216,255,14}) end
    nvgBeginPath(vg);nvgRect(vg,sx+.5,sy+.5,sw-1,sh-1);nvgStrokeColor(vg,nvgRGBA(122,216,255,64));nvgStrokeWidth(vg,1);nvgStroke(vg)
    -- 摇杆只能放在左半边：中线标一下
    local mid=r.x+l.cssWidth*.5*k
    for y=sy,sy+sh,14*k do D.Rect(vg,mid,y,1,7*k,{122,216,255,46}) end
end
function Marks:Render(vg)
    local e=self.editor;if not e or e.closed then return end
    D.Begin(vg);local k=e.layout.k
    local rects={};for _,id in ipairs(Prefs.layoutControls) do rects[id]=e:Rect(id) end
    for _,a in ipairs(Prefs.layoutControls) do
        local overlap=false
        for _,b in ipairs(Prefs.layoutControls) do
            -- 加速 / 下降和舵键在不同载具上不会同时出现，但摆位时仍按重叠提示
            if a~=b and Overlaps(rects[a],rects[b]) then overlap=true;break end
        end
        local r=rects[a];local selected=e.selected==a
        if overlap or selected then
            nvgBeginPath(vg);nvgRect(vg,r.left-2*k,r.top-2*k,r.width+4*k,r.height+4*k)
            nvgStrokeColor(vg,D.Color(selected and D.orange or {255,109,114,230}));nvgStrokeWidth(vg,(selected and 2 or 1.5)*k);nvgStroke(vg)
        end
        if selected then
            local label=NAMES[a];local size=11*k;local tw=D.Width(vg,label,size,'vox-title')
            local ly=r.top-2*k-18*k;if ly<0 then ly=r.top+r.height+4*k end
            local lx=Clamp(r.left+r.width/2-tw/2-6*k,2*k,e.width-tw-14*k)
            D.Rect(vg,lx,ly,tw+12*k,16*k,D.orange);D.Text(vg,label,lx+6*k,ly+2*k,size,{10,15,24,255},'vox-title')
        end
    end
end
function Editor:Teardown()
    if self.closed then return end
    self.closed=true;self.drag=nil;UI.PopOverlay(self)
    local owner=self.owner
    if owner.dialog==self.stub then owner.dialog=nil;owner.dialogTick=nil end
end
function Editor:Destroy()
    -- HUD 根节点被整体重建时这里会跟着销毁，记得把占位弹窗撤掉，否则对局一直当成有弹窗
    self:Teardown();UI.Panel.Destroy(self)
end
function Editor:Close(back)
    if self.closed then return end
    self:Teardown()
    if self.parent then self.parent:RemoveChild(self) end
    UI.Panel.Destroy(self)
    if back and self.onBack then self.onBack() end
end
function Editor:Save()
    local prefs=self.prefs;local previous=prefs.layout
    prefs.layout=Prefs.CopyLayout(self.draft)
    local ok=self.owner.app:SaveTouchPrefs(prefs)
    if not ok then prefs.layout=previous;return end
    -- 局内触屏层每帧在 Labels 里比对 prefs.layout，换成新表就会按新布局重排，这里不用再通知
    self:Close(true)
end
--- 打开编辑器。onBack：保存或取消后回到上一级（触屏设置弹窗）。
function M.Open(owner,onBack)
    local root=UI.GetRoot();if not root then return nil end
    local prefs=Prefs.Get(owner.app)
    local width,height=UI.GetViewportSize();local dpr=math.max(1,graphics:GetDPR())
    local k=width/math.max(1,graphics:GetWidth()/dpr)
    local editor=Editor{position='absolute',left=0,top=0,width='100%',height='100%'}
    editor.owner=owner;editor.prefs=prefs;editor.draft=Prefs.CopyLayout(prefs.layout);editor.onBack=onBack;editor.previews={};editor.buttons={}
    for _,id in ipairs(Prefs.layoutControls) do
        local widget
        if id=='stick' then widget=DriveWidgets.Stick{position='absolute',touchScale=k,pointerEvents='none'};widget.live=true
        else
            local v=VISUALS[id]
            widget=DriveWidgets.Button{position='absolute',touchScale=k,unit=1,padding=0,minWidth=0,minHeight=0,pointerEvents='none',
                kind=v.kind,icon=v.icon,iconPath=v.iconPath,weapon=v.weapon,flipX=v.flipX,text=v.text}
        end
        editor:AddChild(widget);editor.previews[id]=widget
    end
    local marks=Marks{position='absolute',left=0,top=0,width='100%',height='100%',pointerEvents='none'};marks.editor=editor;editor:AddChild(marks)
    local bar=W.Surface{kind='dock',sourceScale=k,position='absolute',padding=8*k,gap=6*k,flexDirection='column'};editor.bar=bar
    editor.title=UI.Label{text='',fontFamily='vox-title',fontSize=13*k,color='#edf6ff',height=20*k,flexShrink=0,pointerEvents='none'}
    bar:AddChild(editor.title)
    local row=UI.Panel{width='100%',height=40*k,flexDirection='row',gap=4*k,flexShrink=0};bar:AddChild(row)
    local function Add(key,text,fn,grow)
        local b=W.Button{text=text,kind='segment',sourceScale=k,flexGrow=grow or 1,flexBasis=0,height=40*k,minWidth=0,padding=0,onClick=function() if not editor.closed then fn() end end}
        row:AddChild(b);editor.buttons[key]=b
    end
    Add('smaller','缩小',function() editor:Resize(-STEP) end)
    Add('bigger','放大',function() editor:Resize(STEP) end)
    Add('reset','复位此键',function() if editor.selected then editor.draft[editor.selected]=nil;editor:Relayout() end end,1.3)
    Add('resetAll','全部复位',function() editor.draft={};editor:Relayout() end,1.3)
    Add('cancel','取消',function() editor:Close(true) end)
    Add('save','保存',function() editor:Save() end)
    editor.buttons.save.props.selected=true
    editor:AddChild(bar)
    -- 占位弹窗：DialogHost 关闭 / 替换弹窗时只会调 Close，这里直接收起编辑器（不回上一级）
    local stub={isOpen_=true,props={source={}},touchLayoutEditor=true}
    function stub:Close() editor:Close(false) end
    editor.stub=stub
    if owner.dialog then owner.dialog:Close(true) end
    owner.dialog=stub;owner.dialogTick=nil
    root:AddChild(editor);UI.PushOverlay(editor)
    editor:Relayout()
    return editor
end
return M
