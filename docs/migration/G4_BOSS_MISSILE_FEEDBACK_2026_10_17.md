# Boss projectile hit feedback

## Confirmed source gap

Baseline remains the frozen Three.js branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. `three/src/battle/storyBoss.js:1337` runs `_explodeMissile` after the real projectile consumer finds an impact. An unoccluded player hit increments `missileHits`, raises camera trauma to at least `0.35`, and calls `once('outside')` if an upward shelter ray has no roof other than the Boss. Ally hits do not raise player trauma.

Current `StoryBoss.Projectiles` already performed the explosion, line-of-sight check and hit counter, but omitted the trauma and shelter-gated `once` consumer. Only that player-hit branch was changed. Existing damage, radius, projectile retirement, allies and source timing remain unchanged. The shelter ray excludes the player's body, matching source; using the existing general `UnderRoof` helper would exclude the Boss body and apply additional polygon classification, so this narrow source query is retained directly.

The frozen Level5 script has **no `outside` dialogue entry**. The restored call consequently remains silent with actual content. This change must not be described as a newly audible warning or completed audio migration. No dialogue or generated assets were added.

Before production SHA256: `1c83a942b7cb45981fec0a61de889efc83eaceb481a7efa513060ef2dac507a9` (ordinary manifest351f49cb snapshot).

After production SHA256: `25e4a402d6a8bf7dc577553437ca17cecc27ce5d47d272aad54564166ba5102a`.

The checker reconstructs the previous production bytes from this exact branch change and verifies they match the frozen ordinary snapshot. No other production edits were made by this subtask.

## Executed offline consumer checks

`verify-story-boss-missile-feedback.py` executes the complete actual frozen `FoxBoss._missiles -> _explodeMissile -> _team/_sheltered/once/say/talk` and actual Lua `StoryBoss.Projectiles -> Team/Once/Say`. Geometry raycasts, native vehicle damage and the voice output sink are controlled doubles; the production methods and frozen authored data execute unchanged.

Result: **26 cases, 396 checks, PASS**. Of these, 21 use actual authored content. Five explicitly marked synthetic-cue cases verify shelter, once-only and busy-channel behavior using a controlled missing-cue entry; those cases are not evidence that the authored game plays a warning.

Coverage includes stronger existing trauma, repeated impacts, player and ally together, only an ally alive, dead player, inside/outside explosion radius, blocked line of sight, unknown collision ownership, a collision belonging to the victim, remote obstacle hits, environment/unknown/Boss/no roof, and an occupied story channel followed by a later retry.

Five negative controls are rejected: previous missing branch, overwriting stronger trauma, ignoring shelter, repeating the bark, and excluding the Boss instead of player body. Evidence: `docs/migration/evidence/story-boss-missile-feedback-offline.json`.

The older `verify-story-boss-impact.py` was also attempted but stops before testing behavior: its import doubles do not cover the modules now hoisted to the top of `StoryBoss.lua`, causing `parts/Defs.lua:4` to read a non-Defs fixture. This is a stale isolated harness dependency problem, not an observed production error. That existing checker was not edited because root owns concurrent verification. No passing regression result is claimed for it.

## Prepared actual-scene check, not yet run

`tools/migration/check-boss-missile-feedback-native.lua` uses the existing validation API. It enters real `story5` through the production loading flow, advances the controlled objective to create the actual Boss, and sends three actual production missiles through `AddMissile -> Projectiles`: player impact, stronger existing trauma, and distant miss. Real world line of sight and real player explosion handling remain enabled. It requires a real hit-counter increment before accepting camera trauma, checks no invented cue exists, retires all missiles, and returns through the normal scene-release flow.

Root can run it with the current exact production snapshot using the same Native arguments as `verify-boss-native.ps1`, substituting this `-validate-test` file and a unique output/log directory. The original broad Boss validator is not changed. Root exclusively owns hardware; this subtask did not launch Native or a browser.

