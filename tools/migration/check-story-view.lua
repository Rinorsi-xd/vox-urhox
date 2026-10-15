V.atFrame(43,function()
    local scene=Scene:new();scene:CreateComponent('Octree')
    local Data=require('story.MissionData').view;local View=require 'render.MissionView';local view=View.New(scene)
    local function Near(a,b) return math.abs(a-b)<1e-5 end
    local function Color(material,r,g,b,label)
        local c=material:GetShaderParameter('uColor'):GetVector3()
        V.assert(Near(c.x,r) and Near(c.y,g) and Near(c.z,b),label)
    end
    local step={kind='capture',pos={0,0,0},r=20}
    view:Objective(step,step.pos)
    local function Linear(c) c=c/255;return c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4 end
    for i,m in ipairs(view.beacon.materials) do if m.data.line then Color(m.material,1,1,1,'source beacon outline remains white') else Color(m.material,1,Linear(59),Linear(70),'capture beacon source linear red '..i) end end
    Color(view.zoneMaterial,1,Linear(59),Linear(70),'capture zone source linear red')
    local model=view.beacon.nodes[2]:GetComponent('StaticModel')
    V.assert(model.enabledEffective,'visible beacon enables its real StaticModel')
    local hidden=view.beacon.root:CreateChild('OriginallyHiddenChild');hidden.enabled=false
    view:HideBeacon()
    V.assert(not model.enabledEffective,'hideBeacon disables all descendant geometry')
    step={kind='install',pos={0,0,0},r=20};view:Objective(step,step.pos)
    V.assert(model.enabledEffective and not hidden.enabled,'show beacon restores geometry and preserves originally hidden child')
    local rules={inside=true,install=0,StepSpec=function()return step end}
    view:Update(1/60,rules,nil)
    for i,m in ipairs(view.beacon.materials) do
        if not m.data.line then Color(m.material,1,Linear(106),Linear(19),'install beacon source linear orange '..i) end
        if m.data.shader=='Beam' or m.data==Data.materials[Data.beacon.nodes[Data.beacon.gem].material] then
            V.assert(Near(m.material:GetShaderParameter('opacity'):GetFloat(),m.data.alpha*.94),'source install first frame opacity '..i)
        end
    end
    local outlines=0;for _,definition in ipairs({Data.beacon,Data.intel}) do local rig=view:Rig(definition);require('render.NodeVisibility').Set(rig.root,true)
        for id,node in ipairs(definition.nodes) do if node.lines then local geometry=rig.nodes[id]:GetComponent('CustomGeometry');V.assert(geometry~=nil and geometry.enabledEffective,'actual source outline CustomGeometry enabled');outlines=outlines+1 end end
    end
    V.assert(outlines>=2,'source beacon and intel retain authored edge outlines')
    for _=1,120 do view:Update(1/60,rules,nil) end
    V.assert(view.beacon.fade>.25 and view.beacon.fade<.251,'inside install circle fades beacon to 25 percent')
    rules.inside=false;view:Update(1/60,rules,nil)
    V.assert(view.beacon.fade>.30,'leaving install circle restores beacon gradually')
    local Boundary=require 'render.BoundaryFx';local boundary=Boundary.New(scene,Boundary.Square(10,-2,20))
    local walls=boundary.root:GetChild('Walls'):GetComponent('CustomGeometry')
    local ceiling=boundary.root:GetChild('Ceiling'):GetComponent('CustomGeometry')
    boundary:SetVisible(false);V.assert(not walls.enabledEffective and not ceiling.enabledEffective,'boundary hide disables walls and ceiling')
    boundary:SetVisible(true);V.assert(walls.enabledEffective and ceiling.enabledEffective,'boundary show restores walls and ceiling')
    boundary:Dispose()
    local BossView=require 'render.BossView';local BossData=require('core.ResourceData').Read('Story/Boss/View.json')
    local cameraNode=scene:CreateChild('StoryGlowCamera');local camera=cameraNode:CreateComponent('Camera')
    local config=require('core.ResourceData').Read('Story/Mission/Level5.json').boss
    local bossRules=require('story.BossRules').New(config,150)
    local bossHost={rules=bossRules,time=5,unit={},tails={},missiles={},flow={},world={layout={enginePit={points={floorCentre={10,0,20}}}}},
        session={camera={GetCamera=function()return camera end},combatView={units={}}},Ground=function()return 12 end,
        Nodes=function()end,Cockpit=function()return {0,0,0} end}
    for i,n in ipairs(bossRules.nodes) do n.pos={i*5,0,0} end
    local boss=BossView.New(scene,bossHost)
    local Visibility=require 'render.NodeVisibility'
    for _,pair in ipairs({{boss.warn,BossData.ring},{boss.sector,BossData.sector},{boss.pod,BossData.pod}}) do
        local o,def=pair[1],pair[2];local child=o.nodes[2]:GetComponent('StaticModel')
        V.assert(not child.enabledEffective,'initial Boss composite hidden '..#def.nodes)
        Visibility.Set(o.root,true);V.assert(child.enabledEffective,'show Boss composite restores child '..#def.nodes)
        Visibility.Set(o.root,false);V.assert(not child.enabledEffective,'hide Boss composite disables child '..#def.nodes)
    end
    bossRules:Go('ult');bossRules.t=config.ult.charge/2;boss:Update(1/60)
    V.assert(boss.dome.root.enabled and boss.dome.root.scale==Vector3(560,560,560) and Near(boss.dome.root.position.y,-18),'source ult dome uses ground minus30 and560m hemisphere')
    V.assert(Near(boss.dome.material:GetShaderParameter('opacity'):GetFloat(),.08),'source ult dome quadratic half-charge opacity')
    bossRules:Go('lanes');bossRules.t=config.lanes.warn*.2;bossRules.laneFrom={1,2,3};bossRules.laneYaw=0;boss:Update(1/60)
    local lane=boss.lanes[1];V.assert(Near(lane.root.scale.z,config.lanes.len*.352) and Near(lane.root.position.y,2.6),'source lanes ease twice-progress and600mm offset')
    V.assert(Near(lane.materials[1]:GetShaderParameter('opacity'):GetFloat(),.224),'source lanes warn opacity')
    bossRules:Go('fight');boss:Update(1/60)
    V.assert(not lane.root:GetComponent('StaticModel').enabledEffective and not boss.dome.model.enabledEffective,'recovering from attacks hides actual lanes and dome')
    bossHost.shock={pos={0,0,0},r=40,age=0};boss:Update(.35)
    V.assert(Near(boss.shock.root.scale.x,40*.65) and Near(boss.shock.material:GetShaderParameter('opacity'):GetFloat(),.4),'source shock has eased radius and independent orange ring')
    bossHost.shock=nil;bossHost.missiles={{bomb=true,prev={0,0,5},to={0,0,8},hist={}}};boss:Update(1/60)
    V.assert(boss.missiles[1].model.model==cache:GetResource('Model',BossData.models[BossData.bomb].path),'raid bombs use original capsule geometry')
    bossHost.missiles[1].bomb=false;boss:Update(1/60)
    V.assert(boss.missiles[1].model.model==cache:GetResource('Model',BossData.models[BossData.missile].path),'reused missile slot switches to original160cm cone')
    Color(boss.missiles[1].material,1,Linear(224),Linear(192),'source ordinary missile is linear warm white')
    boss:Dispose()
    for i=1,4 do local level=require('core.ResourceData').Read('Story/Mission/Level'..i..'.json')
        V.assert(level.source.commit=='2b169a9964645f5f346a7158bcb14447f040814a','story level frozen current baseline '..i)
    end
    local file=File('tools/migration/source-story-fx-fixtures.json',FILE_READ);local fixtures=cjson.decode(file:ReadString());file:Dispose()
    local fixtureView=nil;local collector=nil;local instant=nil;local landed=0
    for _,f in ipairs(fixtures.cases) do
        if instant~=f.instant then
            if fixtureView then fixtureView:Dispose() end
            fixtureView=View.New(scene);fixtureView:Collector({0,0,0},f.instant);collector=fixtureView.collectors[1];instant=f.instant;landed=0
            fixtureView.onLand=function()landed=landed+1 end
        end
        fixtureView:Update(1/24,{install=0,StepSpec=function()return nil end},nil)
        local r=Data.collector.rig;local nodes=collector.nodes;local lamp=collector.materialByNode[r.lamp]:GetShaderParameter('uColor'):GetVector3()
        V.assert(Near(nodes[r.body].position.y,f.body) and nodes[r.flame].enabled==f.flame and nodes[r.halo].enabled==f.halo,'source collector fall and visible states '..f.frame..'/'..tostring(instant))
        V.assert(Near(nodes[r.halo].scale.x,f.scale) and Near(collector.materialByNode[r.up]:GetShaderParameter('opacity'):GetFloat(),f.up),'source collector deployment and uplink '..f.frame..'/'..tostring(instant))
        V.assert(Near(lamp.x,f.lamp[1]) and Near(lamp.y,f.lamp[2]) and Near(lamp.z,f.lamp[3]) and Near(collector.glowByNode[r.glow].opacity,f.glow),'source collector lamp HSL and glow opacity '..f.frame..'/'..tostring(instant))
        V.assert(Near(nodes[r.drill].position.y,f.drill) and landed==f.landings,'source collector drill and single landing '..f.frame..'/'..tostring(instant))
    end
    fixtureView:Glows(camera);V.assert(fixtureView.glow.count==1 and fixtureView.glow.mesh.enabled,'original collector glow emits one real billboard')
    fixtureView:Dispose()
    local chips=0;local fx={smoke={},maxSmoke=100,chips={Emit=function()chips=chips+1 end}}
    require('render.StoryStomp').Emit(fx,{10,0,20},1)
    V.assert(#fx.smoke==15 and chips==6,'original landing emits 15 radial dust and 6 chips')
    for _,smoke in ipairs(fx.smoke) do V.assert(Near(math.sqrt((smoke.pos[1]-10)^2+(smoke.pos[3]-20)^2),.6) and smoke.drag==2.2 and Near(smoke.grow,3.52),'source stomp dust radial origin and expansion') end
    fx.maxSmoke=15;require('render.StoryStomp').Emit(fx,{0,0,0},1);V.assert(#fx.smoke==15,'story dust honors shared bounded smoke budget')
    view:Dispose();scene:Dispose();V.finish()
end)
