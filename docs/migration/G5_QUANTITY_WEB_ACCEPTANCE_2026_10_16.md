# G5 quantity and inspection Web acceptance

Status: tools ready; browser route NOT EXECUTED by this agent. Production files were not changed in this acceptance batch.

## Run

The root task must finish the candidate build, restart its ordinary QA server after the probe edit, and check `/identity.json` before running the following command serially with other GPU checks:

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:4458'
node tools/migration/check-salvage-quantity-web.cjs
```

Use the actual root-owned QA port if it changes. The tool refuses non-QA/experiment servers, mismatched injected probe bytes, missing quantity modules, or candidate production files whose HTTP SHA256 differs from the reviewed working-tree files. It reads item/rule data from the served frozen package, not from mutable local resource JSON.

## Public UI Route

1. Fresh nonpersistent Chrome context, 1600x900; enter the public salvage lobby. Require CloudStorage Web `state=session`, zero pending cloud writes before inventory-sensitive checks.
2. Merchant -> sell -> materials -> an actual visible material with more than 100 loose units. Read the real stock rather than injecting inventory.
3. Type into the actual quantity field; verify 7, zero-to-one, upper clamping, blur on Enter. Compare every inventory entry, wallet, installed parts and scene mode to prove Enter does not trade or deploy.
4. Verify minus changes exactly once, maximum uses actual loose stock, wheel up/down changes by one over the field, and wheel outside it leaves quantity unchanged.
5. Hold plus until observed repeat ticks reach 14. Verify immediate +1, one per tick through 12, then five per tick. Release on the button and outside it; verify repeat ownership clears and quantity stops.
6. Switch merchant to buy, select an actual material, and commit quantity with Enter without buying.
7. Open loadout -> warehouse -> materials -> actual item inspection. Commit quantity with Enter without deploying. Capture the inspection at 1600x900, 2000x900 (20:9) and 1280x720. Check field/sell controls remain within the logical viewport.
8. Sell exactly two from the inspection while last merchant mode remains buy. Verify that only the selected stock decreases, wallet rises by the original buyback price, installed parts remain unchanged, and quantity resets to one.

## Safety And Evidence Boundary

The only sale is inside a new anonymous browser session and uses the packaged `testFill:999` fixture. It is not earned-stock or real-account evidence. The context is destroyed at shutdown. No inventory, time, position, HP, account, cloud or production state is injected. F8 only reads the existing QA snapshot. A non-session cloud state stops the route before transactions.

No buyback is attempted: the source fixture can already exceed the 120-cell limit, so buying even two items back can correctly fail capacity validation. The report explicitly records the isolated stock delta instead of claiming stock was restored.

Output: `docs/migration/evidence/salvage-quantity-web-<manifest>-<timestamp>/report.json`, console log, startup/market/input/hold/inspection/sale screenshots and a failure screenshot where possible. All screenshots still require root visual inspection. Viewport bounds alone do not prove typography, clipping or visual parity. The route does not certify mobile performance, cloud persistence, real-account economy, or comparison against H5 appearance.

## Completed Offline Checks

- Node `--check` passes for the Web runner.
- Full updated `probe-outgame-web.lua` compiles with Lua 5.4 `load`, without executing game code.
- Only a read-only quantity observation branch was added to the existing widget walk: row/field/button rectangles, text value, focus, quantity, maximum and copied repeat counters. No gameplay mutation keys were added.
- `git diff --check` passes for these tool/report edits.

Pending: fresh candidate build/server, actual route execution, runtime/HTTP errors, screenshots and root visual review. No browser or GPU process was started by this agent.

## First Actual Web Route And Corrective Follow-Up

Root ran `manifest-f9b98d5f` against the frozen observer. Evidence is retained in `evidence/salvage-quantity-web-manifest-f9b98d5f-2026-10-16T09-24-47-762Z/`. It passed 21 checks, including actual typing, zero/upper clamp, Enter safety, minus/maximum and field wheel directions. It then FAILED on a wheel moved outside the field. Runtime errors and HTTP errors were both zero; the route stopped before any sale.

The recorded pointer was physically `(1451,127)` at scale `0.8333`, or logical `(1741.2,152.4)`: inside the sell segment `(1644,128.4,194.4,48)` and far outside the field `(1506,747.6,200.4,52.8)`. The live probe hit was `出售`, but quantity changed 7 -> 8. The pinned, actually shipped `urhox-libs/UI/Core/UI.lua` handler starts from its cached hover, dispatches the wheel, and only then refreshes hover. The test used immediate public move -> wheel, which exposed that stale route.

Follow-up production change is confined to `scripts/ui/SalvageQuantity.lua`: while at least one quantity row exists, a shared module-reentry-safe adapter refreshes the pointer through public `UI.HandleMouseMove` before the original wheel dispatcher, only when the current hit or previous hover is an active quantity field. The field independently rejects stale/outside and zero-delta calls. The last row destruction restores the prior engine handler; other pages do not retain a wrapper or per-frame polling. `urhox-libs` and the frozen observer remain unchanged.

The quantity offline checker now executes the actual packaged `UI.HandleWheel` unchanged, alongside actual Quantity code, and covers field -> outside, outside -> field first wheel, field -> field, field -> ScrollView, ordinary ScrollView unchanged, wrapper sharing, last destruction cleanup and module reentry. The stale-refresh-removed negative control must fail. Root must build a new candidate and repeat the unchanged Web route; this follow-up is not yet Web-verified.
