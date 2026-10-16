# Payslip Camera Candidate

This is a next-package candidate. Frozen `manifest-5b8cf21c.json` and `.tmp/outgame-cached-1792113063203` are unchanged. Production edits are limited to `scripts/intro/IntroShots.lua` and `scripts/app/OpeningHost.lua`. No build, server, GPU, commit, upload or `CURRENT_EXECUTION.md` edits occurred in this task.

## Source And Numeric Contract

Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`; `three/src/intro/intro.js` SHA256 `8674acaea7cfa5df986a233010a11b7c8f9cf3e9a64acd32a4d21b6ed314877f`.

| Contract | Frozen source | Lua candidate |
| --- | --- | --- |
| Entry | `actPayslip`, lines 965-975: wait for wipe coverage, mark payslip, clear previous tasks | Existing `IntroSession:Ad` waits for wipe, then `Mark('payslip','crater')`; actual `OpeningHost.Shot` initializes entry pose |
| Captured actor | `cine.target`, set to original cart at line 854, captured once as `cu` | Capture `session.combat.cart` at entry; do not use montage target or player |
| Missing actor | `[30,0,-170]` | `{30,0,-170}` |
| Initial anchor | `q0=cp()` once | `target:Position()` once for initial anchor |
| Initial camera | `[q0.x+8, ground(q0.x+8,q0.z-12)+2.5, q0.z-12]` | Same values, logical source coordinates |
| Obstacle look point | `[q0.x,q0.y+1,q0.z]` | Same values |
| Ray | `clearCam`, lines 1344-1359: origin at obstacle look point, normalized direction to camera, length equal to separation | Existing `IntroShots.SafeCamera` called once without previous lift |
| Excluded body | Original `cartUnit?.vehicle?.body` | Original cart's current vehicle body; nil if absent |
| Clear condition | No hit, `hit.dist > length-0.6`, or `hit.owner.ref` | Same strict `>` margin and actor exemption |
| Raise | `0.5m` per blocked attempt, maximum `20` attempts / `10m` | Same values, no per-frame resampling or smoothed lift inheritance |
| Drift | Task has `dur=0`; actual `update` at lines 209-215 passes elapsed seconds as `k`; `camP.x-k*2` | Shot age in seconds, `base.x-age*2`; base Y/Z retained |
| Frame look | Live captured cart `[p.x,p.y+1.5,p.z]` | Live captured cart `Position()` plus `1.5m` Y |
| FOV | `44` each frame | `44` each frame |
| Duration | Persists through n05 voice and `0.45s` tail; `actDecide` marks decide and clears tasks | Existing `Say('n05',.45)` retained; next `host.Shot` releases captured payslip state |
| Coordinate conversion | Source right-handed logical coordinates | Actual `core.Coord.Vec` reflects X once at host output |
| Cancellation | Source task collection cleared on next act | Next shot or `host.Dispose` releases entry pose and actor reference |

The registered n05 duration is 5.86s, so the nominal camera span is 6.31s before normal frame scheduling; runtime voice duration still governs the existing timeline. No new camera easing, clamp or fixed-duration task is introduced. `CarUnit:Position` retains its last position after vehicle removal, matching the source actor's retained `pos`.

## Offline Verification

Run `python tools/migration/check-intro-payslip-camera.py` with the workspace Python/Lupa runtime. This executes actual frozen `actPayslip` until UI access immediately after camera registration, actual `clearCam`, `task`, `update` and `clearTasks`, then compares actual Lua `OpeningHost.Shot/CameraShot`, `IntroShots` and `core.Coord` under controlled engine adapters.

Result: **616 checks PASS**, **3 mutation controls rejected** (drift speed, live look height, FOV). Seven source cases cover clear ray, three blocked rays, twenty blocked rays, just inside the 0.6m endpoint margin, exact margin equality, vehicle-actor exemption and absent cart. Frame ages are 0, 0.25, 1, 2.5 and 5.5 seconds. Other checks cover live cart movement, retained actor despite combat target replacement, removed vehicle, one-time ground/raycast sampling, independent montage lift, reentry, next-shot release and repeated disposal.

The actual frozen 5b8c Host and IntroShots fail the entry-camera requirement as expected. The negative control is executed from the immutable package, not recreated from candidate code. Frozen hashes are pinned in the runner and rechecked after execution.

Relevant regression results: `check-opening-host-residuals.py` **1199 checks PASS / 3 historical negatives**, `check-opening-hidden-idle.py` **32 checks PASS**. Their evidence was refreshed to the candidate Host/IntroShots hashes.

Evidence: `docs/migration/evidence/intro-payslip-camera-offline.json`. Source oracle: `tools/migration/source-intro-payslip-camera.mjs`. Runner: `tools/migration/check-intro-payslip-camera.py`.

## Hashes And Boundary

| File | Candidate SHA256 |
| --- | --- |
| `scripts/intro/IntroShots.lua` | `67dbe1eb14df5c09c37b31703a022d7044191ae8bdd9fc012f241c8a2da1413b` |
| `scripts/app/OpeningHost.lua` | `96affe73d3bea9c4502944472a423a9af7e58d3db6f6b62c552312d25bb00014` |

`IntroSession.lua`, `IntroPromo.lua` and `IntroPayslip.lua` hashes remain respectively `c897536f3dd67695313dcb9a29b795a4a0f257a2e31bb91c92c6ba341019514d`, `f17e9934b4422ddd0ec755ef832458209ffde6ffa562b2f1b30f6030abc4f2f9`, and `6557bc4c4c128d02e39e342ae9eb2d00f78de1c1afa39e3c09339f88ed8030d4`.

This proves camera equations and callback wiring with controlled terrain/collision inputs. It does not prove native raycast hits, actual terrain visibility, projected composition, GPU rendering, natural playback, mobile performance or user visual acceptance. Source payslip `trauma=0.8` and root shake `1.6 / 380ms` remain separate pending work; subtitles, layout and shake are outside this candidate.
