# G5 Salvage Garage Restoration and Departure

## Baseline

- Frozen H5 branch: `2026-10-15`.
- Commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Snapshot: `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
- Source contracts: `shared/salvage/session.js` (`enter`, `usage`),
  `shared/salvage/stash.js` (starter kit, test fill, shortages, purchases),
  `shared/ui/salvageHub.js` (`renderLoadout` departure control).

## Confirmed Defects and Changes

1. UrhoX treated a missing `draft` as an empty salvage garage and overwrote
   saved bay 1 with a starter. It now restores the selected saved bay, or the
   first valid saved bay when the selected bay is absent. Only a garage with no
   saved bays receives a new vehicle. Preview and entry select the same car.
2. New stash starter inventory was previously granted during vehicle creation.
   It now belongs to stash initialization, matching H5. An existing stash with
   no bays receives an empty chassis without another free starter kit.
3. UrhoX displayed an enabled departure control even with insufficient stock,
   then emitted only `warehouse missing <item>` at the final game guard.
   The loadout now disables departure, displays the number of shortage kinds,
   and restores the source tooltip directing the player to build or market.
   The Enter/direct callback guard also reports actual missing quantities.
4. Storage write failure during bay selection is propagated before changing
   the visible lobby. Existing bay contents remain intact.

## Inventory Behavior Preserved

- Installed parts count across all saved salvage vehicles. The active saved
  vehicle is replaced by its live blueprint once; an unslotted draft is added.
- Core chassis parts are free and excluded from warehouse usage.
- Test fill is still 999 per item on stash construction, as in H5. It is not
  unlimited stock. The actual mega-mech preset uses more than 999 light blocks,
  so its missing-block result is a legitimate shortage.
- Buying the exact shortage consumes credits and persists the inventory;
  failed persistence rolls the transaction back. Departure never auto-buys.
- A player's actual old-session stock has not been inspected. The reported
  user's precise shortage cause remains open pending account/runtime evidence.

## Verification

- `check-salvage-departure.py`: PASS, 74 checks, 7 rejected negative controls.
  Executes actual production Lua modules, actual blueprint/catalog resources,
  actual garage and store code, and `SalvagePage.Create/Key/Deploy`.
  Includes both configured 999 fill and an explicit zero-fill scenario.
- `check-g5-cloud-recovery.py`: PASS, 61 checks, 5 rejected negative controls;
  refreshed evidence includes the new production hashes.
- `git diff --check` passed for the owned production and test files.
- Evidence: `evidence/salvage-departure-offline.json` and
  `evidence/g5-cloud-recovery-offline.json`.

## Acceptance Boundary

CPU adapters control filesystem, JSON and UI widget construction. No GPU,
real account writes, user-save changes, live pointer testing, rendered visual
comparison, battle departure or mobile performance acceptance occurred here.
The source red outline for deficient installed-item tiles is not part of this
three-file repair. The CTA and keyboard guard do expose all shortage kinds.
