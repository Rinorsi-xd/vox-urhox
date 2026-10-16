# Opening raw download overlap

Date: 2026-10-16. Continue the existing G0-G6 migration; do not restart G0. Frozen H5 source remains branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Change and ownership

`IntroSession.Update` now starts `PrefetchScene` on its first ordinary boot update, after the ResourceGate pending scan, without waiting for the opening media group. This permits the media and original map/actor byte groups to download concurrently. It does not decode the map, increase decode concurrency, skip any of the 55 audio preparations, or remove any of the seven warmup poses.

Native preparation still requires both `audioReady` and `sceneDownloaded`. A failed media callback seals the first error before cancelling the owned prefetch. Late media/raw success or failure cannot override that error or revive a disposed session. Starting from Update avoids creating a legacy pending gate inside another gate's completion scan.

Frozen production SHA256: `scripts/intro/IntroSession.lua` = `c897536f3dd67695313dcb9a29b795a4a0f257a2e31bb91c92c6ba341019514d`.

## Actual offline verification

Ran `check-opening-prefetch.py`: **176 PASS**, using the actual IntroSession, OpeningHost, ResourceGate and SceneLoader with controlled native I/O. Cases cover modern and legacy simultaneous pending groups, media-first and raw-first completion, synchronous callbacks before a returned group ID, media failure, raw failure, audio failure, cancellation, disposal and late callbacks. All-local and optional-host paths retain audio/native ordering.

Evidence: `evidence/opening-prefetch-offline.json`, SHA256 `7e717cd27e4c1238522bd2bd0a7546b763907f3dd796304dab4eec24816a4392`. Test Lua SHA256: `6ceb9e5b941d2badbc1fb26a985930bdd8ef88140ac4ef0e90ce83843dda8418`.

This is an ordering/ownership result, not network-throughput, shorter-wait, rendered-parity or mobile-performance acceptance. The new production hash is not in historical 82a; root must package and naturally measure the combined batch.
