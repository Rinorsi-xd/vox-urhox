local UI=require 'urhox-libs/UI'
local Layer=require 'ui.SourceLayer'
local D=require 'ui.SourceDraw'
local root,card,overlay,scale,phase,bytes= nil,nil,nil,1,0,{}
local function Prepare() return {w=64,h=64,scale=scale} end
local function Read()
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    local values={}
    for _,p in ipairs({{'outside',10,10},{'blue',112,16},{'white',104,48},{'empty',140,48},
        {'leftEdge',80,48},{'leftInside',81,48},{'rightInside',142,48},{'rightEdge',143,48},
        {'nestedFrame',88,8},{'directFrame',168,8}}) do
        local c=image:GetPixel(p[2],p[3]);values[p[1]]={c.r,c.g,c.b,c.a}
    end
    image:SavePNG('docs/migration/evidence/pc-ui-groups-'..scale..'.png');image:Dispose()
    return values
end
local function Verify()
    local actual=Read()
    -- Browser source-over: gray .4, black backdrop .6, child group .5,
    -- outer group .5. Blue is opaque; white patch has alpha128/255.
    local expected={outside={.4,.4,.4},blue={.24,.24,.49},white={.38549,.38549,.38549},empty={.28,.28,.28}}
    for key,exp in pairs(expected) do for i=1,3 do V.assert(math.abs(actual[key][i]-exp[i])<.013,'DPR '..scale..' nested CSS group '..key..' channel '..i) end end
    for _,edge in ipairs({'leftEdge','leftInside','rightInside','rightEdge'}) do
        V.assert(math.abs(actual[edge][1]-.28)<.013,'DPR '..scale..' crop edge matches ungrouped backdrop: '..edge)
    end
    V.assert((actual.nestedFrame[1]>actual.nestedFrame[2])==(actual.directFrame[1]>actual.directFrame[2]),'nested render groups use the same animation frame as direct UI')
    local f=assert(io.open('docs/migration/evidence/pc-ui-groups-'..scale..'.json','w'));f:write(cjson.encode({actual=actual,expected=expected,bytes=card.bytes+overlay.bytes}));f:close()
end
V.atFrame(20,function()
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    card=Layer.New(999980,Prepare,function(vg)
        D.Rect(vg,0,0,48,32,{255,0,0,255});D.Rect(vg,16,0,48,32,{0,0,255,255})
        D.Rect(vg,16,32,32,32,{255,255,255,128})
        D.Rect(vg,4,4,8,8,phase%2==0 and {255,0,0,255} or {0,255,0,255})
    end)
    overlay=Layer.New(999981,Prepare,function(vg)
        D.Rect(vg,0,0,64,64,{0,0,0,153});card:Draw(vg,0,0,.5)
    end)
    root.Render=function(self,vg)
        D.Rect(vg,0,0,graphics.width,graphics.height,{102,102,102,255})
        overlay:Draw(vg,80,0,.5)
        D.Rect(vg,164,4,8,8,phase%2==0 and {255,0,0,255} or {0,255,0,255})
    end
    root.Update=function() phase=phase+1 end
end)
V.atFrame(30,function() Verify();bytes[1]=card.bytes+overlay.bytes;scale=2 end)
V.atFrame(40,function()
    Verify();bytes[2]=card.bytes+overlay.bytes
    V.assert(bytes[2]==bytes[1]*4,'DPR2 allocation scales exactly with physical pixel area')
    local allocations=card.allocations;for _=1,10 do card:Resize(64,64,2) end
    V.assert(card.allocations==allocations,'same-sized groups reuse existing texture')
    scale=1
end)
V.atFrame(50,function()
    Verify();V.assert(card.bytes+overlay.bytes==bytes[1],'PC resize returns to bounded target size')
    card:Dispose();overlay:Dispose();UI.SetRoot(nil);root:Destroy();UI.Shutdown()
    V.assert(not card.texture and not card.rgbTexture and card.bytes==0 and not card.vg and not next(card.images) and not overlay.texture and not overlay.vg,'group disposal releases contexts, bridges and textures')
    V.finish()
end)
