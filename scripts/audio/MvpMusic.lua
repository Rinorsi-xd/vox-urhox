local ResourceData=require("core.ResourceData")
local MusicPlayer=require("audio.MusicPlayer")

local Motion=require 'combat.MvpMotion'
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.New(scene,player)
    local self=setmetatable({},M);self.player=player;self.sound=assert(cache:GetResource('Sound','Mvp/music.mp3'))
    self.sound.looped=true;self.source=scene:CreateChild('MvpMusic'):CreateComponent('SoundSource');self.source.soundType='VoxMvpMusic';self.source:Play(self.sound)
    self.beats=ResourceData.Read('Mvp/Beats.json').beats
    self.cues=ResourceData.Read('Mvp/Cues.json');self.root=scene:CreateChild('MvpCues');self.slots={};self.cursor=0
    self:Update();return self
end
function M:Play(id,gain)
    local cue=self.cues[id];if not cue or not input.focus or input.minimized then return end
    self.cursor=self.cursor%4+1;local source=self.slots[self.cursor]
    if not source then source=self.root:CreateChild('Cue'..self.cursor):CreateComponent('SoundSource');source.soundType='VoxFeedback';self.slots[self.cursor]=source end
    source:StopImmediate();Levels.Play(source,assert(cache:GetResource('Sound',cue.path)),0,cue.gain*math.max(0,math.min(1,gain or 1))*.65,0,'sfx','feedback')
end
function M:Update()
    if self.disposed then return end
    local p=self.player;local enabled=p.enabled and p.volume>0 and input.focus and not input.minimized
    self.source.gain=MusicPlayer.Gain(p.volume)
    if enabled then audio:ResumeSoundType('VoxMvpMusic') else audio:PauseSoundType('VoxMvpMusic') end
    self.beat=enabled and self.source.playing and Motion.Beat(self.source.timePosition,self.beats) or {pulse=0,bounce=0,lean=0,twist=0,index=-1}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.source:StopImmediate();self.source:Dispose();self.sound=nil
    audio:ResumeSoundType('VoxMvpMusic');cache:ReleaseResource('Sound','Mvp/music.mp3')
    self.root:Dispose();for _,cue in pairs(self.cues) do cache:ReleaseResource('Sound',cue.path) end
end
return M
