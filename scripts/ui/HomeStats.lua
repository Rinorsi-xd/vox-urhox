-- Source-faithful NanoVG vehicle statistics.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Theme=require 'ui.VoxTheme'
local Config=require 'Config'
local Defs=require 'parts.Defs'
local Stats=Panel:Extend('VoxSourceHomeStats')
local function Section(vg,x,y,w,title,icon,count)
    D.Icon(vg,icon,x,y+2,18,D.blue);D.Text(vg,title,x+26,y,17,D.white,nil,nil,1)
    local label=D.Width(vg,title,17,nil,1);D.Rect(vg,x+34+label,y+11,w-label-78,1,{120,147,165,60})
    if count then D.Text(vg,count,x+w,y,17,D.muted,nil,NVG_ALIGN_RIGHT) end
end
function Stats:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w=r.x,r.y,r.w;local a=self.data;local st=a.stats;local tier=a.tier
    nvgSave(vg);nvgIntersectScissor(vg,x,y,w,r.h)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,54/48,61/54)
    D.Path(vg,{24,2,45,14,45,40,24,52,3,40,3,14});nvgFillColor(vg,D.Color({29,32,37,255}));nvgFill(vg);nvgStrokeWidth(vg,2.5);nvgStrokeColor(vg,D.Color(a.fits and D.orange or {255,59,48,255}));nvgStroke(vg)
    D.Path(vg,{24,8,40,17.5,40,36.5,24,46,8,36.5,8,17.5});nvgStrokeWidth(vg,1.5);nvgStrokeColor(vg,D.Color({255,255,255,36}));nvgStroke(vg)
    D.Text(vg,'T'..tier.id,24,19,19,D.white,nil,NVG_ALIGN_CENTER);nvgRestore(vg)
    D.Text(vg,tier.name,x+68,y+10,18,D.orange,nil,nil,.5)
    if st.fitTier then D.Text(vg,'最低可进 T'..st.fitTier.id,x+68+D.Width(vg,tier.name,18,nil,.5)+10,y+14,14,D.muted,nil,nil,.5) end
    local status=a.ok and '可出战' or a.errors>0 and (a.errors..' 个问题') or '超出限制';local sw=D.Width(vg,status,14)+33
    D.Rect(vg,x+68,y+36,sw,20,a.ok and D.green or {255,59,48,255});D.Icon(vg,a.ok and 'check' or 'warn',x+74,y+39,14,{8,19,12,255});D.Text(vg,status,x+93,y+38,14,{8,19,12,255})
    D.Text(vg,a.slot,x+78+sw,y+38,13,D.muted,'vox-body')
    local len=utf8.len(a.name) or #a.name;local size=len<=6 and 54 or len<=9 and 44 or 34
    D.Text(vg,a.name,x,y+75-size*.1,size,D.white)
    local rule=75+size+14;D.Rect(vg,x,y+rule,w,2,{255,255,255,30});D.Rect(vg,x,y+rule-1,72,4,D.orange)
    D.Path(vg,{x+w-8,y+rule+1,x+w-4,y+rule-3,x+w,y+rule+1,x+w-4,y+rule+5});nvgFillColor(vg,D.Color({255,255,255,90}));nvgFill(vg)
    local cy=y+rule+18;D.Icon(vg,'chip',x,cy+17,22,D.orange);D.Text(vg,'预算',x+30,cy+15,19,D.muted)
    local suffix=' / '..D.Number(tier.budget);local tail=D.Width(vg,suffix,19)
    D.Text(vg,D.Number(st.budget),x+w-tail,cy-2,40,D.white,'vox-tabular',NVG_ALIGN_RIGHT);D.Text(vg,suffix,x+w,cy+17,19,D.muted,nil,NVG_ALIGN_RIGHT)
    D.Meter(vg,x,cy+48,w,12,st.budget,tier.budget,true)
    local sy=cy+78;Section(vg,x,sy,w,'车辆参数','car');sy=sy+31
    local function Row(icon,label,value,unit,valueForBar,cap)
        D.Icon(vg,icon,x,sy+8,18,D.muted);D.Text(vg,label,x+30,sy+8,13,D.muted,'vox-body')
        local unitW=D.Width(vg,unit or '',14);D.Text(vg,value,x+w-unitW,sy+3.8,22,D.white,nil,NVG_ALIGN_RIGHT)
        if unit then D.Text(vg,unit,x+w,sy+12,14,D.muted,nil,NVG_ALIGN_RIGHT) end
        if cap then D.Meter(vg,x+30,sy+35,w-30,3,valueForBar,cap);sy=sy+44 else sy=sy+(unit and 35 or 34) end
    end
    Row('shield','耐久',D.Number(a.hp));Row('gauge','参考极速',st.topSpeed>0 and tostring(math.floor(st.topSpeed+.5)) or '—',' km/h')
    Row('weight','质量',D.Number(st.mass),' / '..D.Number(tier.mass)..' kg',st.mass,tier.mass);Row('cube','零件',D.Number(st.parts),' / '..D.Number(tier.parts),st.parts,tier.parts)
    local function Metres(n) return string.format('%.1f',n*Config.CELL):gsub('%.0$','') end
    Row('ruler','尺寸',Metres(st.dims.L)..'×'..Metres(st.dims.W)..'×'..Metres(st.dims.H),' 米');sy=sy+16
    for _,group in ipairs(a.groups) do
        Section(vg,x,sy,w,group.title,group.icon,group.count);sy=sy+31
        for i,item in ipairs(group.items) do
            local tx=x+((i-1)%6)*64;local ty=sy+math.floor((i-1)/6)*64
            if item.id then
                D.Panel(vg,tx,ty,58,58,9,{48,52,60,255},{28,31,36,255})
                self:RenderBackgroundImage(vg,Theme.Thumbnail(item.id),{x=tx+5,y=ty+5,w=48,h=48},'contain',nil)
                D.Text(vg,'×'..item.count,tx+54,ty+40,15,D.white,nil,NVG_ALIGN_RIGHT)
            else
                D.Path(vg,{tx,ty,tx+49,ty,tx+58,ty+9,tx+58,ty+58,tx,ty+58});nvgFillColor(vg,D.Color({255,255,255,8}));nvgFill(vg);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,D.Color({255,255,255,35}));nvgStroke(vg);D.Icon(vg,'plus',tx+20,ty+20,18,D.dim)
            end
        end
        sy=sy+math.max(1,math.ceil(#group.items/6))*64+10
    end
    local wc=a.warning and {255,194,26,255} or D.green
    local warning=a.warning or '车辆状态良好，可以出战';local layout=self.warningParagraph:Measure(vg,warning,w-41,D.white)
    D.Rect(vg,x,sy,3,layout.height+4,wc);D.Icon(vg,a.warning and 'warn' or 'check',x+15,sy+3,18,wc)
    self.warningParagraph:Draw(vg,warning,x+41,sy+2,w-41,D.white);nvgRestore(vg)
end
local M={}
function M.Fill(root,app)
    local bp=app.blueprint;local tier=Config.TIERS[app.tier];local diag=bp:Diagnose(tier);local st=diag.stats
    local data={stats=st,tier=tier,name=bp.name,hp=0,errors=0,groups={},slot=app.bays.active and string.format('车位 %02d%s',app.bays.active,app.bays.unsaved and ' · 有改动未保存' or '') or '草稿 · 还没放进车位'}
    local groups={weapon={},movement={},['function']={}};local lookup={};local keep={}
    for _,p in ipairs(bp:List()) do local def=Defs.PARTS[p.type];data.hp=data.hp+def.hp
        if groups[def.cat] then if not lookup[p.type] then lookup[p.type]={id=p.type,count=0};table.insert(groups[def.cat],lookup[p.type]) end;lookup[p.type].count=lookup[p.type].count+1 end
    end
    for _,d in ipairs(diag.list) do if d.level~='warn' then data.errors=data.errors+1;data.warning=data.warning or d.text end end
    data.warning=data.warning or diag.list[1] and diag.list[1].text;data.fits=st.fitTier and st.fitTier.id<=tier.id;data.ok=data.errors==0 and st.fitTier~=nil
    for _,spec in ipairs({{'weapon','武器','crosshair'},{'movement','移动部件','wheel'},{'function','功能部件','bolt'}}) do
        local items=groups[spec[1]];local total=0;for _,item in ipairs(items) do total=total+item.count;keep[Theme.Thumbnail(item.id)]=true end
        if total>0 or spec[1]~='function' then
            if spec[1]=='weapon' then for i=st.weapons+1,tier.weapons do items[#items+1]={} end end
            data.groups[#data.groups+1]={title=spec[2],icon=spec[3],items=items,count=spec[1]=='weapon' and (st.weapons..' / '..tier.weapons) or tostring(total)}
        end
    end
    local widget=Stats{width=380,height=820,pointerEvents='none'};widget.data=data;widget.warningParagraph=Paragraph.New(13,19.5);root:AddChild(widget);Theme.TrimThumbnails(keep)
end
return M
