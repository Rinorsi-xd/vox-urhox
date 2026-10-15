-- Original catalog/queue semantics; at most two compressed tracks are resident.
local Gate=require 'app.ResourceGate'
local Catalog=require('core.ResourceData').Read('UI/Music/Catalog.json')
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
local BUS='VoxMusic'
local serial=0
local function Clamp(v) return math.max(0,math.min(1,v)) end
function M.Gain(v) return v<=0 and 0 or 10^(-36*(1-Clamp(v))/20)*.8 end
local function Valid(v)
    if type(v)~='table' or type(v.volume)~='number' or v.volume~=v.volume or v.volume<0 or v.volume>1 then return false end
    if v.mode~='shuffle' and v.mode~='sequence' and v.mode~='repeat' then return false end
    if type(v.favorites)~='table' or type(v.last)~='table' then return false end
    for id,f in pairs(v.favorites) do if type(id)~='string' or f~=true then return false end end
    return type(v.enabled)=='boolean'
end
M.Valid=Valid
function M.New(store,backend)
    local self=setmetatable({},M);self:init(store,backend);return self
end
function M:init(store,backend)
    serial=serial+1;self.bus=BUS..serial
    self.store=store;self.backend=backend or cache;self.catalog=Catalog;self.byId={};self.pools={};self.bags={}
    self.libraryTracks=Catalog.tracks;self.volume=.75;self.enabled=true;self.playMode='shuffle';self.favorites={};self.last={}
    for _,track in ipairs(Catalog.tracks) do self.byId[track.id]=track;self.pools[track.group]=self.pools[track.group] or {};table.insert(self.pools[track.group],track) end
    local saved=store and store:Read('music',Valid)
    if saved then
        self.volume=saved.volume;self.enabled=saved.enabled;self.playMode=saved.mode
        for id in pairs(saved.favorites) do if self.byId[id] then self.favorites[id]=true end end
        for group,id in pairs(saved.last) do if self.byId[id] then self.last[group]=id end end
    end
    self.lastVolume=self.volume>0 and self.volume or .75;self.userPaused=false;self.unlocked=false;self.hidden=false
    self.libraryMode=false;self.time=0;self.serial=0;self.retryAt=0;self.errors={};self.failed={};self.history={}
    self.duckLevel=1;self.duck=1
    self.current=nil ---@type integer|nil
    self.pending=nil ---@type integer|nil
    self.scene=Scene();self.root=self.scene:CreateChild('Music')
    self.slots={}
    for i=1,2 do self.slots[i]={gate=Gate.New(self.backend),level=0,target=0} end
    self.unwatch={Levels.On('music',function(value)
        self.volume=value;if value>0 then self.lastVolume=value end
        for _,slot in ipairs(self.slots) do if slot.source then slot.source.gain=M.Gain(value)*slot.level*self.duckLevel end end
        self:PauseBus()
    end),
        Levels.On('musicEnabled',function(value) self.enabled=value;self:PauseBus() end)}
    self:PauseBus()
end
function M:Save()
    if not self.store then return end
    local ok,err=self.store:Write('music',{volume=self.volume,enabled=self.enabled,mode=self.playMode,favorites=self.favorites,last=self.last},Valid)
    if not ok then print('[MusicPlayer] '..err) end
end
function M:CanPlay() return not self.disposed and self.unlocked and self.enabled and self.volume>0 and not self.userPaused and not self.hidden end
function M:PauseBus()
    if self:CanPlay() then audio:ResumeSoundType(self.bus) else audio:PauseSoundType(self.bus) end
end
function M:Unlock() self.unlocked=true;self:PauseBus() end
function M:SetVolume(v)
    if type(v)~='number' or v~=v or v==math.huge or v==-math.huge then return end
    self.volume=Clamp(v);if self.volume>0 then self.lastVolume=self.volume;self:Unlock() end
    Levels.Set('music',self.volume)
    self:PauseBus();self.saveDelay=.3
end
function M:Resume()
    local changed=not self.enabled or self.volume==0
    self.enabled=true;self.userPaused=false;if self.volume==0 then self.volume=self.lastVolume end
    Levels.SetMusicEnabled(true);if self.volume>0 then Levels.Set('music',self.volume) end
    self:Unlock();if changed then self:Save() end
end
function M:SetPaused(paused) self.userPaused=paused;self:PauseBus() end
function M:SetEnabled(enabled)
    self.enabled=enabled==true;Levels.SetMusicEnabled(self.enabled);self:PauseBus();self:Save()