The dedicated launcher is now `tools/migration/verify-boss-missile-feedback-native.ps1`. Its default mode is preflight only. `-Label c074-preflight-a` passed against frozen `.tmp/outgame-cached-1792213080660`: all 549 Lua files match the snapshot identity, the reviewed Boss hash is present, and all six beta40 Runtime inputs plus four shared resource inputs match their existing Native identities. Preflight evidence is `.tmp/g4-boss-missile-native-c074-preflight-a/launch.json`; no Runtime was started and no assets were copied.

Root's serial actual invocation is:

```powershell
& './tools/migration/verify-boss-missile-feedback-native.ps1' -Label 'c074-a' -Run
```

This uses the current beta40 `.tmp/perf-effects-runtime-beta40/UrhoXRuntime.exe`, the explicit previously tested Native resource prefix, and real frozen c074 project assets. It preserves unique launch/process/completion metadata, stdout, stderr and `validation.json` under `.tmp/g4-boss-missile-native-c074-a/`. An existing label is rejected instead of overwritten. The 195-second external deadline terminates only the process this launcher owns and records the timeout. The actual run remains pending until root collects the result; the preflight is not a gameplay or rendering pass.

### Native startup fixture correction

Root's actual `c074-a` did not reach game Lua. Its stdout shows beta40 detecting the Web frozen root's `dist/latest.json`, selecting the five-step Manifest Bootstrap, adding an `engine-startup` source at the placeholder `https://.../src/engine-startup/`, and failing to download it after four attempts. `stderr.log` then reports `Bootstrap/Startup: 未找到启动资源`. This is a failed Native test startup, not a Boss behavior result; preserve the failed logs and owned-process completion evidence.

The previously successful beta40 capability probe instead had no `dist/` directory: its stdout registers loose `scripts/` and `assets/`, executes the single `Ready` bootstrap step, then runs the supplied Lua entry. `prepare-boss-missile-native-loose.cjs` therefore prepared `.tmp/g4-boss-missile-native-loose-c074-1017-b/` using junctions to the exact c074 scripts/assets, a small `.project/` copy and the unchanged snapshot identity, without `dist/` or `.build/`. It verified all 549 Lua hashes and both junction targets; it copied no game assets and started no process. The unchanged launcher also passed `c074-loose-preflight-b` against this new entry root.

Root's corrected serial invocation is:

```powershell
& './tools/migration/verify-boss-missile-feedback-native.ps1' -Label 'c074-b' -Snapshot '.tmp/g4-boss-missile-native-loose-c074-1017-b' -Run
```

Evidence goes to `.tmp/g4-boss-missile-native-c074-b/`. This tests the same frozen gameplay sources and assets through the observed Native loose-resource startup; it is not a fix or acceptance of the Web-to-Native Manifest Bootstrap protocol. The original launcher and Lua fixture remained frozen during root's run. The corrected actual result is pending.

### Actual b result: closed by cold Native shader startup timeout

Root ran corrected `c074-b`; it reached real `main.lua` and installed the actual hangar. It did **not** reach Boss entry or execute the impact assertions. The external 195-second deadline ended its owned PID `26524`, recorded `status=TIMEOUT`, `exitCode=-1`, and the launcher exited `1`. There is no `validation.json`. `stderr.log` is empty; this does not turn the timed-out check into a pass.

The final log remains at frame `23`. `LoadingFlow` reports `Scene installed; awaiting rendered frames` at `13:22:54.556`. Frame 23's logged timestamps span at least **174.093 seconds**, with 103 `Loaded ... shader` records. Eight completed intervals between `RecordCompiledTarget` and the immediately following matching `Loaded pixel shader` total **170.539 seconds**:

| Generated surface | Log interval |
|---|---:|
| VoxPaint | 22.597 s |
| VoxPBRCoat | 22.525 s |
| Glass | 22.405 s |
| VoxDecor | 21.010 s |
| Sign | 20.629 s |
| Surface | 20.555 s |
| Weapon | 20.446 s |
| VoxPBR | 20.372 s |

