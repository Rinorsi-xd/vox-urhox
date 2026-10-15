local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Draw=require 'ui.DriveDraw'
local Rich=require 'ui.SourceRichText'
local Meter=Panel:Extend('VoxDriveMeter')
function Meter:Refresh()
    local Readout=require 'ui.DriveReadout';self.speedValue=Readout.Speed(self.session.vehicle)
    self.speedText=string.format('%.0f',self.speedValue);self.motionText=Readout.Motion(self.session.vehicle)
end
function Meter:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w=r.x,r.y,r.w;local v=self.session.vehicle;local m=v.spec.motion;local t=v.telemetry
    if not self.baseLayout then
        local runs={};local function Text(text,bold,bad) runs[#runs+1]={text=text,size=12,spacing=.5,font=not bold and 'vox-body' or nil,color=bad and {255,59,48,255} or bold and D.white or D.muted} end
        Text('地面 ');Text(string.format('%.0f',m.topSpeed*3.6),true);Text(' km/h')
        if #v.spec.thrusters>0 then Text(string.format(' · 推进参考 %.0f km/h',(m.thrusterSpeed or 0)*3.6)) end
        Text(' · 负载率 ');Text(m.L<math.huge and string.format('%.2f',m.L) or '—',true,m.L>1.2);Text(string.format(' · 质量 %.0f kg',m.mass))
        self.baseLayout=Rich.Layout(vg,{runs},366,15)
    end
    local info=self.motionText or ''
    if info~=self.infoKey then self.infoKey=info;self.infoLayout=info~='' and Rich.Layout(vg,{{{text=info,size=13,font='vox-body',color=D.white}}},366,17) or nil end
    local h=95+self.baseLayout.height+(self.infoLayout and self.infoLayout.height or 0)
    if self.props.height~=h then self:SetStyle({height=h});return end
    Draw.Panel(vg,x,y,w,h)
    local kmh=self.speedValue or 0;local speed=self.speedText or '0';local numWidth=math.max(D.Width(vg,'0',50,'vox-tabular')*2.4,D.Width(vg,speed,50,'vox-tabular'));local unit=Draw.Width(vg,'km/h',12,2)
    local start=x+(w-numWidth-6-unit)/2
    nvgSave(vg);nvgFontBlur(vg,8);D.Text(vg,speed,start+numWidth,y+11,50,{95,228,255,128},'vox-tabular',NVG_ALIGN_RIGHT);nvgRestore(vg)
    D.Text(vg,speed,start+numWidth,y+11,50,{255,255,255,255},'vox-tabular',NVG_ALIGN_RIGHT);Draw.Text(vg,'km/h',start+numWidth+6,y+44,12,D.white,2)
    local max=math.max(40,math.max(m.topSpeed,m.thrusterSpeed or 0)*3.6*1.15);local fill=366*math.min(1,kmh/max)
    D.Rect(vg,x+17,y+71,366,4,{95,228,255,26});nvgBeginPath(vg);nvgRect(vg,x+17,y+71,fill,4);D.Gradient(vg,x+17,y+71,math.max(1,fill),4,{31,168,230,255},{127,240,255,255},true)
    D.Rect(vg,x+17+366*m.topSpeed*3.6/max,y+71,2,4,D.orange);Rich.Draw(vg,self.baseLayout,x+17+(366-self.baseLayout.width)/2,y+82,true)
    if self.infoLayout then Rich.Draw(vg,self.infoLayout,x+17,y+82+self.baseLayout.height) end
    local flags={};if t.boosting then flags[#flags+1]={'推进',D.orange,{29,10,0,255}} end
    if (t.contact or 0)==0 and (t.hovers or 0)==0 and (t.legContacts or 0)==0 then flags[#flags+1]={'离地',D.white,{2,22,35,255}} end
    if v.drifting then flags[#flags+1]={'手刹',{255,59,48,255},{42,0,0,255}} end
    for i,flag in ipairs(flags) do local fw=Draw.Width(vg,flag[1],11,1.5)+14;D.Rect(vg,x+w-10-fw,y+10+(i-1)*18,fw,15,flag[2]);Draw.Text(vg,flag[1],x+w-17,y+11+(i-1)*18,11,flag[3],1.5,nil,NVG_ALIGN_RIGHT) end
end
return Meter
