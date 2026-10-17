-- Isolated exact-height candidate. Fixed direct-mapped slots bound retained cells.
local M={};M.__index=M
local CACHE_SLOTS=4096
function M.New(path)
    local file=assert(cache:GetFile(path),'Missing height field '..path)
    local ok,result=pcall(function()
        assert(file:ReadFileID()=='VHF1','Unsupported height field')
        local n=file:ReadUInt();local x,z,step=file:ReadFloat(),file:ReadFloat(),file:ReadFloat()
        assert(n>=1 and n<=4096 and step>0,'Invalid height field bounds')
        local bytes=(n+1)*(n+1)*4
        assert(file.size==20+bytes,'Incomplete height field')
        return setmetatable({n=n,x=x,z=z,step=step,buffer=file:Read(bytes),disposed=false,
            cellKeys={},cellA={},cellB={},cellC={},cellD={}},M)
    end)
    file:Dispose();assert(ok,result);return result
end
function M:Sample(x,z)
    assert(not self.disposed,'Height field already released')
    local n=self.n;local fx,fz=(x-self.x)/self.step,(z-self.z)/self.step
    local i,j=math.max(0,math.min(n-1,math.floor(fx))),math.max(0,math.min(n-1,math.floor(fz)))
    local u,v=math.max(0,math.min(1,fx-i)),math.max(0,math.min(1,fz-j))
    local buffer=self.buffer;local k=i*(n+1)+j
    local slot=k%CACHE_SLOTS+1
    local a,b,c,d
    if self.cellKeys[slot]==k then
        a,b,c,d=self.cellA[slot],self.cellB[slot],self.cellC[slot],self.cellD[slot]
    else
        buffer:Seek(k*4);a,c=buffer:ReadFloat(),buffer:ReadFloat()
        buffer:Seek((k+n+1)*4);b,d=buffer:ReadFloat(),buffer:ReadFloat()
        self.cellA[slot],self.cellB[slot],self.cellC[slot],self.cellD[slot]=a,b,c,d
        self.cellKeys[slot]=k
    end
    return a*(1-u)*(1-v)+b*u*(1-v)+c*(1-u)*v+d*u*v
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;self.buffer:Clear()
    self.cellKeys=nil;self.cellA=nil;self.cellB=nil;self.cellC=nil;self.cellD=nil
end
return M
