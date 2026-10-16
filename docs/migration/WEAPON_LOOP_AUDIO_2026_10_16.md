# Weapon loop audio continuation

Continues CURRENT_EXECUTION and G1-G6; does not restart G0. Frozen H5 is
`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This candidate follows
manifest7493837a; that package's runtime results do not validate this change.
Production is frozen for root's next immutable build. No GPU/native/browser,
service, commit or upload was performed by this agent.

## Source differences and repair

The actual reachable H5 player is `shared/ui/uiSound.js`, called by
`three/src/drive/testDrive.js:1118-1120,1198`. It is not the standalone sample
review player.

| Behavior | Frozen source | Previous Lua | This candidate |
| --- | --- | --- | --- |
| Live loop threshold | uiSound:138, amount > .005 | WeaponAudio used .0001/0 | .005, including exact boundary |
| Live gain rising/falling | uiSound:144, attack .08 | Falling used release | Both use attack .08 |
| Pitch | uiSound:146, .12 exponential, clamped .65-1.5 | Immediate | .12 exponential from 1 on each new voice |
| Stereo pan | uiSound:145, .08 exponential | Immediate | .08 exponential from center on each new voice |
| Stop | uiSound:140, release .025, stop at 5 tau = 125ms | Export default .1, stop below raw .0001 | .025 and fixed five-tau tail |
| Reactivation during tail | Old key removed, new voice starts | Same source resumed | Old tail survives while a new voice starts |
| Sniper firing | heavyWeaponMix:33, setLoop charge to zero | StopImmediate | Same release path as ordinary loop stop |
| Pause/exit | uiSound:65-70, stopDriving | Immediate | Still immediate, also clears released tails |

The affected cues are `mg_motor`, `sniper_charge`, `missile_flight`.
The old .1 release / amplitude threshold could retain a full-strength voice for
roughly .71-.76 seconds; the original schedules its end at .125 seconds.

`import-weapon-audio.mjs` now uses the original .025 default and regenerated
WeaponSounds.json against b276. All 18 original WAVs are byte-identical to the
frozen snapshot. All cue gains and trims, cooldowns, event routing and pitch
jitter are preserved. The existing ten-one-shot / three-per-cue policy remains.

Released loop voices use at most 20 reusable sources inside this module, matching
the source loop ceiling locally. The last loop record remains observable for
existing probes until its source is reused for a different cue; active records
are distinguished by `released`. No source is shared by concurrent voices.
The original globally shared ceiling across all sample modules is still OPEN.

## Verification

- `verify-weapon-loops.py`: **4518 PASS**, 7 scenarios, 133 sampled actions.
  Executes real frozen `uiSound` / `HeavyWeaponMix` in Node VM and real production
  WeaponAudio / AudioLevels in Lua 5.4 with audio, cache and scene adapters.
  Covers live rises/falls, .005 +/- epsilon, rate clamps, all three loops,
  124ms/125ms tail boundaries, repeated stop, overlapping restart, 20-source cap,
  sniper local versus remote fire, actual `WeaponAudio.Update` tail processing,
  pause/exit, 10 one-shot cap and same-cue 3 cap.
- Historical negative control is pinned to
  `9541dc59ef2f281cafa5126762a57550189e04dc:scripts/audio/WeaponAudio.lua`; it is rejected for
  immediate pitch/pan. At 16ms old rate/pan are 1.4/.8; frozen source and new
  Lua are 1.049930672382821/.1450153975376145.
- `verify-game-audio-context.py`: **851 PASS**, actually rerun after final
  production freeze; refreshed `evidence/game-audio-context-offline.json`.
- Scoped `git diff --check` passed. Git's LF/CRLF notices are not failures.
- `check-missiles.lua`'s old immediate-frequency assertion was updated to the
  original .12 envelope in absolute sample Hz. Native was not run; its old
  report is not a new acceptance result.

Reproduce using the bundled Python executable:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-weapon-loops.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-game-audio-context.py
```

`weapon-loops` / `evidence/weapon-loops-offline.json` is registered as current-batch
evidence in the unified audit. Exact source, production and checker hashes are
in that JSON. WeaponAudio SHA256 is
`12ec1b4b1a57fbac1197cf3d02800c64627c5b8a5d2ed1e8f3a693e01ecf342f`.

Actual `manifest-d47ba6e2.json` payload read from
`.tmp/outgame-cached-1792107779538` was independently hashed: WeaponAudio's
workspace, copied snapshot and emitted payload all equal the hash above;
WeaponSounds.json all equal
`91808aca9729d02e135e1c49c9fc1c88d2daf9e293d392c8a1b735b6a3ac2690`.
Both are blocking resources; sizes are 9510 and 5520 bytes. This is package
identity verification, not runtime acceptance. Registered report freshness was
actually checked after final checker refresh: **FRESH, 0 drift**, recorded in
`evidence/weapon-loop-report-freshness.json`.

## Acceptance boundary and remaining audio work

These are frame-boundary control-envelope comparisons. Lua applies controls on
engine updates, whereas WebAudio schedules AudioParams on the audio clock.
This does not prove sample-accurate automation, native DSP/headroom, audible
output, callback continuity, browser performance or sustained mobile performance.
Root must verify the new immutable Web package; no old package signs this code.

Already repaired volume/context/duck/voice-completion work remains covered by
GAME_AUDIO_CONTEXT, INTRO_AUDIO_ENVELOPE, INTRO_AUDIO_TAIL and INTRO_VOICE_CLOCK.
DrivingAudio currently has the live attack, .12 pitch and .08 pan curves; it was
not edited here. Its fixed tail/restart semantics remain separate follow-up work.
IntroAudio still lacks the original compressor and tv-cut lowpass; voice RMS
and precise audio-clock automation remain engine/API feasibility items. The
measured whole-opening callback starvation remains a distinct performance FAIL,
not something this loop repair claims to resolve.
