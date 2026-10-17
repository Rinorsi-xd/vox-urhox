# G5 trade failure feedback - 2026-10-16

Status: production candidate frozen after actual source/consumer checks. Web rendering and real-account acceptance remain OPEN.

## Baseline and change

Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Source `shared/salvage/stash.js` buy/sell and `shared/ui/salvageHub.js` `_trade` are executed unchanged in the source oracle; their hashes are checked against the baseline registry.

`scripts/app/SalvageLobby.lua` Trade now returns the source business messages:

- A sale that needs installed parts explains that installed parts must first be removed.
- Other insufficient stock reports the source stock failure.
- An unaffordable purchase reports the exact total shortage with grouped thousands, before checking warehouse capacity.

Only failure feedback changed. Quantity, stock, credits, storage transaction behavior and UI composition are preserved.

Before SHA-256: `9eb9b132a1983fc2f99e738fc2a4482ce897ede40b267102464b5af1d045ce66`.

Frozen SHA-256: `24409eb0f27604038c230a77f0db32681034217f265849a32cd4706f79d49c29`.

## Verification

Run `python tools/migration/check-salvage-trade-failures.py` with the bundled Python containing Lupa support via `.tmp/nav-python-deps`.

The before-change production failed case 1 at the actual Page.Trade toast consumer. The final version passes 26 source scenarios / 156 checks / 3 rejected negative controls. Tests execute real source stash+hub and production Lobby.Trade+Page.Trade, with actual item/capacity data. Cases cover installed stock, absent stock, multiple purchase quantities, shortages from 1 through 1,234,567, full warehouse and error priority. Every failure preserves all inventory, balance and entered quantity, plays no purchase/sale sound, and performs no storage write.

Negative controls restore either generic error or incorrectly calculate shortage without quantity; all are rejected at the source business failure assertion.

Focused regressions: result 29 checks PASS; cloud recovery 61 checks / 5 rejected negative controls PASS.

Evidence: `docs/migration/evidence/salvage-trade-failures-offline.json` records source and production SHA-256, all checks and rejected controls. Native/UI rendering, audible quality, actual accounts and performance are outside this offline test boundary.
