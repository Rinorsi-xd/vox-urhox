-- SVG arc geometry and CSS crosshair from shared/ui/driveHud.js + drive.css.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Draw=require 'ui.DriveDraw'
local M=Panel:Extend('VoxDriveVitals')
function M:SetEnergy(value,offline,armed,dt)
    value=math.max(0,math.min(1,value));self.ghost=self.ghost or 1;self.value=self.value or 1
    if value<self.ghost then
        if value<self.value-.001 then self.hold=.35 end
        self.hold=(self.hold or 0)-dt
        if self.hold<=0 then self.ghost=math.max(value,self.ghost-dt*.9) end
    else self.ghost=value end
    if self.offline and not offline then self.boot=.6 end
    self.boot=math.max(0,(self.boot or 0)-dt)
    self.value=value;self.offline=offline;self.armed=armed
    self.hit=math.max(0,(self.hit or 0)-dt);self.clock=(self.clock or 0)+dt
end
function M:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local cx,cy=r.x+r.w/2,r.y+r.h/2
    local scale=self.session.scope and .7 or 1;local energyColor=self.offline and {255,59,48,255} or (self.value or 1)<.25 and {255,194,26,255} or D.blue
    local function Arc(a,b,color,width)
        if a==b then return end
        nvgBeginPath(vg);nvgArc(vg,0,0,64,-a*math.pi/180,-b*math.pi/180,b>a and NVG_CCW or NVG_CW)
        nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,width);nvgLineCap(vg,NVG_BUTT);nvgStroke(vg)
    end
    nvgSave(vg);nvgTranslate(vg,cx,cy);nvgScale(vg,scale,scale)
    nvgSave(vg);nvgScale(vg,1.25,1.25)
    for side=1,self.armed and 2 or 1 do
        local a,b=side==1 and 230 or -50,side==1 and 130 or 50
        local color=side==1 and D.white or energyColor
        nvgSave(vg)
        if side==2 and self.offline and math.floor((self.clock or 0)/.2)%2==1 then nvgGlobalAlpha(vg,.35) end
        Arc(a,b,{10,12,16,140},7)
        if side==2 then Arc(a,a+(b-a)*(self.ghost or 1),{color[1],color[2],color[3],97},5) end
        local fillColor=side==2 and (self.boot or 0)>0 and D.white or color
        local health=self.session.combat and self.session.combat.player:Health() or 1
        Arc(a,a+(b-a)*(side==1 and health or self.value or 1),fillColor,5)
        for i=0,10 do
            local angle=(a+(b-a)*i/10)*math.pi/180;local endpoint=i==0 or i==10
            local ra,rb=64+(endpoint and 9 or 4),64-(endpoint and 5 or 2.5)
            nvgBeginPath(vg);nvgMoveTo(vg,math.cos(angle)*ra,-math.sin(angle)*ra);nvgLineTo(vg,math.cos(angle)*rb,-math.sin(angle)*rb)
            nvgStrokeWidth(vg,1.4);nvgStrokeColor(vg,nvgRGBA(10,12,16,191));nvgStroke(vg)
        end
        local lx,ly=math.cos(a*math.pi/180)*68,-math.sin(a*math.pi/180)*68+4
        local label=side==1 and '耐久' or '能量';local value=side==1 and tostring(math.floor(health*100+.5))..'%' or tostring(math.floor((self.value or 1)*100+.5))
        local lw,vw=Draw.Width(vg,label,11,1),Draw.Width(vg,value,11,1,'vox-tabular');if side==1 then lx=lx-lw-4-vw end
        Draw.Text(vg,label,lx,ly,11,D.muted,1);Draw.Text(vg,value,lx+lw+4,ly,11,side==1 and D.white or (self.value or 1)<.25 and energyColor or {143,210,255,255},1,'vox-tabular')
        nvgRestore(vg)
    end
    nvgRestore(vg)
    if self.offline then
        local bw=Draw.Width(vg,'能量耗尽',13,3)+20;nvgSave(vg)
        if math.floor((self.clock or 0)/.2)%2==1 then nvgGlobalAlpha(vg,.35) end
        D.Rect(vg,-bw/2,43,bw,20,{255,59,48,217});Draw.Text(vg,'能量耗尽',0,45,13,D.white,3,nil,NVG_ALIGN_CENTER);nvgRestore(vg)
    end
    nvgRestore(vg)
    local radius=self.session.scope and 8 or 14;local color=self.hint~='' and {255,90,70,230} or {160,240,255,217}
    if (self.hit or 0)>0 then
        local ratio=self.hit/(self.killed and .35 or .18);radius=radius*(1+(self.killed and .6 or -.3)*ratio)
        color=self.killed and {255,75,62,255} or {255,207,74,255}
    end
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,radius);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,2);nvgFillColor(vg,nvgRGBA(255,255,255,255));nvgFill(vg)
    if self.hint and self.hint~='' then D.Text(vg,self.hint,cx,cy+(self.session.scope and 29 or 23),13,{255,179,168,255},nil,NVG_ALIGN_CENTER) end
end
return M
