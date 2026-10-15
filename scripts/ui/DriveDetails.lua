local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Draw=require 'ui.DriveDraw'
local Details=Panel:Extend('VoxDriveDetails')
function Details:Refresh()
    local v=self.session.vehicle;local m=v.spec.motion
    self.rows={{'总质量',string.format('%.0f kg',m.mass)},{'总承载',string.format('%.0f kg',m.load)},
        {'负载率',m.L<math.huge and string.format('%.2f',m.L) or '—'},{'顶速 / 推进',string.format('%.0f / +%.0f km/h',m.topSpeed*3.6,(m.thrusterSpeed or 0)*3.6)},
        {'当前车速',string.format('%.1f km/h',math.abs(v.telemetry.speed or v.speed)*3.6)},{'重心高度',string.format('%.2f m',v.com[2])},
        {'碰撞盒 / 轮子 / 悬浮器',string.format('%d / %d / %d',#v.spec.boxes+#(v.spec.hulls or {}),#v.wheels,#v.spec.hovers)}}
    self.wheels={}
    for i,wheel in ipairs(v.wheels) do
        local pose=v:WheelPose(i);local on=v.suspension.states[i].grounded
        self.wheels[i]={on=on,compression=math.max(0,math.min(1,(pose.lift+wheel.drop)/(wheel.rest*.95))),
            text=(wheel.center[1]>0 and '左' or '右')..(wheel.center[3]>0 and '前' or '后')..' · '..(on and '着地' or '离地')}
    end
end
function Details:ContentHeight()
    return 23+#(self.rows or {})*17+(#(self.wheels or {})>0 and math.ceil(#self.wheels/2)*31+6 or 0)+17
end
function Details:DrawContent(vg,x,y,w)
    D.Text(vg,'详细数据',x,y,14,D.white,'vox-title',nil,1.5)
    local cy=y+23
    for _,row in ipairs(self.rows or {}) do
        D.Text(vg,row[1],x,cy+1,12,D.muted,'vox-body')
        D.Text(vg,row[2],x+w,cy+1,12,D.white,'vox-body',NVG_ALIGN_RIGHT);cy=cy+17
    end
    local wheels=self.wheels or {}
    if #wheels>0 then
        cy=cy+6;local cell=(w-4)/2
        for i,wheel in ipairs(wheels) do
            local wx,wy=x+(i-1)%2*(cell+4),cy+math.floor((i-1)/2)*31
            D.Rect(vg,wx,wy,cell,27,{7,15,26,102})
            D.Text(vg,wheel.text,wx+6,wy+3,12,wheel.on and D.muted or {255,138,122,255},'vox-body')
            D.Rect(vg,wx+6,wy+21,cell-12,3,{95,228,255,31})
            D.Rect(vg,wx+6,wy+21,(cell-12)*wheel.compression,3,D.green)
        end
        cy=cy+math.ceil(#wheels/2)*31
    end
    D.Text(vg,'悬挂压缩',x,cy+1,12,D.muted,'vox-body')
    D.Text(vg,'条越长压得越深',x+w,cy+1,12,D.white,'vox-body',NVG_ALIGN_RIGHT)
end
function Details:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w=r.x,r.y,r.w;local v=self.session.vehicle;local rows=self.rows or {}
    local wheelHeight=#v.wheels>0 and math.ceil(#v.wheels/2)*31+2 or 0;local h=20+23+#rows*17+wheelHeight+17
    if self.props.height~=h then self:SetStyle({height=h}) end
    Draw.Panel(vg,x,y,w,h);Draw.Text(vg,'详细数据',x+13,y+11,14,D.white,1.5)
    local cy=y+34
    for _,row in ipairs(rows) do D.Text(vg,row[1],x+13,cy+1,12,D.muted,'vox-body');D.Text(vg,row[2],x+w-13,cy+1,12,D.white,'vox-body',NVG_ALIGN_RIGHT);cy=cy+17 end
    if #v.wheels>0 then
        cy=cy+6
        for i,wheel in ipairs(self.wheels or {}) do
            local wx,wy=x+13+(i-1)%2*129,cy+math.floor((i-1)/2)*31
            D.Rect(vg,wx,wy,125,27,{0,0,0,77});D.Text(vg,wheel.text,wx+6,wy+3,12,wheel.on and D.muted or {255,138,122,255},'vox-body')
            D.Rect(vg,wx+6,wy+21,113,3,{95,228,255,31});D.Rect(vg,wx+6,wy+21,113*wheel.compression,3,D.green)
        end
        cy=cy+wheelHeight-6
    end
    D.Text(vg,'悬挂压缩',x+13,cy+1,12,D.muted,'vox-body');D.Text(vg,'条越长压得越深',x+w-13,cy+1,12,D.white,'vox-body',NVG_ALIGN_RIGHT)
end
return Details
