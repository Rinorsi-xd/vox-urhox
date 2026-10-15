-- Frozen shared/audio/levels.js: independent persistent audio controls.
local M={KEY='vox.audio.v2',DEFAULT_LEVELS={sfx=.65,music=.75,voice=.6}}
local data={sfx=.65,music=.75,voice=.6,musicEnabled=true}
local listeners={sfx={},music={},voice={},musicEnabled={}}
local store=nil ---@type table|nil
local speaking=setmetatable({},{__mode='k'})
local sources=setmetatable({},{__mode='k'})
local kinds={VoxWeapons='sfx',VoxFeedback='sfx',VoxDriving='sfx',VoxStoryVoice='voice',VoxMatchVoice='voice'}
local function Finite(value)
 if type(value)~='number' then return false end
 local bits=string.unpack('<I8',string.pack('<d',value))
 return bits & 0x7ff0000000000000 ~= 0x7ff0000000000000
end
local function Scaled(slot) return slot.raw*data[slot.kind]/M.DEFAULT_LEVELS[slot.kind] end
local function ApplySources(key)
 for source,slot in pairs(sources) do if not key or slot.kind==key then
  local ok=pcall(function() source.gain=Scaled(slot) end);if not ok then sources[source]=nil end
 end end
end
local function Copy() return {sfx=data.sfx,music=data.music,voice=data.voice,musicEnabled=data.musicEnabled} end
local function Emit(key) for fn in pairs(listeners[key]) do fn(data[key]) end end
function M.Valid(value)
 if type(value)~='table' or type(value.musicEnabled)~='boolean' then return false end
 for key in pairs(M.DEFAULT_LEVELS) do local v=value[key];if not Finite(v) or v<0 or v>1 then return false end end
 return true
end
function M.Snapshot() return Copy() end
function M.Get(key) return data[key] end
function M.SetSpeaking(owner,active) speaking[owner]=active and true or nil end
function M.Speaking() for _ in pairs(speaking) do return true end;return false end
function M.MusicGain(value) return value<=0 and 0 or 10^(-36*(1-math.min(1,value))/20) end
function M.Save()
 if not store then return true end
 return store:Write(M.KEY,Copy(),M.Valid)
end
function M.Init(backend)
 store=backend
 local saved=store and store:Read(M.KEY,M.Valid)
 for key,value in pairs(M.DEFAULT_LEVELS) do data[key]=saved and saved[key] or value end
 data.musicEnabled=not saved or saved.musicEnabled~=false
 for key in pairs(listeners) do Emit(key) end
 ApplySources()
 return M
end
function M.Set(key,value)
 if not M.DEFAULT_LEVELS[key] or not Finite(value) then return false,'Invalid audio level' end
 data[key]=math.max(0,math.min(1,value));Emit(key);ApplySources(key);return M.Save()
end
function M.SetMusicEnabled(enabled)
 data.musicEnabled=enabled==true;Emit('musicEnabled');return M.Save()
end
function M.On(key,fn)
 assert(listeners[key] and type(fn)=='function','Invalid audio level subscription')
 listeners[key][fn]=true;fn(data[key])
 return function() listeners[key][fn]=nil end
end
function M.SetGain(source,gain,kind)
 kind=kind or kinds[source.soundType];assert(M.DEFAULT_LEVELS[kind],'Unclassified audio bus')
 local slot=sources[source] or {};slot.raw=gain;slot.kind=kind;sources[source]=slot;source.gain=Scaled(slot)
end
function M.RawGain(source) local slot=sources[source];return slot and slot.raw or source.gain end
function M.Play(source,sound,frequency,gain,pan,kind)
 kind=kind or kinds[source.soundType];assert(M.DEFAULT_LEVELS[kind],'Unclassified audio bus')
 local slot=sources[source] or {};slot.raw=gain or 1;slot.kind=kind;sources[source]=slot
 source:Play(sound,frequency or 0,Scaled(slot),pan or 0)
end
return M
