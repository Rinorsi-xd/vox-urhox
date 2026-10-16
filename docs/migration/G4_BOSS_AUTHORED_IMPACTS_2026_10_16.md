# Boss cinematic input and authored impacts

## Prevent an unintended missing ending

The higher-impact defect found during the follow-up audit was in `TrialSession.Update`: holding Enter during ordinary Boss combat set `boss.skip`, which survived release and caused the first ending update to complete immediately. This silently omitted the defeat, escape pod, recovery truck and their dialogue. Frozen H5 `BOSS_KIND.key` only arms this action inside its cinematic, on a fresh key press.

The production branch now requires a cinematic and a fresh press belonging to that flow. Releasing Enter or leaving a cinematic resets hold tracking; a new flow cannot inherit it. The first press does not charge the previous frame's duration. The threshold is strictly over 900ms, matching source, rather than at 900ms. Ordinary dialogue Enter still uses the existing handler.

Final TrialSession SHA256: `21643c47e238d69d7544d4664396f114badd79c4d9f438e3dd77d3fac2214acb`.

`verify-story-boss-cinematic-input.py` executes complete source `BOSS_KIND.key`, the actual Lua TrialSession held-key branch, and then actual source/current ending update branches. Six controlled parity scenarios plus two historical divergence scenarios / 43 checks pass. The parity cases cover fight-release-ending, held across fight-ending, first threshold, release/repress, fresh flow and first-frame accounting. The actual previous 46ba package mismatches five parity scenarios and actually takes the unintended ending-skip branch. Three required mutations are rejected.

This is a conservative fix against accidental ending skips, not a claim of 1:1 parity with all historical H5 input behavior. Real H5 reuses the same `F` object through introduction, fight and ending, and never clears `F.holdAt`. A press during the introduction can therefore leave an old timestamp that a repeat event during the ending reuses, even after release or ordinary combat. Current Lua replaces the ending flow and clears hold tracking on release or non-cinematic frames, intentionally requiring a fresh ending press. Two explicit source executions preserve this historical counterexample in `historicalSourceDifferences`: H5 skips the ending and current Lua does not. The six parity scenarios that explicitly replace source flow are controlled lifecycle cases; they do not represent H5's actual shared-F lifecycle. The independently confirmed migration defect remains that an ordinary-combat fresh press must never newly arm `skip`.

All nine directly associated TrialSession regressions were actually rerun: combat result 13005, endless lifetime 22 plus setup497, intro runtime446, practice40, opening construction348, match actions103, trial event boundary24, story input260 and combat warmup684. All pass against the frozen TrialSession. Both new reports are registered in the auditor; parser/diff checks pass. No native key delivery, natural S5 win or new-package acceptance is claimed.

## Authored impacts

Frozen source `b276064942ae09c0227ec28d4cfda1d5ff006455` applies camera trauma once after the Boss introduction exceeds 1.2 seconds (`0.45`), and on each phase advance (`0.5`). The UrhoX entry and phase-event branches omitted both. Existing attack, ult and defeat impacts do not trigger at those moments.

Only `scripts/combat/StoryBoss.lua` production code changed: the introduction uses its existing flow's once flag; the phase event raises the existing session trauma. Both preserve a stronger current effect through `math.max`. No subtitles, mission rules, source-authored timing, assets or QA probe changed.

Final StoryBoss SHA256: `d81ff4f307cf3ff68cc4b76e9a41e8bd1d745470962cc925e8066e93c67ab37f`.

`verify-story-boss-impact.py` executes the complete frozen `BOSS_KIND.update` and `FoxBoss._phase`, comparing their impact state to actual Lua `StoryBoss.Update` and `BossRules.Phase -> StoryBoss.Events`: 160 assertions across 16 scenarios pass. The actual previous 46ba package's StoryBoss (`227d5ca6...`) fails 12 scenarios. Four targeted mutations are rejected: missing introduction, missing phase, repeated introduction, and overwriting a stronger effect.

All nine directly registered Boss regressions were actually rerun and passed, totaling 9956 checks: allies 3079, barks 754, combat flow 1090, defeat 33, exposed 163, kneel dialogue 1617, kneel posture 2178, recovery 90 and waypoint 952. Defeat's stale fixed production hash guard was replaced with an input hash captured before execution and checked unchanged afterward; its source behavior expectations and old-package negative control remain unchanged.

The `story-boss-impact` report is registered in the snapshot auditor. Parser and diff checks pass. Native impact visibility, natural S5 completion, actual new-package audit and sustained performance remain open; no build or GPU was run for this change.

Additional read-only scope checks: current S5 does not author a Boss reply choice, and epilogue version 6 deliberately removes the hangar and 404 interception. These were not reintroduced as supposed omissions. Existing stage flow includes defeat, escape pod, recovery truck, completion, result-triggered version-gated epilogue and retained battle captures. The unintended input path that could skip these stages is corrected separately above. Mission and QA probe files were not modified.
