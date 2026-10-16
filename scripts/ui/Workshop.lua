-- Port of frozen shared/ui/workshop.js and its final workshop.css rules.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Button=require 'ui.WorkshopButton'
local Data=require('core.ResourceData').Read('UI/Workshop.json')
local Paragraph=require 'ui.SourceParagraph'
local Carousel=require 'ui.WorkshopCarousel'
local Entrance=require 'ui.WorkshopEntrance'
local Shop=require 'ui.WorkshopShop'
local ShopPaint=require 'ui.WorkshopShopPaint'
local Page=UI.Panel:Extend('VoxWorkshopPage')
local Card=require 'ui.WorkshopCard'
local Dot=UI.Panel:Extend('VoxWorkshopDot')
local More=UI.Panel:Extend('VoxWorkshopMore')
local M={}
local featureDescriptionColor={219,238,255,191}
local featured=Carousel.ids
local groups={{'all','全部'},{'wheel','轮式'},{'track','履带'},{'mech','机甲'},{'plane','飞机'},{'pirate','海盗'},{'blank','底盘'}}
local function Find(id) for _,p in ipairs(Data.prefabs) do if p.id==id then return p end end end
local function IsFeatured(id) for _,candidate in ipairs(featured) do if candidate==id then return true end end;return false end
local function FeaturedSelection(ws)
    for _,id in ipairs(featured) do if id==ws.featureSelected then return id end end
    for _,id in ipairs(featured) do if id==ws.selected then return id end end
    return featured[1]
end
local function Clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function Fade(vg,x,y,w,h,a,b,horizontal) nvgBeginPath(vg);nvgRect(vg,x,y,w,h);D.Gradient(vg,x,y,w,h,a,b,horizontal) end
function Dot:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.item;local selected=self.owner.workshop.selected==p.id
    local image=selected and 'UI/Prefabs/'..p.id..'.jpg' or 'UI/Prefabs/Filtered/dot-'..p.id..'.jpg'
    Paint.Image(vg,image,{x=r.x,y=r.y,w=r.w,h=66},1,.62)
    D.Text(vg,p.name,r.x,r.y+72,13,selected and D.white or {219,238,255,140})
    D.Rect(vg,r.x,r.y+r.h-3,r.w,3,{255,255,255,38})
    if selected then
        local length=r.w*math.min(1,(self.owner.workshop.elapsed or 0)/7)
        Paint.Glow(vg,r.x,r.y+r.h-3,length,3,8,D.orange,.8);D.Rect(vg,r.x,r.y+r.h-3,length,3,D.orange)
    end
