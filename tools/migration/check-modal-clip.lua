-- Actual SourceModalVisual.Card over a neutral background. The original CSS
-- clips box-shadow outside the card; test both direct and SourceLayer draws.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Modal=require 'ui.SourceModal'
local Visual=require 'ui.SourceModalVisual'
local Layer=require 'ui.SourceLayer'
local root,shell,layer,menu
local scale,grouped,menuMode=1,false,false
local rect={x=158,y=118,w=325,h=337.375,cardX=160,cardY=120,cardW=320,cardH=332.375,contentW=320,contentH=332.375}
local records={}
local function DrawCard(vg,r) Visual.Card({modal=shell},vg,r,not grouped) end
local function Check()
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local crop=im:GetSubimage(IntRect(80*scale,40*scale,560*scale,530*scale));assert(crop,'capture must fit physical framebuffer');crop:SavePNG('docs/migration/evidence/pc-modal-clip-'..scale..'-'..tostring(grouped)..'.png');crop:Dispose()
    local samples={}
    for _,distance in ipairs({2,8,16,32,60}) do
        for _,point in ipairs({{160-distance,250},{480+distance,250},{320,120-distance},{320,453+distance}}) do
            local c=im:GetPixel(math.floor(point[1]*scale),math.floor(point[2]*scale))
            samples[#samples+1]={x=point[1],y=point[2],r=c.r,g=c.g,b=c.b}
            V.assert(math.abs(c.r-160/255)<.008 and math.abs(c.g-160/255)<.008 and math.abs(c.b-160/255)<.008,'original clip removes external shadow at '..point[1]..','..point[2]..' DPR '..scale..' grouped '..tostring(grouped))
        end
    end
    local corner=im:GetPixel(477*scale,123*scale);local inside=im:GetPixel(400*scale,150*scale)
    V.assert(math.abs(corner.r-160/255)<.008 and inside.r<.2,'source chamfer is transparent and card is opaque')
    records[#records+1]={scale=scale,grouped=grouped,samples=samples,bytes=layer.bytes or 0};im:Dispose()
end
V.atFrame(20,function()
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    shell=Modal{source={fullScroll=true},title=''}
    menu=require('ui.HomeNewMenu').Create({Track=function(widget) return widget end})
    menu.GetAbsoluteLayout=function() return {x=160,y=120,w=320,h=332.375} end
    local content=shell.contentContainer_;content.renderOffsetX_=160;content.renderOffsetY_=120;content.renderWidth_=320;content.renderHeight_=332.375
    layer=Layer.New(999980,function() rect.scale=scale;return grouped and rect or nil end,function(vg,r) DrawCard(vg,r) end)
    root.Render=function(self,vg)
        nvgSave(vg);nvgScale(vg,scale,scale);D.Rect(vg,0,0,640,600,{160,160,160,255})
        if menuMode then menu:Render(vg)
        elseif grouped then layer:Draw(vg,rect.x,rect.y,1) else DrawCard(vg,rect) end;nvgRestore(vg)
    end
end)
V.atFrame(30,function() Check();grouped=true end)
V.atFrame(35,function() Check();scale=2;grouped=false end)
V.atFrame(40,function() Check();grouped=true end)
V.atFrame(45,function()
    Check();layer:Dispose();shell:Destroy();menuMode=true;scale=1
    local f=assert(io.open('docs/migration/evidence/pc-modal-clip.json','w'));f:write(cjson.encode(records));f:close()
end)
local function MenuShot()
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local crop=im:GetSubimage(IntRect(80*scale,40*scale,560*scale,530*scale));assert(crop:SavePNG('docs/migration/evidence/pc-menu-shadow-'..scale..'.png'));crop:Dispose();im:Dispose()
    local count=0;for _ in pairs(menu.shadow.images) do count=count+1 end
    V.assert(count==1,'same menu context reuses one shadow image at DPR '..scale)
end
V.atFrame(50,function() MenuShot();scale=2 end)
V.atFrame(55,function()
    MenuShot();local shadow=menu.shadow;menu:Destroy();V.assert(not next(shadow.images),'destroying menu releases its shadow images')
    UI.SetRoot(nil);root:Destroy();UI.Shutdown();V.finish()
end)
