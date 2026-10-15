local UI=require 'urhox-libs/UI'
local app,s,view,oldXray,edited,originalColor,source
local function Click(widget)
    local Event=require 'urhox-libs/UI/Core/PointerEvent'
    local r=widget:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale()
    for _,kind in ipairs({'PointerDown','PointerUp'}) do UI.HandlePointerEvent(Event.new(kind,{x=(r.x+r.w*.5)*scale,y=(r.y+r.h*.5)*scale,pointerId=52,pointerType='mouse',button=MOUSEB_LEFT})) end
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img) and img:SavePNG('docs/migration/evidence/'..name..'.png'),'rendered '..name);img:Dispose()
end
local function Rules()
    local f=assert(io.open('tools/migration/source-build-xray.json'));source=cjson.decode(f:read('*a'));f:close()
    local Defs=require 'parts.Defs';local Config=require 'Config'
    local sample=require('render.VehicleView').New(app.scene,'XrayTypeValidation');sample.root.enabled=false
    for i,def in ipairs(Defs.LIST) do
        local expected=source.parts[def.id]
        sample:SetXray(true)
        local p={id=i,type=def.id,pos={0,4,0},rot=require('core.Rotations').IDENTITY,color=0x35acf0}
        local vis=sample:AddPart(p)
        V.assert((vis.xrayOriginals~=nil)==expected.instanced,'source xray scope '..def.id)
        if expected.instanced then
            local slots={};for _,slot in ipairs(expected.slots) do slots[slot.slot]=slot end
            for model,original in pairs(vis.xrayOriginals) do
                V.assert(not model.castShadows,'structural shadow disabled '..def.id)
                for j,slot in ipairs(vis.materialSlots[model]) do
                    local e=assert(slots[slot]);local mat=model:GetMaterial(j-1);local tint=mat:GetShaderParameter('tint_color'):GetColor();local c=Config.HexLinear(e.color,e.opacity)
                    V.assert(math.abs(tint.r-c.r)<1e-6 and math.abs(tint.g-c.g)<1e-6 and math.abs(tint.b-c.b)<1e-6 and math.abs(tint.a-c.a)<1e-6,'source xray tint '..def.id..':'..slot)
                    V.assert(mat==(e.painted and sample.xray.paint or sample.xray.other),'shared xray material '..def.id..':'..slot)
                end
            end
            local originals=vis.xrayOriginals;sample:SetXray(false)
            for model,original in pairs(originals) do
                V.assert(model.castShadows==original.shadow,'restored shadow '..def.id)
                for j,mat in ipairs(original.materials) do V.assert(model:GetMaterial(j-1)==mat,'restored material '..def.id..':'..j) end
            end
        end
        sample:RemovePart(i)
    end
    sample:Dispose()
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app:EnterBuild();s=app.build;view=app.car
    Rules()
    app.hangar.Update=function() end;app.car.UpdateIdle=function() end
    s.controls:Cancel();s:Refresh()
end)
V.atFrame(70,function()
    Shot('build-solid')
    local saved=input
    input={GetKeyDown=function() return false end,GetKeyPress=function(_,key) return key==KEY_V end}
    local ok,err=pcall(s.Keys,s);input=saved;if not ok then error(err) end
    oldXray=view.xray;V.assert(oldXray~=nil,'V key toggles structural xray')
end)
V.atFrame(85,function()
    Shot('build-xray')
    V.assert(app.buildXray and view.xray~=nil,'build toggle enables current vehicle only')
    local before=oldXray.paint
    for _,p in ipairs(app.blueprint:List()) do if view.visuals[p.id].instanced then edited=p;break end end
    originalColor=edited.color;edited.color=0x23dd78;view:Repaint(edited)
    local vis=view.visuals[edited.id]
    V.assert(view.xray.paint==before and vis.models[1].instanceColor.g>.5,'painting updates shared-instance color under xray')
    local extra={id=99991,type='cube',pos={12,4,0},rot=require('core.Rotations').IDENTITY,color=0xff0000}
    local added=view:AddPart(extra);V.assert(added.xrayOriginals~=nil,'new structural part inherits enabled xray')
    view:RemovePart(extra.id);V.assert(not added.xrayOriginals and #added.models==0,'removal drops original material references')
    s:ToggleXray();V.assert(not view.xray and not oldXray.paint,'disable restores then releases both shared materials')
    edited.color=originalColor;view:Repaint(edited)
end)
V.atFrame(100,function()
    Shot('build-xray-restored')
    for _=1,12 do s:ToggleXray();local x=view.xray;s:ToggleXray();V.assert(not x.paint and not x.other,'toggle releases owned xray materials') end
end)
V.atFrame(110,function()
    Click(s.hud.xrayButton);V.assert(view.xray~=nil,'native tool button enables xray')
    oldXray=view.xray;app:Reload()
end)
V.atFrame(155,function()
    s=assert(app.build);view=app.car
    V.assert(view.xray and view.xray~=oldXray and not oldXray.paint,'F5 recreates xray resources with new scene owner')
    app:EnterTrial()
end)
V.atFrame(220,function()
    V.assert(app.trial~=nil and not app.trial.view.view.xray,'trial uses normal materials')
    app:Reload()
end)
V.atFrame(280,function()
    s=assert(app.build);V.assert(s.car.xray~=nil,'trial return restores build-only xray preference')
    oldXray=s.car.xray;app:ExitBuild()
    V.assert(not app.car.xray and not oldXray.paint and not app.buildXray,'home restores materials and releases build-only xray')
    V.finish()
end)
