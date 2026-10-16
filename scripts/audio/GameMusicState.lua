-- Frozen shared/audio/gameMusic.js state, separate from queue/RNG ownership.
local Levels=require 'audio.AudioLevels'
local M={}
function M.Resolve(drive,shell,introActive,modalOpen,disabled)
 local matching=drive.matchStarting==true
 local driving=(drive.active or drive.pausedDrive) and not matching
 local controller=drive.modeController or {}
 local briefing=controller.intro~=nil and controller.intro~=false
 local atMenu=modalOpen or drive.pausedDrive or drive.active and not (drive.input and drive.input.locked) or controller.rules and controller.rules.state=='over'
 local screen=shell.screen or 'home'
 local scene=driving and (drive.mapId=='salvage' and 'salvage' or drive.mapId=='test' and 'training' or 'drive-combat') or 'hangar'
 local duck=math.min(matching and .4 or 1,briefing and .25 or Levels.FeedbackActive() and .45 or atMenu and .5 or drive.firing and .63 or 1)
 if Levels.Speaking() then duck=math.min(duck,.5) end
 return {scene=not disabled and scene or nil,destination=driving and ('drive:'..drive.mapId..':'..(drive.pausedDrive and 'edit' or 'play'))
  or shell.storyPage and shell.storyPage.visible and 'story' or 'screen:'..(screen=='edit' and 'home' or screen),
  matching=matching,paused=disabled or introActive or controller.mvpShow and not controller.mvpShow.cleared or false,
  duck=duck,briefing=briefing,introActive=introActive==true}
end
function M.FromApp(app,home)
 local session=app.mode=='trial' and app.trial
 local flow=app.loadingFlow
 local matching=flow and flow.active and flow.match~=nil and not flow.cancelled and not flow.failed
 local editing=session and session.endless and session.endless.run.state=='editing'
 local controller=session and session.combat
 local intro=session and session.intro and not session.intro.done and session.intro or nil
 local mvp=session and session.battle and session.battle.mvpShow
 local rules=controller and controller.rules
 local over=rules and (rules.state=='over' or rules.finished)
 local mapId=session and session.map.id or 'test'
 if mapId=='trial' then mapId='test' elseif session and session.map.storyLevel then mapId=session.map.storyLevel==5 and 'engine-pit' or 'crater' elseif mapId=='endless' then mapId='crater' end
 local dialog=session and session.dialog or home and home.dialog
 -- The source audio panel previews the normal music level; driving pointer
 -- release and paused editing still apply their independent menu attenuation.
 local modalOpen=type(dialog)=='table' and not dialog.sourceAudioSettings or home and home.newOpen==true
 return M.Resolve({active=session~=nil and session~=false,pausedDrive=editing,mapId=mapId,matchStarting=matching==true,
  input={locked=session and session.pointer and session.pointer.captured},firing=session and session.firing,
  modeController={intro=intro,rules=over and {state='over'} or nil,mvpShow=mvp and {cleared=mvp.done}}},
  {screen=home and home.tab or 'home',storyPage={visible=home and home.tab=='story'}},
  app.opening and app.opening.active==true,modalOpen)
end
return M
