# Remaining audio gaps: targeted source audit

Follow-up: root authorized and the DrivingAudio source-loop candidate below
has now been implemented and CPU verified. See
`DRIVING_LOOP_RELEASE_2026_10_16.md`. Its new runtime acceptance remains open;
the original observations below describe the pre-edit target. Radio is owned
by another lane; do not treat its later candidate as accepted by this audit.

Read `CURRENT_EXECUTION.md` first. Frozen H5 remains
`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455` at
`.tmp/outgame-source-2026-10-15T12-35-57-243Z`. Root reports candidate
`35b14da3`; this audit reads current production source, not that package's
rendered or audible output. No production edit, GPU, build, commit or upload.

## 1. Driving loop release and fresh attack still differ

Source `shared/ui/uiSound.js:136-146` removes the active loop key immediately
when amount <= .005, fades for release .025, and schedules stop at five tau
(125 ms). A reactivation gets a fresh voice, with playback rate initially 1
and pan initially centered, smoothed over .12/.08 seconds.

Target `scripts/audio/DrivingAudio.lua:39-54` retains the same key/source,
stops only when gain < .0001, and initializes fresh pitch/pan directly to the
requested values. Reactivating while fading reuses the old voice. This affects
all five local and remote driving loops. WeaponAudio already has the corrected
release/restart implementation; do not reopen that completed work.

Recommendation: port the proven WeaponAudio active/tail ownership mechanism to
DrivingAudio, retaining driving bus, source cue values and spatial selection.
Verify 124/125 ms boundaries, stop/restart overlap, fresh rate/pan and focus
cleanup against actual frozen `sfx.setLoop`, followed by one public drive.

## 2. Battle radio is still a dry immediate voice

Source `shared/audio/radio.js:11-44,120-137` includes VOICE_MIX .4, the
300-3600 Hz radio band, peaking/drive/compression/wobble, hiss and key/reception
cues; speech starts at audio time now + .02 + .24 seconds.

Target `scripts/audio/MatchVoice.lua:37-40` immediately calls
`Levels.Play(...,.7)`, then advances ownership/card timers. The newly repaired
speaking owner correctly ducks music, but it does not add the radio signal
chain, audio lead or reception cues. Do not call the .7 versus .4 difference
an exact audible loudness ratio: the omitted DSP is nonlinear.

Recommendation: retain the current queue, cooldown and speaking-owner fix;
implement one shared Radio playback adapter with original lead/tail/cues.
Evaluate actual engine DSP support before adding filters. If unavailable,
preprocess fixed voice files with the frozen signal chain and keep source and
processed provenance; do not substitute a blanket volume reduction. Accept
on actual speech onset, interruption/cancellation, cues and listening.

## 3. Global sample voice limits are still separate module limits

Source `shared/ui/uiSound.js:73-85` shares one registry across UI, driving,
weapons, damage, rewards and battle/match flow: 10 one-shots, three per cue,
20 loops. Voice eviction protects battle/match flow cues.

Target retains separate pools: `WeaponAudio.lua:41` and
`CombatFeedbackAudio.lua:44` each allow 10; `UiSound.lua:28` creates another
10; `BattleFlow.lua:29` rotates through another 10; `DrivingAudio.lua:63`
has its own three mechanical voices. AudioLevels tracks gain/bus ownership,
but does not arbitrate these pools. Consequently source-wide concurrency and
priority behavior are absent. This is a proven policy difference, not proof
that these voices caused the measured main-thread freeze.

Recommendation: add a session-owned shared allocator for the source uiSound
sample family, with exactly the original caps/eviction protection and immediate
release on teardown. Keep IntroAudio and the separate source recovery player
outside that family. Test cross-module bursts and protected flow cue eviction.

## First live driving: do not repeat the already repaired diagnosis

`IntroBattle.lua:25` selects the feedback player; `:94-95` sends world view
events into the shared overlay. `OpeningHost.lua:155` uses the source easy
enemy health < .9 condition, and `:167-170` performs the source scripted finish.
Frozen `introSortie.js:169-176` uses the same health threshold and 15-second
fallback: the tutorial does not require naturally shooting all remaining HP.

CURRENT records the actual manifest-29283a2f natural run with real W movement,
LMB enemy damage, hit confirmation, damage numbers and confirmation audio.
That evidence supports the repaired path on that package; it does not accept
new candidate 35b14da3, every weapon, full visual parity or continuous audio.
The remaining freeze/audio starvation remains a separate measured FAIL owned
by root's current return-route profile. This audit finds no new source-proven
first-driving attack blocker and does not invent a replacement fix.
