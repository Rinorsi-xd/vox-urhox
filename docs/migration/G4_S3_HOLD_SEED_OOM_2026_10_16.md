# S3 hold: rule parity, wave seed candidate and OOM boundary

Baseline: frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Observed build: `manifest-9e5d7ed6`. Runtime evidence: `evidence/story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-55-04-396Z/runtime.log`.

## Observed hold result

The actual run reached hold and recorded five kills, 4,841 shots and six failed hold attempts before OOM at story time 335.48 seconds. No complete hold, lunch choice, coupon pickup or S3 completion was observed. Failed attempts had approximately 79-82 seconds remaining on the 120-second hold clock.

Frozen H5 `shared/story/level3.js` and `three/src/battle/storyKinds.js` agree with Lua on center `[0,6,-234]`, heal radius 26, drain radius 70, drain 0.011 per living enemy per second, duration 120 and delay 4. The horizontal circle intentionally ignores walls and height in both versions. Three surviving enemies in range drain full energy in approximately 30.3 seconds of residence. Healing repairs the player, not the objective's energy.

The tool parks at the center and fires at a nearest generic enemy position. Assault AI's authored 25-45 m engagement band is wholly inside the objective's 70 m drain circle. The observed failures are compatible with the source rules and insufficient removal of the first wave. They do not prove the objective is broken. World hit totals include enemy hits on the player; unchanged part counts do not prove damage failed. This report does not certify the tool's aim or each muzzle-to-target line of sight.

## Confirmed migration difference and candidate

H5 `StoryMission._beats` passes `b.tag || 'wave'` into actual spawn. Lua previously emitted an absent tag and `Mission:Spawn` assembled seed `story:s3::0:73` rather than `story:s3:wave:0:73`. This changes reaction, aim and route randomness but does not establish the cause of the hold failures.

The candidate changes `MissionRules:Beats` to emit `tag=beat.tag or 'wave'`. A second confirmed difference was fixed in `Mission:Events`: the clear/fight path now supplies the step ID as its spawn tag, matching H5 `spawn(..., s.id)`. It builds new spawn arguments without modifying the authored step. Capture guard/counter paths are untouched; explicit beat tags remain unchanged.

`tools/migration/check-story-event-order.py` now executes frozen H5 `_beats`, `update` and `spawn`, and production Lua `Beats`, `Step`, `Events` and `Spawn`. Native constructors are adapters capturing actual driver options. Default wave, explicit reinforcements and clear/fight scouts tags, both generated driver seeds, and selective enemy clearing are compared. Existing authored S2/S3/S4 event order and completion checks remain active.

- Initial wave check: 13 checks, two failures, default tags and default seeds only; after wave correction 13 checks passed.
- Expanded check before clear/fight correction: 18 checks, three failures, clear/fight tags, seeds and selective clearing. Evidence: `evidence/story-event-order-offline-before.json`.
- After both corrections: 18 checks PASS. Evidence: `evidence/story-event-order-offline.json`, with production hashes.
- Related production Lua regression: objective 934 checks PASS; death/flee order 2,572 checks PASS; timer fixture scheduling 20 checks PASS and three negative controls rejected. These use engine adapters and are not native/Web runtime acceptance.
- Frozen candidate hashes: `Mission.lua` = `b197930df20cd8429bf799ef3e631a714cf5157d25b3dc5e4339e30dd9575346`; `MissionRules.lua` = `c2a3a29e4a6dc6065a66b80e5834a941d6db19c7c35082a71eeac4574bf8c5bc`.
- No GPU run was started. The candidate requires a new immutable package and a new natural run; no earlier build result accepts this change.

## OOM comparison

The new abort hook records requested heap size 1,766,825,984 bytes against current heap 1,719,533,568 bytes. The eight WASM frames are `2103:6239f`, `767:29009`, `14385:344de0`, `621:24ee6`, `9777:22c048`, `24192:59b388`, `9292:20fb45`, `9293:20fdc3`.

The earlier S1 `manifest-5b8cf21c` failure at approximately 409 seconds had no allocator-abort hook or WASM call stack, as recorded in `G4_STORY_S1_OOM_2026_10_16.md` and `G3_STORY1_OOM_READONLY_2026_10_16.md`. Its engine also had a fixed 1,719,533,568-byte heap. The equal heap limit is confirmed; an equal failed allocation path or common leak is not. These addresses are unsymbolized, so they cannot be assigned to physics, audio, rendering or QA serialization from this evidence alone. Long-session OOM remains OPEN.
