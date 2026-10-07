local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Theme=require 'ui.VoxTheme'
local Defs=require 'parts.Defs'
local Icons=require('ui.InventoryChrome').icons
local Detail=Panel:Extend('VoxInventoryDetail')
local maximum={budget=1,mass=1,hp=1};local category={}
for _,d in ipairs(Defs.LIST) do for k,v in pairs(maximum) do maximum[k]=math.max(v,d[k] or 0) end end
for _,c in ipairs(Defs.CATEGORIES) do category[c.id]=c.name end
local function Lines(vg,text,width,size,font)
    local lines={};local line=''
    for _,code in utf8.codes(text) do
        local c=utf8.char(code)
        if c=='\n' or line~='' and D.Width(vg,line..c,size,font)>width then lines[#lines+1]=line;line=c=='\n' and '' or c else line=line..c end
    end
    lines[#lines+1]=line;return lines
end
function Detail:SetPart(id)
    self.partType=id;local d=Defs.PARTS[id];if not d then return end
    self.rows={{'chip','预算',d.budget==0 and '免费' or d.budget..' 点','budget',d.budget},
        {'weight','质量',d.mass..' kg','mass',d.mass},{'shield','耐久',tostring(d.hp),'hp',d.hp}}
    local function Row(icon,label,text) self.rows[#self.rows+1]={icon,label,text} end
    if d.load>0 then Row('weight','承载',d.load..' kg');Row('gauge','基础速度',d.speed..' km/h') end
    if d.speedLimit then Row('gauge','参考限速（不叠加）',d.speedLimit..' km/h') end
    if d.wheel then Row('wheel','转向',d.steer and ('会转向，最大 '..d.steerAngle..'°') or '不转向（动力轮）') end
    if d.track then Row('wheel','转向','原地差速转向，不需要转向轮') end
    if d.wtier then Row(d.weapon and 'crosshair' or 'wheel',d.weapon and '武器阶位' or '阶位','T'..d.wtier..'（车辆档位不能更低）') end
    local ws=d.weapon and require('combat.WeaponDefs').Stats(id)
    if ws then
        local n=math.floor(1/ws.share+.5)
        Row('gauge','火力',n==1 and '1 份（一把就满）' or ('1/'..n..' 份（'..n..' 把同类凑满）'))
        Row('crosshair','单把秒伤',tostring(math.floor(ws.damage*(ws.rate or 1/ws.interval)+.5))..(ws.spinUp and '（转满后）' or ''))
        Row('chip','每发耗能',tostring(tonumber(string.format('%.2f',ws.energy))))
    end
    Row('build','占用',#d.cells..' 格');Row('lock','解锁',d.unlock..'（原型已全部开放）')
    self.layoutKey=nil
end
function Detail:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local d=Defs.PARTS[self.partType];if not d then return end
    local x,y,w=r.x,r.y,r.w
    nvgSave(vg);nvgTranslate(vg,x+w/2,y+136);nvgScale(vg,w/220,1);nvgBeginPath(vg);nvgRect(vg,-110,-136,220,220)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,110,nvgRGBA(255,255,255,20),nvgRGBA(255,255,255,0)));nvgFill(vg);nvgRestore(vg)
    self:RenderBackgroundImage(vg,Theme.Thumbnail(d.id),{x=x+(w-190)/2,y=y+15,w=190,h=190},'contain',nil)
    D.Icon(vg,Icons[d.cat] or 'cube',x,y+230,18,D.orange);D.Text(vg,category[d.cat] or '',x+24,y+230,16,D.orange)
    for i,t in ipairs(self.inventory.hotbar) do if t==d.id then D.Text(vg,'快捷栏第 '..(i%10)..' 格',x+w,y+232,14,D.muted,nil,NVG_ALIGN_RIGHT);break end end
    D.Text(vg,d.name,x,y+254,34,nil,nil,nil,.5)
    local key=d.id..':'..w
    if self.layoutKey~=key then
        self.layoutKey=key;self.description=Lines(vg,d.desc or '',w,13,'vox-body');self.rowLines={}
        for i,row in ipairs(self.rows) do local labelWidth=D.Width(vg,row[2],13,'vox-body');self.rowLines[i]=Lines(vg,row[3],math.max(100,w-40-labelWidth),19) end
    end
    local cy=y+302
    for _,line in ipairs(self.description) do D.Text(vg,line,x,cy,13,D.muted,'vox-body');cy=cy+21.45 end;cy=cy+16
    for i,row in ipairs(self.rows) do
        local lines=self.rowLines[i];local height=math.max(19,#lines*19)+15+(row[4] and 9 or 0)
        D.Icon(vg,row[1],x,cy+7,18,D.muted);D.Text(vg,row[2],x+30,cy+8,13,D.muted,'vox-body')
        for j,line in ipairs(lines) do D.Text(vg,line,x+w,cy+5+(j-1)*19,19,nil,nil,NVG_ALIGN_RIGHT) end
        if row[4] then local ratio=math.max(.02,math.min(1,row[5]/maximum[row[4]]));D.Rect(vg,x+30,cy+height-11,w-30,3,{255,255,255,26});D.Rect(vg,x+30,cy+height-11,(w-30)*ratio,3,D.orange) end
        D.Rect(vg,x,cy+height-1,w,1,{255,255,255,13});cy=cy+height
    end
    local height=math.ceil(cy-y+18);if self.props.height~=height then self:SetStyle({height=height}) end
end
return Detail

