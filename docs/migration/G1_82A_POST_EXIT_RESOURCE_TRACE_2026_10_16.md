# 82a post-exit resource trace

Read-only review of `intro-natural-web-1600x900-manifest-82a41dd6-early-retirement` and actual Lua sources. Tutorial, StoryComms, StoryCommsCues, StoryRadio, MusicPlayer, CommsCard and TutorialPage currently match their frozen 82a bytes.

## Evidence boundary

CompleteFinish returned at 06:22:39.139 after 76ms inclusive. The 25-resource group completed at 39.592; the longest task was 39.664-40.345 (681ms), beginning about 525ms after CompleteFinish returned. The one-resource group completed at 40.342; audio-tail disposal logged at 40.347 with 0ms; MusicPlayer logged circuit-ready at 40.633. Logs do not provide group IDs/path lists or native symbol stacks. These timings do not prove an individual callback or resource operation caused the 681ms task.

## Tutorial group and concrete deferred work

`story/Tutorial.lua:30` constructs 29 unique paths: three Nono faces, 18 `Story/Tutorial/*.ogg` voices and eight Radio dependencies (Radio.json plus seven WAVs). ResourceGate filters paths through Exists before starting a download group. Three faces were prepared for the opening, and Radio.json was already loaded by StoryRadio; excluding those four gives exactly 25. This is a source/count-consistent attribution, not a recorded native group-to-path trace.

The 18 voices are T-01 through T-13 and T2-01 through T2-05. The seven WAVs are match_found_b, missile_close_a, objective_loss_a, loot_pickup_a, objective_gain_b, urgent_warning_a and match_victory_a, under `Story/Radio/`.

Tutorial.Start only starts rules. Tutorial.Prepare's completion callback only records failure; success sets the gate ready. On the first visible Tutorial.Update (`Tutorial.lua:102`), StoryComms.New creates the retained audio scene and two SoundSources if absent, creates StoryCommsCues, and indexes/normalizes all 18 voice texts. Say then prepares the first T-01 voice using async/background loading. In the fallback path there is no synchronous voice GetResource decode.

StoryCommsCues.New (`StoryCommsCues.lua:10`) checks its own group and requests seven BackgroundLoadResource jobs. Ready checks cache residency before Radio.New. Radio.New's seven GetResource calls (`StoryRadio.lua:18`) therefore normally hit resources already loaded; they are not evidence of seven synchronous decodes. The first successful cue additionally creates its SoundSource.

Concrete preparation candidates are: normalize/build the 18-entry index before first visibility; begin first-voice and seven-cue background preparation during a controlled earlier phase; move scene/source construction into a bounded preparation stage. Preserve shared-owner handoff, cancellation and no early sound. Queueing the seven background requests across frames can bound Lua/native submission work, but does not by itself bound native completion/finalization cost.

CommsCard's first visible draw lazily creates `UI/Comms/dots.png` with nvgCreateImage (`CommsCard.lua:46`), initializes three retained paragraphs (`:22`) and measures tutorial text (`:37`). Those are concrete draw-context preparation candidates. A valid signed opening hands off its already prepared Nono portrait through AdoptPortrait; do not claim that normal tutorial startup allocates another two portrait render targets. The log does not instrument the adoption result or first-draw cost, so exact savings are unmeasured.

## Music group and concrete deferred work

The observed track is `Sounds/Music/hangar-02-circuit-ready.mp3` (catalog ID hangar-02-circuit-ready). MusicPlayer.Next (`MusicPlayer.lua:176`) starts one selected track's gate only when CanPlay permits it. The callback only sets downloaded/error. PreparePending (`:145`) uses GetExistingResource then BackgroundLoadResource, with no synchronous GetResource fallback. The ready stage creates a SoundSource, calls Play at zero initial gain, updates fade/queue/history, saves state and pauses/resumes the bus before the 40.633 log.

An earlier preparation phase could retain the same selected pending track and allow its bytes/background resource work while playback remains paused. It must not call Played early, consume another shuffle selection, change continuation ownership, play sound or start fades prematurely. The existing code already places decode preparation outside the download callback. There is no source evidence that replacing a synchronous music decode is the missing fix.

To attribute the 681ms task, time exactly Tutorial first-visible New/Use/Say, cue Ready/Radio.New, CommsCard first Height/Draw, music PreparePending and native background-completion handling in a subsequent authorized run. This review did not add production instrumentation or run GPU/browser work.
