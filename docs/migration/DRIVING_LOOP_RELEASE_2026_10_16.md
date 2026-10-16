# Driving loops: source release and fresh voice ownership

Continues CURRENT; frozen source is 10/15
`b276064942ae09c0227ec28d4cfda1d5ff006455`. This is a candidate after root's
35b14da3 package. It has not been built or accepted by an old runtime result.

## Production

Only `scripts/audio/DrivingAudio.lua` changed in this lane. It now releases a
loop at amount <= .005, keeps its original .025-second exponential tail,
and retires it at five tau (125 ms at observed frame boundaries). A restart
allocates a fresh voice while the old tail finishes. Fresh rate starts at 1
and pan at center, retaining original .12/.08-second smoothing. Source slots
are reused up to a local ceiling of 20 and all active/tail sources are stopped
on pause, focus loss, mute and disposal. Last released records remain visible
for existing probes, identified by `released`; they do not own new playback.

The five original cues, samples, gains, attack/release constants, local/remote
mix selection, spatial attenuation and player input are preserved. Radio DSP,
global cross-module voice arbitration and WeaponAudio are not changed here.

SHA256: `ab998edb85e18b88422e722f47881f5aaaef8963f41d06fa39f6fd0e3a4a5ec9`.

## Actual CPU verification

`source-driving-loops.cjs` loads the frozen, manifest-byte-verified actual
uiSound and drivingMix modules in Node VM. `verify-driving-loops.py` executes
the current actual DrivingAudio/AudioLevels/DrivingMix in Lua 5.4 with adapters
at the native sound/input/cache boundary.

- 12 scenarios / 234 sampled actions / 7717 checks PASS, including all five
  local and remote loops, exact .005 boundaries, 124/125 ms tail boundaries,
  repeated release, overlapping restart, pool reuse/cap, actual Update with
  parts disappearing on a nonzero timestep, focus/mute/disposal and original
  sample bytes/gains.
- Seven negative controls rejected the saved actual pre-edit production,
  immediate pitch, immediate pan, early stop, late stop, resuming the old
  released source, and loss of the source bound. Original pre-edit code is
  preserved and SHA-pinned in
  `evidence/history/DrivingAudio-before-source-loop-repair-20261016.lua`.
- Existing `verify-game-audio-context.py` actually rerun: 851 PASS / 96 cases.
  Its current report now associates the new DrivingAudio hash. Search found
  no other active offline report associating this production file.
- Scoped `git diff --check` passed. No native, browser, GPU, build, commit or
  upload was run by this lane.

Controls compare simultaneous voices by their key and relative per-key start
order: Lua local/remote traversal order is different from JS, so this does not
claim a shared global allocator. All sources play at absolute sample Hz.
Frame-boundary agreement does not prove sample-accurate audio-clock scheduling,
audible output, Web callback continuity, DSP or mobile performance.

## Root's public runtime command

After updating `.tmp/outgame-prepare-cached.json` to the new immutable package
and starting its QA service:

```powershell
$env:VOX_QA_PORT='<new-package-QA-port>'
$env:VOX_QA_CASE='pc'
$env:VOX_QA_TAG='manifest-<new-package>-driving-loops'
node tools/migration/check-driving-audio-web.cjs
```

The existing checker verifies package identity and uses real public hall T,
pointer capture, W travel >1 m and speed >2, actual idle/load playback, Esc
release, return disposal and a second trial/re-entry. For the existing 20:9
touch route, use `VOX_QA_CASE='phone-landscape'` (or both names separated by a
comma). This does not accept exact tail audio timing or listening quality.

Current evidence: `evidence/driving-loops-offline.json` and refreshed
`evidence/game-audio-context-offline.json`. Root owns unified audit registration
and all live verification.
