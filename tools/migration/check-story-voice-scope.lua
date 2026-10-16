package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function Check(value,label) checks=checks+1;assert(value,label) end
local function Set(list) local out={};for _,path in ipairs(list) do out[path]=true end;return out end
local function Same(a,b,label)
    for path in pairs(a) do Check(b[path]==true,label..' unexpected '..path) end
    for path in pairs(b) do Check(a[path]==true,label..' missing '..path) end
end
local function noop() end
package.loaded['core.ResourceData']={Read=READ_JSON}
package.loaded['audio.AudioLevels']={SetSpeaking=noop}
package.loaded['urhox-libs.Platform.PlatformUtils']={}
package.loaded['ui.CommsCard']={Dispose=noop}
local radio=require'audio.StoryRadio'
package.loaded['audio.StoryCommsCues']={Dependencies=radio.Dependencies,New=function() return {Dispose=noop} end}
Scene=function() return {CreateChild=function() return {CreateComponent=function() return {SetSoundType=noop,StopImmediate=noop} end} end,Dispose=noop} end
local requested={}
cache={GetResourceAsync=function(_,kind,path) Check(kind=='Sound','voice request type');requested[#requested+1]=path end}
local Data=require'story.MissionData'
local C=assert(load(COMMS_SOURCE,'@audio/StoryComms.lua'))()
package.loaded['audio.StoryComms']=C
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','drive.SpawnSpecCache'}) do package.loaded[name]={} end
package.loaded['combat.ArenaData']={prefabs=setmetatable({},{__index=function(_,key) return key end})}
package.loaded['construction.Blueprint']={New=function() return {Load=function(self) return self end,List=function() return {} end} end}
package.loaded['parts.Dependencies']={For=function() return {'fixture/parts'} end}
package.loaded['render.MissionView']={Dependencies=function() return {'fixture/mission-view'} end}
package.loaded['render.SalvageExplosion']={Dependencies=function() return {'fixture/explosion'} end}
local bossCalls,epilogueCalls=0,0
package.loaded['combat.StoryBoss']={Dependencies=function() bossCalls=bossCalls+1;return {'fixture/boss'} end}
package.loaded['ui.Epilogue']={Dependencies=function() epilogueCalls=epilogueCalls+1;return {'fixture/epilogue'} end}
local Mission=assert(load(MISSION_SOURCE,'@story/Mission.lua'))()
local bp={Stats=function() return {fitTier={id=3}} end}
local all=Set(C.Dependencies())
for _,path in ipairs(EXPECTED_ALL) do Check(all[path],'no-argument compatibility '..path) end
local common={}
for path in pairs(all) do if not path:match('^Story/Mission/.+%.ogg$') then common[path]=true end end
Same(Set(C.Dependencies(nil)),all,'explicit nil compatibility')
Same(Set(C.Dependencies(false)),all,'invalid scope compatibility')
local result={}
for i,expected in ipairs(EXPECTED_LEVELS) do
    local level=Data.levels[i]
    local scope={level=level,quotes={}}
    for _,grade in ipairs({'S','A','B'}) do
        scope.quotes[grade]=Mission.Quote({level=level,rules={grade=grade}})
        Check(scope.quotes[grade]==expected.quotes[grade],'actual runtime quote '..i..' '..grade)
    end
    local deps=Set(C.Dependencies(scope));local want=Set(expected.paths)
    for path in pairs(common) do want[path]=true end
    Same(deps,want,'current level exact complete closure '..i)
    local viaMission=Set(Mission.Dependencies(bp,i))
    for path in pairs(want) do Check(viaMission[path],'actual Mission.Dependencies forwards scope '..i..' '..path) end
    for _,path in ipairs(EXPECTED_ALL) do Check((viaMission[path]==true)==(deps[path]==true),'Mission excludes unrelated voice '..i..' '..path) end
    for _,path in ipairs({'fixture/parts','fixture/mission-view','fixture/explosion'}) do Check(viaMission[path],'existing nonvoice dependency remains') end
    for _,path in ipairs(radio.Dependencies()) do Check(viaMission[path],'common radio remains '..path) end
    Check((viaMission['fixture/boss']==true)==(i==5),'Boss dependency remains S5-specific')
    Check((viaMission['fixture/epilogue']==true)==(i==5),'Epilogue dependency remains S5-specific')
    local matched=0
    for _,text in ipairs(expected.matchedTexts) do
        C.Shutdown();requested={};local owner=C.New(nil)
        owner:Say({{'nono',text}},true)
        Check(#requested==1,'actual playback index resolves authored text '..i)
        Check(deps[requested[1]],'actual Say path was predeclared '..requested[1]);matched=matched+1
    end
    for _,grade in ipairs({'S','A','B'}) do
        C.Shutdown();requested={};local owner=C.New(nil,i==5 and {voices={}} or nil)
        owner:PrepareResultQuote(scope.quotes[grade])
        for _,path in ipairs(requested) do Check(deps[path],'actual result quote predeclared '..path) end
    end
    result[i]={id=level.id,voices=#expected.paths,matchedTexts=matched}
end
Check(bossCalls==1 and epilogueCalls==1,'five real Mission dependency calls retain S5 independent owners')
-- The actual playback index may select either normalized collision; both must preload.
Data.voices.scopeA={path='fixture/scope-a.ogg',text={'Alpha 123'}}
Data.voices.scopeB={path='fixture/scope-b.ogg',text={'Alpha-123!'}}
local synthetic={steps={{ask={options={{reply={{'nono','【LABEL】Alpha 123?!'}}}}}}}}
synthetic.self=synthetic
local scoped=Set(C.Dependencies(synthetic))
Check(scoped['fixture/scope-a.ogg'] and scoped['fixture/scope-b.ogg'],'normalized collisions retained across deep choice replies')
for path in pairs(common) do Check(scoped[path],'synthetic scope retains shared dependencies') end
C.Shutdown();requested={};C.New(nil):Say({{'nono','【LABEL】Alpha 123?!'}},true)
Check(#requested==1 and scoped[requested[1]],'synthetic actual playback index is in closure')
Data.voices.scopeA=nil;Data.voices.scopeB=nil;C.Shutdown()
return {checks=checks,levels=result,allVoices=#EXPECTED_ALL}
