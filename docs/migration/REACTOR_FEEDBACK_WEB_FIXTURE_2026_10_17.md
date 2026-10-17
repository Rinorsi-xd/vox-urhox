# Reactor Feedback Rendered Fixture

Status: **A FAIL / CLOSED; B SUPERSEDED_NOT_RUN; C PASS / CLOSED**. This fixture is functional rendered acceptance, not natural combat or a performance benchmark. Root ran A and C separately; this child audited the saved C evidence offline and did not launch hardware.

## A Failure And B Fixture Correction

Root's A capture is preserved at `evidence/reactor-feedback-web-20261017-a`. All seven screenshots/readbacks were saved; the runner failed because `culled` showed the unhit blue reactor still enabled. At age 1.35 the red active-flash reactor had already run its per-frame visibility refresh, but blue had not reached its next normal 10 Hz refresh within the three-frame (0.05 s) away interval. This does not establish a shader/depth defect.

Only the QA fixture changes for B: wait seven fixed frames (0.116667 s) while facing away, exceeding the ordinary refresh interval. On return call actual `view:Update(0,rule,cameraNode)` to check immediate re-entry without advancing the flash clock; the snapshot still waits a rendered frame before native readback. The existing runner/thresholds and both production files remain unchanged. The repeated explosion's flash is approximately 0.533333 on cull return. B uses the same unified source freeze as A and a fresh derived directory; A's fixture, report and screenshots are not overwritten.

Root then visually found A's screenshots were still covered by the HTML 0% loading layer; A cannot sign rendered reactor output even where its native readback checks succeeded. B was not run and is superseded. The QA-only C runner now removes `#loading` only after the first actual fixture snapshot (at least 60 Update callbacks, scene submitted and native geometry readback available), recording removal timing. This follows the isolated decision-fixture runner approach; it does not emit a fake production LoadingFlow message or change the shared shell.

C requires the loading node absent, five viewport points reporting canvas as the top element, and full-size canvas bounds. Screenshots use `locator('#canvas')`, carry SHA-256, and compare white-pixel counts: hit and explosion must produce more white pixels than the idle/decayed image. A fixed loader or frozen screenshot therefore fails. Shell loader/topmost/bounds controls and a constant-white-image control are included in nine rejection tests. This additional validation still requires root's visual inspection.

C was prepared from the same unified `.tmp/outgame-cached-1792191490122/identity.json` into `.tmp/reactor-feedback-web-20261017-c/identity.json`. Root ran the following commands on the dedicated port 4562; the completed runner reports `shutdown: CLOSED`:

```powershell
node tools/migration/reactor-feedback-serve.cjs .tmp/reactor-feedback-web-20261017-c/identity.json 4562
node tools/migration/reactor-feedback-run.cjs http://127.0.0.1:4562 docs/migration/evidence/reactor-feedback-web-20261017-c
```

## C Actual Result And Independent Evidence Audit

Saved evidence: `evidence/reactor-feedback-web-20261017-c/report.json`, `runtime.log` and seven stage PNGs. The run started at `2026-10-16T23:11:24.206Z` and finished at `2026-10-16T23:11:55.488Z` (2026-10-17 in Asia/Shanghai). The report records `status: PASS`, seven completed stages, `released: true`, `errors: []`, `httpErrors: []` and `shutdown: CLOSED`. These are this fixture's captured errors, not a claim about every game route.

The offline independent audit read all seven snapshots and recomputed every PNG SHA-256; all seven match the report. The HTTP main entry and both repaired module hashes match the frozen identity:

| HTTP resource | SHA-256 |
|---|---|
| `main.lua` | `4f50f196b69b297108f138acb42882768e5a4e0f1c06c2a350b3e5f5d0746a95` |
| `render/ObjectiveView.lua` | `b680c39195cf041564c0ed112003d7245df22fbe0c016ce46a35b4865392348c` |
| `combat/BattleObjectives.lua` | `0034441d32c41a1a0f5e4cfbec99955fa60bfd65bc2b0675d6725e3fcabc07fc` |

All captures are the actual 960 x 540 engine canvas, with no HTML loading node and canvas topmost at all five sampled viewport points. The loader was removed only after the first native snapshot at Update callback 62. Root visually inspected `before.png` and `hit.png`: the red reactor becomes white on hit while the blue reactor remains blue. The numerical and pixel records are consistent with that inspection:

| Stage | Red flash | Charge red / blue | Actual mesh enabled red / blue | White canvas pixels |
|---|---:|---|---|---:|
| before | 0 | 50 / 50 | true / true | 0 |
| hit | 1 | 48 / 52 | true / true | 9,595 |
| decayed | 0 | 48 / 52 | true / true | 0 |
| explosion-hit | 1 | 46.8 / 53.2 | true / true | 9,594 |
| culled | 0.533333 | 46.8 / 53.2 | false / false | 0 |
| cull-return | 0.533333 | 46.8 / 53.2 | true / true | 6,884 |
| shielded | 0 | 46.8 / 53.2 | true / true | 0 |

The hit X displacement is +0.079063 m, explosion displacement -0.108266 m, and the decayed/shielded X returns to -6 m. Blue uploaded vertex color is unchanged across all seven snapshots. The culled canvas has zero non-dark pixels as expected when facing away; every visible stage is nonblank. Shield restoration prevents both charge theft and a new flash. A remains FAIL/CLOSED with its original invalid loader screenshots preserved; C does not retroactively validate A. B remains unrun.

