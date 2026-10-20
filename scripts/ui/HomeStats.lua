local SourceParagraph=require("ui.SourceParagraph")
local SourceButton=require("ui.SourceButton")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Theme=require 'ui.VoxTheme'
local Config=require 'Config'
local Defs=require 'parts.Defs'
local Stats=UI.Panel:Extend('VoxSourceHomeStats')
function Stats:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w=r.x,r.y,r.w-8;local a=self.data;local st=a.stats
    nvgSave(vg);nvgIntersectScissor(vg,r.x,r.y,r.w,r.h)
    if self.loadout then
        local sy=y;local cols=5;local stride=50
        for _,group in ipairs(a.groups) do
            D.Icon(vg,group.icon,x,sy+1,16,D.orange);D.Text(vg,group.title,x+23,sy,14)
            D.Text(vg,group.count,x+w,sy,14,D.muted,'vox-display',NVG_ALIGN_RIGHT);sy=sy+27
            for i,item in ipairs(group.items) do
                local tx=x+((i-1)%cols)*stride;local ty=sy+math.floor((i-1)/cols)*50
                D.Path(vg,{tx,ty,tx+44,ty,tx+44,ty+36,tx+36,ty+44,tx,ty+44})
                nvgFillColor(vg,D.Color(item.id and {32,58,84,128} or {28,48,69,102}));nvgFill(vg)
                if item.id then
                    self:RenderBackgroundImage(vg,Theme.Thumbnail(item.id),{x=tx+3.52,y=ty+3.52,w=36.96,h=36.96},'contain',nil)
                    D.Text(vg,'×'..item.count,tx+40,ty+28,13,nil,'vox-display',NVG_ALIGN_RIGHT)
                else D.Icon(vg,'plus',tx+14,ty+14,16,D.dim) end
            end
            sy=sy+math.max(1,math.ceil(#group.items/cols))*50+10
        end
    else
        D.Text(vg,'战车整备',x,y,11,D.white,'vox-body');D.Text(vg,a.slot,x+w,y,11,D.muted,'vox-body',NVG_ALIGN_RIGHT)
        D.Path(vg,{x,y+39.55,x+20,y+28.3,x+40,y+39.55,x+40,y+62.05,x+20,y+73.3,x,y+62.05})
        nvgFillColor(vg,D.Color({24,52,83,255}));nvgFill(vg);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(a.ok and D.orange or {255,109,114,255}));nvgStroke(vg)
        D.Text(vg,'T'..a.tier.id,x+20,y+42,17,nil,'vox-display',NVG_ALIGN_CENTER)
        D.Text(vg,a.tier.name,x+50,y+28.3,16)
        local badge=a.ok and '可出战' or '超出限制';local badgeWidth=D.Width(vg,badge,11,'vox-body')+29
        -- 角标高度跟字号走（手机上小字会抬到可读字号），以原 20 高的中线为准上下扩
        local ba,bd=D.FontMetrics(vg,11,'vox-body');local bh=math.max(20,ba+bd+6)
        D.Rect(vg,x+50,y+63.3-bh/2,badgeWidth,bh,a.ok and {142,227,208,255} or {255,109,114,255})
        D.Icon(vg,a.ok and 'check' or 'warn',x+55,y+56.3,14,{10,37,48,255},2.6)
        D.Text(vg,badge,x+74,y+63.3-bh/2,11,{10,37,48,255},'vox-body',nil,0,false,bh)
        if a.unsaved then D.Text(vg,'有改动未保存',x+57+badgeWidth,y+56.3,11,D.muted,'vox-body') end
        D.Icon(vg,'chip',x,y+103.97,16,D.orange);D.Text(vg,'预算',x+23,y+103.97,12,D.muted,'vox-body')
        local cap=' / '..D.Number(a.tier.budget);local capWidth=D.Width(vg,cap,14,'vox-display')
        D.Text(vg,D.Number(st.budget),x+w-capWidth,y+88.97,31,nil,'vox-display',NVG_ALIGN_RIGHT,0,false,31)
        D.Text(vg,cap,x+w,y+102.97,14,D.muted,'vox-display',NVG_ALIGN_RIGHT,0,false,14)
        D.Meter(vg,x,y+127.97,w,7,st.budget,a.tier.budget,true)
        for i,entry in ipairs({{'shield','总耐久',D.Number(a.hp)},{'gauge','参考极速',tostring(math.floor(st.topSpeed+.5))}}) do
            local tx=x+(i-1)*(w+15)*.5;D.Icon(vg,entry[1],tx,y+148.97,16,D.orange);D.Text(vg,entry[2],tx+23,y+149.47,12,D.muted,'vox-body')
            D.Text(vg,entry[3],tx,y+170.97,27,nil,'vox-display',nil,0,false,27)
            if i==2 then D.Text(vg,'km/h',tx+D.Width(vg,entry[3],27,'vox-display')+2,y+183.97,11,D.muted,'vox-body') end
        end
        if self.expanded then
            local cy=y+284
            for _,entry in ipairs({{'质量',D.Number(st.mass)..' kg'},{'零件',st.parts..' / '..a.tier.parts},{'武器',st.weapons..' / '..a.tier.weapons},
                {'尺寸',string.format('%.1f × %.1f × %.1f m',st.dims.L*Config.CELL,st.dims.W*Config.CELL,st.dims.H*Config.CELL)}}) do
                D.Text(vg,entry[1],x,cy,13,D.muted,'vox-body');D.Text(vg,entry[2],x+w,cy,16,nil,nil,NVG_ALIGN_RIGHT);cy=cy+34
            end
            if a.warning then self.paragraph:Draw(vg,a.warning,x,cy+8,w,{230,187,112,255}) end
        end
    end
    nvgRestore(vg)
end
local M={}
function M.Fill(root,app,s)
    local bp=app.blueprint;local tier=Config.TIERS[app.tier];local diag=bp:Diagnose(tier);local st=diag.stats
    local data={stats=st,tier=tier,name=bp.name,hp=0,errors=0,groups={},unsaved=app.bays.unsaved,slot=app.bays.active and string.format('车位 %02d',app.bays.active) or '未入库草稿'}
    local groups={weapon={},movement={}};local lookup={};local keep={}
    for _,p in ipairs(bp:List()) do local def=Defs.PARTS[p.type];data.hp=data.hp+def.hp
        if groups[def.cat] then
            if not lookup[p.type] then lookup[p.type]={id=p.type,count=0};table.insert(groups[def.cat],lookup[p.type]) end
            lookup[p.type].count=lookup[p.type].count+1
        end
    end
    for _,d in ipairs(diag.list) do if d.level~='warn' then data.errors=data.errors+1;data.warning=data.warning or d.text end end
    data.warning=data.warning or diag.list[1] and diag.list[1].text;data.ok=data.errors==0 and st.fitTier~=nil
    for _,spec in ipairs({{'weapon','武器','crosshair'},{'movement','移动部件','wheel'}}) do
        local items=groups[spec[1]];local total=0
        for _,item in ipairs(items) do total=total+item.count;keep[Theme.Thumbnail(item.id)]=true end
        if spec[1]=='weapon' then for _=st.weapons+1,math.min(tier.weapons,math.max(st.weapons,6)) do items[#items+1]={} end end
        data.groups[#data.groups+1]={title=spec[2],icon=spec[3],items=items,count=spec[1]=='weapon' and (st.weapons..' / '..tier.weapons) or tostring(total)}
    end
    local expanded=s and s.detailsOpen
    local widget=Stats{width='100%',height=expanded and 525 or 273,pointerEvents='none',flexShrink=0}
    widget.data=data;widget.expanded=expanded;widget.paragraph=SourceParagraph.New(13,19);root:AddChild(widget)
    if s then
        root:AddChild(s.Track(SourceButton{text='车辆详情',subtitle=st.parts..' 个零件 · '..st.weapons..' / '..tier.weapons..' 武器',icon=expanded and 'minus' or 'plus',sourceKind='details',
            position='absolute',left=0,top=s.compact and 200 or 211.97,width=s.infoWidth-8,height=51,onClick=function() s.detailsOpen=not s.detailsOpen;s.revision=-1 end}))
        local loadoutHeight=0
        for _,group in ipairs(data.groups) do loadoutHeight=loadoutHeight+27+math.max(1,math.ceil(#group.items/5))*50+10 end
        s.loadoutHeight=loadoutHeight-6
        local loadout=Stats{width='100%',height=s.loadoutHeight,pointerEvents='none',flexShrink=0}
        loadout.data=data;loadout.loadout=true;s.loadout:AddChild(loadout)
    end
    Theme.TrimThumbnails(keep)
end
return M
