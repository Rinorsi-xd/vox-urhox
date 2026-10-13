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
    self.partType=id;self.imageEntry=0;local d=Defs.PARTS[id];if not d then return end
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
function Detail:Update(dt) self.imageEntry=math.min(.24,(self.imageEntry or 0)+math.max(0,dt)) end
function Detail:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local d=Defs.PARTS[self.partType];if not d then return end
    local x,y,w=r.x,r.y,r.w
    local compact=self.props.compact
    local imageSize=compact and 76 or math.min(200,self.props.viewportHeight*.23)
    local imageHeight=compact and 76 or math.min(250,math.max(160,self.props.viewportHeight*.22))
    local entry=require('ui.SourceButtonMotion').Ease((self.imageEntry or .24)/.24,'css-ease-out')
    nvgSave(vg);nvgGlobalAlpha(vg,entry);nvgTranslate(vg,7*(1-entry),0)
    self:RenderBackgroundImage(vg,Theme.Thumbnail(d.id),{x=x+(w-imageSize)/2,y=y+(imageHeight-imageSize)/2,w=imageSize,h=imageSize},'contain',nil);nvgRestore(vg)
    local tagY=y+imageHeight+8
    D.Icon(vg,Icons[d.cat] or 'cube',x,tagY,16,D.orange);D.Text(vg,category[d.cat] or '',x+24,tagY,12,D.orange,'vox-body')
    if not compact then for i,t in ipairs(self.inventory.hotbar) do if t==d.id then D.Text(vg,'快捷栏第 '..(i%10)..' 格',x+w,tagY+2,10,D.muted,'vox-body',NVG_ALIGN_RIGHT);break end end end
    local titleSize=compact and 22 or math.min(32,math.max(24,self.props.viewportWidth*.022))
    while titleSize>16 and D.Width(vg,d.name,titleSize)>w do titleSize=titleSize-1 end
    D.Text(vg,d.name,x,tagY+26,titleSize,nil,nil,nil,1)
    local key=d.id..':'..w
    if self.layoutKey~=key then
        self.layoutKey=key;self.description=Lines(vg,d.desc or '',w,12,'vox-body');self.rowLines={}
        for i,row in ipairs(self.rows) do local labelWidth=D.Width(vg,row[2],11,'vox-body');self.rowLines[i]=Lines(vg,row[3],math.max(80,w-32-labelWidth),12,'vox-body') end
    end
    local cy=tagY+26+titleSize*1.2+12
    for _,line in ipairs(self.description) do D.Text(vg,line,x,cy,12,{170,192,213,255},'vox-body');cy=cy+20.4 end;cy=cy+17
    for i,row in ipairs(self.rows) do
        if i==4 then
            cy=cy+16
            if not self.more then
                self.more=require('ui.InventoryChrome').Button{kind='more',text='更多参数',width=w,height=compact and 44 or 38,position='absolute',left=0,top=0,onClick=function(b)
                    self.expanded=not self.expanded;b.props.selected=self.expanded
                end};self:AddChild(self.more)
            end
            self.more.props.count=tostring(#self.rows-3);self.more:SetStyle({top=cy-y})
            cy=cy+(compact and 44 or 38)
            if not self.expanded then break end
        end
        local lines=self.rowLines[i];local height=i<=3 and 54 or math.max(16.8,#lines*18.6)+19
        D.Icon(vg,row[1],x,cy+10,15,{131,172,208,255});D.Text(vg,row[2],x+24,cy+11,11,{156,184,210,255},'vox-body')
        if i<=3 then
            local unit=i==1 and (d.budget>0 and ' 点' or '') or i==2 and ' kg' or ''
            local value=i==1 and (d.budget>0 and tostring(d.budget) or '免费') or i==2 and tostring(d.mass) or tostring(d.hp)
            local unitWidth=D.Width(vg,unit,12,'vox-body')
            D.Text(vg,value,x+w-unitWidth,cy+5,value=='免费' and 12 or 24,nil,value=='免费' and 'vox-body' or 'vox-display',NVG_ALIGN_RIGHT)
            D.Text(vg,unit,x+w,cy+14,12,nil,'vox-body',NVG_ALIGN_RIGHT)
            local ratio=math.max(.02,math.min(1,row[5]/maximum[row[4]]));D.Rect(vg,x+24,cy+height-12,w-24,3,{37,62,86,255});D.Rect(vg,x+24,cy+height-12,(w-24)*ratio,3,{117,185,223,255})
        else
            for j,line in ipairs(lines) do D.Text(vg,line,x+w,cy+9+(j-1)*18.6,12,nil,'vox-body',NVG_ALIGN_RIGHT) end
        end
        D.Rect(vg,x,cy+height-1,w,1,{41,71,97,255});cy=cy+height
    end
    local height=math.ceil(cy-y+18);if self.props.height~=height then self:SetStyle({height=height}) end
end
return Detail

