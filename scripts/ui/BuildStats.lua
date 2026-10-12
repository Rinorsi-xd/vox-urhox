local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Button=require 'ui.BuildButton'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Config=require 'Config'
local Stats=Panel:Extend('VoxBuildStats')
local BAD={255,59,48,255};local WARN={255,194,26,255}
local WHITE={255,255,255,255}
local OK={61,220,132,255}
local function Level(w) return w and (w.level=='error' and BAD or w.level=='warn' and WARN or D.orange) or OK end
function Stats:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w=r.x,r.y,r.w
    local data=self.diag;if not data then return end;local st=data.stats;local tier=Config.TIERS[self.session.app.tier]
    local errors=0;local first=data.list[1]
    for _,v in ipairs(data.list) do if v.level~='warn' then errors=errors+1;if not first or first.level=='warn' then first=v end end end
    local fits=st.fitTier and st.fitTier.id<=tier.id;local ok=errors==0 and st.fitTier
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,46/48,52/54)
    D.Path(vg,{24,2,45,14,45,40,24,52,3,40,3,14});nvgFillColor(vg,D.Color({29,32,37,255}));nvgFill(vg)
    nvgStrokeWidth(vg,2.5);nvgStrokeColor(vg,D.Color(fits and D.orange or BAD));nvgStroke(vg)
    D.Path(vg,{24,8,40,17.5,40,36.5,24,46,8,36.5,8,17.5});nvgStrokeWidth(vg,1.5);nvgStrokeColor(vg,D.Color({255,255,255,36}));nvgStroke(vg)
    D.Text(vg,'T'..tier.id,24,19,19,nil,nil,NVG_ALIGN_CENTER);nvgRestore(vg)
    D.Text(vg,tier.name,x+58,y+4,22)
    local status=ok and '可出战' or errors>0 and errors..' 个问题' or '超出限制'
    D.Rect(vg,x+58,y+31,D.Width(vg,status,14)+16,20,ok and OK or BAD);D.Text(vg,status,x+66,y+32,14,ok and {8,19,12,255} or D.white)
    local cy=y+111
    local function Bar(icon,label,value,max,unit,major)
        D.Icon(vg,icon,x,cy+(major and 4 or 1),major and 20 or 17,major and D.orange or D.muted)
        D.Text(vg,label,x+(major and 27 or 24),cy+(major and 3 or 1),major and 17 or 13,major and D.white or D.muted,major and nil or 'vox-body')
        D.Text(vg,D.Number(value)..' / '..D.Number(max)..(unit or ''),x+w,cy-2,major and 26 or 18,value>max and BAD or D.white,'vox-tabular',NVG_ALIGN_RIGHT)
        D.Meter(vg,x,cy+(major and 32 or 24),w,major and 10 or 3,value,max,major)
        cy=cy+(major and 54 or 39)
    end
    Bar('chip','预算',st.budget,tier.budget,nil,true);Bar('weight','质量',st.mass,tier.mass,' kg');Bar('cube','零件',st.parts,tier.parts);Bar('crosshair','武器',st.weapons,tier.weapons)
    if #st.fire>0 then
        cy=cy-6;local fx=0
        for _,f in ipairs(st.fire) do
            local text=f.name..' 火力 '..math.floor(f.output*100+.5)..'%'..(f.share>1.001 and ' +备用' or '')
            local fw=D.Width(vg,text,12,'vox-body')+14
            if fx>0 and fx+fw>w then cy=cy+27;fx=0 end
            D.Rect(vg,x+fx,cy,fw,23,{255,255,255,15});D.Text(vg,text,x+fx+7,cy+3,12,D.muted,'vox-body')
            D.Rect(vg,x+fx,cy+21,fw*f.output,2,f.output>=1 and D.green or D.dim);fx=fx+fw+4
        end
        cy=cy+35
    end
    if st.decor>0 then Bar('decor','装饰',st.decor,tier.decor) end
    self.warningHits={}
    self.warningParagraphs=self.warningParagraphs or {}
    local warningIndex=0
    local function Warning(item,text,detail)
        warningIndex=warningIndex+1
        local paragraph=self.warningParagraphs[warningIndex] or Paragraph.New(12.5,18.75)
        self.warningParagraphs[warningIndex]=paragraph
        local hovered=detail and item and self.hoverWarning==item
        local color=detail and not item and D.green or hovered and WHITE or D.white
        local layout=paragraph:Measure(vg,text,w-13,color);local h=layout.height+4
        if hovered then D.Rect(vg,x,cy,w,h,{255,255,255,13}) end
        D.Rect(vg,x,cy,3,h,Level(item));paragraph:Draw(vg,text,x+13,cy+2,w-13,color)
        self.warningHits[#self.warningHits+1]={y=cy-y,h=h,item=item,detail=detail};cy=cy+h
    end
    Warning(first,first and first.text or '车辆状态良好，可以进入对战')
    cy=cy+12;self.more:SetStyle({top=cy-y});cy=cy+24
    if self.expanded then
        cy=cy+10;D.Rect(vg,x,cy,w,1,{255,255,255,26});D.Text(vg,'尺寸 长×宽×高',x,cy+9,12,D.muted,'vox-body')
        local d=st.dims;local cells=d.L..'×'..d.W..'×'..d.H
        local function Metres(v) return (string.format('%.1f',v*Config.CELL):gsub('%.0$','')) end
        D.Text(vg,cells,x,cy+27,18);D.Text(vg,'格 · '..Metres(d.L)..'×'..Metres(d.W)..'×'..Metres(d.H)..' 米',x+D.Width(vg,cells,18)+6,cy+31,12,D.muted,'vox-body');cy=cy+64
        for i,row in ipairs({{'总质量',D.Number(st.mass)..' kg'},{'总承载',D.Number(st.load)..' kg'},{'负载率',st.load>0 and string.format('%.2f',st.L) or '—',st.L>2 and BAD or st.L>1.2 and WARN or D.green},{'参考极速',st.topSpeed>0 and D.Number(st.topSpeed)..' km/h' or '—'}}) do
            local tx=x+((i-1)%2)*142;local ty=cy+math.floor((i-1)/2)*48.890625
            D.Text(vg,row[1],tx,ty,12,D.muted,'vox-body');D.Text(vg,row[2],tx,ty+19,19,row[3] or D.white)
        end
        cy=cy+99.78125;D.Text(vg,'检查结果',x,cy,15,D.muted);cy=cy+24
        if #data.list==0 then Warning(nil,'没有发现问题',true) end
        for i,item in ipairs(data.list) do if i>1 then cy=cy+4 end;Warning(item,item.text,true) end
    end
    for i=#self.warningParagraphs,warningIndex+1,-1 do self.warningParagraphs[i]=nil end
    local height=cy-y
    if self.props.height~=height then self:SetHeight(height) end
    local scrollHeight=math.max(1,math.min(height,UI.GetHeight()-210))
    if self.scroll.props.height~=scrollHeight then self.scroll:SetHeight(scrollHeight) end
end
function Stats:WarningAt(e,hoverOnly)
    local r=self:GetAbsoluteLayoutForHitTest();local y=e.y-r.y
    for _,hit in ipairs(self.warningHits or {}) do
        if y>=hit.y and y<hit.y+hit.h and (not hoverOnly or hit.detail) and hit.item and #hit.item.ids>0 then return hit.item end
    end
end
local M={}
function M.Create(session)
    local pane=Stats{width=272,height=409};pane.session=session
    pane.props.onClick=function(_,e) local item=pane:WarningAt(e);if item then session.inspection:Focus(item,true) end end
    pane.props.onPointerMove=function(e) local item=pane:WarningAt(e,true);if item~=pane.hoverWarning then pane.hoverWarning=item;session.inspection:Focus(item,false) end end
    pane.props.onPointerLeave=function() if pane.hoverWarning then pane.hoverWarning=nil;session.inspection:Focus(nil,false) end end
    pane.tiers={}
    for i=1,5 do
        local b=Button{kind='tier',text='T'..i,position='absolute',left=(i-1)*55,top=67,width=52,height=28,onClick=function()
            session.controls:Cancel();session.app.tier=i;session.app.hangar:SetTier(i);session:Refresh()
        end};pane:AddChild(b);pane.tiers[i]=b
    end
    pane.more=Button{kind='more',text='详细数据',position='absolute',left=0,top=385,width=120,height=24,onClick=function()
        pane.expanded=not pane.expanded;pane.more.props.selected=pane.expanded;pane.more.props.text=pane.expanded and '收起详细数据' or '详细数据'
        if not pane.expanded and pane.hoverWarning then pane.hoverWarning=nil;session.inspection:Focus(nil,false) end
    end};pane:AddChild(pane.more)
    local scroll=UI.ScrollView{position='absolute',left=18,top=74,width=272,height=math.min(409,UI.GetHeight()-210),showScrollbar=false,children={pane}}
    pane.scroll=scroll
    return {root=scroll,pane=pane,Refresh=function()
        local diag=session.inspection:Get()
        if pane.diag~=diag then pane.hoverWarning=nil end
        pane.diag=diag;local fit=pane.diag.stats.fitTier
        for i,b in ipairs(pane.tiers) do b.props.selected=i==session.app.tier;b.props.unfit=not fit or i<fit.id end
    end}
end
return M
