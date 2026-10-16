package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Near(a,b,name) Check(math.abs(a-b)<1e-8,name..': '..tostring(a)..' != '..tostring(b)) end
local vector={};vector.__index=vector
function Vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
function vector.__add(a,b) return Vector3(a.x+b.x,a.y+b.y,a.z+b.z) end
function vector.__sub(a,b) return Vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
function vector.__mul(a,b) return Vector3(a.x*b,a.y*b,a.z*b) end
VectorRight=Vector3(1,0,0);VectorUp=Vector3(0,1,0)
-- Production Vector3 exposes constants on its callable class.
local newVector=Vector3;Vector3=setmetatable({RIGHT=VectorRight,UP=VectorUp},{__call=function(_,...)return newVector(...)end})
MOUSEB_LEFT=1;MOUSEB_MIDDLE=4;MOUSEB_RIGHT=2;KEY_SHIFT=1;KEY_SPACE=2;KEY_ALT=3
local uiWidth,uiHeight,cssWidth,cssHeight,dpr=1920,1080,1920,1080,1
package.loaded['urhox-libs/UI']={GetViewportSize=function()return uiWidth,uiHeight end}
package.loaded['render.LiveryProjection']={};package.loaded['render.LiveryModel']={};package.loaded['core.Coord']={}
package.loaded['controls.TouchPreferences']={Get=function(app)return app.touchPrefs end}
package.loaded['controls.Wheel']={Zoom=function(dist,wheel,min,max)return math.max(min,math.min(max,dist*1.0012^-wheel))end}
graphics={GetWidth=function()return cssWidth*dpr end,GetHeight=function()return cssHeight*dpr end,GetDPR=function()return dpr end}
local held={};input={GetKeyDown=function(_,key)return held[key] or false end,GetKeyPress=function()return false end,focus=true,minimized=false,mousePosition={x=1000,y=500},mouseMoveWheel=0}
local Controls=dofile('scripts/controls/LiveryControls.lua')
local function Make(row)
    local basis=row and row.basis or {r={1,0,0},u={0,1,0}}
    local rotation=setmetatable({},{__mul=function(_,v)local b=v==VectorRight and basis.r or basis.u;return Vector3(-b[1],b[2],b[3])end})
    local camera={dist=row and row.distance or 20,minDist=2.5,maxDist=60,panMaxY=20,yaw=180-math.deg(.7),pitch=90-math.deg(1.24),target=Vector3(0,1.1,0),node={rotation=rotation},flight=true,autoSpin=true,Step=function()end}
    local session={app={camera=camera,car={livery={SetPreview=function()end}},touchPrefs={sens=row and row.sensitivity or 1}},sel=0,pick=false,list={{p={0,0,0},w=3,r=0}},records=0,edits=0,places=0}
    function session:List()return self.list end
    function session:Select(i)self.sel=i;self.pick=false end
    function session:Place()self.places=self.places+1;self.sel=1;self.pick=false end
    function session:Edit(fn)fn(self.list[self.sel]);self.edits=self.edits+1 end
    function session:Record()self.records=self.records+1 end
    function session:Update()end
    local c=Controls.New(session);c.Gizmo=function()return nil end;c.DecalAt=function()return 0 end;c.Surface=function()return nil end;c.Screen=function()return {x=500,y=300}end
    return c,session,camera
end
local function Event(kind,id,x,y)return {pointerType=kind,pointerId=id,button=MOUSEB_LEFT,x=x,y=y}end
for index,row in ipairs(goldens.rows)do
    for _,scale in ipairs({1,1.8})do
        cssWidth,cssHeight=row.width,row.height;uiWidth,uiHeight=cssWidth*scale,cssHeight*scale;dpr=scale==1 and 1 or 3
        local c,s,cam=Make(row)
        for n,step in ipairs(row.steps)do
            local a=step.action;local e=Event('touch',a[2],(a[3] or 0)*scale,(a[4] or 0)*scale)
            if a[1]=='down'then c:Down(e)elseif a[1]=='move'then c:Move(e)elseif a[1]=='up'then c:Up(e)else c:Update(0,false)end
            Near(cam.dist,step.dist,'distance '..index..'/'..n);Near(cam.yaw,step.yaw,'yaw '..index..'/'..n);Near(cam.pitch,step.pitch,'pitch '..index..'/'..n)
            Near(cam.target.x,step.target[1],'target X '..index..'/'..n);Near(cam.target.y,step.target[2],'target Y '..index..'/'..n);Near(cam.target.z,step.target[3],'target Z '..index..'/'..n)
        end
        Check(s.edits==0 and s.places==0 and s.records==0,'background gesture never edits sticker history')
    end
