# Crater retirement at the comms boundary

## Change and source boundary

The opening now begins retirement of its owned crater session/world/scene when `OpeningHost.Shot('comms')` runs. Previously those objects remained live until the final page close, where their retirement overlapped HUD creation. This changes resource lifetime; it does not change the shot sequence or voice timings.

The inspected `IntroSession.Run` first sets `playing=false`, returns to the garage at `tvcut`, then marks `comms` with scene `garage`. Its remaining shots are contract, stamp, and gate; none returns to crater. Retirement stays after tvcut's existing EndSortie work. `IntroSession.Camera` uses the hall camera during these shots, and crater-only CameraShot work is guarded by the active scene. This makes comms the earliest inspected irreversible boundary selected for this change.

`OpeningHost.RetireCrater` captures owned objects and ReleaseAssets into local retirement ownership, pauses the trial, disables its scene, and releases retained postprocessing. It disposes/nils sortie UI and detaches public session/world/scene/strike, montage target, wreck camera, and pending capture references before the first possible coroutine yield. A disposed warmup is dropped without calling its restoration logic again. Observers therefore cannot inspect a half-disposed trial.

The existing OpeningRetirement queue handles trial, world, strike, and scene disposal over frames. Its completion schedules the existing deferred cache release with incremental GC. `craterRetired` makes final page Dispose idempotent with respect to that owned work. Capture textures, opening page, hall actor, garage, assembly, and opening audio keep their original independent lifetimes. The no-session Update branch continues hall actor idle and garage animation.

Tutorial resume still requires the owning opening state, original hall/tutorial identities, hangar mode, no opening/build, and an app that has not stopped. If early release completes before Finish establishes a pending tutorial, Finish resumes it through the same guard. If release is still pending, its callback performs the resume later.

## Ownership review

- Cancellation after comms disposes borrowed hall objects immediately; captured crater work remains in the existing owned retirement job. Repeated Dispose cannot enqueue a second job.
- Stop sets stopped, disposes the current opening, then synchronously drains the existing queue before graphics teardown. The retired job does not traverse a replacement app scene.
- Replacement/replay changes openingRestoreOwner and/or app.opening; the previous completion cannot restore or resume a newer opening/tutorial through the guarded callback.
- GetCamera and SortieStatus tolerate a detached session. FramePresented capture work is no longer pending, while previously captured comic textures remain available until final Dispose.
- No determined source-level ownership regression was found in this independent review. This is not native userdata or rendered acceptance.

## Verification

The current saved evidence was inspected and every recorded production hash matched current source:

| Evidence | Result | Scope |
| --- | --- | --- |
| `docs/migration/evidence/intro-runtime-offline.json` | PASS, 437 checks | Existing 423 plus 14 early-retirement checks |
| `docs/migration/evidence/intro-finish-offline.json` | PASS, 53 checks | Existing finish/audio/ownership regressions |

The new 14 checks run seven assertions for each of normal completion and cancellation while early retirement is pending: one paused queued job; public battle objects detached; hall animations continue; repeated comms is idempotent; captured trial/scene/release complete once; asset gate clears; final repeated Dispose does not repeat retirement. Existing runtime coverage also exercises real queue ordering with replacement scenes, synchronous Stop draining, and incremental cache-release selection. Existing finish coverage includes partial fade cancel/Stop/replacement, delayed native retirement, tutorial ownership, and post-handoff audio cancellation.

The independent review did not rerun GPU/browser work. These fixtures execute production Lua with controlled native/UI adapters and frozen JavaScript reference behavior. They do not prove actual native memory reduction, smooth frames, audible output, or successful natural handoff. The older `check-lifecycle-isolated` fixture's missing GameMusicState map setup is outside this change and was not used to alter production behavior.

Frozen source SHA256 for `scripts/app/OpeningHost.lua`: `26d80c5f8a19a22775376dcfe78b3560c56f35b464f7292858267f8034a3f32d`.

The failed prior 9b natural run and its CPU/OOM limits are recorded separately in `G1_9B_PROFILE_OOM_READONLY_AUDIT_2026_10_16.md`. A fresh manifest-bound package and complete natural run are required before claiming this lifetime change resolves that OOM. The next diagnostic is configured by root to use a failure-only OOM hook without CPU profiling or filesystem memory scans; no result from that future run is claimed here.
