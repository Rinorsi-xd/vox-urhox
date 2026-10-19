local Data=require 'construction.LiveryData'
local Project=require 'render.LiveryProjection'
local M={};M.__index=M
function M.New(app,onCue)
    local self=setmetatable({},M);self:init(app,onCue);return self
end
function M:init(app,onCue)
    self.app=app;self.sel=0;self.pick=false;self.mirrorNew=false;self.history={cjson.encode(app.blueprint.livery)};self.hi=1
    self.start=self.history[1];self.revision=0;self.pending=0;self.active=true;self.onCue=onCue
    app.car.livery:SetAsync(true);self.liveryLayer=app.car.livery
end
function M:Cue(id) if self.onCue then self.onCue(id) end end
function M:List() return self.app.blueprint.livery end
function M:Apply(list)
    self.app.blueprint.livery=list;self.app.car.livery:Set(list);self.app.bays:Changed();self.revision=self.revision+1
    if self.sel>#list then self.sel=#list end
end
function M:Record(soon)
    self.pending=soon and .4 or 0;if soon then return end
    local value=cjson.encode(self:List());if value==self.history[self.hi] then return end
    for i=#self.history,self.hi+1,-1 do self.history[i]=nil end
    self.history[#self.history+1]=value;if #self.history>60 then table.remove(self.history,1) end
    self.hi=#self.history;self.revision=self.revision+1
end
function M:Flush() if self.pending>0 then self:Record() end end
function M:Undo(redo)
    self:Flush();local index=self.hi+(redo and 1 or -1);if index<1 or index>#self.history then return end
    self.hi=index;self:Apply(Data.Clean(cjson.decode(self.history[index])))
end
function M:Twin(index,list)
    list=list or self:List();local d=list[index];if not d or not d.m or d.m==0 then return 0 end
    for i,q in ipairs(list) do if i~=index and q.m==d.m then return i end end;return 0
end
function M:Group(list) local n=0;for _,d in ipairs(list) do n=math.max(n,d.m or 0) end;return n+1 end
function M:Edit(fn,record)
    if self.sel==0 then return end;local list=Data.Clone(self:List());local d=list[self.sel];if not d then return end;fn(d)
    local j=self:Twin(self.sel,list);if j>0 then list[j]=Data.Mirror(d,Data.Catalog().byId[d.s]) end
    self:Apply(list);if record then self:Record(record=='soon') end
end
function M:Pick(id) self.pick=id or false;if id then self.sel=0 end;self.app.car.livery:SetPreview(nil);self.revision=self.revision+1 end
function M:Select(index) self.sel=index or 0;self.pick=false;self.app.car.livery:SetPreview(nil);self.revision=self.revision+1 end
function M:NewDecal(id,hit)
    local st=Data.Catalog().byId[id];local d={s=id,p=hit.p,n=hit.n,r=0,w=st.kind=='portrait' and 3.5 or 3}
    if st.kind=='shape' then d.c={table.unpack(st.colors)} end;return d
end
function M:Place(hit)
    if not self.pick then return end;local list=Data.Clone(self:List());if #list>=48 then self.app.toasts:Push('一辆车最多贴 48 张','warn');return end
    local d=self:NewDecal(self.pick,hit);list[#list+1]=d;self.sel=#list
    if self.mirrorNew and not Data.OnCenter(d) and #list<48 then d.m=self:Group(list);list[#list+1]=Data.Mirror(d,Data.Catalog().byId[d.s]) end
    self.pick=false;self.app.car.livery:SetPreview(nil);self:Apply(list);self:Record()
    self:Cue('paint')
end
function M:Mirror()
    if self.sel==0 then return end;local list=Data.Clone(self:List());local d=list[self.sel];local j=self:Twin(self.sel,list)
    if j>0 then table.remove(list,j);d.m=nil;if j<self.sel then self.sel=self.sel-1 end;self.mirrorNew=false
    else
        if Data.OnCenter(d) then self.app.toasts:Push('贴在中线上了，对称过去就是它自己','warn');return end
        if #list>=48 then self.app.toasts:Push('一辆车最多贴 48 张','warn');return end
        d.m=self:Group(list);list[#list+1]=Data.Mirror(d,Data.Catalog().byId[d.s]);self.mirrorNew=true
    end;self:Apply(list);self:Record()
end
function M:Duplicate()
    local src=self:List()[self.sel];if not src then return end;local list=Data.Clone(self:List())
    if #list+(src.m and 2 or 1)>48 then self.app.toasts:Push('一辆车最多贴 48 张','warn');return end
    local d=Data.Clone({src})[1];local f=Project.Frame(src);for k=1,3 do d.p[k]=d.p[k]+f.x[k]*src.w*.7 end;d.m=nil
    list[#list+1]=d;self.sel=#list;if src.m then d.m=self:Group(list);list[#list+1]=Data.Mirror(d,Data.Catalog().byId[d.s]) end
    self:Apply(list);self:Record()
end
function M:Remove()
    if self.sel==0 then return end;local twin=self:Twin(self.sel);local list={}
    for i,d in ipairs(self:List()) do if i~=self.sel and i~=twin then list[#list+1]=d end end
    self.sel=0;self:Apply(list);self:Record()
    self:Cue('remove')
end
function M:MoveLayer(dir)
    local i,j=self.sel,self.sel+dir;local list=Data.Clone(self:List());if i==0 or j<1 or j>#list then return end
    list[i],list[j]=list[j],list[i];self.sel=j;self:Apply(list);self:Record()
end
function M:Clear() self.sel=0;self:Apply({});self:Record() end
function M:Update(dt) if self.pending>0 then self.pending=self.pending-dt;if self.pending<=0 then self:Record() end end end
function M:Dispose()
    if not self.active then return end;self:Flush();self.active=false;self.app.car.livery:SetPreview(nil)
    if self.liveryLayer then self.liveryLayer:SetAsync(false);self.liveryLayer=nil end
    if self.start~=cjson.encode(self:List()) and self.app.bays.active then
        local ok,err=self.app.bays:Save();if not ok then self.app.toasts:Push(err,'bad') end
    end
end
return M