The final `Deck` pixel shader record at `13:25:48.558` has no matching loaded record before termination. The expensive completed variants share desktop quality-3 cluster lighting, local shadows, IBL/PBR and SSAO macros. In contrast, many shadow, depth and vertex intervals in the same frame are tens of milliseconds. These are **wall-clock intervals around shader loading**, not direct compiler CPU timers; `RecordCompiledTarget: 0 matched` alone is not proof of shader cache misses or a specific compiler bug.

Actual production `LoadingFlow.PrepareScene` instantiates `SceneWarmup` only for `PlatformUtils.IsWebPlatform()`. This Native run therefore renders the restored initial hangar together, rather than using that Web batch warmup. The checked `scripts/` tree has no `PrecacheShaders` or `BeginDumpShaders` call. This provides a concrete cold Native startup blockage to investigate separately; it does not attribute the Web battle's ongoing frame cost, prove an AI problem, or establish mobile timing. No production warmup or quality setting was changed, and this failed check will not be rerun in this subtask.

Persistent evidence is `docs/migration/evidence/g4-boss-missile-native-1017/`: exact copies of both attempts' raw launch/process/completion/log files, b's `startup-log-derived.json`, and `archive-identity.json` SHA checks. `tools/migration/analyze-boss-native-startup-log.cjs` derives line-numbered shader intervals without editing the raw logs. Both failed attempts remain available; G4 actual Boss acceptance remains open.

This remains controlled consumer acceptance, not natural S5 completion, subjective camera shake approval, audible playback, sustained performance or mobile/TapTap acceptance. No build, commit or push was performed by this subtask. G4 overall remains open.

## Frozen Web alternative: prepared, not run

The isolated Web fixture `.tmp/boss-missile-web-c074-1017-a/` was prepared from the exact c074 identity. All 549 frozen production Lua hashes passed preparation checks; only its derived main entry adds the separate observer. No production source, frozen package or game asset was changed. No server, browser or Runtime was launched for this alternative.

`boss-missile-web-observer.lua` uses actual story5 loading, Boss creation, `AddMissile -> Projectiles`, native world queries and player damage. It records the three controlled same-frame impact cases, immediate trauma/hit/damage results, restored temporary observation wrappers, and normal pause-menu return with scene/resource release. This is a prepared controlled consumer test, not natural S5 completion or a visual/audio/performance claim.

Offline preparation checks passed: combined production main plus observer compiles under Lua 5.4; both JavaScript preparation/runner files pass syntax checks; the acceptance checker passes its synthetic valid record and rejects 13 negative controls. The observer itself has not executed in a browser, and none of these offline checks proves actual scene behavior.

Root paused G4 hardware work to prioritize current battle performance and ADS investigation. The following hashes freeze this prepared alternative until explicitly resumed:

| File | SHA-256 |
|---|---|
| `tools/migration/boss-missile-web-observer.lua` | `55274cda8d2ab0d4f925ad2a8545c2b2d8673e7319e3d330aa75cf9d8fea7734` |
| `tools/migration/boss-missile-web-prepare.cjs` | `5c3138dc6ff58c29a4fc4ece78e2c1002289fd9e9309c5d88859571f4a25bff7` |
| `tools/migration/boss-missile-web-acceptance.cjs` | `fa8d61d49b085609fa894d55fc64f14ed5c435694cdad67930122359defa76c2` |
| `tools/migration/boss-missile-web-run.cjs` | `2be50b800c594eee4075189caa68e4fb4d101e6ce8d3db9dc4e98d4cf8f31059` |
| Derived fixture `scripts/main.lua` | `d08e70e494dc29585c1dc6607747a5001f6cdf6b3e43f8c4455119ae8a03f853` |

Status: **PREPARED_NOT_RUN; G4 actual Boss acceptance remains open**. Neither Native failure was replaced by an offline pass.

## Actual latest-build Web result: narrow consumer gate passed

Root resumed this check on the latest ordinary snapshot `4a3a78e7`, fingerprint `1d462212b0e039c489f1c8fecdd2fb844d4bfdac0b8cde07656ebd9f9a070f76`, rather than running the older c074 alternative above. The new derived fixture is `.tmp/boss-missile-web-4a3a-1017-a`, manifest `4ce77a17`; its observer/runner/acceptance remain the reviewed versions. The old c074 alternative remains **PREPARED_NOT_RUN**, and both actual Native startup failures remain unchanged.

