# G5 debug departure inventory gate

The production departure path applied strict stock checks at three locations:
the loadout button, its callback, and `HangarApp:EnterTrial`. The explicit
`-vox-debug=1` flag did not affect any of them. `SalvageRules.testFill=999`
only grants a finite count per kind; aggregate garage usage and large authored
vehicles can exceed it. The exact stock deficit in the user's browser has not
been captured by this offline test.

## Change

`SalvageLobby:DeploymentShortfall(usage)` returns an empty shortage only when
`app.debugEnabled == true`. Otherwise it delegates to the existing strict
`Shortfall`. All three departure gates call it. Actual `Shortfall`, `Owned`,
`Loose`, stock persistence, trading and settlement are unchanged. Departure
still checks vehicle validity and operation entry value. Existing `svGo` and
`mapSalvage` debug actions already call `EnterTrial` and share its final gate.

Final frozen production SHA-256:

| File | SHA-256 |
| --- | --- |
| `scripts/app/SalvageLobby.lua` | `4f1b8daa6f380ae250e071f45c91bdd7f2aa3858b979f1e4d4823b902192b5f3` |
| `scripts/ui/SalvagePage.lua` | `6a442231e7c874af34f56ed411f09cca0c8df60221f47e5a3f4162496d8879e4` |
| `scripts/app/HangarApp.lua` | `f27e071d1a05e9771d1630761b7ed26ecde9a1c108172456a8e084d8e8bbc4b0` |

## Executed Checks

Run with the bundled Python and `tools/migration/check-salvage-debug-deploy.py`.
The actual complete Lobby, Page, App and DebugActions modules execute with
adapted widget/native services. The loading endpoint is an explicit sentinel;
no scene loading or hardware runs in this test.

- Before the fix, the check fails at `button gate debug=true quantity=1000`.
- After the fix: 51 assertions pass, including 1,000/20,000 required parts,
  real aggregate usage across two 800-block cars, all three departure gates,
  immediate strict checking after disabling debug, absent/string flags,
  both debug actions, valid stock and unchanged vehicle/value restrictions.
- Five behavioral mutations are rejected independently: remove the debug
  exception, accept truthy string flags, regress each of the three gates.
- All exercised departure checks leave stock, cash and write count unchanged.
- Existing natural rules: 221 assertions and 9 negative controls pass.
- Existing result/return rules: 179 assertions and 7 negative controls pass.

Evidence: `evidence/salvage-debug-deploy-offline.json`,
`evidence/g5-natural-parity-2026-10-16.json`, and
`evidence/salvage-result-return-offline.json`.

The new b2b281a1 package subsequently passed 16 actual Web checks using explicit
`-vox-debug=0` and `-vox-debug=1`: strict rejection versus mouse departure into
the loaded salvage transport opening, with unchanged stock, credits and saved
inventory. See `SALVAGE_DEBUG_STOCK_WEB_2026_10_17.md`. The browser and QA 4520
are closed; ordinary preview 4519 remains available. Landing, full raid,
real-account economy and performance remain separate acceptance steps.
