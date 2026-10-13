-- Recolor source RG masks once per visible variant; never synthesize sticker art.
local D=require 'ui.SourceDraw'
local M={};M.__index=M
function M.New() return setmetatable({items={},tick=0},M) end
local function RGB(hex) return ((hex>>16)&255)/255,((hex>>8)&255)/255,(hex&255)/255 end
function M:Draw(widget,vg,st,colors,x,y,w,h)
    local default=not colors or st.kind~='shape';if not default then default=true;for i,c in ipairs(st.colors) do if colors[i]~=c then default=false end end end
    local iw,ih=w,h;if st.aspect>iw/ih then ih=iw/st.aspect else iw=ih*st.aspect end;x=x+(w-iw)/2;y=y+(h-ih)/2
    if default then if cache:Exists(st.texture) then widget:RenderBackgroundImage(vg,st.texture,{x=x,y=y,w=iw,h=ih},'contain',nil) end;return end
    if not cache:Exists(st.mask) then return end
    local key=st.id..'|'..table.concat(colors,',');local item=self.items[key];self.tick=self.tick+1
    if not item then
        local mask=assert(cache:GetResource('Image',st.mask));local image=Image:new()
        local width=math.floor(st.aspect>=1 and 128 or 128*st.aspect+.5);local height=math.floor(st.aspect>=1 and 128/st.aspect+.5 or 128)
        assert(image:SetSize(width,height,4));local ar,ag,ab=RGB(colors[1]);local br,bg,bb=RGB(colors[2] or colors[1]);local color=Color()
        for py=0,height-1 do for px=0,width-1 do
            local v=mask:GetPixel(math.min(mask.width-1,math.floor((px+.5)*mask.width/width)),math.min(mask.height-1,math.floor((py+.5)*mask.height/height)))
            color.r=v.r*ar+v.g*br;color.g=v.r*ag+v.g*bg;color.b=v.r*ab+v.g*bb;color.a=v.a;image:SetPixel(px,py,color)
        end end
        local tex=Texture2D:new();tex:SetSRGB(false);assert(tex:SetData(image,true));image:Dispose();cache:ReleaseResource('Image',st.mask,false)
        item={texture=tex,handles={},tick=self.tick};self.items[key]=item
        local count=0;local oldest,oldKey
        for k,q in pairs(self.items) do count=count+1;if k~=key and (not oldest or q.tick<oldest.tick) then oldest=q;oldKey=k end end
        if count>64 then for context,handle in pairs(oldest.handles) do nvgDeleteVideo(context,handle) end;oldest.texture:Dispose();self.items[oldKey]=nil end
    end
    item.tick=self.tick;local handle=item.handles[vg];if not handle then handle=nvgCreateVideo(vg,item.texture);assert(handle>0);item.handles[vg]=handle end
    D.Path(vg,{x,y,x+iw,y,x+iw,y+ih,x,y+ih});nvgFillPaint(vg,nvgImagePattern(vg,x,y,iw,ih,0,handle,1));nvgFill(vg)
end
function M:Dispose()
    for _,item in pairs(self.items) do for vg,h in pairs(item.handles) do nvgDeleteVideo(vg,h) end;item.texture:Dispose() end;self.items={}
end
return M
