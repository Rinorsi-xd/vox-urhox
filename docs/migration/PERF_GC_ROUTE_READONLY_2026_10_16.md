# GC mode switch during pause and return: read-only attribution

Date: 2026-10-16. This audit changes no production code and runs no GPU test.

## Finding and boundary

The measured 49 ms spike is in `collectgarbage('incremental')`, called by
`CollectionCycle.EnterIncremental`, inside the render-target retirement update.
`gc.Advance` measured 0 ms in that frame. This attribution is supported by the
separately instrumented scopes; 0 ms means below the integer clock resolution,
not zero CPU work.

However, this is a pause/return-transition spike, not a representative frame of
continuous driving. Frame 4203 still carries `matchState=live` and loading closed,
but its fixed-step count is 0, as are frames 4201-4204. The nearest real observer
snapshots show released pointer lock, a pause menu followed by the leave-confirm
dialog, and only then the return loading cover. The match rule state remains
`live` throughout these menus.

Consequently this finding does not replace the separate sustained combat CPU
investigation. It does not identify the texture owners or justify changing their
lifetimes, resolution, appearance, or disposal rules.

## Evidence identity

- Actual ordinary Web build: manifest `fb3e73b7`, source branch `2026-10-15`, source
  commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Build identity target commit: `f94827b26fc12b707e6d6904d093e16358caaf41`; this is an
  identity base, not a claim that the tested workspace had no uncommitted edits.
- Route: `performance-route-match-1792161375245`, 30,000 ms driving action, actual
  production match route, 6 vehicles, crater map; route report PASS, no transport
  drops. This is functional timing coverage, not isolated FPS/device acceptance.
- Original monitor session:
  `evidence/performance-live/2026-10-16T14-34-01-126Z-53292-cb6dd3/session-39edb72b58eef00336881a10.jsonl`.
- Expanded frame data:
  `evidence/performance-route-match-1792161375245/timings.frames.csv`.
- Pointer/menu observations and wall times:
  `evidence/performance-route-match-1792161375245/runtime.log`.

## Observed sequence

The automation source `tools/migration/check-performance-routes-web.cjs:59`
holds forward and fire for the configured drive interval, releases both, presses
F10, waits 1,800 ms, collects evidence and a screenshot, then presses Escape and
clicks return and confirm (`:81`). Thus the return phase must be separated from
the driving sample even while the match rule state remains unchanged.

Actual runtime observations, not inferred texture identities:

| Log line | Wall time | Pointer and UI | Rule time / fixed steps | Retired RT count | Loading |
| --- | --- | --- | --- | --- | --- |
| 3128 | 22:39:59.424 | captured=true; ordinary battle buttons | 37.700 s / 2262 | 0 | closed |
| 3131 | 22:39:59.993 | first logged load of `ui/PauseMenu.lua` | not a state snapshot | not recorded | not recorded |
| 3134 | 22:40:00.158 | captured=false, pending=false; pause menu buttons visible | 38.383 s / 2303 | 0 | closed |
| 3137 | 22:40:00.305 | captured=false, pending=false; confirm/cancel, leaveConfirm=true | 38.517 s / 2311 | 4 | closed |
| 3138 | 22:40:00.417 | `[LoadingFlow] Open hangar` | not a state snapshot | not recorded | opening |
| 3140 | 22:40:00.440 | captured=false; leaveConfirm=false | 38.517 s / 2311 | 4 | cover |
| 3142 | 22:40:00.544 | captured=false | 38.517 s / 2311 | 4 | cover |
| 3143 | 22:40:00.595 | captured=false | 38.517 s / 2311 | 4 | cover |

These observer samples are not one-to-one with monitor frame numbers. The audit
does not assign a fabricated exact wall time or pointer snapshot to frame 4203.
The monitor's own successive frames establish the simulation stop and cover:

| Monitor frame | Frame / Lua ms | Fixed steps | Loading | Relevant measured scope |
| --- | --- | --- | --- | --- |
| 4198 | 94 / 69 | 3 | false | stability.Step self 42 ms; retirement.Update 0 ms |
| 4199 | 48 / 31 | 4 | false | retirement.Update 0 ms |
| 4200 | 53 / 37 | 4 | false | retirement.Update 0 ms |
| 4201 | 21 / 4 | 0 | false | retirement.Update 0 ms |
| 4202 | 24 / 4 | 0 | false | retirement.Update 0 ms |
| 4203 | 68 / 53 | 0 | false | retirement.Update 49 -> gc.Step 49 -> gc.EnterIncremental self 49; gc.Advance 0 |
| 4204 | 28 / 4 | 0 | false | retirement.Update 0 ms |
| 4205 | 18 / 1 | 0 | true, cover | retirement.Update 0 ms |

The 49/49/49 numbers nest; they are one interval, not 147 ms.

