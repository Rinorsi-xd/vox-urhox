# Opening Raw Resource Prefetch

Date: 2026-10-16. Next-batch implementation only; not in `manifest-0bcd53d6.json`.

## Behavior

After the opening media gate completes, the next opening update starts raw crater/actor resource prefetch before the first of the 55 audio preparation steps. Raw downloading and audio preparation can overlap. Both `audioReady` and `sceneDownloaded` must be true before `OpeningHost.Prepare` starts the normal SceneLoader path.

The original two-array decode retirement, scene loading, world/actor construction, environment bake, all seven renderer warmup phases, viewport ownership, and final ready condition remain in their existing stages. This does not reduce shader variant count or establish a shorter compile time.

Changes are scoped to `scripts/intro/IntroSession.lua` and `scripts/app/OpeningHost.lua`. The optional `host.Prefetch` hook preserves compatibility with hosts that only implement `Prepare`. The host computes one dependency list, includes the scene XML in the raw request, and reuses that same list for SceneLoader. ResourceGate remains responsible for local checks and download deduplication; its shared implementation was not changed.

The prefetch owner is invalidated before cancellation. Audio preparation failure cancels pending prefetch without replacing the audio error. Download failure blocks native preparation. Disposed sessions reject restart, and late callbacks cannot write into disposed or replacement sessions.

## Legacy Web Boundary Found During Testing

The first candidate launched prefetch directly inside the media completion callback. Running it with the actual legacy ResourceGate path reproduced `invalid key to 'next'`: `UpdatePending` was iterating its pending table while the old completion removed a gate and the new prefetch added another gate.

The final candidate sets only `downloaded` in that callback and starts prefetch in `IntroSession.Update`. `HangarApp.Update` calls ResourceGate.UpdatePending at line 553 and the opening update at line 580, so the new group starts after the pending-table scan, in the same application update when that scan completes. Asynchronous completions outside an update wait until the next opening update. No shared ResourceGate changes are required.

## Verification

- `check-opening-prefetch.py`: 58 checks pass with actual IntroSession, OpeningHost, SceneLoader, and ResourceGate implementations.
- `check-opening-construction.py`: 328 checks pass against the updated OpeningHost, with native boundaries doubled.
- `check-lifecycle-isolated.py`: 30 checks pass against the updated OpeningHost and existing HangarApp.

The new prefetch fixture covers download-first/audio-first order, 55-step audio readiness, failure and late success/failure, synchronous download completion before returned group ID, synchronous callbacks during cancellation, repeated owner requests, stale owner cancellation, all-local bytes, optional-hook compatibility, and the shipped legacy download-manager path. It verifies no native scene read or viewport change before both prerequisites and no second native download group when SceneLoader rechecks already-local resources.

Evidence: `evidence/opening-prefetch-offline.json`, refreshed `evidence/opening-construction-offline.json`, and `evidence/lifecycle-isolated-2026-10-15T20-03-19-564549Z/report.json`.

Native scene construction and render behavior retain their prior checks; these CPU fixtures do not certify GPU output, actual voice playback, memory peaks, network throughput, or elapsed-time improvement. Root must create and audit a new immutable package and rerun the real opening/tutorial flow. Prior 0b runtime evidence cannot certify this increment.