This closes only the isolated reactor feedback rendered fixture. It does not measure natural battle timing, complete G3, prove an FPS improvement, or accept Snapdragon 845 / TapTap sustained 30 FPS.

## Files And Isolation

New QA-only tools:

- `tools/migration/reactor-feedback-prepare.cjs`: takes the new unified frozen identity, requires both repaired production module hashes to match `reactor-feedback-1015-offline.json`, derives a separate project and changes only its main entry.
- `tools/migration/reactor-feedback-render.lua`: uses actual frozen `ObjectiveView`, `BattleObjectives`, `ConquestRules` and `ArenaData`; creates one real Scene/Octree/Camera and two reactors. Synthetic scores/shield/aims exist only in this fixture. No normal App, player inventory, saves or battle is created.
- `tools/migration/reactor-feedback-serve.cjs`: requires the dedicated fixture identity and delegates serving to the unchanged existing isolated-fixture server.
- `tools/migration/reactor-feedback-run.cjs`: verifies actual HTTP main and both production module SHA-256 values, launches its own browser, captures/acknowledges seven stages, checks node/color readback and screenshot pixels, then closes its browser. Does not stop unrelated services.

The tools reuse `g1-web-cpu-prepare.cjs`/`g1-web-cpu-serve.cjs` without editing those files or the normal preview/QA runners. Resource hardlinks in the derived project must remain read-only. Original frozen/production files stay untouched. The fixed 1/60 updates are deliberate reproducible fixture stages, not a real-time or FPS measurement.

Earlier G3 delivery changed only two production files: `scripts/render/ObjectiveView.lua` and `scripts/combat/BattleObjectives.lua`. It also changed `tools/migration/combat-source-golden.cjs` to use the current baseline plus SHA checks, added `check-reactor-feedback.py`, and updated `COMBAT_FX_SOURCE_PARITY_PROGRESS.md` plus offline JSON results. No Intro, IntroAudio or CURRENT change belongs to this child increment.

## Run After Unified Freeze

Replace the first value with root's newly built unified identity that contains the repaired modules. Use a fresh output directory and a free port. Do not use an earlier freeze missing the two hash-bound fixes; preparation rejects it.

```powershell
$reactorFreeze = '.tmp/outgame-cached-NEW/identity.json'
node tools/migration/reactor-feedback-prepare.cjs --frozen $reactorFreeze --out .tmp/reactor-feedback-web-NEW
node tools/migration/reactor-feedback-serve.cjs .tmp/reactor-feedback-web-NEW/identity.json 4560
```

Run the following separately while that dedicated service is running:

```powershell
node tools/migration/reactor-feedback-run.cjs http://127.0.0.1:4560 docs/migration/evidence/reactor-feedback-web-NEW
```

The runner refuses to overwrite a prior result, uses a 180-second deadline and closes its owned browser on success/failure. Stop only the dedicated 4560 service after root inspects the result. Do not leave it running as a normal preview.

## Expected Artifacts And Acceptance

`report.json` binds service identity and HTTP hashes; `runtime.log` preserves all errors and snapshots. Each stage waits for screenshot completion and a real F8 acknowledgement before continuing, so its geometry stays fixed during capture. The seven PNGs are:

| Capture | Expected actual state |
|---|---|
| `before.png` | Both visible; no flash; red shield down, 50 charge |
| `hit.png` | Actual `BattleObjectives:Hit` steals charge; red flash=1, first uploaded crystal color white, X displacement within 0.15m; blue unchanged |
| `decayed.png` | After 18 fixed updates flash=0, source X restored; exposed warning color remains |
| `explosion-hit.png` | Actual `BattleObjectives:Explode` steals source 60% charge and restarts flash |
| `culled.png` | Camera faces away; both actual meshes disabled and red marked culled; flash keeps decaying |
| `cull-return.png` | Camera returns; mesh re-enabled with still-active flash and updated uploaded color |
| `shielded.png` | Shield restored, both hit methods do not steal/flash; original X restored |

Readback uses documented `CustomGeometry:GetVertex(0,0).color`, `Color:FromUInt`, `GetNumVertices`, mesh enabled state and node position. Non-culled screenshots require 960×540 dimensions and nonblank colored pixels. Root still needs visual inspection to confirm composition/shader output; automated numeric checks alone do not sign user visual acceptance.

## Offline Checks Run

```powershell
node tools/migration/reactor-feedback-run.cjs --self-test
node --check tools/migration/reactor-feedback-prepare.cjs
node --check tools/migration/reactor-feedback-serve.cjs
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-reactor-feedback.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-combat-source-fx.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-objective-culling.py
```

Runner positive readback/shell sequences plus nine rejection controls passed. Lua 5.4 compilation of `reactor-feedback-render.lua` passed offline; no native binding/render claim follows from compilation. Prior real-module regression results remain 249 checks/four mutations, 18 current-source FX scenarios, and 45 culling checks/four mutations. The isolated C rendered fixture is now PASS/CLOSED with root's before/hit visual inspection; natural combat and Snapdragon 845/TapTap sustained performance remain open until separately run and accepted.
