local ResourceData=require("core.ResourceData")
local MusicPlayer=require("audio.MusicPlayer")

local Motion=require 'combat.MvpMotion'
local Levels=require 'audio.AudioLevels'
-- 原配乐因版权问题移除；替换时填写资源路径，并同步更新 Mvp/Beats.json。
local M={MUSIC_PATH=false};M.__index=M
function M.New(scene,player)
    local self=setmetatable({},M);self.player=player;self.soundPath=M.MUSIC_PATH;self.position=0
    self.source=scene:CreateChild('MvpMusic'):CreateComponent('SoundSource');self.source.soundType='VoxMvpMusic'
    if self.soundPath then self.sound=assert(cache:GetResource('Sound',self.soundPath));self.sound.looped=true;self.source:Play(self.sound) end
    local beats=ResourceData.Read('Mvp/Beats.json');self.beats=beats.beats;self.duration=beats.duration
    self.cues=ResourceData.Read('Mvp/Cues.json');self.root=scene:CreateChild('MvpCues');self.slots={};self.cursor=0
    self:Update();return self
end
function M:Play(id,gain)
    local cue=self.cues[id];if not cue or not input.focus or input.minimized then return end
    self.cursor=self.cursor%4+1;local source=self.slots[self.cursor]
    if not source then source=self.root:CreateChild('Cue'..self.cursor):CreateComponent('SoundSource');source.soundType='VoxFeedback';self.slots[self.cursor]=source end
    source:StopImmediate();Levels.Play(source,assert(cache:GetResource('Sound',cue.path)),0,cue.gain*math.max(0,math.min(1,gain or 1))*.65,0,'sfx','feedback')
end
function M:Update(dt)
    if self.disposed then return end
    local p=self.player;local enabled=p.enabled and p.volume>0 and input.focus and not input.minimized
    self.source.gain=MusicPlayer.Gain(p.volume)
    Levels.PauseBus(self,'VoxMvpMusic',not enabled)
    if self.sound then self.position=self.source.timePosition
    elseif enabled then
        -- 无配乐时仍沿原节拍表推进动画；焦点和音乐开关沿用原来的暂停规则。
        self.position=(self.position+math.max(0,dt or 0))%self.duration
    end
    self.beat=enabled and (not self.sound or self.source.playing) and Motion.Beat(self.position,self.beats) or {pulse=0,bounce=0,lean=0,twist=0,index=-1}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.source:StopImmediate();self.source:Dispose();self.sound=nil
    Levels.ReleaseBuses(self,{'VoxMvpMusic'});if self.soundPath then cache:ReleaseResource('Sound',self.soundPath) end
    self.root:Dispose();for _,cue in pairs(self.cues) do cache:ReleaseResource('Sound',cue.path) end
end
return M
