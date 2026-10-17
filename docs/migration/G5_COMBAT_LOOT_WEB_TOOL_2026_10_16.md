# G5 optional combat-loot consumer route - 2026-10-16

Status: tool frozen, offline contracts PASS. Actual unified Web execution FAILED with OOM before any verified kill/drop; acceptance remains OPEN. See `G5_SALVAGE_WEB_OOM_2026_10_16.md` for manifest8d107d95, raw log3924, actual runner79514 exit1/CLOSED and preserved incomplete JSON. No successful natural combat-loot route is claimed.

## Entry

Use the existing immutable QA package server port selected by the root task. In PowerShell:

```powershell
$env:VOX_QA_PORT = '<current immutable QA port>'
$env:VOX_NATURAL_STRONG = '1'
$env:VOX_NATURAL_STRICT = '1'
node tools/migration/check-salvage-natural-web.cjs --combat-loot
```

By default this follows genuine hangar -> salvage -> existing source workshop purchase/garage selection -> departure -> drop -> mouse capture -> movement -> public mouse aiming/firing -> at least two observed enemy deaths -> E remnant search -> exact actual cargo pickup -> T abandonment -> result -> return -> local store readback. No QA damage, kill, teleport, cargo or clock fixture is used.

The optional `VOX_NATURAL_COMBAT_KILLS` ranges from 2 to 4. The route chooses a source encounter whose squad has distinct observable names; ambiguous duplicate names cannot certify a death and cause explicit failure. Actual firing, enemy survival/damage, terrain access and remnant reachability can fail; the tool saves that failure and screenshots rather than manufacturing a pass.

Set `VOX_NATURAL_EXTRACT=1` and optionally `VOX_NATURAL_ROADS=1` to attempt the existing actual extraction/countdown route after enemy pickups instead of abandonment. This is expected to require longer hardware occupancy. No successful extraction is claimed by creating this tool.

Without `--combat-loot`, the original natural crate/death/extraction routes remain selected exactly as before. The source road navigation and timed extraction helpers are unchanged.

## Proof and boundaries

Each confirmed death requires a previously unique red actor to disappear while the real Run kill counter increases. Last living coordinates are only a search destination; a matching named remnant prompt and actual matching E-search panel independently establish the drop consumer. Every completed item must be shown/full; `n-left` must equal the precise cargo delta, with no unrelated added or removed cargo. At least one item must actually enter cargo for every counted remnant. Full remnants remain valid if a partial pickup occurred; they need not auto-close.

On abandonment the original stash remains unchanged and all carried goods are discarded. On extraction only committed net cargo is added. Both paths check unchanged credit balance, once-only outcome counts, real transaction identity, return overlay release and actual local validated-store readback in strict mode. Refresh/cloud/accounts remain outside this same-session route.

The route observes sequential public-input consumers. It does not establish simultaneous multi-death ordering or exclusive player attribution for every death. Atomic insertion/drop/RNG order remains covered by the separate actual-source 256-case death-order test. This functional browser tool is not an isolated frame-rate benchmark.

## Offline verification

`node tools/migration/check-salvage-combat-loot-tool.cjs` regenerates verified frozen H5 source fixtures, replays 256 cases / 656 actual source pickups and rejects 112 no-pickup remnants. Seventeen adapter checks also reject despawn-only disappearance, unrelated deaths, duplicate names, friendly/unobserved actors, unrelated crates, unfinished/hidden search, phantom cargo, missing pickup, removed cargo and invalid leftovers. This proves evidence checks, not Web execution.

Existing navigation 28 checks PASS, including replay of the old failed 93-sample route. Progress replay PASS still reports that old route as failed. `node --check` and `git diff --check` pass (Git line-ending policy warnings only).

Frozen `check-salvage-natural-web.cjs` SHA-256: `8b0f35e1c87e24aa2cba660b1b2ea9c8329ab8a99e0cb4bda631c575b1cfb773`.

The frozen hash above identifies the original OOM run. A subsequent QA-only fatal watchdog correction changes the tool hash to `c2bf28b64f1b57fc1db4ee22b2795341c648fa04652a2a03a1d61fd3879d5c64`. It interrupts stalled input after OOM/RuntimeError, persists FAIL and bounds actual browser close with honest CLOSED/CLOSE_TIMEOUT/FAILED states.22 controlled offline checks PASS; original OOM artifacts are unchanged, and no new actual combat-loot pass is claimed. Details are in the independent OOM report.

Evidence: `docs/migration/evidence/salvage-combat-loot-tool-offline.json` and existing natural navigation/progress offline reports. Runtime output remains in the established `salvage-natural-<manifest>-<time>` evidence directory with `combatLoot` samples, death/search/cargo records, failure, screenshots and shutdown status.
