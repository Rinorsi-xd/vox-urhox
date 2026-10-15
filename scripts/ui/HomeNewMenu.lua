-- .bay-new-menu: original PC content, CSS boxes, transparent items and entry.
-- UI retains hit testing/ownership; entry opacity composites one bounded layer.
local Popover=require 'ui.SourcePopover'
local Button=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local source=require('core.ResourceData').Read('UI/SourceHomeMenu.json')
local Menu=Popover:Extend('VoxHomeNewMenu')
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Header=Panel:Extend('VoxHomeNewMenuHeader')
local Item=Button:Extend('VoxHomeNewMenuItem')
function Menu:DrawGlow(vg,kind,x,y,scaleY)
    if scaleY<=0 then return end
    self.glowImages=self.glowImages or {}
    local images=self.glowImages[vg]
    if not images then images={};self.glowImages[vg]=images end
    if not images[kind] then
        images[kind]=nvgCreateImage(vg,'UI/SourceMenuGlow-'..kind..'.png',0)
        assert(images[kind]>0,'Source menu shadow mask unavailable')
    end
    local width,height=kind=='top' and 104 or 43,(kind=='top' and 42 or 74)*scaleY
    nvgSave(vg)
    local r=self:GetAbsoluteLayout();nvgIntersectScissor(vg,r.x,r.y,r.w,r.h)
    nvgBeginPath(vg);nvgRect(vg,x-20,y-20*scaleY,width,height)
    nvgFillPaint(vg,nvgImagePatternTinted(vg,x-20,y-20*scaleY,width,height,0,images[kind],D.Color(D.orange)))
    nvgFill(vg);nvgRestore(vg)
end
function Menu:DrawBackground(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    D.Path(vg,{r.x,r.y,r.x+r.w-16,r.y,r.x+r.w,r.y+16,r.x+r.w,r.y+r.h,r.x,r.y+r.h})
    D.Gradient(vg,r.x,r.y,r.w,r.h,{14,30,50,247},{7,14,26,247})
    -- CSS clips a rectangular inset shadow; it never outlines the cut edge.
    local edge={122,216,255,71}
    D.Rect(vg,r.x,r.y,r.w-16,1,edge);D.Rect(vg,r.x,r.y,1,r.h,edge)
    D.Rect(vg,r.x+r.w-1,r.y+16,1,r.h-16,edge);D.Rect(vg,r.x,r.y+r.h-1,r.w,1,edge)
    self:DrawGlow(vg,'top',r.x,r.y,1)
    D.Rect(vg,r.x,r.y,64,2,D.orange)
end
function Menu:Destroy()
    for vg,images in pairs(self.glowImages or {}) do for _,image in pairs(images) do nvgDeleteImage(vg,image) end end
    self.glowImages=nil;Popover.Destroy(self)
end
function Header:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    D.Text(vg,'新战车',r.x+16,r.y+12,15,D.white,nil,nil,3)
    D.Text(vg,'NEW VEHICLE',r.x+80,r.y+17,10,{219,238,255,102},nil,nil,3)
    D.Rect(vg,r.x,r.y+r.h-1,r.w,1,{122,216,255,36})
end
local function Tween(value) return {value=value,start=value,target=value,elapsed=0,duration=0} end
local function Mix(a,b,t)
    local color={}
    for i=1,4 do color[i]=math.floor(a[i]+(b[i]-a[i])*t+.5) end
    return color
end
function Item:Update(dt)
    self.hoverMotion=self.hoverMotion or Tween(0)
    self.barMotion=self.barMotion or Tween(0)
    self.arrowMotion=self.arrowMotion or Tween(0)
    local target=self.state.hovered and 1 or 0
    Motion.Step(self.hoverMotion,target,.15,dt,'ease')
    Motion.Step(self.barMotion,target,.18,dt,'ease')
    Motion.Step(self.arrowMotion,target,.2,dt,'ease')
end
function Item:GetSourceLayout(vg)
    local r=self:GetAbsoluteLayout();local count=self.props.count
    local countWidth=count and (count==source.countText and source.countWidth or D.Width(vg,count,12,'vox-body')) or 14
    local arrow=self.arrowMotion and self.arrowMotion.value or 0
    -- With no <em>, the source grid places the arrow in column three.
    return {
        icon={r.x+12,r.y+8,34,34},glyph={r.x+20,r.y+16,18,18},
        title={r.x+58,r.y+15.5,r.w-112-countWidth,19},
        count=count and {r.x+r.w-42-countWidth,r.y+17.5,countWidth,15} or nil,
        arrow={r.x+r.w-(count and 30 or 56)-6*(1-arrow),r.y+18,14,14},
    }
end
function Item:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    local layout=self:GetSourceLayout(vg)
    local hover=self.hoverMotion and self.hoverMotion.value or 0
    local bar=self.barMotion and self.barMotion.value or 0
    local arrow=self.arrowMotion and self.arrowMotion.value or 0
    if p.separator then D.Rect(vg,r.x,r.y,r.w,1,{255,255,255,13}) end
    if hover>0 then
        nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h)
        D.Gradient(vg,r.x,r.y,r.w*.85,r.h,{122,216,255,math.floor(41*hover+.5)},{122,216,255,0},true)
    end
    if bar>0 then
        local y=r.y+8+(r.h-16)*(1-bar)/2
        p.sourceGlow(vg,'bar',r.x,y,bar)
        D.Rect(vg,r.x,y,3,(r.h-16)*bar,D.orange)
    end
    local color=Mix(D.orange,D.ink,hover)
    D.Rect(vg,r.x+12,r.y+8,34,34,Mix({40,121,235,56},D.orange,hover))
    nvgBeginPath(vg);nvgRect(vg,r.x+12.5,r.y+8.5,33,33);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(122,190,255,89));nvgStroke(vg)
    D.Icon(vg,p.icon,r.x+20,r.y+16,18,color)
    D.Text(vg,p.text,layout.title[1],layout.title[2],16,Mix({237,246,255,217},{255,255,255,255},hover),nil,nil,2,false,19)
    if p.count then D.Text(vg,p.count,layout.count[1],layout.count[2],12,{219,238,255,115},'vox-body',nil,nil,false,15) end
    if arrow>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,arrow);nvgTranslate(vg,layout.arrow[1]+7,layout.arrow[2]+7);nvgRotate(vg,-math.pi/2)
        D.Icon(vg,'chev',-7,-7,14,D.orange);nvgRestore(vg)
    end
end
local M={height=197}
function M.Create(s)
    local menu=Menu{position='absolute',padding=0,paddingBottom=6,gap=0,visible=false,sourceEntryDuration=.22,sourceEntryOffset=8}
    menu:AddChild(Header{width='100%',height=41,flexShrink=0,pointerEvents='none'})
    local rows={{'empty','创建新车','cube'},{'import','导入蓝图','download'},{'workshop','创意工坊','workshop'}}
    for i,p in ipairs(rows) do
        menu:AddChild(s.Track(Item{text=p[2],icon=p[3],separator=i>1,count=i==3 and (#require('core.ResourceData').Read('UI/Workshop.json').prefabs..' 辆预制车') or nil,width='100%',height=50,flexShrink=0,
            sourceGlow=function(vg,kind,x,y,scaleY) menu:DrawGlow(vg,kind,x,y,scaleY) end,
            onClick=function()
                if p[1]=='workshop' then s.SetNew(false);s.SetTab('workshop')
                elseif p[1]=='import' then s.SetNew(false);require('ui.GarageDialogs').Code(s,true)
                else s.CreateVehicle(p[1]) end
            end}))
    end
    return menu
end
return M
