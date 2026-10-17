# G5 settlement after returned hall

Date: 2026-10-17. Branch: `1016`. This closes a source-order defect in code and offline contracts; actual Web return acceptance remains pending. No hardware, build, commit or push was performed in this subtask.

## Frozen reference and correction

Reference: H5 10/15 commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, recorded by `baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json`. Its actual `_extracted`, `_fail`, `_finish`, `dispose`, blocking `key` and Stash economic methods were executed with the import/DOM/timer/save edges adapted. Part definitions use the generated migration `UI/Outgame.json` catalogue; this is an import adapter, not independent proof of catalogue identity.

H5 normal settlement waits 250 ms, exits the live drive, then shows the result owned by the hall. Abandonment through disposal keeps the original car, loses cargo, counts one loss and shows the result after leaving. The result button only closes its modal. The previous Lua order displayed the result over the live battle and required acknowledgement before returning, so this was a real migration difference rather than an intentional match to the source.

The current implementation automatically requests return after the original 250 ms completion delay. `salvage.ResultReturn` retains copied result/part data and the lobby store only, without the old run/session/world. The hall displays the result only after actual old trial disposal, hall installation and loading closure. Acknowledgement closes that modal without another reload or economic write.

## Lifecycle and failure handling

- Success, death, timeout and abandonment preserve the same source economic outcomes and original run identity. Repeated return/acknowledgement cannot charge or credit twice.
- `Run.Dispose` also handles F5/scene replacement during an unfinished begun raid as abandonment. Disposal during the 250 ms finished delay retains the already settled outcome instead of adding another loss. Cancelling preparation before Begin records no loss.
- Blocking drop/extract/death cinematics leave ESC/T to the existing session controls, matching source. Space still uses the authored drop skip. The project's unified ESC pause behavior remains owned by the session.
- Failed local writes retain a detached retry result through hall loading and owner closure. Successful retry commits the original result once. Local commit is not cloud ACK or real-account acceptance.
- The existing engine hall load is asynchronous. The abandonment 200 ms visual delay currently starts after hall/loading readiness; H5 starts it at synchronous disposal. This documented timing difference remains and is not represented as millisecond-identical animation.

## Changed files

Production: `scripts/salvage/ResultReturn.lua` and its `.meta`, `scripts/salvage/Run.lua`, `scripts/ui/SalvageRunHud.lua`; narrow lifecycle hooks in `scripts/app/HangarApp.lua`. Other preexisting dirty changes in shared files are preserved. Full SHA-256 values are recorded in `evidence/salvage-result-return-offline.json`.

QA: result/source/offline fixtures, public natural-return runner, read-only probe, return acceptance gates, and the old Native settlement/cinematic expectations. Native expectations now allow source-compatible abandonment and detached save retry; Native hardware tests were not rerun.

The probe exposes actual hall generation plus bounded release booleans observed immediately after old `TrialSession.Dispose`. Public acceptance requires all seven release fields, hall-owned result, no live salvage run, closed loading, committed original result, identical generation/economy across acknowledgement, then actual garage/loadout mouse transitions. A closed Debug overlay alone is never sufficient input proof.

## Verification and remaining acceptance

- Actual Lua/source lifecycle/economic suite: 179 checks and 7 behavioral negative controls PASS. It executes the current enclosing `TrialSession.Dispose` body with engine services adapted, including direct F5, save failures and disposal during the completion delay.
- Return acceptance contracts: 40 checks PASS, including rejection of hidden hall reload, repeated settlement, unreleased old resources and unknown overlays.
- Existing result, natural parity and extraction suites remain separate evidence; their earlier passing results are not actual acceptance of the new hall flow.
- Public `--return-only`, actual old trial release, result button without reload, garage/loadout clicks and rendered result inspection must be rerun against a newly frozen build/probe. Existing pre-change Web acceptance in `G5_RETURN_OVERLAY_2026_10_17.md` does not certify this production change.
- Real account/cloud ACK, full extraction/death/timeout routes, long-session memory, whole-frame performance and Snapdragon 845 sustained 30 FPS remain OPEN.

This correction does not claim to improve combat FPS or identify the remaining CPU bottleneck.
