# 5f opening boot and shadow audit

Date: 2026-10-16. Read-only investigation; no production edits, new shadow experiments, GPU run, packaging or upload. The later e9 package's natural run remains owned by root and is not evidence for the historical 5f timing below.

## Evidence boundary

Read `CURRENT_EXECUTION.md`, `OUTGAME_CURRENT.md`, `G1_INTRO_5F_READONLY_OBSERVATIONS_2026_10_16.md` and the existing natural-run log `evidence/intro-natural-web-1600x900-manifest-5f39f096.log`. Inspected immutable payload `.tmp/outgame-cached-1792099539845` / `manifest-5f39f096.json`, fingerprint `48c659df9cc9568bc56e5c9db0bc6b225d038dde98a27357fd18dd43c4563643`.

Current `SceneLoader.lua`, `ResourceGate.lua`, `SceneWarmup.lua`, `IntroWarmup.lua` and `assets/Scenes/Crater.xml` match that payload byte for byte. Loading/warmup conclusions can therefore be traced to those modules, while current opening audio and visual updates remain a separate batch. Measurements include QA instrumentation and are not an uninstrumented performance baseline.

## The 90.587 seconds are separate stages

The first observed boot sample is 05:27:19.936. The first ready sample is 05:28:50.523. The following adjacent intervals sum to exactly 90.587 seconds; boundaries use actual native completion/warmup logs where available.

| Interval | Wall seconds | What it includes |
| --- | ---: | --- |
| Boot sample to native 70-resource group complete, 05:27:30.388 | 10.452 | Opening media raw-byte readiness; 63,149,747 bytes by the ready sample |
| Media complete to native 525-resource group complete, 05:28:02.950 | 32.562 | Dependency-list preparation plus crater/actor raw prefetch readiness; 178,758,722 bytes; audio/image preparation overlaps |
| Prefetch complete to first actual warmup, 05:28:20.782 | 17.832 | Array decoding/upload retirement, asynchronous XML scene and sliced world/actor construction |
| First warmup to restored, 05:28:50.324 | 29.542 | Seven poses, 413 presented frames and 392 batches |
| Restored to first ready sample | 0.199 | Completion and observation boundary |

`OpeningHost.Prefetch` starts only after opening media is downloaded, via `IntroSession.Update -> PrefetchScene`. Its dependency work is visible from 05:27:30.398 to 05:27:31.084 before the first image decode log. Exact group creation has no timestamp, so 32.562 seconds must not be labeled pure network transfer. Native group completion at 05:28:02.950 precedes the prefetch-ready/resources sample at 05:28:03.604 by only 654ms: existing evidence does not support blaming tens of seconds on a late Lua poll after the whole group finished. Sampled byte-progress fields also exist; the run's gate backend was not explicitly probed.

Audio is already ready at 05:27:39.152, well before the 525-resource group completes. Its 55 `PrepareNext` calls total 827ms of measured work; images total 2022ms at ready. The older `OPENING_WARMUP_FEASIBILITY_2026_10_16.md` Candidate A, overlapping crater raw prefetch with audio preparation, has already been implemented. It is not a new proposed fix for 5f.

`SceneLoader.phaseTimes.download=0.012s` is not the full opening download. The opening media and dedicated prefetch gates happen before `SceneLoader.Load`; its gate then finds local bytes. Ready counters are resources 1.440s, scene 6.005s, prepare 10.358s and activate 0.017s. Prepare has 449 updates, 4210ms measured CPU work, maximum slice 398ms (`intro-montage-view`). Wrapper total/max and these nested values must not be summed as independent costs. The 90.587s wall interval is also not the cinematic `I.time=38.2578s`.

| Warmup phase | Wall seconds to next phase | Successful VS/FS compile log entries |
| --- | ---: | ---: |
| idyll | 2.121 | 19 |
| idyll-crossing | 0.885 | 3 |
| build | 0.860 | 3 |
| brief | 17.128 | 181 |
| drive | 2.582 | 12 |
| effects | 4.530 | 64 |
| effects-single | 1.436 | 9 |

There are 291 compile-completion entries during these intervals. Counts establish first-use work in each phase; they are not driver CPU/GPU timings and do not imply all wall time is compilation. The current one-presented-frame batch cadence does not establish shadow-caster submission.

## Exact missing shadow resources

