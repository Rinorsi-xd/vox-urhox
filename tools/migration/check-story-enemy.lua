V.atFrame(40,function()
    local f=File('tools/migration/source-story-enemy-fixtures.json',FILE_READ);local data=cjson.decode(f:ReadString());f:Dispose()
    local R=require 'story.EnemyRules'
    for i,c in ipairs(data.cases) do local action=R.Doom(c.spec,c.hull,c.hp,c.flee,c.boss);V.assert(action==c.action,'actual source _doomed state '..i) end
    local Rules=require 'story.MissionRules';local r=Rules.New({steps={{kind='clear',pos={100,0,0}}},spawn={}})
    r.index=1;r.phase='fight';r.playerPos={0,0,0};r.enemyPositions={{15,0,0},{4,0,0}};V.assert(r:Target()==r.enemyPositions[2],'story clear beacon follows nearest living enemy')
    local app=VOX_HANGAR and VOX_HANGAR.app
    V.assert(app and app.EnterTrial,'production story app remains loaded after full driver integration')
    local A=require 'combat.EnemyDriverMath'
    local unit={Core=function()return {hp=80,max=100}end,Integrity=function()return .66 end,Life=function()return .1 end}
    V.assert(math.abs(A.Life(unit)-.6)<1e-9,'source AI retreat health excludes shared hull HUD life')
    V.finish()
end)
