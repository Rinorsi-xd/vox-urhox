# G2 inventory digit stock parity

Status: LOCAL_IMPLEMENTED / OFFLINE_PASS / WEB_OPEN.

This continues G2 on branch `1016`, H5 `2026-10-15`, frozen commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`. It does not restart G0.
There is no commit, push, server launch or runtime launch in this subtask.

## Confirmed user-visible difference

The actual frozen `shared/ui/inventory.js` `digit(i)` checks `_available`
before assigning the hovered or focused part. With no remaining stock,
the number key selects that hotbar slot instead.

The actual Lua `InventoryPanel:Digit` always called `AssignHotbar` for an
identified part, even with zero stock. In salvage, the existing
`SalvageBuild.AssignHotbar` wrapper opens a purchase prompt for this call.
In endless editing, the existing wrapper rejects the call with a stock
notification. Both differed from the source slot-selection behavior.

## Narrow production change

The conditional in `scripts/ui/InventoryPanel.lua:Digit` changed:
assignment requires `not self:Unavailable(id)`; otherwise it calls the
existing `SelectHotbar`. This uses the existing salvage Remaining policy
and the existing endless per-panel Unavailable override. Normal catalog
assignment, available stock, mouse purchase, drag/drop, existing hotbar
parts, geometry, rendering and stock consumption are not altered.

`scripts/ui/InventoryKeys.lua` also filters unavailable non-buyable parts
from `Stops` and refuses them in `Focus`. The existing initial-focus path
therefore falls back to the close button when the current part is disabled.
The salvage `stockRemaining` policy is buyable, so its zero-stock cards
remain in Tab order and may still open the purchase dialog. Normal catalog
parts remain focusable. Offscreen focus preserves original result indices.

Production SHA256:
`4e6f796d40c0b32121a1e46d244249988380902809cffd913df60a9780cec6fe`.

InventoryKeys SHA256:
`f9bde8322b5e32d4b01c5943aba6752f441ddf2b87914c01621209d33e0500f4`.

## Actual source/consumer verification

`tools/migration/check-inventory-digit-stock.py` verifies the snapshot's
source SHA, then executes its complete `_available` and `digit` methods
with Node VM. It compares callbacks against the real Lua
`InventoryPanel:Digit`, `Remaining`, and `Unavailable` under Lua 5.4.

- 36 combinations: normal/salvage/endless, stock 0/1/4, hovered/focused
  part and no part. Source zero-based and Lua one-based slot indices are
  explicitly converted. Callback/focus adapters do not render UI.
- Unmodified production: 4 failures, retained in
  `evidence/inventory-digit-stock-before.json`; every failure is the
  zero-stock part invoking assignment rather than slot selection.
- Modified production: 36 cases PASS, retained in
  `evidence/inventory-digit-stock-offline.json`.
- Additional actual frozen `_fill` execution supplies disabled status for
  9 normal/salvage/endless stock cases. Real Lua `Stops` and `Focus` match
  allowed parts and initial focus; two negative controls reject immutable
  c074 InventoryKeys and incorrectly skipping buyable salvage parts.
  `evidence/inventory-digit-stock-focus-offline.json` records 36 digit cases,
  9 focus cases and both controls PASS.
- Related detail-retention regression: actual existing 120 checks PASS,
  `evidence/inventory-detail-retention-digit-regression.json`.
- Limited `git diff --check` passed. Its existing Git LF-to-CRLF warning
  is not a Lua runtime error.

The first oracle attempt incorrectly normalized CRLF before checking the
snapshot SHA and stopped before running cases. The tool now verifies raw
bytes first, then normalizes only the method-extraction text. The source
hash guard was retained.

## Earlier G5 h evidence boundary corrected

The existing `endless-stock-web-c074-h` full flow remains its original PASS.
Its exhausted laser was active slot 7; slot 10 was empty. The old runner
required Tab to reach the disabled card and digit 0 to preserve active slot
7. That section proves the old flow did not modify the blueprint/inventory,
but does not prove H5 keyboard parity: actual H5 `_fill` sets disabled on
exhausted non-buyable cards, and root Tab stops use
`button:not(:disabled)`. Disabled native HTML buttons cannot be Tab-focused.
Source `digit` still selects slot 10 when hovering a zero-stock part, or
when there is no assignable hovered part. The old sameSelection assertion
includes active/type, so it will reject this intentional source correction.
This subtask has not edited the shared G5 runner or rewritten its old result.

## Same-build public-input acceptance still required

Root should include this SHA in the next unified package. In salvage
construction, open inventory with a zero-stock purchasable part, hover
it and press a number: active slot must change without a purchase modal
or hotbar assignment. Repeat with keyboard focus. Clicking the same
zero-stock part must still open the original purchase dialog; an
available part must still assign via number key. Repeat slot selection
in endless editing with a consumed limited part. These tests must use
real UI input rather than calling the callback directly.

No browser/Yoga/NanoVG visual check, full G2 acceptance, full inventory
workflow, FPS improvement or Snapdragon 845/TapTap claim is made here.

## Prepared narrow actual Web check

Use a new unified identity containing both production SHAs, then root alone
may run:

```powershell
node tools/migration/inventory-digit-stock-web-serve.cjs <identity.json> 4581
node tools/migration/inventory-digit-stock-web-run.cjs http://127.0.0.1:4581 docs/migration/evidence/inventory-digit-stock-web-1017-a
```

The dedicated server appends a read-only F8 observer. No source inventory or
blueprint is injected. The runner uses public salvage entry, E/B, a naturally
missing weapon's actual search field, mouse hover and digit, actual Tab focus
and digit, and finally clicks the buyable missing card to confirm purchase
still opens without confirming or spending. It requires active-slot change,
unchanged hotbar/content/history/stock and no purchase modal for number keys.
Module HTTP bytes, current production and identity hashes are pinned.
The observer waits for actual game PostUpdate before runner polling starts.

`--self-test` and Node syntax checks PASS; no server/browser was launched by
this subtask. The narrow check covers salvage common consumer behavior, not
natural endless exhaustion or every Tab key in a rendered endless inventory.

## Actual Web a failure and isolated observer correction

Root ran `evidence/inventory-digit-stock-web-1017-a`: FAIL, CLOSED,
exit 1, zero runtime and HTTP errors. The hall rendered, the read-only
observer emitted READY and the standard probe emitted OUTGAME_STATE, but
the runner failed its fresh-snapshot gate before loaded-hall acceptance:
there were no INVENTORY_DIGIT_STATE records. This is a QA acquisition
failure, not evidence that the inventory input correction failed.

The original observer read F8 only in PostUpdate; the standard probe reads
it in Update. The observer now latches the request before the original
Update callback and reads state after the original PostUpdate callback.
It retains both original callbacks, clears each request once, and changes
no production script. The precise reason F8 was absent from the original
actual PostUpdate remains unconfirmed until the rerun.

`check-inventory-digit-observer.py` executes the actual observer in Lua 5.4
with an explicit adapter where key press is available during Update and
cleared before PostUpdate. Six checks PASS, including the original
PostUpdate-only negative control; this is a phase-contract test, not a
browser result. Evidence: `evidence/inventory-digit-observer-phase-offline.json`.
Observer SHA256:
`6a8a23d0cf7392fd3a007ee0e549f1fa620437f17b9138b67c507ee6c5c3af54`.
The runner's unchanged five-negative self-test and limited diff check PASS.

Root's new candidate command, retaining a unchanged:

```powershell
node tools/migration/inventory-digit-stock-web-serve.cjs .tmp/outgame-cached-1792217492466/identity.json 4581
node tools/migration/inventory-digit-stock-web-run.cjs http://127.0.0.1:4581 docs/migration/evidence/inventory-digit-stock-web-1017-b
```

Actual rendered public-input validation remains OPEN until b completes.

Root ran b and retained `evidence/inventory-digit-stock-web-1017-b`:
FAIL, CLOSED, exit 1, zero runtime/HTTP errors, stage `loaded hall`, zero
inventory states and the same `Fresh snapshot` gate failure. Therefore
the Update latch did not resolve actual acquisition. The offline phase
contract remains a narrow PASS and cannot explain the actual failure.
No further speculative observer change or runtime retry was performed.
Production digit/focus corrections remain offline-verified, Web OPEN.
Main work has returned to the user's ADS visibility and measured CPU request.
