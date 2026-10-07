local UI=require 'urhox-libs/UI'
local app,zone
local function Exposure(value)
    for k,v in pairs({['Auto Exposure Enable']=true,['Auto Exposure Plus Enable']=true,
        ['Auto Exposure Extended Luminance Range']=false,['Auto Exposure Min Brightness']=1,
        ['Auto Exposure Max Brightness']=1,['Auto Exposure Bias']=math.log(value,2),
        ['Auto Exposure Curve Bias']=0,['Auto Exposure Force Target']=true}) do
        local value=type(v)=='number' and Variant(VAR_FLOAT,tostring(v)) or Variant(v)
        V.assert(zone:SetAttribute(k,value),'set '..k)
    end
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'capture '..name)
    V.assert(img:SavePNG('.tmp/postfx-'..name..'.png'),'save '..name);img:Dispose()
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.camera.autoSpin=false;_G.VOX_DEBUG={time=10,hideUI=true}
    UI.SetRoot(UI.Panel{width='100%',height='100%',pointerEvents='none'})
    zone=app.scene:GetComponent('Zone',true)
    zone:SetAttribute('Auto Exposure Enable',Variant(false))
    renderer:GetViewport(0):SetRect(IntRect(0,0,1280,720))
end)
V.atFrame(72,function() Shot('base');Exposure(.6) end)
V.atFrame(90,function() Shot('exposure06');Exposure(1.1) end)
V.atFrame(108,function() Shot('exposure11');Exposure(1.4) end)
V.atFrame(126,function()
    Shot('exposure14');Exposure(1.1)
    V.assert(zone:SetAttribute('Ambient Occlusion Intensity',Variant(VAR_FLOAT,'0')),'set material AO intensity')
end)
V.atFrame(144,function() Shot('ao-off');V.finish() end)
