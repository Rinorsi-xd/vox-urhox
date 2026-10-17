# Close-range engine fixture readiness

Status: PASS / CLOSED. Serial real-engine Web fixture completed on port 4518.
Its browser and dedicated service were closed; ordinary port 4514 was preserved.

Baseline remains H5 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`.
Current prepared game is `.tmp/outgame-cached-1792180474126`,
`manifest-b88e4703.json`. The QA tail is injected only by an explicit
`--qa --qa-aim-engine` service; it does not modify the frozen game or ordinary service.

## Previous failures

- `evidence/aim-engine-1792179330476/result.json`: Playwright did not recognize
  `keyboard.press('F16')`. No fixture result. The driver now sends the actual F16
  virtual key through CDP.
- `evidence/aim-engine-1792179485297/result.json`: a large `OUTGAME_STATE` console
  message was truncated. No fixture result. The driver records incomplete state
  messages separately and still requires an intact hall state before continuing.
- Code inspection found another QA error before rerunning: the fixture assigned
  `player.weapons.energyMax`, which does not exist. It now reads the real
  `WeaponDefs.ENERGY.max` constant before the second shot. No production energy
  mechanics were changed.

Old failure evidence is retained. None of these failures proves an engine aim pass.

## Real Web execution

Evidence: `evidence/aim-engine-1792181760502/result.json`, `runtime.log`,
`before.png`, `after.png`. The screenshots show the hall; the controlled native
Bullet fixture is private and unrendered. HTTP byte audit of ordinary 4514 and
QA 4518 passed before launch (`evidence/http-snapshot-manifest-b88e4703-4514-4518-audit.json`).

The runner exited 0 with PASS, all 29 checks true, no Lua/page/HTTP errors,
`cleanup=true` and `browser=CLOSED`. The resource gate readied 24 dependencies.
Measured fixture results:

- Actual low enemy surface `[0, 0.31875, 4.75]` exceeded real turret limits;
  recovery selected reachable surface `[0, 0.80625, 4.75]` on the same enemy.
- Direct camera hit preserved that exact surface and made zero recovery calls.
- Actual laser Fire recorded one hit and 14 damage against the real enemy.
- A native 0.031496 m muzzle blocker stopped Fire while the camera still hit the
  enemy. No additional damage was recorded through that blocker.
- A native camera blocker hid the higher surface while leaving the low surface
  visible. Recovery retained the mechanically limited low point and Fire refused.
- Actual Flush and Spawn replaced native vehicle/weapon ownership correctly;
  Clear released all retained aim callback references.

This is correctness evidence for those controlled aim paths, not visual,
natural-match, FPS, mobile or Snapdragon 845 acceptance.

## Engine checks

The tail constructs a private, unrendered Scene with real PhysicsSpace, CarUnit,
VehicleSpec, WeaponLoadout, WeaponSystem, TrackWorld.CastRay/Hit, AimAssist,
AimReach and DriveAim modules. It verifies:

1. The real low soft-lock surface is mechanically unreachable; bounded recovery
   finds a reachable surface on the same real enemy.
2. A real camera ray directly hitting the enemy bypasses recovery and preserves
   the exact reticle hit.
3. A real laser Fire damages the real enemy.
4. A native box between muzzle and target blocks a second real Fire while the
   camera still sees the target.
5. A native camera wall leaves the low surface visible and hides the recovered
   surface. Recovery refuses the hidden surface and the limited turret cannot fire.
6. Real Flush/Spawn replacement refreshes retained body/weapon references; Clear
   drops those references. Fixture objects are disposed even on assertion failure.

Before constructing the fixture, its coroutine uses production ResourceGate to
download the dependency index and the exact core/cube/laser3 dependencies. Hall
readiness alone is insufficient for on-demand Web rigs. Completion callbacks
only mark readiness; construction resumes on the next update. Cleanup cancels
the fixture's own gate if a download or assertion fails.

The final report travels in numbered console records of at most 1800 text bytes.
The driver requires every chunk, accepts identical transport retries and rejects
conflicting duplicates, malformed records and inconsistent run IDs. A partial
report cannot be mistaken for PASS. A completed report must contain the named
reachability, exact reticle, damage, muzzle-wall, camera-wall and cleanup checks.

This fixture is controlled geometry, not natural gameplay, visual approval,
timing, FPS, TapTap or Snapdragon 845 evidence.

## Offline verification already run

- `node tools/migration/check-aim-engine-web.cjs --protocol-test`: PASS. Covers
  long reports, missing/reordered/retried/conflicting chunks, malformed records,
  bounds and truncated state messages ending in a nested closing brace.
- Actual Lua 5.4 compilation of `qa-aim-engine.lua`: PASS; fixture not executed.
- `check-aim-fallback.py`: 43 existing assertions and 6 behavioral negative tests
  PASS against actual modules. This remains offline evidence.

## Exact serial run

Root selects a free QA port; 4516 is an example. Restarting a dedicated service
is required because it captures the QA tail at startup. Keep ordinary 4514 and
the user's old tabs unchanged.

```powershell
$env:VOX_PREVIEW_PORT='4516'
$env:VOX_PREPARE_FILE='.tmp/outgame-cached-1792180474126/identity.json'
node tools/migration/serve-outgame.cjs --qa --qa-aim-engine
```

In the runner process, from the project root:

```powershell
node tools/migration/audit-snapshot-http.cjs .tmp/outgame-cached-1792180474126 4514 4516
$env:VOX_QA_PORT='4516'
node tools/migration/check-aim-engine-web.cjs
```

Expected hardware occupancy: approximately 1-2 minutes if hall startup is warm;
hard limits are 240 seconds to hall and 60 seconds after F16, plus screenshot and
browser cleanup. The driver closes its own browser and writes a new
`evidence/aim-engine-<timestamp>/result.json` with identity, raw log, before/after
or failure screenshot, geometry, individual checks and cleanup state. The root
must stop only the dedicated QA service when finished.

If an assertion fails, retain the failure and diagnose its exact geometry or
shipping module before changing gameplay. No production code was changed here.
