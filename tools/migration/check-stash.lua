local Rules=require('salvage.StashRules')
local function Same(a,b)
    for k,v in pairs(a) do if b[k]~=v then return false end end
    for k,v in pairs(b) do if a[k]~=v then return false end end;return true
end
V.atFrame(10,function()
    local file=assert(io.open('tools/migration/source-stash.json'));local f=cjson.decode(file:read('*a'));file:close()
    for i,c in ipairs(f.cases) do
        c.before.v=1;local result=Rules.Buy(c.before,c.list);local actual=result.ok and result.data or c.before
        V.assert(result.ok==c.result.ok and result.cost==c.result.cost,'source buyAll result '..i)
        V.assert(actual.credits==c.credits and Same(actual.items,c.items),'source atomic purchase inventory/credits '..i)
    end
    for i,c in ipairs(f.shorts) do V.assert(Same(Rules.Shortfall(c.owned,c.usage),c.result),'source installed shortage '..i) end
    for i,c in ipairs(f.needs) do V.assert(Same(Rules.Need(c.parts),c.result),'source blueprint requirement '..i) end
    local cases={
        {v=1,credits=8000,items={scrap=36}},
        {v=1,credits=0,items={['part:laser1']=0},op=1,stats={raids=2,extracted=1,lost=1},lastRun='run:1'},
        {v=1,credits=0/0,items={}}, {v=1,credits=string.unpack('<d',string.char(0,0,0,0,0,0,240,127)),items={}},
        {v=1,credits=-1,items={}}, {v=1,credits=.5,items={}},
        {v=1,credits=8000,items={ghost=1}}, {v=1,credits=8000,items={scrap=-1}},
        {v=1,credits=8000,items={scrap=.5}}, {v=1,credits=8000,items={},stats={lost=-1}},
        {v=1,credits=8000,items={},op=0}, {v=1,credits=8000,items={},lastRun=12},
    }
    for i,c in ipairs(cases) do if i==3 or i==4 then print('[StashFinite] '..i..' value='..tostring(c.credits)..' type='..type(c.credits)..' bits='..tostring(string.unpack('<I8',string.pack('<d',c.credits)))) end;V.assert(Rules.Valid(c)==(i<=2),'restore finite integer/catalog validation '..i) end
    local Lobby=require('app.SalvageLobby');local s=setmetatable({data={v=1,credits=8000,items={scrap=2}},Save=function() return false,'storage fault' end},Lobby)
    local previous=s.data;local result=s:BuyAll({scrap=5})
    V.assert(not result.ok and s.data==previous and s.data.items.scrap==2 and s.data.credits==8000,'production failed Save rolls back all purchase rows')
    s.Save=function() return true end;result=s:BuyAll({scrap=5})
    V.assert(result.ok and s.data.items.scrap==7 and s.data.credits==8000-result.cost,'production acknowledged purchase commits exact source totals')
    local decode=require('storage.CloudStorage').Decode
    for i,c in ipairs(cases) do if i~=3 and i~=4 then
        local text=cjson.encode({v=1,generation=1,data=c});local good=decode(text,'vox-save-v1-vox-salvage-stash')~=nil
        V.assert(good==(i<=2),'actual cloud restore rejects corrupt stash '..i)
    end end
    V.finish()
end)
