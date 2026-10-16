local checks={}
local function check(ok,label) assert(ok,label);checks[#checks+1]=label end
for i,k in ipairs({'TAB','A','D','LEFT','RIGHT','T','N','BACKSPACE','R'}) do _G['KEY_'..k]=i end
local records={};local pending
package.loaded['combat.Matchmaker']={Record=function(...) records[#records+1]={...};return {saved=true} end}
package.loaded['ui.DialogHost']={Confirm=function(owner,title,text,yes,no)
    pending={yes=yes,no=no,text=text};owner.dialog={};return owner.dialog
end}
local A=dofile('scripts/combat/MatchActions.lua')
local function unit(name,team,alive,p,yaw)
    return {name=name,team=team,alive=alive,Position=function() return p or {3,4,5} end,
        vehicle={Yaw=function() return yaw or 0 end}}
end
local function battle(state)
    local b={rules={state=state or 'live'},player=unit('me','blue',false),roster={rating={red=1200}},mode='conquest',entries={}}
    b.session={app={store={}},Pause=function(self) self.pauses=(self.pauses or 0)+1 end}
    return b
end
local b=battle()
check(A.Key(b,KEY_TAB) and b.boardOn,'Tab opens on press')
check(A.Key(b,KEY_TAB) and not b.boardOn,'Tab closes on next press')
for _,key in ipairs({KEY_T,KEY_N,KEY_BACKSPACE}) do check(A.Key(b,key),'source blocks competitive key '..key) end
check(not A.Key(b,KEY_R),'reset remains handled by existing session')
local one=unit('one','blue',true);local two=unit('two','blue',true);local enemy=unit('red','red',true)
b.entries={{unit=enemy},{unit=b.player},{unit=one},{unit=two}}
check(A.Watched(b)==one,'source prefers first living ally over enemy')
check(A.Key(b,KEY_A) and A.Watched(b)==two,'negative index wraps to last ally')
check(A.Key(b,KEY_RIGHT) and A.Watched(b)==one,'right arrow cycles forward')
check(A.Key(b,KEY_D) and A.Watched(b)==two,'D cycles forward')
check(A.Key(b,KEY_LEFT) and A.Watched(b)==one,'left arrow cycles backward')
b.player.alive=true;check(not A.Key(b,KEY_A),'living player keeps driving A');b.player.alive=false
one.alive=false;two.alive=false;check(A.Watched(b)==enemy,'no allies falls back to living enemy')
enemy.alive=false;check(A.Watched(b)==nil and A.Pose(b,{0,0,0},.1)==nil,'empty spectator list is safe')
for _,yaw in ipairs({0,math.pi/2,math.pi,-math.pi/2}) do
    local p={13,8,-21};one=unit('watch','blue',true,p,yaw);b.entries={{unit=one}};b.spectate=0
    for _,dt in ipairs({0,1/60,.1,.25,1}) do
        local eye={19,3,27};local pose=A.Pose(b,eye,dt);local k=math.min(1,dt*4)
        local expected={p[1]-math.sin(yaw)*16,p[2]+7,p[3]-math.cos(yaw)*16}
        for i=1,3 do check(math.abs(pose.eye[i]-(eye[i]+(expected[i]-eye[i])*k))<1e-10,'source spectator axis '..i..' yaw '..yaw..' dt '..dt) end
        check(pose.target[1]==13 and pose.target[2]==9.5 and pose.target[3]==-21 and pose.name=='watch','source look target/name '..yaw..' '..dt)
    end
end
b=battle();A.ConfirmLeave(b)
check(b.session.dialog.matchLeave and b.session.pauses==1 and #records==0 and not b.session.wantsReturn,'confirmation has no premature loss/exit')
check(pending.text=='退出这局对战？本局按失败计算。','source leave text')
A.ConfirmLeave(b);check(b.session.pauses==1,'duplicate click does not replace pending confirm')
b.session.dialog=nil;A.ConfirmLeave(b);pending.yes()
check(#records==1 and records[1][2]=='red' and records[1][3]==1200 and records[1][4]==0 and records[1][5]==false,'forfeit uses source loss accounting without kills/MVP')
check(b.session.wantsReturn,'confirmed exit returns through existing session lifecycle')
A.Leave(b);check(#records==1,'forfeit is idempotent')
b=battle('over');b.result={saved=true};A.ConfirmLeave(b)
check(#records==1 and b.session.wantsReturn,'finished exit never records another result')
b=battle();A.Again(b);check(not b.session.app.restartBattle and not b.session.wantsReturn,'live match cannot rematch')
b=battle('over');b.result={saved=true};A.Again(b)
check(b.session.app.restartBattle=='conquest' and b.session.wantsReturn and #records==1,'rematch queues mode after return without recording twice')
return checks