## Collection epochs and retirement queue

Only full monitor contexts contain GC state and pending counts. Compact per-frame
records do not. Therefore state at 4203 must not be invented from later contexts.

| Full-context frame | RT pending | Epoch | GC active | Context and observation |
| --- | --- | --- | --- | --- |
| 2843 | 0 | 3 | false | loading crater, prep; full collect 98 ms |
| 4198 | 0 | 3 | false | match rules live, physics ran 3 steps |
| 4218 | 4 | 3 | true | return cover, no physics; subsequent steps reuse the entered mode |
| 4266 | 4 | 4 | false | return loading; Advance 4 ms, Restore 73 ms, Step total 77 ms |
| 4288 | 4 | 4 | true | return loading; mode entered again at frame 4269, 33 ms |
| 4301 | 9 | 4 | false | hall installed under loading; 5 Retire calls recorded, Restore 70 ms |
| 4304 | 0 | 6 | false | hall loading; two Collect calls 96 ms inclusive, ReleaseSettledAssets 109 ms |

The original queue is empty late in combat, then four targets appear around the
pause-card replacement. There is no evidence here of old hangar targets staying
queued throughout combat. The return ends with pending count 0 and no live battle
units; this does not prove that every resource class is leak-free.

## Why mode entry runs here

`HangarApp.Update` calls `RenderTargetLifetime.Update` (`scripts/app/HangarApp.lua:656`)
before its later loading/gameplay gates. The retirement module has no scene or
pause scheduling policy. When pending is nonempty it runs a collector step every
third eligible update (`scripts/render/RenderTargetLifetime.lua:32`).

`CollectionCycle.Step` enters incremental mode only if no prior mode lease is
stored (`scripts/core/CollectionCycle.lua:28`), then performs the budgeted step.
It restores the prior collector mode after each completed cycle (`:43`). Thus
`Step(128)` is not a 128-unit bound on mode-entry or mode-restore time. The measured
49 ms is precisely the entry cost, and the later 73 ms restore plus 33 ms reentry
show that repeated mode transitions can also cost more than collector steps.

Frame 4203 can only reach this module's Step after finding a nonempty pending
queue. That follows from the executed code, independently of absent compact-frame
queue counts. It does not reveal which textures were in that queue.

## Owner attribution limit

No texture identifier, producer tag or callsite is logged for the four targets.
`retirement.Retire` timings are also absent in frames 4198-4218; the first mode
entry is captured later by Update. No owner identity can be recovered from a
count of four alone.

A concrete source path worth tracing next is pause-card replacement:
`PauseMenu -> DialogHost.Open/Close -> SourceModal.Destroy ->
SourceModalVisual.Dispose -> SourceLayer.ReleaseTexture`. Each modal owns two
SourceLayers, and each layer owns coverage and RGB textures, so this path can
retire four targets. `DialogHost.Open` destroys a closing dialog when replacing
its card. This is consistent with the observed zero-to-four change between the
pause and leave-confirm snapshots, but remains a hypothesis until callsite or
owner labels are captured. Do not label these targets as minimap or postprocess
textures, and do not change this visual path based only on that count.

## Minimal next experiment, preserving the finalizer fence

First record non-owning producer tags and retirement/clear/release epochs during
only the pause -> leave-confirm -> cover sequence. Avoid retaining RenderSurface
wrappers in diagnostics, which could itself prolong their lives. Capture pointer,
dialog and loading phase in the same frame context so future reports can classify
paused rule-live frames directly.

If changing scheduling, keep the weak-surface and completed-cycle fence intact.
Reducing `Step(128)` alone cannot address the measured mode-entry cost. A narrow
scheduling candidate can defer a *new* retirement collector cycle until a covered
loading boundary, leaving the texture pending and alive; it must not dispose
early or infer finalizer completion from elapsed frames. Such a policy needs a
bounded fallback for players who close many modals without loading, or pending
memory will accumulate. Do not ship an indefinitely deferred queue.

Another candidate is a scoped collector-mode lease acquired inside covered
loading and released inside a subsequent cover, so entry/restore do not happen
while the game is exposed. This is broader: changing generational/incremental
residency affects ordinary allocation behavior and heap growth and needs actual
Web measurements. Do not call the current EnterIncremental helper externally;
mode switching can execute finalizers and must remain inside the existing
reentrancy guard. No such production change was made in this audit.

Any candidate must pass existing real Lua finalizer tests: shared epochs,
mid-cycle owners, externally held borrowed surfaces, reentrant finalizers,
new owners queued during collect/restore, collector errors and full flush.
Then repeat the exact real route and compare mode-entry/restore timing, frame
pacing and pending counts, with sustained driving and pause/return reported
separately. FPS or Snapdragon 845 sustained 30 FPS is not established by this
read-only attribution.
