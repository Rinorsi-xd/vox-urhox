-- UI owns its stable NanoVG context; portraits own their four engine textures.
-- Upload one original image per rendered frame before narrative audio starts.
local Images=require 'urhox-libs/UI/Core/ImageCache'
local M={};M.__index=M
function M.New(paths,portrait)
 local self=setmetatable({items={},index=0,owned={},portrait=portrait,ready=false,disposed=false},M)
 local names={};for name in pairs(paths) do names[#names+1]=name end
 -- Other poses sample the closed smile texture, so prepare that dependency first.
 local order={nono_smile=1,nono_talk=2,nono_deadpan=3,nono_stamp=4}
 table.sort(names,function(a,b)local x,y=order[a] or 0,order[b] or 0;return x==y and a<b or x<y end)
 for _,name in ipairs(names) do self.items[#self.items+1]={name=name,path=paths[name],face=name:match('^nono_(.+)$')} end
 return self
end
function M:Step(vg,downloaded)
 if self.disposed or self.ready or not downloaded or not vg or Images.GetContext()~=vg then return self.ready end
 if self.frame==time.frameNumber then return false end
 self.frame=time.frameNumber;self.context=vg
 local item=self.items[self.index+1];if not item then self.ready=true;return true end
 if item.face then
  local portrait=self.portrait()
  if not portrait:Prepare(0,item.face,false) then return false,'Opening portrait unavailable: '..item.path end
  portrait:Queue();portrait:Draw(vg,{x=0,y=0,w=330,h=410})
  local texture=portrait.faces[item.face]
  item.width=texture.width;item.height=texture.height
 else
  local borrowed=Images.IsLoaded(item.path);local handle=Images.Get(item.path)
  if not handle or handle<=0 then return false,'Opening image unavailable: '..item.path end
  if not borrowed then self.owned[item.path]=handle end
  item.width,item.height=Images.GetSize(item.path)
 end
 if item.width<=0 or item.height<=0 then return false,'Opening image has invalid dimensions: '..item.path end
 self.index=self.index+1;self.ready=self.index==#self.items
 if self.ready then local portrait=self.portrait();portrait.glitch=0;portrait.face=nil;portrait.lastTime=0 end
 print('[IntroImages] '..item.name..' '..item.width..'x'..item.height..' '..(item.face and 'portrait' or 'ui'))
 return self.ready
end
function M:Dispose()
 if self.disposed then return end;self.disposed=true
 if self.context and Images.GetContext()==self.context then
  for path,handle in pairs(self.owned) do
   if Images.IsLoaded(path) and Images.Get(path)==handle then Images.Release(path) end
  end
 end
 self.owned={};self.portrait=nil
end
return M
