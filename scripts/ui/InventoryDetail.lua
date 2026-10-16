local WeaponDefs=require("combat.WeaponDefs")
local InventoryDetailRows=require("ui.InventoryDetailRows")
local SourceButtonMotion=require("ui.SourceButtonMotion")
local InventoryShadows=require("ui.InventoryShadows")
local InventoryChrome=require("ui.InventoryChrome")

local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Theme=require 'ui.VoxTheme'
local Defs=require 'parts.Defs'
local Icons=require('ui.InventoryChrome').icons
local Layout=require 'ui.InventoryDetailLayout'
local Detail=Panel:Extend('VoxInventoryDetail')
local maximum={budget=1,mass=1,hp=1};local category={}
for _,d in ipairs(Defs.LIST) do for k,v in pairs(maximum) do maximum[k]=math.max(v,d[k] or 0) end end
for _,c in ipairs(Defs.CATEGORIES) do category[c.id]=c.name end
function Detail:SetPart(id)
    self.partType=id;self.imageEntry=0;local d=Defs.PARTS[id];if not d then return end
    local ws=d.weapon and WeaponDefs.Stats(id)
    self.rows=InventoryDetailRows.Build(d,ws)
    self.layoutKey=nil
end
function Detail:Update(dt) self.imageEntry=math.min(.24,(self.imageEntry or 0)+math.max(0,dt)) end
function Detail:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local d=Defs.PARTS[self.partType];if not d then return end
    local x,y,w=r.x,r.y,r.w
    local compact=self.props.compact
    local imageSize=compact and 76 or math.min(200,self.props.viewportHeight*.23)
    local imageHeight=compact and 76 or math.min(250,math.max(160,self.props.viewportHeight*.22))
    local entry=SourceButtonMotion.Ease((self.imageEntry or .24)/.24,'css-ease-out')
    nvgSave(vg);nvgGlobalAlpha(vg,entry);nvgTranslate(vg,7*(1-entry),0)
    InventoryShadows.Image(self,vg,d.id,'detail',{x=x+(w-imageSize)/2,y=y+(imageHeight-imageSize)/2,w=imageSize,h=imageSize})
    self:RenderBackgroundImage(vg,Theme.Thumbnail(d.id),{x=x+(w-imageSize)/2,y=y+(imageHeight-imageSize)/2,w=imageSize,h=imageSize},'contain',nil);nvgRestore(vg)
    local tagY=y+imageHeight+8
    D.Icon(vg,Icons[d.cat] or 'cube',x,tagY,18,D.orange);D.Text(vg,category[d.cat] or '',x+24,tagY,12,D.orange,'vox-body')
    if not compact then for i,t in ipairs(self.inventory.hotbar) do if t==d.id then D.Text(vg,'快捷栏第 '..(i%10)..' 格',x+w,tagY+2,10,D.muted,'vox-body',NVG_ALIGN_RIGHT);break end end end
    local titleSize=compact and 22 or math.min(32,math.max(24,self.props.viewportWidth*.022))
    while titleSize>16 and D.Width(vg,d.name,titleSize)>w do titleSize=titleSize-1 end
    D.Text(vg,d.name,x,tagY+26,titleSize,nil,nil,nil,1)
    local key=d.id..':'..w..':'..tostring(vg)
    if self.layoutKey~=key then
        self.layoutKey=key;self.description=Layout.Description(vg,d.desc or '',w);self.rowLayouts={}
        for i,row in ipairs(self.rows) do if i>3 then self.rowLayouts[i]=Layout.Row(vg,row,w) end end
    end
    local cy=tagY+26+math.floor(titleSize*1.05*64)/64+(compact and 9 or 12)
    Layout.Draw(vg,self.description,x,cy,w);cy=cy+self.description.height+(compact and 10 or 17)
    for i,row in ipairs(self.rows) do
        if i==4 then
            cy=cy+16
            if not self.more then
                self.more=InventoryChrome.Button{kind='more',text='更多参数',width=w,height=compact and 44 or 38,position='absolute',left=0,top=0,onClick=function(b)
                    self.expanded=not self.expanded;b.props.selected=self.expanded
                end};self:AddChild(self.more)
            end
            self.more.props.count=tostring(#self.rows-3);self.more:SetStyle({top=cy-y})
            cy=cy+(compact and 44 or 38)
            if not self.expanded then break end
        end
        local layout=self.rowLayouts[i];local height=i<=3 and 53.796875 or layout.height
        if i<=3 then
            D.Icon(vg,row[1],x,cy+10,15,{131,172,208,255});D.Text(vg,row[2],x+24,cy+11,11,{156,184,210,255},'vox-body')
            local unit=i==1 and (d.budget>0 and ' 点' or '') or i==2 and ' kg' or ''
            local value=i==1 and (d.budget>0 and tostring(d.budget) or '免费') or i==2 and tostring(d.mass) or tostring(d.hp)
            local unitWidth=D.Width(vg,unit,12,'vox-body')
            D.Text(vg,value,x+w-unitWidth,cy+5,value=='免费' and 12 or 24,nil,value=='免费' and 'vox-body' or 'vox-tabular',NVG_ALIGN_RIGHT)
            D.Text(vg,unit,x+w,cy+14,12,nil,'vox-body',NVG_ALIGN_RIGHT)
            local ratio=math.max(.02,math.min(1,row[5]/maximum[row[4]]));D.Rect(vg,x+24,cy+height-12,w-24,3,{37,62,86,255});D.Rect(vg,x+24,cy+height-12,(w-24)*ratio,3,{117,185,223,255})
        else
            local contentHeight=height-19
            D.Icon(vg,row[1],x,cy+9+(contentHeight-15)/2,15,{131,172,208,255})
            Layout.Draw(vg,layout.label,x+23,cy+9+(contentHeight-layout.label.height)/2,layout.labelWidth)
            Layout.Draw(vg,layout.value,x+31+layout.labelWidth,cy+9+(contentHeight-layout.value.height)/2,layout.valueWidth,true)
        end
        D.Rect(vg,x,cy+height-1,w,1,{41,71,97,255});cy=cy+height
    end
    local height=math.ceil(cy-y);if self.props.height~=height then self:SetStyle({height=height}) end
end
return Detail