end
function M:SetPlayMode(mode)
    if mode~='shuffle' and mode~='sequence' and mode~='repeat' then return end
    self.playMode=mode;self:Save()
end
function M:Favorite(id)
    if not self.byId[id] then return end
    self.favorites[id]=not self.favorites[id] or nil;self:Save()
end
function M:SetLibraryPlaylist(tracks) self.libraryTracks=tracks;self.bags['music-box']=nil end
function M:SetLibraryMode(on)
    self.libraryMode=on
    if on then self.continuationId=nil;self.requestedId=nil
    else
        local slot=self.slots[self.pending or self.current]
        self.continuationId=self.requestedId or slot and slot.track and slot.track.id
    end
end
function M:Track() local slot=self.slots[self.current];return slot and slot.track end
function M:Position() local slot=self.slots[self.current];return slot and slot.source and slot.source.timePosition or 0 end
function M:Duration() local slot=self.slots[self.current];return slot and slot.sound and slot.sound.length or 0 end
function M:Seek(seconds)
    local slot=self.slots[self.current];if not slot or not slot.source or self.pending then return false end
    slot.source:Seek(math.max(0,math.min(self:Duration()-.05,seconds)));return true
end
function M:Level(slot)
    if not slot.fade then return slot.level end
    local t=Clamp((self.time-slot.fade.start)/2.4)
    return slot.fade.from+(slot.target-slot.fade.from)*t*t*(3-2*t)
end
function M:Fade(slot,target) slot.fade={start=self.time,from=self:Level(slot)};slot.target=target end
function M:Clear(index)
    local slot=self.slots[index];if not slot then return end
    slot.gate:Cancel();self.serial=self.serial+1;slot.token=self.serial
    local file=slot.track and slot.track.file
    if slot.source then slot.source:StopImmediate();slot.source:Dispose();slot.source=nil end
    slot.sound=nil;slot.track=nil;slot.fade=nil;slot.level=0;slot.target=0
    if file then self.backend:ReleaseResource('Sound',file,false) end
