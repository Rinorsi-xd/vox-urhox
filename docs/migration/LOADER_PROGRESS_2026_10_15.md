# Loading progress watchdog continuation

This continues G0/G6 shared loading work, not a restarted baseline audit.
Source is `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`.

## Observed failure

The 6d natural salvage run bought the actual original T5 Scorpion (1557 parts)
through the real workshop and inventory. Downloads finished (1023/1023), but
the resources phase failed with `Scene loading timed out` while native resource
preparation was still advancing. It spent 115.399 seconds downloading and
98.389 seconds preparing before that failure. This was a real production
watchdog failure, not merely the automation's wait deadline.

## Production fix

`app/SceneLoader.lua` retains the 90-second stall timeout. Download bytes/files,
successful native resource preparation, scene async progress, and increasing
per-stage preparation checkpoints refresh it. Repeating the same checkpoint
does not refresh it. Changing phase starts a new stall interval. Cancellation,
partial candidate cleanup, visible loading presentation and retry remain in
the existing owner.

`app/LoadingFlow.lua` shows the actual prepared resource count during that
phase. The loader does not announce readiness until installation and the
existing rendered-frame warmup complete.

## Exact evidence

- `evidence/loader-progress-2026-10-15T07-53-18-330Z`: 6/6 PASS;
  Lua/resource/engine errors 0. Actual native resource warming advances over
  320 simulated seconds; real candidate scene/coroutine checkpoints can
  complete after 90 total seconds. Stalled resources, repeated checkpoints
  and unchanged async progress still fail and clean up.
- The first fixture skipped `Loader:Load` initialization, causing a nil
  `prepareTotalMs`; its 2 assertions are not a completed PASS. Preserved in
  `evidence/loader-progress-2026-10-15T07-50-08-895Z`.
- Full shared loading-flow regression: 772/772 functional PASS,
  Lua/resource/engine errors 0, `evidence/loading-flow-native.json`.
  This wrapper's 5000 ms guard is functional only, not a performance threshold.
- An earlier full regression let a fake camera-only wing marker enter real
  aerodynamic physics (`area=nil`), then failed to restore the fixture. Its
  errors and assertions are retained in
  `evidence/loading-flow-2026-10-15T07-54-16-failed-fixture`.
  The camera branch now uses actual `TrialSession:Update(0)` so that marker
  selects the camera branch without advancing simulation. Production wing
  physics was not weakened to tolerate malformed specs.
- Full resource cancellation/retry/native environment preparation regression:
  52/52 functional PASS, Lua/resource/engine errors 0,
  `evidence/resource-loading.json`. Native preparation used 267 slices, with
  a 93 ms worst slice despite the 3 ms cooperative target; this is not smooth
  Web loading evidence. The prior 51/52 run expected the historical 0.9 m
  boulder radius. Frozen source `shared/combat/tuning.js` instead sets
  `TERRAIN.minObstacleRadius=1.6`; the expectation now uses that verified
  source value. The old failure is preserved in
  `evidence/resource-loading-2026-10-15T08-00-old-radius-fixture`.
- New immutable Web package PC shared flow: 9/9 PASS, game/probe errors 0,
  `evidence/loading-battle-manifest-d6764c9c-2026-10-15T07-59-51-154Z`.
  Real failure return, retry, rendered readiness, browser pointer lock, smooth
  reversible wheel zoom, held-throttle driving, equipped weapon firing and
  return to hall all executed. Trial and loading screenshots were inspected.
  Four optional engine/library Windows archive requests returned 404 before
  normal individual-resource fallback; no required-resource failure is hidden.
- Same immutable package, real 20:9 touch flow: 7/7 PASS, game/probe errors 0,
  `evidence/loading-battle-manifest-d6764c9c-2026-10-15T08-07-30-447Z`.
  Actual CDP two-finger spread follows the source 2/3 distance ratio; inverse
  pinch restores distance and releases both contacts. Failure return, rendered
  readiness and return to hall also pass. Loading/trial screenshots inspected.
  The earlier fixture expected a removed zoom button and failed after four
  checks; preserved in the 08-03-09 report. No production button was invented
  to satisfy it. Four optional archive 404 fallbacks remain disclosed above.

## Immutable package boundary

Included in `manifest-d6764c9c.json`, snapshot
`.tmp/outgame-cached-1792051106196`, script fingerprint
`a7028dff4185d6a4915cd887f30231c54ac1429b71bde132310b3542ce193d81`.

Real Web T5 loading and natural extraction are in progress on this package.
The native checks do not close natural extraction, Web memory exhaustion,
loading smoothness, mobile sustained performance or the entire G6 stage.
