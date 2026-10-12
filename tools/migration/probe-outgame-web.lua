local original=HandleUpdate
local UI=require 'urhox-libs/UI'
local frames=0;local previous='';local samples={}
local function Dump(app)
    local w,h=UI.GetViewportSize()
    local home=require('ui.GarageHud').GetState()
    local data={width=w,height=h,physical={graphics:GetWidth(),graphics:GetHeight()},dpr=graphics:GetDPR(),
        touch=require('controls.TouchMode').Enabled(),tab=home and home.tab or '',build=app.build~=nil,
        inventory=app.build and app.build.inventoryPanel~=nil or false,dialog=app.build and app.build.dialog~=nil or false,blueprint=app.blueprint.name,parts=app.blueprint:Size(),
        widgets={},quality=require('render.Quality').current.name}
    if home and home.workshop then
        local ws=home.workshop;data.workshop={}
        for _,key in ipairs({'selected','pending','view','group','sort','elapsed','hold','from','slides','imagesReady'}) do
            data.workshop[key]=ws[key]
        end
    end
    data.modeChoice=home and home.modeChoice;data.storyLevel=home and home.storyLevel
    data.salvage=home and home.salvage;data.lobby=app.lobby or 'arena';data.mapPreview=app.mapPreview~=nil
    data.previewMap=app.mapPreview and app.mapPreview.map.id;data.sceneVisible=renderer:GetViewport(0)~=nil
    if app.warehouse then data.warehouse={ready=app.warehouse.ready,cursor=app.warehouse.cursor,hallVisible=app.hangar.root.enabled} end
    local scale=app.graphicsSettings.sceneScale
    if scale then data.render={scale.graph.width,scale.graph.height} end
    local preview=home and home.workshopPreview
    if home and home.storyHolo then data.story={ready=home.storyHolo.ready,cursor=home.storyHolo.cursor,gate=home.storyHolo.gate.state,completed=home.storyHolo.gate.completed,total=home.storyHolo.gate.total,level=home.storyHolo.level,az=home.storyHolo.view.az,el=home.storyHolo.view.el,zoom=home.storyHolo.view.zoom} end
    if preview then data.preview={ready=preview.ready,cursor=preview.cursor,total=#preview.parts,complete=preview.ready and preview.cursor>#preview.parts} end
    local function Walk(widget,shown)
        shown=shown and widget:IsVisible()
        if not shown then return end
        local p=widget.props
        if p.onClick then
            local r=widget:GetAbsoluteLayoutForHitTest()
            if r.w>0 and r.h>0 then
                local motion=widget.cardMotion
                data.widgets[#data.widgets+1]={text=p.text or '',icon=p.icon or '',part=p.partType,kind=p.sourceKind or p.kind,styleWidth=p.width,styleHeight=p.height,selected=p.selected,disabled=p.disabled,rect={r.x,r.y,r.w,r.h},
                    card=motion and {hovered=widget.state.hovered or false,lift=motion.lift.value,image=motion.image.value,reveal=motion.reveal.value,opacity=motion.opacity.value}}
            end
        end
        for _,child in ipairs(widget.children or {}) do Walk(child,shown) end
    end
    local root=UI.GetRoot();if root then Walk(root,true) end
    local inventory=app.build and app.build.inventoryPanel
    if inventory then
        Walk(inventory.body,true)
        local close=inventory.closeButton
        local r=close:GetAbsoluteLayoutForHitTest()
        if r.w>0 and r.h>0 then data.widgets[#data.widgets+1]={text='关闭',rect={r.x,r.y,r.w,r.h}} end
    end
    if #samples>10 then
        table.sort(samples);local n=#samples
        data.frames={count=n,p50=samples[math.ceil(n*.5)]*1000,p95=samples[math.ceil(n*.95)]*1000,p99=samples[math.ceil(n*.99)]*1000}
    end
    print('OUTGAME_STATE '..cjson.encode(data));samples={}
end
function HandleUpdate(et,ed)
    original(et,ed)
    local app=VOX_HANGAR and VOX_HANGAR.app
    if not app then return end
    if input:GetKeyPress(KEY_F6) then app:PreviewMap(app.selectedMap or 'trial') end
    frames=frames+1
    local dt=ed:GetFloat('TimeStep');if dt>0 then samples[#samples+1]=dt end
    local home=require('ui.GarageHud').GetState()
    local preview=home and home.workshopPreview
    local key=tostring(home and home.tab)..':'..tostring(home and home.workshop and home.workshop.view)..':'..tostring(home and home.salvage and home.salvage.tab)..':'..tostring(app.mapPreview~=nil)..':'..tostring(preview and preview.ready and preview.cursor>#preview.parts)..':'..tostring(app.build~=nil)..':'..tostring(app.build and app.build.inventoryPanel~=nil)..':'..graphics:GetWidth()..':'..graphics:GetHeight()
    local story=home and home.storyHolo
    key=key..':'..tostring(story and story.ready)..':'..tostring(story and story.gate.state)
    key=key..':'..tostring(app.warehouse and app.warehouse.ready)..':'..tostring(app.build and app.build.dialog~=nil)
    key=key..':'..tostring(home and home.workshop and home.workshop.selected)..':'..tostring(home and home.workshop and home.workshop.pending)
    if frames%30==0 and key~=previous or input:GetKeyPress(KEY_F8) then previous=key;Dump(app) end
end
