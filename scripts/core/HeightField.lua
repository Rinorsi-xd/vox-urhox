-- Source-space X/Z -> visual terrain height. One compact native buffer per map.
-- Bilinear interpolation matches H5 near.userData.sample, including edge clamp.
local M={};M.__index=M
function M.New(path)
    local file=assert(cache:GetFile(path),'Missing height field '..path)
    local ok,result=pcall(function()
        assert(file:ReadFileID()=='VHF1','Unsupported height field')
        local n=file:ReadUInt();local x,z,step=file:ReadFloat(),file:ReadFloat(),file:ReadFloat()
        assert(n>=1 and n<=4096 and step>0,'Invalid height field bounds')
        local bytes=(n+1)*(n+1)*4
        assert(file.size==20+bytes,'Incomplete height field')
        return setmetatable({n=n,x=x,z=z,step=step,buffer=file:Read(bytes),disposed=false},M)
    end)
    file:Dispose();assert(ok,result);return result
end
function M:Sample(x,z)
    assert(not self.disposed,'Height field already released')
    local n=self.n;local fx,fz=(x-self.x)/self.step,(z-self.z)/self.step
    local i,j=math.max(0,math.min(n-1,math.floor(fx))),math.max(0,math.min(n-1,math.floor(fz)))
    local u,v=math.max(0,math.min(1,fx-i)),math.max(0,math.min(1,fz-j))
    local buffer=self.buffer;local k=i*(n+1)+j
    buffer:Seek(k*4);local a,c=buffer:ReadFloat(),buffer:ReadFloat()
    buffer:Seek((k+n+1)*4);local b,d=buffer:ReadFloat(),buffer:ReadFloat()
    return a*(1-u)*(1-v)+b*u*(1-v)+c*(1-u)*v+d*u*v
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;self.buffer:Clear()
end
return M
