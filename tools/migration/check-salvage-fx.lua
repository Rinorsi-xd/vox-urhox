local Fx=require 'render.SalvageFx'
local scene=Scene();scene:CreateComponent('Octree')
local fx
local camera
local showing=false
local shownFrames=0
local finished=false
V.atFrame(10,function()
    fx=Fx.New(scene,function() return .5 end)
    V.assert(#fx.beams==4 and #fx.cubes==16,'source four rare beams and sixteen flight cubes are fixed pools')
    V.assert(Fx.Color({kind='crate',tier=0})==0xc9c1b2 and Fx.Color({kind='crate',tier=3})==0xc46bff,'source crate tier colors preserved')
    V.assert(Fx.Color({kind='kill'})==0xff8a6a and Fx.Color({kind='wreck',model='core'})==0xffb21e,'source wreck and enemy loot target colors preserved')
    fx:Target({kind='wreck',model='core',g={10,0,0}},.34)
    V.assert(fx.mark.enabled and fx.mark.position.x==-10 and math.abs(fx.mark.scale.x-2)<.001,'source core marker uses mirrored real world position and radius six')
    V.assert(fx.mark:GetComponent('CustomGeometry'):GetNumVertices(0)==600,'48-segment rings and four-sided pointer are immutable geometry')
    V.assert(math.abs(fx.markMaterial:GetShaderParameter('uProgress'):GetFloat()-20/60)<.001,'source progress arc is quantized to sixtieths')
    fx:Loot({0,0,0},0xffb020,2);fx:Update(.375,12,{10,0,0})
    local c=fx.cubes[1]
    V.assert(c.node.enabled and math.abs(c.node.position.x+2.5)<.001 and math.abs(c.node.position.y-5.5)<.001,'loot cube follows source eased quarter-distance and four-meter flight arch')
    V.assert(math.abs(c.node.scale.x-.35)<.001 and fx.cubes[2].t<c.t,'source half-meter cube shrinks while subsequent cube delay remains staggered')
    V.assert(fx.beams[1].node.enabled and math.abs(fx.beams[1].node.scale.x-1.234375)<.001,'source 1.6 second rarity beam expands horizontally')
    fx:Update(.5,12.5,{10,0,0});V.assert(not c.node.enabled and fx.beams[1].node.enabled,'flight cubes finish before source beam fades')
    fx:Update(.8,13.3,{10,0,0});V.assert(not fx.beams[1].node.enabled,'source rarity beam hides after 1.6 seconds')
    fx:Target(nil);V.assert(not fx.mark.enabled,'completed or distant interaction hides original marker')
    for i=1,30 do fx:Loot({0,0,0},0x3ee6ff,6) end
    V.assert(#fx.root:GetChildren()==21 and #fx.beams==4 and #fx.cubes==16,'repeated loot reuses fixed source pool without creating nodes')
    fx:Target({kind='crate',tier=2,g={0,0,0}},.65);fx:Loot({4,0,0},0xc46bff,3);fx:Update(.25,14,{0,0,0})
    local n=scene:CreateChild('Camera');n.position=Vector3(0,12,-28);n:LookAt(Vector3(0,2,0));camera=n:CreateComponent('Camera');camera.farClip=500
end)
local function Poll()
    if finished or not fx or not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
    if not showing then
        showing=true;require('urhox-libs/UI').SetRoot(require('urhox-libs/UI').Panel{width='100%',height='100%',pointerEvents='none'})
    end
    renderer:SetViewport(0,Viewport:new(scene,camera));shownFrames=shownFrames+1
    if shownFrames~=28 then return end
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'actual source salvage marker and pool screenshot available')
    V.assert(image:SavePNG('docs/migration/evidence/salvage-fx-native.png'),'native salvage effects screenshot saved');image:Dispose()
    finished=true;fx:Dispose();scene:Dispose();V.finish()
end
for frame=20,370 do V.atFrame(frame,Poll) end
V.atFrame(375,function() V.assert(finished,'salvage effect screenshot captured after actual loader exit');V.finish() end)