Actual result: `evidence/boss-missile-web-4a3a-1017-a/report.json` is **PASS / CLOSED / exit 0**, with **0 Runtime errors and 0 HTTP errors**. Root inspected the actual impact and returned-hangar screenshots. The fixture requested real `EnterTrial('story5')`, waited for EnginePit installation/warmup and mission beginning, captured the driving pointer, then explicitly advanced the objective through `Rules.Go(2) / Mission.Events` and set the actual Boss to fight. The Boss had 2,227 parts. This controlled progression is declared in the raw evidence; it does not establish natural S5 encounter progression.

All three production `AddMissile -> Projectiles` cases executed atomically on frame **1385**, with mission time unchanged at `0.9000000000000011` during the calls:

| Actual case | Hit counter delta | Actual structure | Camera trauma | Remaining missiles |
|---|---:|---|---|---:|
| Player impact | +1 | 658.875 -> 653.8845662276867 | 0 -> 0.35 | 0 |
| Existing stronger trauma | +1 | 653.8845662276867 -> 648.8941324553734 | 0.8 -> 0.8 | 0 |
| Distant miss, 50 m offset | 0 | 648.8941324553734 unchanged | 0 -> 0 | 0 |

Each actual impact applied `4.9904337723133` damage through the original player explosion method, with radius 7.5 m and nominal damage 5; each called real Flush once and Fx once, and cleared the world attacker. The player remained alive. Each impact executed the real 1 m downward line-of-sight query and 90 m upward shelter query; both were unobstructed at the sampled spawn location, and the shelter query excluded the player's body. The distant miss called neither player Explode nor Flush, still emitted its world explosion once, and retired its missile. Temporary observation wrappers restored the exact original methods. This actual run covers unobstructed player impacts; blocked line of sight, allies and roof variants retain their explicitly controlled offline coverage above rather than being inferred from this scene.

One actual **Escape** press opened the unified pause page and released pointer capture. The runner clicked the visible `返回车库` button through its actual UI hit-test rectangle. By returned state 237 the game was in the hangar with no trial, loading or pending release; the original mission/Boss were disposed, mission entries were empty, voice/radio/view references were nil, the old world was disposed and its visualGround reference was nil. These are observed production lifecycle/reference checks, not a measured GPU-memory-release or leak-free long-session claim.

Independent offline reconstruction is `evidence/boss-missile-web-4a3a-1017-a-independent.json`, produced by `tools/migration/verify-boss-missile-web-evidence.cjs`. It rebuilt **569 checksum/UTF-8-length-checked runtime chunks into 238 consecutive states**, matched the report's actual impact, pause, return and screenshot states to those raw records, and checked the detailed damage/trauma/ray/retirement/release invariants independently of the runner's acceptance result. All **549 fixture Lua sources and package payloads** match their recorded hashes; all 548 non-entry files match ordinary 4a3a, and the eight recorded actual HTTP module hashes match the fixture identity. This is offline verification of captured HTTP hashes, not a second live HTTP or browser run. The independent checker initially treated cjson's empty rays table as a JSON array; its empty-table representation check was corrected without changing raw evidence or production.

Raw report SHA-256: `ebdf896553d1aa152c7e3d11fcd0d697c84a0690a7b7e111861d2a7d08534d1d`.

Raw runtime log SHA-256: `f2d22756c9061750824b407d8450929ab505ca5da27db20b733d32e4d3891e5f`.

This closes the **controlled actual Web Boss projectile feedback and public-return disposal gate** on the latest 4a3a snapshot. G4 overall remains **OPEN**: natural S5, final encounter/cinematics, subjective shake, pixel-level visual parity, audible content, full ending, sustained performance and TapTap/mobile acceptance were not established. The frozen authored content still has no `outside` cue; no new warning audio is claimed. This evidence work changed no production code and performed no commit or push.