end
function M:Choose()
    local pool=self.libraryMode and self.libraryTracks or self.pools[self.group] or {}
    local current=self:Track();local id=current and current.id
    if self.requestedId then local chosen=self.byId[self.requestedId];self.requestedId=nil;return chosen end
    if self.libraryMode and self.playMode~='shuffle' then
        local index=0;for i,t in ipairs(pool) do if t.id==id then index=i;break end end
        for step=1,#pool do local t=pool[(index+step-1)%#pool+1];if not self.failed[t.id] then return t end end
        return
    end
    local group=self.libraryMode and 'music-box' or self.group;local bag=self.bags[group] or {};local allowed={}
    for _,t in ipairs(pool) do if not self.failed[t.id] then allowed[t.id]=true end end
    local rest={};for _,entry in ipairs(bag) do if allowed[entry] then rest[#rest+1]=entry end end
    if #rest==0 then
        for _,t in ipairs(pool) do if allowed[t.id] then rest[#rest+1]=t.id end end
        for i=#rest,2,-1 do local j=math.random(i);rest[i],rest[j]=rest[j],rest[i] end
    end
    local previous=allowed[id] and id or self.last[group]
    if rest[1]==previous and #rest>1 then local j=math.random(2,#rest);rest[1],rest[j]=rest[j],rest[1] end
    self.bags[group]=rest;return self.byId[rest[1]]
end
function M:Played(track)
    local group=self.libraryMode and 'music-box' or self.group;local rest={}
    for _,id in ipairs(self.bags[group] or {}) do if id~=track.id then rest[#rest+1]=id end end
    self.bags[group]=rest;self.last[group]=track.id
    self.history[#self.history+1]=track.id;if #self.history>50 then table.remove(self.history,1) end
    self:Save()
end
function M:Next()
    if not self:CanPlay() or not self.group then return false end
    self.advanceRequested=true
    local index=self.current==1 and 2 or 1;local slot=self.slots[index]
    if self.pending~=index and self:Level(slot)>0 then return true end
    if not self.libraryMode and not self.pending and not self.requestedId then self.continuationId=nil end
    local track=self:Choose()
    if not track then self.retryAt=self.time+5;self.advanceRequested=false;return false end
    self:Clear(index);self.pending=index;self.advanceRequested=false;slot.track=track
    local token=slot.token
    slot.gate:Start({track.file},function(ok,err)
        if self.disposed or slot.token~=token then return end
        local sound=ok and self.backend:GetResource('Sound',track.file) or nil
        if not sound then
            self.failed[track.id]=true;self.errors[#self.errors+1]={id=track.id,message=err or '音频解码失败'}
            print('[MusicPlayer] Unable to play '..track.id..': '..tostring(err));self:Clear(index)
            self.pending=nil;self.advanceRequested=true;self.retryAt=self.time+.5;return
        end
        slot.sound=sound;slot.source=self.root:CreateComponent('SoundSource');slot.source.soundType=self.bus
        slot.source:Play(sound,0,0)
        local old=self.slots[self.current];if old and old~=slot then self:Fade(old,0) end
        self.current=index;self.pending=nil;self:Fade(slot,1);self:Played(track);self:PauseBus()
        print('[MusicPlayer] '..track.id..' compressed='..tostring(sound.compressed)..' bytes='..sound.dataSize)
    end)
    return true
end
function M:PlayTrack(id)
    if not self.libraryMode or not self.byId[id] then return false end
    local allowed=false;for _,t in ipairs(self.libraryTracks) do if t.id==id then allowed=true end end
    if not allowed then return false end
    self:Resume()
    if self:Track() and self:Track().id==id and not self.pending then return true end
    if self.pending then self:Clear(self.pending);self.pending=nil end
    self.failed[id]=nil;self.requestedId=id;self.advanceRequested=true;self.retryAt=0;return self:Next()
end
function M:Previous()
    if not self.libraryMode then return false end
    if self:Position()>3 then return self:Seek(0) end
    local current=self:Track();local id=current and current.id
    for i=#self.history-1,1,-1 do
        for _,t in ipairs(self.libraryTracks) do if t.id==self.history[i] and t.id~=id then return self:PlayTrack(t.id) end end
    end
    local index=1;for i,t in ipairs(self.libraryTracks) do if t.id==id then index=i end end
    local prior=self.libraryTracks[(index-2+#self.libraryTracks)%math.max(1,#self.libraryTracks)+1]
    return prior and self:PlayTrack(prior.id) or false
end
function M:Status()
    if not self.unlocked then return '点击播放' end
    if not self.enabled or self.volume==0 then return '已静音' end
    if self.userPaused then return '已暂停' end
    if not self.current and #self.errors>0 then return '暂时无法播放' end
    if self.pending or self.advanceRequested then return '正在载入' end
    return '正在播放'
end
function M:Update(dt,group,hidden)
    local duck=not self.libraryMode and Levels.Speaking() and .5 or 1
    self.duck=duck;local response=duck<self.duckLevel and .12 or 1.2
    self.duckLevel=self.duckLevel+(duck-self.duckLevel)*(1-math.exp(-math.max(0,dt)/response))
    if self.disposed then return end
    if self.saveDelay then self.saveDelay=self.saveDelay-dt;if self.saveDelay<=0 then self.saveDelay=nil;self:Save() end end
    self.hidden=hidden==true;self:PauseBus();if self:CanPlay() then self.time=self.time+math.max(0,dt) end
    local destination=self.libraryMode and 'music-box' or group
    if self.group~=destination then
        self.group=destination
        local t=self:Track();local belongs=t and (self.libraryMode or t.id==self.continuationId or t.group==destination)
        local pending=self.slots[self.pending]
        if pending and not (self.libraryMode or pending.track.id==self.continuationId or pending.track.group==destination) then self:Clear(self.pending);self.pending=nil end
        self.advanceRequested=not belongs;self.retryAt=0
    end
    for i,slot in ipairs(self.slots) do if slot.source then
        slot.level=self:Level(slot);slot.source.gain=M.Gain(self.volume)*slot.level*self.duckLevel
        if slot.target==0 and slot.level==0 and self.current~=i and self.pending~=i then self:Clear(i) end
    end end
    if not self:CanPlay() then return end
    local slot=self.slots[self.current]
    if slot and slot.source and self.libraryMode and self.playMode=='repeat' and not slot.source.playing and not self.pending then
        slot.source:Play(slot.sound,0,M.Gain(self.volume)*slot.level*self.duckLevel)
    elseif not self.pending and self.time>=self.retryAt and (self.advanceRequested or not slot or not slot.source.playing or
        not self.continuationId and self:Duration()-self:Position()<2.6 and not (self.libraryMode and self.playMode=='repeat')) then self:Next() end
end
function M:Dispose()
    if self.disposed then return end
    for _,off in ipairs(self.unwatch) do off() end;self.unwatch={}
    self.disposed=true;self:Save();for i=1,2 do self:Clear(i) end
    self.current=nil;self.pending=nil;self.scene:Dispose();audio:ResumeSoundType(self.bus)
end
return M
