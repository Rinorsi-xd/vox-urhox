local UI=require 'urhox-libs/UI'
local Focus=require 'ui.ReticleFocus'
local Target=require 'ui.ReticleTarget'
local R=require 'ui.ReticleDraw'
local D=require 'ui.SourceDraw'
local State=require 'ui.ReticleState'
local Coord=require 'core.Coord'
local Unit=require 'combat.CarUnit'
local Frame=UI.Widget:Extend('VoxTargetFocusAcceptance')
local scene=nil ---@type Scene?
local camera=nil ---@type Camera?
local actor=nil ---@type table?
local world={}
local root=nil ---@type Widget?
local view={}
local fixture={}
local stage='armed';local drawn={};local combatView=nil ---@type table?
local function Near(a,b,epsilon) return math.abs(a-b)<(epsilon or .12) end
local function Check(ok,text) V.assert(ok,'Focus parity: '..text) end
local function RefId(ref) return ref and ref.id or nil end
local function Capture(name)
    local image=Image:new();Check(graphics:TakeScreenShot(image),'actual target screenshot '..name)
    Check(image:SavePNG('docs/migration/evidence/target-focus-'..name..'.png'),'save target screenshot '..name);image:Dispose()
end
function Frame:Render(vg)
    D.HudFont(vg);local rect=self:GetAbsoluteLayout();local layout=State.Layout(rect.w,rect.h,false)
    local saved=R.Text;local savedD=D.Text;local calls={}
    R.Text=function(ctx,text,x,y,size,color,...)
        calls[#calls+1]={text=text,x=x,y=y,size=size,color=color}
        return saved(ctx,text,x,y,size,color,...)
    end
    D.Text=function(ctx,text,x,y,size,color,...)
        if text=='锁定'or text=='LOCK'then calls[#calls+1]={text=text,x=x,y=y,size=size,color=color}end
        return savedD(ctx,text,x,y,size,color,...)
    end
    Target.Render(vg,view,layout);R.Text=saved;D.Text=savedD;drawn[stage]=calls
end
function HoldTargetFocusRoot() if root then UI.SetRoot(root) end end
V.atFrame(2,function()
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    local file=File('tools/migration/source-target-focus.json',FILE_READ);fixture=cjson.decode(file:ReadString());file:Dispose()
    Check(fixture.baseline=='2b169a9964645f5f346a7158bcb14447f040814a','frozen source identity')
    scene=Scene();scene:CreateComponent('Octree');camera=scene:CreateChild('SourceFacingCamera'):CreateComponent('Camera')
    camera.node.position=Vector3(-120,7,33);camera.fov=48;camera.nearClip=.1;camera.farClip=2600;camera.autoAspectRatio=false
    for index,row in ipairs(fixture.cases) do
        camera.aspectRatio=row.w/row.h
        local refs={}
        for _,a in ipairs(row.actors) do
            local position=a.pos;refs[a.id]={id=a.id,team=a.team,alive=a.alive,spec=a.spec,name=a.name,Life=function()return a.life end,Position=function()return position end}
        end
        local cfg=row.scenario;local units={};for _,id in ipairs(cfg.units)do units[#units+1]=refs[id]end
        local session={scope=cfg.scope~=false,combat={player=refs.me},world={units=units},focusRef=refs[cfg.keep],aimRef=refs[cfg.direct]}
        if cfg.combatUnits then session.world.combatUnits={};for _,id in ipairs(cfg.combatUnits)do session.world.combatUnits[#session.world.combatUnits+1]=refs[id]end end
        if cfg.wall then session.aimHit={owner={type='wall'}}end
        local overlay={session=session,focusHold=refs[cfg.hold],focusHoldTime=cfg.holdT}
        local got=Focus.Resolve(overlay,cfg.dt or 1/60,camera,row.w,row.h)
        local expected=row.expected;local id=RefId(got);local want=type(expected.ref)=='string' and expected.ref or nil
        Check(id==want,'source selected target '..index..' '..row.name..' got '..tostring(id)..' wanted '..tostring(want))
        Check(RefId(session.focusRef)==(type(expected.focus)=='string' and expected.focus or nil),'source focus reference '..index)
        Check(RefId(overlay.focusHold)==(type(expected.hold)=='string' and expected.hold or nil),'source hold reference '..index)
        if got and type(expected.target)=='table' then
            local x,y,d=Focus.Project(camera,got:Position(),row.w,row.h)
            Check(x and Near(x,expected.target.x) and Near(y,expected.target.y) and Near(d,expected.target.distance),'actual native camera projection matches source '..index)
        end
    end
    local savedText,savedPoly,savedLine,savedWidth=R.Text,R.Poly,D.Line,R.Width
    for index,row in ipairs(fixture.plates)do
        local texts,segments,lines={},{},{}
        R.Text=function(_,text,x,y,size,color,align,_,medium,spacing)texts[#texts+1]={text=text,x=x,y=y,size=size,color=color,align=align,medium=medium,spacing=spacing}end
        R.Poly=function(_,points,color)segments[#segments+1]={points=points,color=color}end
        D.Line=function(_,x,y,ex,ey,color,width)lines[#lines+1]={x=x,y=y,ex=ex,ey=ey,width=width}end
        R.Width=function()return 40 end
        local target={x=960,y=540,half=row.half,hp=row.hp,ghost=1,distance=185.4,name='TARGET',arms=row.arms}
        local vg=UI.GetVG and UI.GetVG() or nil
        -- Plate owns only alpha push/pop; no context for this source geometry observation.
        local save,restore,alpha=nvgSave,nvgRestore,nvgGlobalAlpha
        nvgSave=function()end;nvgRestore=function()end;nvgGlobalAlpha=function()end
        Target.Plate(vg,{session={world={time=row.time}}},{k=row.k},target,1)
        nvgSave,nvgRestore,nvgGlobalAlpha=save,restore,alpha
        Check(#texts==5 and #segments==10 and #lines==3,'source target plate primitive counts '..index)
        for _,t in ipairs(texts)do if t.text~=' M'then
            local found=nil;for _,e in ipairs(row.expected.texts)do if e.text==t.text or t.text=='185' and e.text=='185 M'then found=e;break end end
            Check(found and Near(t.x,found.x)and Near(t.y,found.y)and Near(t.size,found.size),'source target text coordinates '..index..' '..t.text)
            if t.text:find('武装',1,true)then Check(t.color[2]==(row.arms<=1 and 210 or 138)and t.spacing==2 and not t.medium,'source arms warning/font '..index)end
            if t.text:find('HULL',1,true)then Check(t.color[2]==(row.hp<.3 and 210 or 138),'source low hull warning '..index)end
        end end
        for i,segment in ipairs(segments)do
            local kind=row.expected.segments[i];local expectedGreen=kind==''and(row.expected.blink and 210 or 59)or 255
            local expectedAlpha=kind=='bg'and 46 or 255
            Check(segment.color[2]==expectedGreen and segment.color[4]==expectedAlpha,'source low blink/white ghost segment '..index..':'..i)
        end
    end
    R.Text,R.Poly,D.Line,R.Width=savedText,savedPoly,savedLine,savedWidth
    local Base=require 'drive.TrackWorld'
    world=setmetatable({scene=scene,space=require('physics.Space').New(scene),time=10,fx={},viewEvents={},stats={},units={},RecordDamage=function()end,RecordKill=function()end},Base)
    world.env={stats={shots=0},castRay=function()end,lockables=function()return{}end,hit=function()end,explode=function()end}
    world.debris=require('combat.Debris').New(world.space)
    local data=require 'combat.ArenaData'
    actor=Unit.New(world,data.prefabs['blue:1:assault:1'],{name='Focus target',spawn={pos={120,7,75},yaw=0},team='red',combat=true,externalControl=true,autoRespawn=false})
    world.units={actor};camera.aspectRatio=graphics:GetWidth()/graphics:GetHeight()
    Check(actor.alive and actor.vehicle.body.native~=nil,'actual CarUnit native Bullet body')
    local session={scope=true,combat={player={alive=true,team='blue'}},world=world,camera={GetCamera=function()return camera end},weapons={LockInfo=function()end}}
    view={session=session}
    local function MoveCenter(fraction,depth)
        local desired={120-2*fraction*depth*math.tan(camera.fov*math.pi/360),7,33+depth}
        local old=actor:Position();local p=actor.vehicle.body.translation()
        actor.vehicle.body.setTranslation({x=p.x+desired[1]-old[1],y=p.y+desired[2]-old[2],z=p.z+desired[3]-old[3]})
        actor:SavePose();actor.previous=actor.current
    end
    MoveCenter(.12,42);Target.Update(view,.016)
    Check(session.focusRef==actor,'actual native CarUnit picked at .12 screen height without direct ray')
    MoveCenter(.24,42);Target.Update(view,.016)
    Check(session.focusRef==actor,'actual native CarUnit kept at .24 screen height')
    MoveCenter(.26,42);Target.Update(view,.016)
    Check(session.focusRef==nil and view.focus and view.focus.ref==actor,'actual native CarUnit outside keep range releases focus but preserves short hold')
    Target.Update(view,.51);Check(not view.focus,'actual native CarUnit focus hold expires after leaving screen gate')
    MoveCenter(.1,1200);session.focusRef=actor;Target.Update(view,.016)
    Check(session.focusRef==actor,'actual native CarUnit retained beyond one-thousand metres')
    session.focusRef=nil;view.focusHold=nil;Target.Update(view,.51)
    Check(not view.focus and not session.focusRef,'actual native CarUnit beyond one-thousand metres not newly picked')
    MoveCenter(0,42);session.aimRef=actor;Target.Update(view,.016);world.time=11;Target.Update(view,.016)
    Check(view.focus and view.focus.ref==actor and view.focus.arms==#actor.spec.weapons and view.focus.locked,'actual CarUnit target acquisition and armed count')
    combatView=require('render.CombatView').New(scene);combatView:Consume(world);combatView:Update(1,1/60)
    renderer:SetViewport(0,Viewport:new(scene,camera))
    local zone=scene:CreateChild('FocusZone'):CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-5000,-5000,-5000),Vector3(5000,5000,5000));zone.ambientColor=Color(.6,.6,.6)
    local light=scene:CreateChild('FocusSun'):CreateComponent('Light');light.lightType=LIGHT_DIRECTIONAL
    UI.UnregisterGlobalComponent('vox-loading-page');root=Frame{width='100%',height='100%',pointerEvents='none'}
    UI.SetRoot(root);SubscribeToEvent('PostUpdate','HoldTargetFocusRoot')
end)
V.atFrame(6,function()
    Capture('armed')
    local found=false;for _,t in ipairs(drawn.armed or{})do if t.text=='武装 ×'..#actor.spec.weapons then found=true end end
    Check(found,'actual NanoVG armed count drawn')
    while #actor.spec.weapons>1 do local id=actor.spec.weapons[#actor.spec.weapons].partId;actor:Destroy(id);actor:Flush()end
    combatView:Consume(world);combatView:Update(1,1/60)
    Check(actor.alive and #actor.spec.weapons==1,'actual weapon destruction rebuilds down to one')
    Target.Update(view,.016);stage='one'
end)
V.atFrame(9,function()
    Capture('one-weapon')
    local found=false;for _,t in ipairs(drawn.one or{})do if t.text=='武装 ×1'and t.color[2]==210 then found=true end end
    Check(found,'actual one-weapon yellow warning drawn')
    local id=actor.spec.weapons[1].partId;actor:Destroy(id);actor:Flush()
    combatView:Consume(world);combatView:Update(1,1/60)
    actor.bodyHp=actor.bodyHpMax*.2;world.time=11.22;Target.Update(view,.016);stage='low'
    Check(actor.alive and #actor.spec.weapons==0 and view.focus.arms==0 and view.focus.hp<.3,'actual zero weapons and low life reach target state')
    Check(view.focus.ghost>view.focus.hp,'actual damage white ghost retained')
end)
V.atFrame(12,function()
    Capture('low-unarmed')
    local arms,hull,lock=false,false,false
    for _,t in ipairs(drawn.low or{})do
        if t.text=='武装 ×0'and t.color[2]==210 then arms=true end
        if t.text:find('HULL',1,true)and t.color[2]==210 then hull=true end
        if t.text=='锁定'then lock=true end
    end
    Check(arms and hull and lock,'actual zero-arms/low-life warning and scoped lock label drawn')
    world.time=11.65;Target.Update(view,.1)
    Check(view.focus.ghost<1 and view.focus.ghost>=view.focus.hp,'actual white ghost decays after source .4 seconds')
    local held=actor;actor.alive=false;Target.Update(view,.016)
    Check(not view.focus and not view.session.focusRef,'dead actual target clears scope focus')
    held.alive=true;view.session.scope=true;view.session.aimRef=held;Target.Update(view,.016)
    view.session.scope=false;view.session.aimRef=nil;Target.Update(view,.2)
    Check(view.focus and not view.session.focusRef,'scope release clears focusRef but retains source aimHold')
    Target.Update(view,.31);Check(not view.focus,'source .5 second hold expires')
    root=nil;combatView:Dispose();actor:Dispose();world.debris:Clear();world.space:Dispose();scene:Dispose();scene=nil;V.finish()
end)
