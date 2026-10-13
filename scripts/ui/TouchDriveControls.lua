-- All touch controls use the same UI pointer dispatcher and logical coordinates.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Button=require 'ui.SourceButton'
local Stick=Panel:Extend('VoxDriveStick')
function Stick:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local cx,cy=r.x+r.w/2,r.y+r.h/2
    for _,circle in ipairs({{cx,cy,72,{20,27,35,170}},{cx+(self.axisX or 0)*52,cy+(self.axisY or 0)*52,29,{255,106,19,200}}}) do
        nvgBeginPath(vg);nvgCircle(vg,circle[1],circle[2],circle[3]);nvgFillColor(vg,D.Color(circle[4]));nvgFill(vg)
        nvgStrokeWidth(vg,2);nvgStrokeColor(vg,nvgRGBA(244,245,247,120));nvgStroke(vg)
    end
    D.Text(vg,'前进 / 倒车 · 转向',cx,r.y+r.h-12,15,D.white,nil,NVG_ALIGN_CENTER)
end
local M={}
function M.Create(session,root)
    local controls=session.controls;local held={};local buttons={};local pointers={}
    local w,h=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
    local left=math.max(18,safe.left or 0);local right=math.max(18,safe.right or 0);local bottom=math.max(16,safe.bottom or 0)
    local look=false
    local function Ready()
        if session.dialog or not session:HasFocus() then return false end
        if not session.pointer.captured then session:Resume() end
        return true
    end
    local playfield=UI.Panel{position='absolute',width='100%',height='100%',
        onPointerDown=function(e) if e:IsTouch() and Ready() and not look then look={id=e.pointerId,x=e.x,y=e.y};pointers[e.pointerId]=true end end,
        onPointerMove=function(e) if look and look.id==e.pointerId then controls:Look((e.x-look.x)*1.4,(e.y-look.y)*1.4);look.x=e.x;look.y=e.y end end,
        onPointerUp=function(e) if look and look.id==e.pointerId then look=false;pointers[e.pointerId]=nil end end,
        onPointerCancel=function(e) if look and look.id==e.pointerId then look=false;pointers[e.pointerId]=nil end end}
    root:AddChild(playfield)
    local stick=Stick{position='absolute',left=left,bottom=bottom,width=180,height=180};root:AddChild(stick)
    local function ResetStick() stick.pointer=nil;stick.axisX=0;stick.axisY=0;controls.touchThrottle=0;controls.touchSteer=0 end
    local function Move(e)
        if stick.pointer~=e.pointerId then return end
        local r=stick:GetAbsoluteLayoutForHitTest();local x,y=(e.x-r.x-r.w/2)/62,(e.y-r.y-r.h/2)/62
        local len=math.sqrt(x*x+y*y);if len>1 then x,y=x/len,y/len end
        stick.axisX=x;stick.axisY=y
        controls.touchSteer=math.abs(x)>.13 and -x or 0;controls.touchThrottle=math.abs(y)>.13 and -y or 0
    end
    stick.props.onPointerDown=function(e) if e:IsTouch() and Ready() and not stick.pointer then stick.pointer=e.pointerId;pointers[e.pointerId]=true;Move(e) end end
    stick.props.onPointerMove=Move
    local function EndStick(e) if stick.pointer==e.pointerId then pointers[e.pointerId]=nil;ResetStick() end end
    stick.props.onPointerUp=EndStick;stick.props.onPointerCancel=EndStick
    local function Hold(id,text,keys,x,y,size)
        local b=Button{text=text,sourceKind=id=='fire' and 'primary' or 'flat',position='absolute',right=right+x,bottom=bottom+y,width=size or 72,height=size or 72}
        b.OnPointerDown=function(self,e)
            Button.OnPointerDown(self,e)
            if not e:IsTouch() or not Ready() or held[id] then return end
            held[id]=e.pointerId;pointers[e.pointerId]=true
            for _,key in ipairs(keys) do controls.held[key]=true end
        end
        local function Release(e)
            if held[id]~=e.pointerId then return end
            pointers[e.pointerId]=nil;held[id]=nil
            for _,key in ipairs(keys) do controls.held[key]=false end
        end
        b.OnPointerUp=function(self,e) Button.OnPointerUp(self,e);Release(e) end
        b.OnPointerCancel=function(self,e) Button.OnPointerCancel(self,e);Release(e) end
        root:AddChild(b);buttons[id]=b
    end
    Hold('fire','开火',{'fire'},0,0,88)
    Hold('brake',session.vehicle.legMode and '跳跃' or '刹车',{'brake','jump','climb'},102,0)
    if #session.vehicle.spec.thrusters>0 or #session.vehicle.spec.hovers>0 then
        Hold('rise','升高',{'climb'},0,102);Hold('descend','降低',{'descend'},84,102)
    end
    local function Tap(id,text,x,fn)
        local b=Button{text=text,sourceKind='flat',position='absolute',right=right+x,bottom=bottom+190,width=64,height=48,onClick=function() if Ready() then fn() end end}
        root:AddChild(b);buttons[id]=b
    end
    Tap('flip','翻正',0,function() session:Flip() end)
    if session.story then Hold('interact','安装',{'interact'},72,190,64)
    elseif not session.battle then Tap('area','传送',72,function() session:NextArea() end) end
    Tap('scope','瞄准',144,function() session.scope=not session.scope end)
    for i,item in ipairs({{'zoomIn','拉近',1},{'zoomOut','拉远',-1}}) do
        local b=Button{text=item[2],sourceKind='flat',position='absolute',right=right+(i-1)*72,top=132,width=64,height=44,
            onClick=function() if Ready() then session:Zoom(item[3]*(require('urhox-libs.Platform.PlatformUtils').IsWebPlatform() and 100 or 1)) end end}
        root:AddChild(b);buttons[item[1]]=b
    end
    local layer={playfield=playfield,stick=stick,buttons=buttons}
    function layer.Clear()
        local ids={};for id in pairs(pointers) do ids[#ids+1]=id end
        for _,id in ipairs(ids) do UI.CancelPointer(id,'touch') end
        pointers={};held={};look=false;ResetStick();controls:Clear();session.pointer:Suppress()
    end
    return layer
end
return M