end
function More:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    D.Path(vg,{r.x,r.y,r.x+r.w-22,r.y,r.x+r.w,r.y+22,r.x+r.w,r.y+r.h,r.x+22,r.y+r.h,r.x,r.y+r.h-22})
    D.Gradient(vg,r.x,r.y,r.w,r.h,{40,121,235,140},{18,38,59,230})
    nvgSave(vg);nvgIntersectScissor(vg,r.x,r.y,r.w,r.h)
    for x=-r.h,r.w,24 do D.Path(vg,{r.x+x,r.y+r.h,r.x+x+12,r.y+r.h,r.x+x+12+r.h,r.y,r.x+x+r.h,r.y});nvgFillColor(vg,nvgRGBA(255,255,255,13));nvgFill(vg) end
    nvgRestore(vg)
    local y=r.y+(r.h-86)/2;D.Text(vg,'+'..(#Data.prefabs-5),r.x+22,y,40,D.orange,'vox-tabular',nil,nil,nil,nil,Paint.textShadows.more)
    D.Text(vg,'查看全部预制车',r.x+22,y+44,19,nil,nil,nil,2);D.Text(vg,'按类型筛选 · 按档位排序',r.x+22,y+71,12,{219,238,255,153},'vox-body')
    nvgSave(vg);nvgTranslate(vg,r.x+r.w-33,r.y+r.h-31);nvgRotate(vg,-math.pi/2);D.Icon(vg,'chev',-13,-13,26,D.orange);nvgRestore(vg)
end
function Page:FeatureLayout(descHeight)
    self.descHeight=descHeight
    local groupHeight=58+self.titleSize*1.02+8+18+16+descHeight+22+64
    self.capY=118+(self.heroHeight-150-118-groupHeight)*.5
    self.descY=self.capY+58+self.titleSize*1.02+8+18+16
    local actionY=self.descY+descHeight+22
    for _,b in ipairs(self.actionButtons or {}) do b:SetStyle({top=actionY}) end
    return actionY
end
function Page:Update(dt)
    if self.shop then
        local wallet=self.owner.app.salvageLobby.data.credits
        if self.shopWallet~=wallet then
            self.shopWallet=wallet
            local shop=Shop.State(self.owner,self.item.id)
            for _,button in ipairs(self.purchaseButtons) do button.props.shop=shop end
            for _,card in ipairs(self.shopCards) do card.shop=Shop.State(self.owner,card.item.id) end
        end
    end
    if self.view~='feature' then
        local entry=self.owner.workshop.entrance
        local elapsed=entry and entry.elapsed or .9
        if self.entranceState~=entry or self.entranceElapsed~=elapsed then
            self.entranceState=entry;self.entranceElapsed=elapsed
            for _,item in ipairs(self.entranceWidgets or {}) do
                local alpha,dx,dy=Entrance.Group(self.owner.workshop,item.index)
                item.widget:SetStyle({opacity=alpha,translateX=dx,translateY=dy})
            end
        end
        return
    end
    local caption=self.owner.workshop.caption
    local elapsed=caption and caption.elapsed or .46
    if self.actionButtons and (self.captionState~=caption or self.captionElapsed~=elapsed) then
        self.captionState=caption;self.captionElapsed=elapsed
        local alpha,offset=Carousel.Caption(self.owner.workshop,6)
        for _,button in ipairs(self.actionButtons) do button:SetStyle({opacity=alpha,translateX=offset}) end
    end
    local shelf=self.owner.workshop.shelf
    local shelfElapsed=shelf and shelf.elapsed or .62
    if self.shelfWidgets and (self.shelfState~=shelf or self.shelfElapsed~=shelfElapsed) then
        self.shelfState=shelf;self.shelfElapsed=shelfElapsed
        for i,widget in ipairs(self.shelfWidgets) do
            local alpha,offset=Carousel.Shelf(self.owner.workshop,i)
            widget:SetStyle({opacity=alpha,translateY=offset})
        end
    end
end
local function CaptionBegin(vg,ws,index)
    local alpha,offset=Carousel.Caption(ws,index)
    nvgSave(vg);nvgGlobalAlpha(vg,alpha);nvgTranslate(vg,offset,0)
end
local function EntranceBegin(vg,ws,index)
    local alpha,dx,dy=Entrance.Group(ws,index)
    nvgSave(vg);nvgGlobalAlpha(vg,alpha);nvgTranslate(vg,dx,dy)
end
local function RetirePage(s)
    -- H5 switches the old .wsv off synchronously, before the next frame rebuild.
    if s.workshopPage then s.workshopPage:SetVisible(false);s.workshopPage=nil end
end
function Page:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.owner;local ws=s.workshop;local p=self.item
    local x,y,w,h=r.x,r.y,r.w,r.h;local pad=self.pad
    if self.view=='feature' then
        local measured=math.min(73.5,self.description:Measure(vg,p.desc,460,featureDescriptionColor).height)
        if measured~=self.descHeight then self:FeatureLayout(measured) end
        D.Rect(vg,x,y,w,h,{5,11,21,255})
        nvgSave(vg);nvgIntersectScissor(vg,x,y,w,self.heroHeight)
        Carousel.Render(vg,ws,x,y,w,self.heroHeight)
        Fade(vg,x,y,w*.24,self.heroHeight,{5,11,21,245},{5,11,21,209},true)
        Fade(vg,x+w*.24,y,w*.26,self.heroHeight,{5,11,21,209},{5,11,21,64},true)
        Fade(vg,x+w*.5,y,w*.16,self.heroHeight,{5,11,21,64},{5,11,21,0},true)
        Fade(vg,x,y+self.heroHeight*.6,w,self.heroHeight*.4,{5,11,21,0},{5,11,21,255})
        Fade(vg,x,y,w,self.heroHeight*.22,{5,11,21,204},{5,11,21,0})
        for yy=0,self.heroHeight,4 do D.Rect(vg,x,y+yy,w,1,{122,216,255,6}) end
        nvgRestore(vg)
        local cy=y+self.capY
        CaptionBegin(vg,ws,1)
        local tierColor=Paint.colors[(Data.stats[p.id] or {}).tier or 1]
        nvgSave(vg);nvgTranslate(vg,x+pad+8,cy+9);nvgRotate(vg,math.pi/4);Paint.Glow(vg,-6,-6,12,12,14,tierColor,.9);nvgRestore(vg)
        D.Path(vg,{x+pad,cy+9,x+pad+8,cy+1,x+pad+16,cy+9,x+pad+8,cy+17});nvgFillColor(vg,D.Color(Paint.colors[(Data.stats[p.id] or {}).tier or 1]));nvgFill(vg)
        D.Text(vg,'本周推荐',x+pad+22,cy,15,{255,255,255,255},nil,nil,4);D.Text(vg,'FEATURED',x+pad+108,cy+3,11,{219,238,255,102},nil,nil,5)
        nvgRestore(vg)
        CaptionBegin(vg,ws,2);Paint.Tier(vg,p.id,x+pad,cy+28);nvgRestore(vg)
        CaptionBegin(vg,ws,3);D.Text(vg,p.name,x+pad,cy+58,self.titleSize,nil,nil,nil,3,false,self.titleSize*1.02,Paint.NameShadows((Data.stats[p.id] or {}).tier or 1,false));nvgRestore(vg)
        CaptionBegin(vg,ws,4);D.Text(vg,p.en,x+pad,cy+58+self.titleSize*1.02+8,15,{219,238,255,102},nil,nil,10);nvgRestore(vg)
        CaptionBegin(vg,ws,5)
        nvgSave(vg);nvgIntersectScissor(vg,x+pad,y+self.descY,460,self.descHeight)
        self.description:Draw(vg,p.desc,x+pad,y+self.descY,460,featureDescriptionColor);nvgRestore(vg)
        nvgRestore(vg)
        D.Text(vg,'官方预制车',x+pad,y+self.shelfY+3,24,nil,nil,nil,3)
        D.Text(vg,'OFFICIAL PREFABS',x+pad+146,y+self.shelfY+14,11,D.orange,nil,nil,4)
        D.Text(vg,'共 '..#Data.prefabs..' 辆 · '..(self.shop and '整车价格 = 零件标价合计，买下直接开走' or '点开可在机库里 3D 预览'),x+pad+320,y+self.shelfY+12,13,{219,238,255,115},'vox-body')
        if self.shop then ShopPaint.Wallet(vg,s.app.salvageLobby.data.credits,x+w-pad-181,y+self.shelfY+12) end
    elseif self.view=='browse' then
        D.Rect(vg,x,y,w,h,{5,11,20,240})
        nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h)
        for offset=-h,w,14*math.sqrt(2) do
            D.Path(vg,{x+offset,y+h,x+offset+2*math.sqrt(2),y+h,x+offset+h+2*math.sqrt(2),y,x+offset+h,y});nvgFillColor(vg,nvgRGBA(122,216,255,6));nvgFill(vg)
        end
        nvgRestore(vg)
        Paint.Radial(vg,{x,y,x+w,y,x+w,y+h,x,y+h},x+w*.7,y+h*.3,w*.9,h*.7,{30,70,120,89},.7)
        EntranceBegin(vg,ws,2)
        D.Text(vg,'创意工坊',x+pad+62,y+84,34,nil,nil,nil,3,false,35.7,Paint.textShadows.title);D.Text(vg,self.shop and 'WORKSHOP · 用信用点买整车' or 'WORKSHOP · 官方预制车',x+pad+62,y+123,11,D.orange,nil,nil,4)
        nvgRestore(vg)
        EntranceBegin(vg,ws,2);D.Rect(vg,x+pad+62+self.browseTitleWidth+22,y+84,1,49.6875,{122,216,255,64});nvgRestore(vg)
    else
        Fade(vg,x,y,w*.22,h,{4,9,18,235},{4,9,18,199},true)
        Fade(vg,x+w*.22,y,w*.16,h,{4,9,18,199},{4,9,18,38},true)
        Fade(vg,x+w*.38,y,w*.12,h,{4,9,18,38},{4,9,18,0},true)
        Fade(vg,x,y+h*.8,w,h*.2,{4,9,18,0},{4,9,18,128})
        local a=Paint.Meta(p.id);local width=self.textWidth;local c=Paint.colors[a.stats.tier or 1]
        EntranceBegin(vg,ws,1)
        local crumbX=x+pad+98
        D.Text(vg,'创意工坊',crumbX,y+106,13,{219,238,255,128},'vox-body',nil,1)
        local arrowX=crumbX+D.Width(vg,'创意工坊 ',13,'vox-body',1)+6
        D.Text(vg,'›',arrowX,y+106,13,{219,238,255,128},'vox-body',nil,1)
        D.Text(vg,p.name,arrowX+D.Width(vg,'› ',13,'vox-body',1)+6,y+106,13,{255,255,255,255},'vox-body',nil,1)
        nvgRestore(vg)
        EntranceBegin(vg,ws,2)
        Paint.Tier(vg,p.id,x+pad,y+160)
        D.Text(vg,p.name,x+pad,y+182,self.titleSize,nil,nil,nil,2,false,self.titleSize*1.05,Paint.NameShadows(a.stats.tier or 1,true));D.Text(vg,p.en,x+pad,y+186+self.titleSize*1.05,14,{219,238,255,102},nil,nil,8)
        nvgRestore(vg)
        local barsY=186+self.titleSize*1.05+38
        EntranceBegin(vg,ws,3)
        for i,b in ipairs(Paint.Bars(p.id)) do
            local yy=y+barsY+(i-1)*47;D.Text(vg,b[1],x+pad,yy,15,nil,nil,nil,2);D.Text(vg,b[2],x+pad+42,yy+5,10,{219,238,255,89},nil,nil,3)
            local ratio=tonumber(string.format('%.3f',b[3]))
            D.Text(vg,b[4],x+pad+width,yy,16,nil,'vox-tabular',NVG_ALIGN_RIGHT);Paint.Segments(vg,x+pad,yy+25,width,ratio*Entrance.Fill(ws),c)
        end
        nvgRestore(vg)
        EntranceBegin(vg,ws,4)
        local factsY=barsY+144;D.Rect(vg,x+pad,y+factsY,width,1,{122,216,255,38})
        local b=a.blueprint.bb;local cell=require('Config').CELL
        local dims=string.format('%.1f × %.1f × %.1f m',(b.maxX-b.minX+1)*cell,(b.maxY-b.minY+1)*cell,(b.maxZ-b.minZ+1)*cell)
        local facts={{'零件',D.Number(a.stats.parts or 0)},{'质量',string.format('%.1f t',(a.stats.mass or 0)/1000)},{'尺寸',dims}}
        if self.shop then local price=Shop.Price(p.id);facts[#facts+1]={'整车价格',price>0 and D.Number(price) or '免费'} end
        local factX=x+pad
        local minWidths,total={},0
        for i,f in ipairs(facts) do
            local content=math.max(D.Width(vg,f[1],12,'vox-body'),D.Width(vg,f[2],18,'vox-tabular'))
            if f[1]=='整车价格' then content=math.max(content,ShopPaint.CostWidth(vg,Shop.Price(p.id),18)) end
            minWidths[i]=content;total=total+content+(i==1 and 14 or 29)
        end
        for i,f in ipairs(facts) do
            local contentWidth=(width-72)/3
            local fx=self.shop and factX or x+pad+(i-1)*(contentWidth+29)-(i>1 and 15 or 0)
            if i>1 then D.Rect(vg,fx,y+factsY+10,1,41,{122,216,255,38});fx=fx+14 end
            D.Text(vg,f[1],fx,y+factsY+11,12,{219,238,255,128},'vox-body')
            if f[1]=='整车价格' then ShopPaint.Cost(vg,Shop.Price(p.id),fx,y+factsY+29,18,D.white)
            else D.Text(vg,f[2],fx,y+factsY+29,18,nil,'vox-tabular') end
            factX=factX+minWidths[i]+(i==1 and 14 or 29)+math.max(0,(width-total)/#facts)
        end
        local loadY=factsY+75;D.Rect(vg,x+pad,y+factsY+61,width,1,{122,216,255,38})
        nvgRestore(vg)
        EntranceBegin(vg,ws,5)
        D.Text(vg,'装备构成',x+pad,y+loadY,13,{219,238,255,179},nil,nil,2);D.Text(vg,'LOADOUT',x+pad+70,y+loadY+3,10,{219,238,255,89},nil,nil,3)
        for i=1,math.min(7,#a.items) do
            local it=a.items[i];local px=x+pad+(i-1)*62;local py=y+loadY+24
            D.Panel(vg,px,py,56,56,0,{30,60,95,179},{10,22,38,217})
            local category=require('parts.Defs').PARTS[it.id].cat
            local edge=category=='weapon' and {255,138,76,255} or category=='function' and {95,211,138,255} or category=='shield' and {255,180,60,255} or D.orange
            D.Rect(vg,px,py+53,56,3,edge)
            D.Rect(vg,px,py,1,56,{122,216,255,56});D.Rect(vg,px+55,py,1,56,{122,216,255,56})
            self:RenderBackgroundImage(vg,require('ui.VoxTheme').Thumbnail(it.id),{x=px+6,y=py+6,w=44,h=44},'contain',nil)
            D.Text(vg,'×'..it.count,px+53,py+40,12,nil,'vox-tabular',NVG_ALIGN_RIGHT,nil,nil,nil,Paint.textShadows.count)
        end
        if #a.items==0 then D.Text(vg,'只有核心驾驶舱',x+pad,y+loadY+24,13,{219,238,255,128},'vox-body') end
        nvgRestore(vg)
        local descY=y+loadY+(#a.items>0 and 94 or 55)
        EntranceBegin(vg,ws,6)
        nvgSave(vg);nvgIntersectScissor(vg,x+pad,descY,width,68.25)
        self.description:Draw(vg,p.desc,x+pad,descY,width,{219,238,255,184});nvgRestore(vg)
        nvgRestore(vg)
        local pagerX=x+pad+width+98
        D.Text(vg,string.format('%02d',self.index),pagerX,y+h-51,30,D.white,'vox-tabular')
        D.Text(vg,string.format('/  %02d',#Data.prefabs),pagerX+38,y+h-40,15,{219,238,255,128},'vox-tabular',nil,nil,nil,nil,Paint.textShadows.pager)
        local cx=x+w-pad-316
        D.Rect(vg,cx,y+h-58,316,40,{8,15,28,153})
        D.Line(vg,cx,y+h-58,cx+316,y+h-58,{83,123,156,128})
        D.Line(vg,cx,y+h-18,cx+316,y+h-18,{83,123,156,128})
        D.Line(vg,cx,y+h-58,cx,y+h-18,{83,123,156,128})
        D.Line(vg,cx+316,y+h-58,cx+316,y+h-18,{83,123,156,128})
        D.Text(vg,'拖拽旋转 · 滚轮缩放',cx+188,y+h-44,12,{219,238,255,128},'vox-body')
    end
    Fade(vg,x,y,w,120,{4,9,18,217},{4,9,18,0})
end
function M.Leave(s)
    RetirePage(s)
    if s.workshop and s.workshop.view=='feature' then s.workshop.featureSelected=s.workshop.selected end
    Paint.TrimImages({})
    Carousel.Leave(s.workshop)
    if s.workshopPreview then s.workshopPreview:Dispose();s.workshopPreview=nil end
    if s.workshop and s.workshop.view=='detail' then s.workshop.view='browse' end
    -- Original leave() changes detail to browse quietly; returning to this tab
    -- does not replay browse entry. Explicit view()/filter clicks start it below.
    if s.workshop then
        -- H5 keeps heroI independent of detailId, including across tab changes.
        s.workshop.selected=FeaturedSelection(s.workshop)
        s.workshop.entrance=s.workshop.view~='feature' and {kind=s.workshop.view,elapsed=.9} or nil
    end
end
function M.Key(s)
    local ws=s.workshop
    if not ws or not s.WorkshopChange then return false end
    local back=input:GetKeyPress(KEY_ESCAPE) or input:GetKeyPress(KEY_BACKSPACE)
    local enter=input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_KP_ENTER)
    local step=input:GetKeyPress(KEY_RIGHT) and 1 or input:GetKeyPress(KEY_LEFT) and -1 or 0
    if ws.view=='detail' then
        if back then s.WorkshopChange(ws.from or 'browse')
        elseif step~=0 then
            local index=1;for i,p in ipairs(Data.prefabs) do if p.id==ws.selected then index=i end end
            s.WorkshopChange('detail',Data.prefabs[(index-1+step)%#Data.prefabs+1].id)
        elseif enter then s.CreateVehicle(ws.selected)
        else return false end
    elseif ws.view=='browse' then
        if back then s.WorkshopChange('feature') else return false end
    elseif enter then s.WorkshopChange('detail',ws.selected,'feature')
    elseif step~=0 then
        local index=1;for i,id in ipairs(featured) do if id==Carousel.Target(ws) then index=i end end
        Carousel.Select(s,featured[(index-1+step)%#featured+1])
    else return false end
    return true
end
function M.Update(s,dt)
    local ws=s.workshop;if not ws then return end
    Entrance.Step(ws,dt)
    if ws.view~='feature' then return end
    Carousel.Step(s,dt)
    if not ws.hold and not ws.pending and Carousel.Ready(ws,ws.selected) then ws.elapsed=(ws.elapsed or 0)+dt end
    if ws.elapsed>=7 then
        local i=1;for n,id in ipairs(featured) do if id==ws.selected then i=n end end
        Carousel.Select(s,featured[i%#featured+1])
    end
end
function M.Create(s)
    s.workshop=s.workshop or {view='feature',selected='scorpion',group='all',sort='rec',elapsed=0}
    local ws=s.workshop;local w,h=s.width,s.height;local pad=Clamp(w*.03,24,64)
    if ws.view=='feature' then
        if not IsFeatured(ws.selected) then ws.selected=FeaturedSelection(ws) end
        ws.featureSelected=ws.selected
    end
    local keep={}
    if ws.view=='feature' then
        Carousel.Mount(s)
        Carousel.Keep(ws,keep)
        for _,id in ipairs(featured) do keep['UI/Prefabs/Filtered/dot-'..id..'.jpg']=true end
        for i=1,5 do keep['UI/Prefabs/Filtered/card-'..Data.prefabs[i].id..'.jpg']=true end
    elseif ws.view=='browse' then
        for _,p in ipairs(Data.prefabs) do keep['UI/Prefabs/Filtered/card-'..p.id..'.jpg']=true end
    end
    Paint.TrimImages(keep)
    local page=Page{position='absolute',width=w,height=h,pointerEvents='box-none'}
    -- A key can change state after this frame's rebuild. Render the mounted tree's view.
    page.view=ws.view;page.item=Find(ws.selected)
    page.owner=s;page.pad=pad;page.textWidth=Clamp(w*.27,380,500);page.shop=Shop.Active(s)
    page.purchaseButtons={};page.shopCards={}
    page.titleSize=ws.view=='detail' and Clamp(w*.027,34,54) or Clamp(w*.039,44,76)
    page.description=Paragraph.New(ws.view=='detail' and 13 or 14,ws.view=='detail' and 22.75 or 24.5)
    page.description.maxLines=3
    local function Change(view,id,from)
        RetirePage(s)
        if ws.view=='feature' then ws.featureSelected=ws.selected end
        -- Featured artwork must never replace an already opened detail vehicle.
        if ws.view=='feature' and view~='feature' then Carousel.Leave(ws) end
        ws.view=view;ws.selected=view=='feature' and FeaturedSelection(ws) or id or ws.selected;ws.from=from or ws.from;s.revision=-1;ws.elapsed=0
        if view=='detail' then
            s.workshopPreview=s.workshopPreview or require('render.WorkshopPreview').New(s.app);s.workshopPreview:Show(ws.selected)
        else M.Leave(s);s.app:HomeView('workshop') end
        if view~='feature' then Entrance.Start(ws,view) end
    end
    s.WorkshopOpen=function(id) Change('detail',id,ws.view) end
    s.WorkshopChange=Change
    if ws.view~='feature' and not ws.entrance then Entrance.Start(ws,ws.view) end
    page.entranceWidgets={}
    local function Animate(widget,index)
        page.entranceWidgets[#page.entranceWidgets+1]={widget=widget,index=index}
        return widget
    end
    local function Add(text,icon,x,y,bw,bh,fn,kind,props)
        local options={text=text,icon=icon,sourceKind=kind,position='absolute',left=x,top=y,width=bw,height=bh,onClick=fn}
        for k,v in pairs(props or {}) do options[k]=v end
        local b=s.Track(Button(options));page:AddChild(b);return b
    end
    if ws.view=='feature' then
        local rowHeight=Clamp(h*.24,180,260);page.shelfY=h-22-rowHeight-12-44;page.heroHeight=page.shelfY-18
        local actionY=page:FeatureLayout(73.5)
        local shop=Shop.State(s,ws.selected)
        local label=Shop.Label(ws.selected,false,shop)
        local vg=UI.GetNVGContext();D.Begin(vg)
        local purchaseWidth=shop and math.max(162,50+D.Width(vg,label,16,nil,2)+28+ShopPaint.CostWidth(vg,shop.cost,18)+22) or 162
        page.actionButtons={
            Add('查看详情','eye',pad,actionY,192,64,function() Change('detail',ws.selected,'feature') end,'view'),
            Add(label,'plus',pad+202,actionY,purchaseWidth,64,function() s.CreateVehicle(ws.selected) end,'add',{disabled=s.usedCount==20,shop=shop}),
        }
        page.purchaseButtons={page.actionButtons[2]}
        page:Update(0)
        page:AddChild(UI.Panel{position='absolute',left=0,top=60,width=w,height=page.heroHeight-60,pointerEvents='box-none',onPointerEnter=function() ws.hold=true end,onPointerLeave=function() ws.hold=false end})
        for i,id in ipairs(featured) do
            local dot=s.Track(Dot{text=Find(id).name,position='absolute',left=pad+(i-1)*142,top=page.heroHeight-120,width=132,height=98,onClick=function() Carousel.Select(s,id) end})
            dot.owner=s;dot.item=Find(id);page:AddChild(dot)
        end
        page.shelfWidgets={}
        if not page.shop then
            page.shelfWidgets[#page.shelfWidgets+1]=Add('导入蓝图','download',w-pad-439.140625,page.shelfY+2,113,40,function() require('ui.GarageDialogs').Code(s,true) end,'ghost')
            page.shelfWidgets[#page.shelfWidgets+1]=Add('分享当前战车','share',w-pad-318.140625,page.shelfY+2,143,40,function() require('ui.GarageDialogs').Code(s,false) end,'ghost')
        end
        page.shelfWidgets[#page.shelfWidgets+1]=Add('查看全部',nil,w-pad-161.140625,page.shelfY,161.140625,44,function() Change('browse') end,'all',{count=#Data.prefabs})
        local unit=(w-pad*2-60)/5.85;local moreWidth=math.max(200,unit*.85);unit=(w-pad*2-60-moreWidth)/5
        for i=1,5 do
            local p=Data.prefabs[i];local card=s.Track(Card{text=p.name,position='absolute',left=pad+(i-1)*(unit+12),top=page.shelfY+56,width=unit,height=rowHeight,onClick=function() Change('detail',p.id,'feature') end})
            card.item=p;card.tier=Data.stats[p.id].tier or 1;card.mini=true;card.shop=Shop.State(s,p.id);page:AddChild(card)
            page.shopCards[#page.shopCards+1]=card
            page.shelfWidgets[#page.shelfWidgets+1]=card
        end
        local more=s.Track(More{text='查看全部预制车',position='absolute',left=pad+5*(unit+12),top=page.shelfY+56,width=moreWidth,height=rowHeight,onClick=function() Change('browse') end})
        page:AddChild(more);page.shelfWidgets[#page.shelfWidgets+1]=more
        page:Update(0)
    elseif ws.view=='detail' then
        if not s.workshopPreview then Change('detail',ws.selected,ws.from or 'browse') end
        Animate(Add('返回','back',pad,92,84,44,function() Change(ws.from or 'browse') end,'back'),1)
        local shop=Shop.State(s,ws.selected)
        local purchase=Animate(Add(Shop.Label(ws.selected,true,shop),'plus',pad,h-84,page.textWidth,70,function() s.CreateVehicle(ws.selected) end,'go',{disabled=s.usedCount==20,shop=shop}),7)
        page.purchaseButtons={purchase}
        local idx=1;for i,p in ipairs(Data.prefabs) do if p.id==ws.selected then idx=i end end;page.index=idx
        local footX=pad+page.textWidth+40
        Add('','chev',footX,h-60,44,44,function() Change('detail',Data.prefabs[(idx-2)%#Data.prefabs+1].id) end,'pager',{iconRotation=90})
        Add('','chev',footX+142,h-60,44,44,function() Change('detail',Data.prefabs[idx%#Data.prefabs+1].id) end,'pager',{iconRotation=-90})
        local auto=Add('自动旋转','play',w-pad-312,h-54,100,32,function() s.workshopPreview:SetAuto(not s.workshopPreview.auto);s.revision=-1 end,'control',{selected=s.workshopPreview.auto})
        Add('复位','swap',w-pad-208,h-54,72,32,function() s.workshopPreview:Reset();auto.props.selected=true end,'control')
    else
        Animate(Add('','back',pad,87,44,44,function() Change('feature') end,'back'),1)
        local vg=UI.GetNVGContext();D.Begin(vg)
        page.browseTitleWidth=math.max(D.Width(vg,'创意工坊',34,nil,3),D.Width(vg,page.shop and 'WORKSHOP · 用信用点买整车' or 'WORKSHOP · 官方预制车',11,nil,4))
        local cssWidth=graphics:GetWidth()/graphics:GetDPR()
        local tabSize=cssWidth<=1440 and 16 or 19
        local tabHeight=math.floor(tabSize+.5)+math.floor(tabSize*.2+.5)+22
        local tabTop=84+(49.6875-tabHeight)/2
        local x=pad+103+page.browseTitleWidth
        for i,g in ipairs(groups) do
            local count=0;for _,p in ipairs(Data.prefabs) do if g[1]=='all' or p.group==g[1] then count=count+1 end end
            local width=36+D.Width(vg,g[2],tabSize,nil,2)+D.Width(vg,count,11,'vox-display')
            local button=Add(g[2],nil,x,tabTop,width,tabHeight,function() ws.group=g[1];Entrance.Start(ws,'grid');s.revision=-1 end,'tab',{selected=ws.group==g[1],count=count,sourceFontSize=tabSize})
            ws.tabMotions=ws.tabMotions or {};button.tabMotion=ws.tabMotions[g[1]];button:Update(0);ws.tabMotions[g[1]]=button.tabMotion
            Animate(button,3);x=x+width+2
        end
        local sorts={{'rec','推荐',52},{'tier','档位',60},{'parts','零件数',74},{'speed','极速',59}}
        if page.shop then sorts[#sorts+1]={'price','价格',59} end
        local sx=w-pad-245-(page.shop and 59 or 0)
        for i,sort in ipairs(sorts) do
            Animate(Add(sort[2],nil,sx,95,sort[3],28,function() ws.sort=sort[1];Entrance.Start(ws,'grid');s.revision=-1 end,'sort',{selected=ws.sort==sort[1],separator=i>1}),4);sx=sx+sort[3]
        end
        local list={};for _,p in ipairs(Data.prefabs) do if ws.group=='all' or p.group==ws.group then list[#list+1]=p end end
        Shop.Sort(list,ws.sort,Data.stats,page.shop)
        local hero=#list>3;local slots=#list+(hero and 3 or 0)+(ws.group=='all' and 1 or 0)
        local rows=math.ceil(slots/4);local gridWidth=w-pad*2;local gridTop=84+49.6875+14;local available=h-gridTop-14
        -- CSS grid-auto-rows:minmax(0,1fr) can be smaller than a card's
        -- min-height. Keep the track spacing separate from the card height.
        local cw=(gridWidth-4-36)/4;local trackHeight=math.max(0,(available-4-(rows-1)*12)/math.max(1,rows))
        local ch=math.max(180,trackHeight)
        local contentHeight=math.max(available,4+(rows-1)*(trackHeight+12)+ch)
        local grid=UI.Panel{width=gridWidth,height=contentHeight,flexShrink=0};local cursor=0
        for i,p in ipairs(list) do
            local col,row,ww,hh
            if i==1 and hero then col,row,ww,hh=0,0,cw*2+12,math.max(180,trackHeight*2+12)
            else
                if hero and cursor==0 then cursor=2 end
                if hero and cursor==4 then cursor=6 end
                col,row,ww,hh=cursor%4,math.floor(cursor/4),cw,ch;cursor=cursor+1
            end
            local card=s.Track(Card{text=p.name,position='absolute',left=2+col*(cw+12),top=2+row*(trackHeight+12),width=ww,height=hh,onClick=function() Change('detail',p.id,'browse') end})
            card.item=p;card.tier=Data.stats[p.id].tier or 1;card.hero=i==1 and hero;card.shop=Shop.State(s,p.id);grid:AddChild(card)
            page.shopCards[#page.shopCards+1]=card
            card.heroTitleSize=cssWidth<=1440 and 34 or 46
            Animate(card,4+i)
        end
        if ws.group=='all' then
            local locked=UI.Panel{position='absolute',left=2+(cursor%4)*(cw+12),top=2+math.floor(cursor/4)*(trackHeight+12),width=cw,height=ch,pointerEvents='none'}
            function locked:Render(vg)
                D.Begin(vg);local r=self:GetAbsoluteLayout();local cx=r.x+r.w/2;local cy=r.y+r.h/2
                local points={r.x,r.y,r.x+r.w-22,r.y,r.x+r.w,r.y+22,r.x+r.w,r.y+r.h,r.x+22,r.y+r.h,r.x,r.y+r.h-22}
                D.Path(vg,points);nvgFillColor(vg,nvgRGBA(7,16,28,255));nvgFill(vg)
                nvgSave(vg);nvgIntersectScissor(vg,r.x,r.y,r.w,r.h)
                for offset=-r.h,r.w,20*math.sqrt(2) do
                    D.Path(vg,{r.x+offset,r.y+r.h,r.x+offset+10*math.sqrt(2),r.y+r.h,r.x+offset+r.h+10*math.sqrt(2),r.y,r.x+offset+r.h,r.y})
                    nvgFillColor(vg,nvgRGBA(122,216,255,13));nvgFill(vg)
                end
                nvgRestore(vg)
                D.Icon(vg,'lock',cx-15,cy-54,30,{219,238,255,128})
                D.Text(vg,'玩家作品',cx,cy-16,20,{255,255,255,191},nil,NVG_ALIGN_CENTER,3)
                D.Text(vg,'浏览、评分、下载玩家分享的战车',cx,cy+16,12,{219,238,255,128},'vox-body',NVG_ALIGN_CENTER)
                D.Text(vg,'联网服务开放后上线',cx,cy+35.2,12,{219,238,255,128},'vox-body',NVG_ALIGN_CENTER)
            end
            grid:AddChild(locked)
            Animate(locked,5+#list)
        end
        page:AddChild(UI.ScrollView{position='absolute',left=pad,top=gridTop,width=gridWidth,height=available,scrollX=false,scrollY=true,bounces=false,children={grid}})
    end
    page:Update(0)
    s.workshopPage=page
    return page
end
return M
