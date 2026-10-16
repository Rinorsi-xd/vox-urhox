-- Source #rotorHud and showRotorHud, rendered inside the UI-owned NanoVG frame.
local Defs=require("parts.Defs")
local Math3=require("core.Math3")
local Coord=require("core.Coord")
local Config=require("Config")

local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local R=require 'construction.Rotors'
local Hud=Panel:Extend('VoxRotorHud')
local colors={{70,224,255,255},{93,255,138,255},{255,154,42,255}}
function Hud:Sync()
    local s=self.session;local e=s.editor;local p=e.hit and e.bp.parts[e.hit.partId]
    local active=p and R.Is(p.type) and not s.dialog and not s.inventoryPanel and not s.hud.colorOpen and s.controls.inside
        and (s.buildCamera.mode~='fp' or s.buildCamera.captured)
    local info=active and s.inspection:Get().rotors[p.id] or nil
    local key=info and tostring(p.id)..':'..e.history.revision or ''
    if key~=self.infoKey then
        self.infoKey=key;self.info=info;self.part=active and p or nil;self.foot=nil
        s.inspection.view:SetRotor(e.bp,info)
        if info then
            self.mode=1;for i,m in ipairs(R.MODES) do if m.type==p.type then self.mode=i end end
            local function Names(ids)
                local counts,order={},{};for _,id in ipairs(ids) do local part=e.bp.parts[id]
                    if part then local name=Defs.PARTS[part.type].name;if not counts[name] then order[#order+1]=name;counts[name]=0 end;counts[name]=counts[name]+1 end
                end
                local names={};for _,name in ipairs(order) do names[#names+1]=name..(counts[name]>1 and ' ×'..counts[name] or '') end;return table.concat(names,'、')
            end
            local paragraphs={}
            local function Line(text,color) paragraphs[#paragraphs+1]={{text=text,size=12,font='vox-body',color=color or {159,216,255,255}}} end
            if info.problem then
                Line(info.problem,{255,138,122,255});local outside={};for _,id in ipairs(info.blockers) do if not info.load[id] then outside[#outside+1]=id end end
                if #outside>0 then Line('连着：'..Names(outside)..'（标红）',{255,138,122,255}) end
            elseif info.count>0 then
                Line('蓝框里 '..info.count..' 个零件一起转')
                local range=info.range
                if range and not range.free then
                    Line(R.RangeText(range),{255,138,122,255})
                    if #range.hiBlockers>0 then Line('按 F 的方向碰到 '..Names(range.hiBlockers)..'（标红）',{255,138,122,255}) end
                    local yellow,red,same={},{},false;for _,id in ipairs(range.hiBlockers) do red[id]=true end
                    for _,id in ipairs(range.loBlockers) do if red[id] then same=true else yellow[#yellow+1]=id end end
                    if #yellow>0 then Line('反方向碰到 '..Names(yellow)..'（标黄）'..(same and '，也碰到标红的' or ''),{255,211,77,255})
                    elseif same then Line('反方向也碰到标红的零件',{255,138,122,255}) end
                end
            else Line('转盘上还没装东西',D.muted) end
            self.paragraphs=paragraphs
        end
    end
end
function Hud:Update(dt)
    local target=self.info and 1 or 0
    self.alpha=Math3.Approach(self.alpha or 0,target,dt/.12)
end
local function Icon(vg,x,y,mode,color)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgBeginPath(vg);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,1.8)
    nvgLineCap(vg,NVG_ROUND);nvgLineJoin(vg,NVG_ROUND)
    if mode==2 then
        nvgArc(vg,10,10,6.5,0,math.pi*2+math.atan(-4.7,4.5),NVG_CW);nvgMoveTo(vg,15.5,2);nvgLineTo(vg,15.5,6);nvgLineTo(vg,11.5,6)
    else
        nvgCircle(vg,10,10,6.5)
        local a,b=mode==1 and 1 or 1.5,mode==1 and 6 or 5.5
        nvgMoveTo(vg,10,a);nvgLineTo(vg,10,b);nvgMoveTo(vg,10,20-b);nvgLineTo(vg,10,20-a)
        nvgMoveTo(vg,a,10);nvgLineTo(vg,b,10);nvgMoveTo(vg,20-b,10);nvgLineTo(vg,20-a,10)
        if mode==3 then nvgRect(vg,8.2,8.2,3.6,3.6) end
    end;nvgStroke(vg);nvgRestore(vg)
end
function Hud:Render(vg)
    if not self.info then return end;D.Begin(vg)
    if not self.foot then self.foot=Rich.Layout(vg,self.paragraphs,360,17,{size=12,font='vox-body'}) end
    local info=self.info;local r=self:GetAbsoluteLayout();local w=math.min(380,r.w-24);local h=157+self.foot.height
    local camera=self.session.app.camera.camera;local f=R.Frame(self.part);local dir=self.session.editor.forward
    local len=math.sqrt(dir[1]^2+dir[3]^2);if len<1e-5 then len=1 end
    local point=camera:WorldToScreenPoint(Coord.Vec((f.pivot[1]-dir[3]/len*2)*Config.CELL,f.pivot[2]*Config.CELL,(f.pivot[3]+dir[1]/len*2)*Config.CELL))
    local x=math.min(r.w-w-12,math.max(r.w/2+40,point.x*r.w));local y=math.min(r.h-h-12,math.max(12,point.y*r.h-h/2))
    self.bounds={x=x,y=y,w=w,h=h}
    nvgSave(vg);nvgGlobalAlpha(vg,self.alpha or 0)
    nvgBeginPath(vg);nvgRect(vg,x-24,y-14,w+48,h+48)
    nvgFillPaint(vg,nvgBoxGradient(vg,x,y+10,w,h,0,24,nvgRGBA(0,0,0,128),nvgRGBA(0,0,0,0)));nvgFill(vg)
    D.Rect(vg,x,y,w,h,{14,15,18,237});D.Rect(vg,x,y,3,h,info.problem and {255,59,48,255} or {70,184,255,255})
    D.Text(vg,'转轴',x+14,y+8,15,D.muted,nil,nil,2)
    for i,m in ipairs(R.MODES) do local yy=y+33+(i-1)*34;local c=colors[i];local on=i==self.mode
        nvgSave(vg);nvgGlobalAlpha(vg,(self.alpha or 0)*(on and 1 or .62))
        if on then
            nvgBeginPath(vg);nvgRect(vg,x+10,yy,w-20,34)
            D.Gradient(vg,x+10,yy,w-20,34,{c[1],c[2],c[3],61},{c[1],c[2],c[3],0},true)
            D.Rect(vg,x+10,yy,2,34,c)
        end
        nvgBeginPath(vg);nvgRoundedRect(vg,x+14,yy+6,22,22,3);nvgFillColor(vg,D.Color(on and c or {255,255,255,20}));nvgFill(vg)
        D.Rect(vg,x+14,yy+26,22,2,{0,0,0,102});D.Text(vg,tostring(i),x+25,yy+8,14,on and {12,14,17,255} or D.white,nil,NVG_ALIGN_CENTER)
        Icon(vg,x+46,yy+7,i,c);D.Text(vg,m.name,x+74,yy+6,17,D.white)
        D.Text(vg,m.hint,x+w-18,yy+9,11.5,D.muted,'vox-body',NVG_ALIGN_RIGHT)
        nvgRestore(vg)
    end
    D.Rect(vg,x+14,y+141,w-28,1,{255,255,255,20})
    Rich.Draw(vg,self.foot,x+14,y+148,false);nvgRestore(vg)
end
return Hud
