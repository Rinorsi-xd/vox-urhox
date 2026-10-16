# S3 array preparation freeze: recorded Web evidence

Input: `evidence/story-natural-s3-manifest-49c15ba7-2026-10-16T02-09-23-829Z/runtime.log`, SHA256 `ea08f333daf1c987f95ca28d2318c789735c3340df30281409f0c0dd061d94fe`. Frozen build `manifest-49c15ba7`, H5 baseline `b276064942ae09c0227ec28d4cfda1d5ff006455`. Read-only attribution; no production changes, build or engine launch.

## What actually blocked

| Local log time | Frame | Observed operation | Actual outer App.Update |
| --- | ---: | --- | ---: |
| 10:10:49.312 | 1681 | SceneLoader Prepared Crater/albedo.xml, 33,554,792 bytes | 651 ms, wall 1115286231 to 1115286882 |
| 10:10:50.092 | 1685 | SceneLoader Prepared Crater/nra.xml, 33,554,792 bytes | 715 ms, wall 1115286946 to 1115287661 |
| 10:10:50.276 | 1691 | Loading scene from the actual authored XML starts | After both array stalls |

The actual source `SceneLoader.lua:143` performs `pcall(cache.GetResource, cache, item.type, item.name)` in the resources phase. Its next operation prints the Prepared message. Both long App.Update calls end at that message in the same frame. This identifies the synchronous array-preparation branch as the narrow blocker; it does not separate PNG decoding, mip generation and native GPU upload time inside GetResource.

The surrounding actual state snapshots corroborate that branch: arrayBytes is zero before preparation, 33,554,792 after albedo, then 67,109,584 after nra. There is no shader compile recorded during these calls. The arrays each reference the original six existing 1024-square RGBA layer images and their mip chains. The source resource branch already waits three further rendered frames between arrays to retire upload staging buffers; this does not divide an individual GetResource call.

Actual music Update maximum is 4 ms through S3 reveal and 7 ms including return; actual ResourceGate.UpdatePending maximum is 1 ms. These measured methods do not explain either 651 or 715 ms call. No attribution to GC, audio decoding, ReadScene or Commit is supported for these two stalls.

## Total entry cost remains broader

The final S3 loading steps report download 35.643 s, resources 1.505 s, scene 5.996 s, prepare 6.997 s, activate/render 32.967 s. This run has no per-request network timing, so download wall time is not evidence of network bandwidth alone. It can include native work outside the timed Lua methods.

Warmup: scene 67 batches / 532 accepted drawables / 14.732 s; disabled 2493 and outside 307 skipped; restored-world frame 1.075 s; combat construction .031 s; combat 256 frames / 429 groups / 17.052 s. The recorded compilation split remains 158 scene + 14 restored-world + 159 combat = 331 records. Removing the restored-world frame would remove observed shader coverage. Array preparation is a concrete freeze target, but resolving its 1.366 s of outer call time cannot by itself remove the roughly 85-second complete map entry.

## API facts and experiment candidate

`urhox-libs/Engine/ResourceCacheExtensions.lua:166` handles local GetResourceAsync by directly calling GetResource. Its download-completion path at line 182 also calls GetResource. Replacing the current call with this wrapper does not establish asynchronous decoding and can move the same work into a download callback.

The native binding declares generic `BackgroundLoadResource(type,name,sendEventOnFailure)` and `GetExistingResource(type,name)` in `.emmylua/ResourceCache.d.lua:72`. No supplied implementation or prose specifies Texture2DArray BeginLoad/EndLoad threading or GPU finalization on the shipped WASM. Support and whole-frame benefit require an actual target runtime experiment.

Candidate A, pending production authorization and target test:

1. Keep all original pixels, six layers, mip levels, format, material references and warmup coverage. Start only after all layer bytes are downloaded.
2. For the selected array, poll GetExistingResource first; if absent, queue BackgroundLoadResource exactly once and keep rendering the loading page. Never issue synchronous GetResource as a timeout fallback.
3. When the cached object is ready, verify width, height, layers, levels and memoryUse against the current arrays, retain the existing three-frame staging fence, then advance to the next array.
4. Cancel the observer by generation; do not pretend this cancels the engine's shared decode. Fail explicitly on a bounded wall-clock timeout. Avoid loading both arrays concurrently on the fixed WASM heap.
5. Record queue-call duration, queue-to-ready duration and all frame intervals spanning preparation. A cheap Lua method does not pass if native finalization simply produces the same 700 ms stall elsewhere in the frame.
6. Prove cache-path/material binding and actual terrain pixels on the same Web renderer. Native results alone cannot approve the WASM candidate. If the long frame persists, retain current production and take the native EndLoad operation to the engine team.

The binding also declares SetFinishBackgroundResourcesMs, but provides no guarantee that it splits one resource's EndLoad; changing this global budget is not the first candidate. Texture2DArray.SetData(layer,Image) is exposed for per-layer uploads, but no AddManualResource binding is exposed to register a constructed replacement under the existing XML path. That approach would require a deliberate material/asset ownership change and should not be improvised as the initial fix.