end
cssWidth,cssHeight,uiWidth,uiHeight,dpr=1920,1080,1920,1080,1
for _,priority in ipairs(goldens.priority)do
    local c,s,cam=Make();local kind=priority.kind;held[KEY_SPACE]=kind=='space'
    s.pick=(kind=='place' or kind=='miss') and 'held' or false
    s.list[3]={p={0,0,0},w=3,r=0};c.DecalAt=function()return kind=='decal' and 3 or 0 end
    c.Surface=function()return kind=='place' and {p={0,0,0},n={0,1,0}} or nil end
    c:Down(Event('touch',1,400,200))
    Check((c.drag and true or false)==priority.claimed,'actual source sticker priority '..kind)
    Check((s.places or 0)==priority.placed,'actual source sticker placement count '..kind)
    if kind=='decal'then Check(s.sel==priority.selected+1,'source zero-based decal selection maps to Lua index')end
    if priority.claimed then Check(next(c.touches)==nil,'claimed sticker contact never becomes camera contact')
    else Check(c.touches[1]~=nil,'unclaimed source hook enters background camera contacts')end
    if kind=='miss'then Check(s.pick=='held','background miss keeps held sticker')end
    c:Cancel();held[KEY_SPACE]=false
end
local c,s,cam=Make();c.DecalAt=function()return 1 end;c.Surface=function()return {p={1,2,3},n={0,1,0}}end
c:Down(Event('touch',1,400,200));c:Down(Event('touch',2,800,200));c:Move(Event('touch',2,900,200));c:Update(0,false)
Near(cam.dist,20,'second finger cannot pinch while sticker owns drag');Check(s.edits==0,'foreign finger cannot move sticker')
c:Move(Event('touch',1,410,210));c:Up(Event('touch',2,900,200));Check(s.records==0,'foreign release cannot commit decal history')
c:Up(Event('touch',1,410,210));c:Up(Event('touch',1,410,210));Check(s.edits==1 and s.records==1,'owning sticker release records exactly once')
for _,kind in ipairs({'scale','rotate'})do
    c,s,cam=Make();s.sel=1
    c.Gizmo=function()return {box=kind=='scale' and {{x=400,y=200}} or {},x=400,y=200,k=1}end
    c:Down(Event('touch',1,400,200));Check(c.drag.kind==kind and next(c.touches)==nil,'gizmo '..kind..' precedes camera')
    c:Move(Event('touch',1,420,220));c:Up(Event('touch',1,420,220));Check(s.edits==1 and s.records==1,'gizmo '..kind..' retains edit history')
end
for _,mode in ipairs({'blocked','focus','minimized','cancel'})do
    c,s,cam=Make();c:Down(Event('touch',1,400,200));c:Down(Event('touch',2,800,200));c:Move(Event('touch',1,410,220))
    local yaw,target=cam.yaw,cam.target
    if mode=='cancel'then c:Cancel()else input.focus=mode~='focus';input.minimized=mode=='minimized';c:Update(0,mode=='blocked')end
    Check(next(c.touches)==nil and #c.touchOrder==0 and c.touchX==0 and c.touchY==0,'lifecycle clears contacts and pending movement '..mode)
    c:Move(Event('touch',1,900,500));input.focus=true;input.minimized=false;c:Update(0,false)
    Near(cam.yaw,yaw,'late movement cannot orbit after '..mode);Near(cam.target.x,target.x,'pending pan cannot leak after '..mode)
end
c,s,cam=Make();c:Down(Event('mouse',1,400,200));c:Move(Event('mouse',1,420,210))
Near(cam.yaw,180-math.deg(.7)+math.deg(.1),'PC left drag still rotates immediately');c:Up(Event('mouse',1,420,210))
held[KEY_SHIFT]=true;c:Down(Event('mouse',2,400,200));c:Move(Event('mouse',2,420,210));Near(cam.target.x,.56,'PC Shift drag retains source pan');c:Up(Event('mouse',2,420,210));held[KEY_SHIFT]=false
input.mouseMoveWheel=100;c:Update(0,false);Near(cam.dist,20*1.0012^-100,'PC scroll retains pixel zoom');input.mouseMoveWheel=0
Check(s.edits==0 and s.records==0,'PC camera actions do not mutate decal history')
return checks
