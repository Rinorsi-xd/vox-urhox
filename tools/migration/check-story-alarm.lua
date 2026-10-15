engine.maxInactiveFps=120
V.atFrame(43,function()
    local file=assert(io.open('tools/migration/source-story-fx-fixtures.json'));local fixtures=cjson.decode(file:read('*a'));file:close()
    local scene=Scene:new();scene:CreateComponent('Octree');local View=require 'render.MissionView';local view=View.New(scene)
    local Data=require('story.MissionData').view;local lamps,lights={},{}
    for id,node in ipairs(view.alarm.nodes) do if view.alarm.lights[id] then lights[#lights+1]=view.alarm.lights[id] elseif node:GetComponent('StaticModel') then lamps[#lamps+1]=node end end
    V.assert(#lamps==2 and #lights==2,'source cargo alarm has two original lamp meshes and two real point lights')
    local function Near(a,b) return math.abs(a-b)<.0001*math.max(1,math.abs(b)) end
    for _,f in ipairs(fixtures.alarms) do
        if not f.on then view:AlarmOff() end
        view:Update(f.dt,{install=0,StepSpec=function()return nil end},nil)
        for i,want in ipairs(f.lights) do local light=lights[i];local p=light.node.position
            V.assert(Near(light.brightness,want.intensity),'original alarm pulse and smooth shutdown '..f.frame..'/'..i)
            V.assert(light.lightType==LIGHT_POINT and light.range==want.range and Near(-p.x,want.pos[1]) and Near(p.y,want.pos[2]) and Near(p.z,want.pos[3]),'authored cargo point light position range '..f.frame..'/'..i)
        end
        for i,want in ipairs(f.lamps) do local node=lamps[i];local q=Quaternion(-want.yaw*180/math.pi,Vector3.UP)
            local actual=node.rotation*Vector3.FORWARD;local expected=q*Vector3.FORWARD
            V.assert((actual-expected).length<.0001,'original lamp rotation retains coordinate transform '..f.frame..'/'..i)
        end
    end
    V.assert(lights[1].brightness<.001 and lights[2].brightness<.001,'alarm brightness fades to dark after original exit event')
    local off=0;local events={};local Mission=require 'story.Mission'
    local host=setmetatable({rules={Drain=function()return events end},voice={Say=function()end},view={AlarmOff=function()off=off+1 end}},Mission)
    events={{type='objectiveDone',step={id='box'}}};host:Events();V.assert(off==0,'picking black box does not turn cargo alarm off prematurely')
    events={{type='objectiveDone',step={id='exit'}}};host:Events();V.assert(off==1,'source exit objective turns cargo alarm off exactly once')
    view:Dispose();view:Dispose();V.assert(scene:GetChild('StoryMissionObjects')==nil,'alarm meshes and real point lights dispose with mission view')
    scene:Dispose();V.finish()
end)
