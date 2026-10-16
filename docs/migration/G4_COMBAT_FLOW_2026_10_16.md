# G4 Boss combat flow continuation - 2026-10-16

## Scope and baseline

- Continues the existing G0-G6 plan after unified `manifest-4227f9e4.json`; does not restart G0.
- Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
- Production edits are limited to `scripts/combat/StoryBoss.lua` and `scripts/story/BossRules.lua`. No shared Mission, TrialSession, controls, general rendering or UI changes. No GPU, package build, commit or upload.

## Confirmed omissions corrected

1. Jump landing now reads the existing physics-stepped `self.flight.t`, forwarded from `StoryBoss.Update` into `BossRules.Step`, matching source `FoxBoss.update` and `_fly`. The render state clock can advance across dropped frames without physical flight advancing; the prior implementation could land immediately after a render stall.
2. A harmless hop no longer resets the attack-slam cooldown. Source `_land` returns after the hop shock/recovery branch before the regular slam cooldown assignment. Regular and drill slams retain their cooldown reset.
3. A dead player now prevents starting new Boss special attacks even when an ally remains alive. The source `fight` branch first requires a live player target; ally focus is chosen inside that gate. Physical weapon stepping against allies is unchanged.

## Retired content rejected

The frozen source still invokes `say('barrage')`, but its authored `level5.js` lines do not contain that key and source `say` returns false. The production Level5 JSON also lacks it. An exploratory Lua first-salvo hook was removed before freeze; no deleted dialogue was restored. This is checked against both complete source and production data.

## Verification

`tools/migration/verify-story-boss-combat-flow.py` executes the complete frozen JS `FoxBoss.update`/`_land` and actual Lua `StoryBoss.Update -> BossRules.Step -> StoryBoss.Events`. It covers hop/drill/regular landings, physical-time thresholds with and without contact, render stalls, player alive/dead with special readiness, and repeated barrage salvos with absent dialogue.

- New comparison: **1090 checks, 183 cases, 191 frames PASS**. The old 4227 scripts reproduce the render-stall landing, hop-cooldown and player-death differences.
- Regressions on final production SHAs: waypoint **952**, physical kneel **2178**, allies **3079**, kneel dialogue **1617**, all PASS.
- Evidence: `evidence/story-boss-combat-flow-offline.json`; related regression reports were refreshed with the final StoryBoss SHA.
- Harness corrections: added source `_ringGrow` adapter; removed an assertion for the nonexistent barrage line after inspecting authored source; supplied Lua ground/roof adapters used by `StartSlam`. No production exception swallowing was added.

## Frozen production identity

| File | SHA256 |
| --- | --- |
| `scripts/combat/StoryBoss.lua` | `ebb80335ce9a59ff8521ce401e60680dfa899bbf1c1ef3c1e6d9711658b1f86f` |
| `scripts/story/BossRules.lua` | `597396c26f1b0b57a5d50dddc55fb0a68189d063c742c65079f385bb8ef68f1a` |
| `assets/Story/Mission/Level5.json` (unchanged) | `55b9aca6e821cc6c5e3766991e3fe6bea1fd2e5207892c0663b19accd82d7319` |

## Acceptance boundary

HUD, body, visual effects and projectile launch are adapters; target-only action creation is adapted while the actual source update decision and Lua production decisions execute. These checks verify behavior contracts and event wiring, not native physics feel, visible Boss choreography, audible output, natural complete mission or mobile performance. Those remain OPEN under the existing plan. The old 4227 runtime evidence does not cover this later increment.
