-- Only the opening's independent audio scene survives the 700ms visual exit.
local M={}
---@type table|nil
local current=nil
function M.CancelAll()
 local previous=current;current=nil
 if previous then previous:Dispose() end
end
function M.Adopt(audio)
 if current==audio then return audio.active end
 M.CancelAll()
 if not audio.active or not audio.tail then return false end
 current=audio;return true
end
function M.Update(dt,focused)
 local active=current;if not active then return end
 active:Update(dt,focused)
 if not active.active then current=nil end
end
function M.Snapshot()
 local active=current
 if not active or not active.active then return {active=false,master=0,remainingWallMs=0,voicePlaying=0,sfxPlaying=0,musicPlaying=0} end
 local voice=0;local sfx=0;local music=0
 for _,slot in ipairs(active.voices) do if slot.source.playing then voice=voice+1 end end
 for _,slot in ipairs(active.sources) do if slot.source.playing then sfx=sfx+1 end end
 for _,slot in ipairs(active.music) do if slot.source.playing then music=music+1 end end
 return {active=true,master=active:MasterLevel(),remainingWallMs=math.max(0,active.tail.deadline-Time:GetSystemTime()),
  voicePlaying=voice,sfxPlaying=sfx,musicPlaying=music}
end
return M
