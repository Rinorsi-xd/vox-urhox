V.atFrame(42,function()
    local file=File('tools/migration/source-story-marker-fixtures.json',FILE_READ);local data=cjson.decode(file:ReadString());file:Dispose()
    local Marker=require 'story.MarkerRules';local Rules=require 'story.MissionRules'
    local function Near(a,b) if type(a)~=type(b) then return false end;if type(a)=='number' then return math.abs(a-b)<1e-7 end;if type(a)~='table' then return a==b end;for k,v in pairs(b) do if not Near(a[k],v) then return false end end;return true end
    for i,c in ipairs(data.projected) do V.assert(Near(Marker.Project(c.nx,c.ny,c.behind,c.w,c.h),c.out),'source story projection '..i) end
    for i,c in ipairs(data.cases) do
        local step={kind=c.kind,id=c.kind=='reach' and 'home' or 'test',pos={0,0,0},r=20,healR=20,site='A',intel='note'}
        local r=Rules.New({steps={step},intel={note={pos={3,0,0}}}});r.index=1;r.phase=c.phase;r.cap={phase=c.phase};r.playerPos={c.distance,0,0}
        local entries={{}};r.enemyPositions={}
        for j=1,c.enemies do local pos={j==1 and 100 or 2,0,0};r.enemyPositions[j]=pos;entries[#entries+1]={unit={alive=true,name=j==1 and '海盗 · 远车' or '海盗 · 近车',Position=function()return pos end}} end
        local convoy={blocked=c.phase=='fight',far=c.distance==200,pos={90,0,0}};r.convoy=convoy
        local shelter=c.phase=='fight' and c.distance==200 and {20,0,20} or nil
        local boss={flow={stage=c.phase=='fight' and 'fight' or 'intro'},unit={Position=function()return {0,0,0}end},Threat=function()return shelter~=nil end,UnderRoof=function()return false end,Shelter=function()return shelter end}
        r.bossTarget=c.phase=='fight' and(shelter or {0,0,0}) or nil
        local m={rules=r,entries=entries,convoy=convoy,boss=boss,player={Position=function()return r.playerPos end}}
        local actualTarget=r:Target();V.assert(c.target==cjson.null and actualTarget==nil or Near(actualTarget,c.target),'source story target '..i)
        local marker=Marker.Select(m)
        local output=marker and {label=marker.label,kind=marker.kind,lift=marker.lift,enemy=marker.enemy,close=marker.close,pips=c.enemies-(marker.excluded and 1 or 0)} or nil
        V.assert(c.marker==cjson.null and output==nil or Near(output,c.marker),'source story marker selection '..i)
    end
    V.finish()
end)
