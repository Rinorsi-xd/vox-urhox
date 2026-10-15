# Combat first-fire evidence and warm-up candidate

## Immutable Web evidence

- Running manifest: `manifest-04a23389.json`, local QA port 4326.
- Evidence: `docs/migration/evidence/destruction-web-2026-10-15T13-40-38-054Z/`.
- The original `report.json`, `console.log`, screenshots and frame samples remain unchanged.
- Public controls only: workshop Red Flame GT -> trial -> shipped N area cycling -> aim and fire -> damage and kill a separate target.
- 16 gameplay assertions passed: 209 -> 149 target parts, then one actual target kill; identically named player stayed alive at 209 parts.
- 59 real damage Flush events, maximum 28 ms. Total 786 shots, 476 hits, one kill; score 300. Audio counters confirm calls, not audible quality.
- Fire phase: 916 frames, median 27.98 ms, P95 48.735 ms, P99 62.195 ms, maximum 138.795 ms, one frame above the unchanged 100 ms limit.
- Overall performance remains FAIL. Desktop Chrome evidence does not establish sustained phone performance.

## Network review

The original final resource assertion treated four bootstrap probes as failures. The console explicitly says both engine-res and urhox-libs packages are absent, skips them, then successfully finishes DownloadInitialPackage. All 3543 game preloads complete without failure.

`check-destruction-web.cjs` now separates only exact local engine-res / urhox-libs `assets@windows.7z` HTTP 404 paths, and only when both matching skip and successful bootstrap evidence exist. Any actual game resource failure, HTTP 500, unmatched path, or missing fallback proof still fails.

Run `node tools/migration/analyze-destruction-web.cjs <evidence-directory>` to write independent `analysis.json`. The original failure is preserved. Functional review PASS, performance FAIL, final review FAIL.

## First-fire shader evidence

The 138.795 ms frame ends at wall time 1792071731267.435. In the corresponding native frame 2761, console lines 1567-1574 show first-use compilation at local 21:42:11.153-21:42:11.239:

- Stencil vertex and fragment shader.
- `surface_pbr_FIJGacrvO5aEcLp0K6C43qPV_11eeca77_61464CF2`, vertex defines `AO INSTANCED PERPIXEL POINTLIGHT RENDER_QUALITY=2 REVERSED_Z`.

The same material had compiled its non-instanced POINTLIGHT variant during loading at 21:41:59.040. Its instanced directional and depth variants appeared after the shipped trial area teleport. No damage Flush event occurred within one second of this first-fire spike.

This establishes missed shader variants in the actual fire frame; it does not prove an exclusive cause for all 138.795 ms. No evidence currently justifies changing particle count, weapon behavior or damage.

## Candidate, pending a new Web build

Files: `scripts/render/CombatWarmup.lua`, `tools/migration/check-combat-warmup.lua`.

Existing warm-up uses only visible real drawables, at most four per signature, with an eye-centred light spanning twice the far clip. A signature with one visible source cannot produce an instanced draw. An eye-centred giant light also misses the finite stencil-volume case.

The candidate retains those stages and adds bounded temporary StaticModel probes for visible model/material signatures. Four probes share the actual model/material and instance flags; the next pass uses one. Each page uses at most eight probes. Model bounds determine their scale. They sit in front of the actual camera and inside a finite light whose volume excludes the eye. There are no simulation events, physics components, weapon state changes or RNG calls. Completion, cancellation and exceptions dispose the temporary tree and restore the light and original scene masks.

22 offline lifecycle scenarios PASS, including sole-source instancing, both finite-volume variants, cancellation, exception cleanup, exact original transform preservation and global RNG preservation. `git diff --check` passes.

Required next acceptance on one new manifest:

1. Reach trial through public menu controls; loading remains visible and responsive.
2. Confirm Stencil and the above instanced POINTLIGHT variant compile before loading closes.
3. Repeat the same real aim/fire/break/kill route; retain all gameplay assertions.
4. Keep the 100 ms threshold and report every live-frame spike. A candidate is not accepted merely because shader logs move earlier.
5. Confirm no `CombatWarmupProbes` nodes or geometry remain after reveal or cancellation.

No Web or native runtime has been started for this candidate. Root owns build scheduling and browser/native exclusivity.
