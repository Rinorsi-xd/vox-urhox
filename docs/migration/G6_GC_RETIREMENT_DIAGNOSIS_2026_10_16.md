# GC retirement spike: measured attribution and safe next candidate

This is a read-only production investigation. No production GC, retirement,
rendering, or gameplay code changes accompany this report.

## Recorded event and build identity

The actual source is archived automated-match log
`evidence/performance-live/2026-10-16T12-40-29-802Z-45796-4d6ff5/session-33786b7521c16556b4a19f61.jsonl`,
served as `manifest-1dc62aae.json`, target parent `25149307`. This is not the
user's current 4471 play session. Its CollectionCycle, RenderTargetLifetime and
HangarApp SHA-256 values match the current modules exactly. Extraction and full
source hashes are in `evidence/gc-retirement-2026-10-16/analysis.json`.

| Recorded frame | Interval | Simulation steps | Actual recorded GC information |
|---|---:|---:|---|
| 3915 | 36 ms | 2 | No complete GC detail in retained compact row |
| 3916-3917 | 21 / 27 ms | 0 | No GC top-stage label |
| 3918 | 70 ms | 0 | Compact row top stage `gc.Step`, 48 ms |
| 3919-3923 | 18-38 ms | 0 | No GC top-stage label |
| 3924 | 88 ms | 0 | Full row: Lua 60 ms, one `gc.Step` call 44 ms |
| 3925 | 19 ms | 0 | Loading switches to `cover` |

Frame 3924 has `gcEpoch=5`, `gcActive=true`, `gcStepping=false` at context
capture. Its measured Lua scope includes GC invocation; this is wall duration,
not a CPU-only timestamp. Heap goes from 86,129.36 KiB at frame 3923 to
69,866.90 KiB at 3924 (about 15.88 MiB difference). This is a correlation, not
proof that those bytes belong to any particular render target or gameplay item.
The retained log has no queue size, retired texture identity or GC subphase.
Neither one scope nor its 44 ms can be divided into unrecorded subphase costs.

## Actual caller chain

`HangarApp.Update` invokes `RenderTargetLifetime.Update` before the loading,
paused-menu and normal gameplay early returns. If any texture is pending,
every third invocation requests `CollectionCycle.Step(128)`. It does this even
when every recorded weak surface still has an external borrower. The step is
an explicit synchronous Lua GC request; 128 is a work/debt amount, not 128 ms
or a hard time budget.

There are only two production `CollectionCycle.Step` call sites:

1. `RenderTargetLifetime.Update`: texture retirement in normal updates.
2. `HangarApp.ReleaseSettledAssets`: incremental release of disposed owners,
   awaiting the shared collection epoch.

Frame 3924 has no `app.ReleaseSettledAssets` parent stage, although that method
was already instrumented in this build. Its `gc.Step` is beneath `app.Update`.
This supports the RenderTargetLifetime path. It does not identify which retire
event originally populated the queue, since `Retire` was not instrumented.

`CollectionCycle.Step` first switches to incremental mode when needed, requests
one GC step, increments the shared epoch only when completion is reported, and
restores the previous mode on completion or a deferred restore request. The
measured `gc.Step` includes mode-entry work, step/atomic/finalizer work and any
nested restore. Frame 3924 has no `gc.Restore` row, so an instrumented Restore
did not account for those 44 ms. Mode entry versus the step itself remains
unseparated in the old log.

Full synchronous collection is intentionally used elsewhere:

- Non-incremental `ReleaseSettledAssets`, normally after scene disposal and
  three update/presented-frame fences, calls `CollectionCycle.Collect`.
- Nonempty `RenderTargetLifetime.Flush` calls `CollectionCycle.Collect` before
  releasing parents. It is used after settled release and at shutdown.
- Opening teardown can request incremental owner release instead. Shared epoch
  accounting prevents one caller's collection from leaving another waiting.

These are real synchronous-GC entry events, but the measured 3924 scope is
`gc.Step`, not `gc.Collect`. It would be incorrect to label that frame a proven
forced full collection from `Flush`.

## Release correctness that must remain

Runtime RenderSurface wrappers retain raw parentTexture pointers. A weak value
can clear before its surface finalizer finishes. The parent Texture must stay
alive until the finalizer has run and the required shared epoch has passed.
An external borrower must keep the parent pending. Disposing parents merely
because the weak slot is nil, deleting the fence, or skipping pending ownership
is unsafe. Permanently omitting GC when the weak slot remains nonnil can also
retain GPU parents indefinitely when Lua allocation pressure is low.

The existing actual Lua 5.4 collector/finalizer test was independently rerun
without writing its output artifact: 830 checks pass in incremental and
generational initial modes. It covers external borrowers, weak nil before
finalization, duplicate retirement, incomplete cycles and explicit Flush.
This is table-finalizer modelling of native ownership, not a native/GPU safety
or performance claim.

## Minimal candidate, pending root approval

The justified first candidate is attribution only, preserving every existing
retirement decision and fence: bind `RenderTargetLifetime.Update/Flush/Retire`,
record its pending count, and split CollectionCycle's incremental-mode entry
and actual step calls into separately measured child scopes. Existing
`gc.Restore` and `gc.Collect` labels remain. Capture from mode entry until queue
drain during the real match-exit route. This distinguishes mode switching,
collector atomic/finalization and continued queue scanning before choosing a
behavior change. A queue count does not reveal texture identity; optional
retirement metadata should be recorded at the event rather than reconstructed.

Potential later candidate, only if measured mode switching dominates: keep one
incremental collection period across a nonempty retirement queue and restore
the previous mode at drain/cancel/shutdown. Preserve shared epoch and reentrant
restore behavior, then rerun the 830 ownership checks plus actual route traces.
This is not demonstrated as a fix for frame 3924, and has not been implemented.

Reducing `Step(128)` alone or scheduling steps after drawing cannot guarantee
a sub-33.3 ms frame: a collector atomic phase or finalizer remains synchronous.
There is not enough recorded evidence to select either as the claimed fix.

## Reproduction

Run `python tools/migration/analyze-gc-retirement.py` to extract the exact frame,
surrounding compact rows and source/build identity. The tool writes only its
dedicated evidence directory and asserts the original 88/60/44 ms values and
absence of a ReleaseSettledAssets parent. No engine or GPU process is started.
