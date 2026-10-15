local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Marks=require 'ui.UnitMarkState'
local Overlay=require 'ui.DriveOverlay'
local Feedback=require 'ui.DriveFeedback'
local Unit=require 'combat.CarUnit'
local Data=require 'combat.ArenaData'
local Frame=UI.Widget:Extend('UnitMarksAcceptance')
local root=nil ---@type Widget?
local scene=nil ---@type Scene?
local world={} ---@type table
local units={};local overlay={};local session={};local drawn={};local stage='full'
local function Near(a,b) return math.abs(a-b)<1e-7 end
local function Capture(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'GPU ordinary marks '..name)
 local f=assert(io.open('.tmp/unit-marks-evidence.txt'));local out=f:read('*a');f:close()
 V.assert(image:SavePNG(out..'/'..name..'.png'),'save ordinary marks '..name);image:Dispose()
end
function Frame:Render(vg)
 D.HudFont(vg);local rect=self:GetAbsoluteLayout();D.Rect(vg,0,0,rect.w,rect.h,{20,27,32,255})
 local texts,lines={},{};local text,line=D.Text,D.Line
 D.Text=function(ctx,value,x,y,size,color,font,...)
  texts[#texts+1]={text=tostring(value),x=x,y=y,size=size,color=color,font=font};return text(ctx,value,x,y,size,color,font,...)
 end
 D.Line=function(ctx,x,y,x1,y1,color,width)
  lines[#lines+1]={x=x,y=y,x1=x1,y1=y1,color=color,width=width};return line(ctx,x,y,x1,y1,color,width)
 end
 local ok,err=pcall(Feedback.Render,overlay.layer,vg);D.Text,D.Line=text,line;assert(ok,err)
 drawn[stage]={texts=texts,lines=lines}
end
function HoldUnitMarksRoot() if root then UI.SetRoot(root) end end
local function HasText(name,color)
 for _,t in ipairs(drawn[stage].texts) do if t.text==name and (not color or t.color[1]==color[1] and t.color[2]==color[2] and t.color[3]==color[3]) then return true end end
 return false
end
V.atFrame(2,function()
 local f=assert(io.open('.tmp/source-unit-marks.json'));local fixture=cjson.decode(f:read('*a'));f:close()
 V.assert(fixture.baseline=='2b169a9964645f5f346a7158bcb14447f040814a','frozen source unit marks identity')
 local states=Marks.New();local enemy={};local previous=0
 for _,row in ipairs(fixture.rows) do
  if row.k~=previous then states=Marks.New();previous=row.k end
  local hp,ghost,low,dim=Marks.Read(states,{ref=enemy,health=row.health,enemy=true},row.now)
  V.assert(Near(hp,row.health) and Near(ghost,row.ghost),'actual source ghost curve '..row.now..' scale '..row.k)
  local group=row.groups[1]
  V.assert((group.cls:find(' low',1,true)~=nil)==low and (group.cls:find(' dim',1,true)~=nil)==dim,'actual source low/blink states')
  V.assert(group.pct==math.ceil(hp*100)..'%','actual source percentage rounds up')
  for i=0,9 do V.assert(Marks.Segment(i,hp,ghost)==group.segments[i+1],'actual source ten segment classification') end
  local ally=row.groups[2];V.assert(ally.cls=='mk ally' and type(ally.pct)~='string','source allies have no low blink/percentage')
 end
 states=Marks.New();local ref={}
 for _,row in ipairs(fixture.ghostRows) do V.assert(Near(Marks.Ghost(states,ref,row.hp,row.at),row.expected),'actual source strict ghost timing and tiny-hit threshold '..row.at) end
 scene=Scene();scene:CreateComponent('Octree')
 local Space=require 'physics.Space';local Base=require 'drive.TrackWorld'
 world=setmetatable({scene=scene,space=Space.New(scene),time=10,fx={},viewEvents={},stats={},units={},metrics={pending={}},RecordDamage=function()end,RecordKill=function()end},Base)
 world.env={stats={shots=0},castRay=function()end,lockables=function()return{}end,hit=function()end,explode=function()end}
 world.debris=require('combat.Debris').New(world.space)
 for i,entry in ipairs({{name='Player',team='blue',x=0,external=true},{name='ENEMY',team='red',x=-22},{name='ALLY',team='blue',x=22}}) do
  local unit=Unit.New(world,Data.prefabs['blue:1:assault:1'],{name=entry.name,spawn={pos={entry.x,4,80},yaw=0},team=entry.team,combat=true,externalView=entry.external,externalControl=true,autoRespawn=false})
  units[i]=unit;world.units[#world.units+1]=unit
  V.assert(unit.alive and unit.vehicle.body.native~=nil,'actual CarUnit native body '..entry.name)
 end
 local cameraNode=scene:CreateChild('MarkCamera');cameraNode.position=Vector3(0,25,-60);cameraNode:LookAt(Vector3(0,7,80))
 local camera=cameraNode:CreateComponent('Camera');camera.fov=48;camera.farClip=1000
 session={world=world,combat={player=units[1]},pointer={captured=true},camera={GetNode=function()return cameraNode end,GetCamera=function()return camera end},weapons=units[1].weapons}
 local fonts=require('ui.SourceFonts').Resolve()
 UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}});root=Frame{width='100%',height='100%',pointerEvents='none'}
 overlay=Overlay.New(session,root,{hit=0});overlay.layer.Render=function()end
 overlay:Update(0);UI.SetRoot(root);SubscribeToEvent('PostUpdate','HoldUnitMarksRoot')
 V.assert(#overlay.tags==2 and overlay.tags[1].enemy and not overlay.tags[2].enemy,'actual overlay filters player and assigns team colors')
 for _,t in ipairs(overlay.tags) do
  local p=t.unit:Position();local point=Marks.Point(t.unit)
  V.assert(Near(point[2],p[2]+t.unit.spec.bounds.max[2]-t.unit.vehicle.com[2]+1.2),'actual source mark uses bounds max minus COM height')
  local engine=require('core.Coord').Vec(table.unpack(point))
  V.assert(math.abs(t.dist-(engine-cameraNode.position):Length())<.001 and t.visible,'actual projected anchor distance and visibility')
 end
end)
V.atFrame(4,function()
 Capture('full');V.assert(HasText('ENEMY') and HasText('ALLY') and HasText('100%') and not HasText('Player'),'real GPU source mark names enemy percentage and player exclusion')
 local enemy=units[2];enemy:HurtHull(enemy.bodyHpMax*.74,enemy:Position())
 enemy:Damage(enemy.bp:CoreParts()[1].id,1,enemy:Position());overlay:Update(0);stage='hit'
 V.assert(enemy.alive and enemy:Life()<.3 and overlay.tags[1].hit,'actual CarUnit damage enters low HP and hit state')
end)
V.atFrame(7,function()
 Capture('hit');V.assert(HasText('ENEMY',{255,255,255}) and HasText('26%',{255,255,255}),'actual source hit overrides low yellow text with white')
 local lost=0;for _,line in ipairs(drawn.hit.lines) do if Near(line.y,overlay.tags[1].y) and line.color[1]==255 and line.color[2]==255 and line.color[3]==255 and line.color[4]==255 then lost=lost+1 end end
 V.assert(lost>0,'actual GPU ghost shows bright lost segments after CarUnit damage')
 world.time=world.time+.2;overlay:Update(0);stage='low'
end)
V.atFrame(10,function()
 Capture('low');V.assert(HasText('26%',{255,210,74}) and HasText('ALLY',{159,243,226}),'low hostile percentage yellow while ally stays cyan')
 units[2]:Heal(1);overlay:Update(0);stage='healed'
end)
V.atFrame(13,function()
 Capture('healed');V.assert(HasText('100%',{255,138,128}),'actual CarUnit healing immediately restores full enemy percentage')
 for _,t in ipairs(drawn.healed.texts) do V.assert(t.font=='vox-hud','all ordinary mark text uses migrated HUD font') end
 local cached=overlay.tags[2];table.remove(world.units,3);overlay:Update(0)
 V.assert(#overlay.tags==1,'removed actual unit leaves the active mark list')
 world.units[#world.units+1]=units[3];overlay:Update(0)
 V.assert(#overlay.tags==2 and overlay.tags[2]==cached,'newly registered actual unit gets mark with cached entry reuse')
 local camera=session.camera:GetNode();camera.position=Vector3(0,25,-1000);overlay:Update(0)
 V.assert(not overlay.tags[1].visible and not overlay.tags[2].visible,'actual overlay source 260 metre range hides distant units')
 for _,u in ipairs(units) do u:Dispose() end
 world.debris:Clear();world.space:Dispose();root=nil;scene:Dispose();V.finish()
end)