The payload's shader `.meta` files map the observed UUIDs to these source resources. Every listed static caster has `Cast Shadows=true` and `Shadow Distance=90`; the sun's CSM splits are 15/40/75m.

| Shader | Static components and source data |
| --- | --- |
| `Db92MdNcR8CY03WHsG6jS_0k` / `Map-MAP_NOSAND-MAP_PANEL.shader` | component174/node179, own-fortress floor `mesh-170.bin` / material8; component242/node261, enemy-fortress floor `mesh-238.bin` / material60 |
| `BNNNcWhirBQkMho_un1Bywvh` / `Map-MAP_ROCK-MAP_VBAKE.shader` | components283-285/nodes314-316, map-wide merged rocks `mesh-279.bin` through `mesh-281.bin` / materials83-85 |

Actual `_shadow`, `VERTEXCOLOR`, non-INSTANCED first compilation remains at 05:29:09.606-09.687 during countdown for Panel and 05:29:44.350-44.432 during play for Rock. `_depth` and forward `SHADOW` variants during boot are different passes.

Static-map selection is not first-versus-nearest duplication: XML contains 289 StaticModels and 289 distinct `(Model, Material, Cast Shadows)` groups, with zero duplicate groups. `IntroWarmup` includes exact Model identity in its admission key. Dynamically added components were not inventoried live.

UMDL vertex bounds plus XML parent transforms give the own floor native bounding box `(-28,6,-258)..(28,6.125,-210)` and enemy floor `(-28,6,210)..(28,6.125,258)`. The fixed brief camera is native `(-98,20.96835,-212)`, looking at reflected source `(46,GroundAt(46,-140)+2,-140)`, FOV50 at 16:9. Analytical AABB/frustum testing puts the entire own floor outside one side plane (maximum signed plane value -18.464); the enemy floor intersects the frustum but its center is 456.883m from the camera. Thus the brief forward/depth observations do not prove a nearby Panel shadow sample: the near floor is filtered before admission, while the visible far floor exceeds its declared shadow distance.

Drive and effects cameras depend on `CarUnit.Position`, which returns native Bullet center of mass after `Vehicle.Place` applies bounds/COM offsets. Nominal spawn-based calculations put the own floor outside those views too, but those two camera values were not captured live and are not asserted as exact. They are a diagnostic lead, not an observed native decision.

The three rock mesh native centers are approximately `(0,13.875,-1.5)`, `(-.875,13.625,-1.375)` and `(-3.75,30.5,-26.625)`. Their centers are 208-232m from the exact brief camera, even though their huge AABBs contain that camera. This makes native distance/CSM caster rejection a specific hypothesis. The inspected bindings expose shadow distance but do not establish whether this Runtime uses center distance, closest-box distance or another shadow-caster rule. Do not claim that rock rejection has been proven solely from these bounds.

There is no project opt-in for directional temporal shadows, and the docs say they default off. A cache/temporal explanation remains unsupported by present source/config evidence.

## Smallest evidence-backed next step

No production change is made or authorized by this report. Preserve the 32-second prefetch interval and 29.5-second warmup as distinct unresolved costs.

For boot, the narrow candidate is to remove the artificial media-completion prerequisite from raw crater prefetch, starting its separate gate from an ordinary early opening update after the pending-gate scan. Native array/scene construction must retain both `audioReady` and `sceneDownloaded` gates and all existing cancellation/ownership checks. This only permits overlap between the two raw groups; shared network capacity, concurrency and decode pressure can erase any gain. The current log cannot assign a saving. Before adopting it, obtain group creation/completion and per-URL status/bytes/timing from the unified-run owner; do not count duplicate logical references as duplicate body transfers or enlarge decode concurrency.

For the two shadow omissions, nearest-duplicate selection is not supported by this static structure. The smallest concrete candidate is a boot-only original-caster pose near the own floor and central merged rocks, with explicit individual admission for these original Model/material identities. Keep source geometry, persistent shadow distances, all seven existing poses and complete camera/mask restoration. Actual camera/bounds/cast/mask/draw/shadow-distance admission records and the two exact `_shadow` VS/FS compile identities must be present before ready; a forward/depth compile or a larger arbitrary frame wait is not acceptance. This candidate has not been implemented or experimentally validated.

Do not reduce shader coverage, delete phases, raise performance thresholds, resume G0 or promise persistent Web shader caching from this audit. Root's current e9 natural run remains focused on the later opening performance and exit timing; no new experiment is started here.
