# CarUnit repeated read and complete-repair work

## Scope and identity

- Production change is limited to `scripts/combat/CarUnit.lua`.
- Before: actual `git show 48ef15f2:scripts/combat/CarUnit.lua`, SHA256 `30a2e758aa70fc20162f1301d417425127b8a67dbafc879a90b20d1c7a592263`.
- After: SHA256 `5d878200ce41e98df9018572d1bde425064c60e88e4c3be75f34b3a25594af72`.
- H5 remains frozen branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. The actual source budget getter iterates live `bp.parts.values()` without sorting.
- This is one bounded CPU optimization, not a claim that sustained combat, first spawn, GPU cost, Web audio continuity or mobile performance is fixed.

## Confirmed repeated work and changes

1. `Mission.BeforeStep -> EnemyDriver.Step -> EnemyDriverThink.Run -> EnemyDriverMath.Life` reads core health and integrity on existing think steps. Previously `CarUnit.Core -> Blueprint.CoreParts -> Blueprint.List` built/sorted every live part just to find the first core. `Integrity -> Budget -> Blueprint.List` built/sorted the full list again. Core now scans live `bp.parts` and explicitly chooses the smallest persistent core ID, preserving the old sorted-list selection. Budget sums live part budgets directly. No snapshot or new cache is retained.
2. Story player regeneration calls `RestoreMissing(1)` every existing half-second interval. Even a complete vehicle used to build the adjacency snapshot, traverse connectivity and sort the core list. When the existing missing-part scan finds no missing IDs, it now returns the same fresh empty result immediately. Actual missing-part sorting, category priority, adjacency traversal, healing, shields, events and restore order are unchanged.
3. `Blueprint.Graph` only lazily populates private neighbor caches and returns a copied graph. In the complete-car case its returned graph/reached set was never consumed by a restoration or event. The test explicitly first calls complete repair, then removes a real part and restores it, comparing the old warm-cache path with the new cold-cache path. Both produce the same authored parts, IDs, HP, body HP, structure, shield state, events and restored order.

## Actual verification

Run `tools/migration/check-car-unit-read-work.py` with the bundled Python runtime. It executes actual current and actual old CarUnit methods, actual Blueprint and production Catalog/Arena/prefab data under Lua 5.4 with a JSON-resource adapter. No GPU/native physics factory is invoked.

- 40 actual red prefab records: complete, damaged and deleted-part core/budget/integrity/life/AI-life equality.
- Sparse IDs, multiple cores, removal of the lowest core, missing HP, empty/dead vehicles and a new part added after a previous budget read.
- All actual Catalog budgets verified nonnegative integers; iteration order therefore does not alter ordinary project budget sums.
- 18 repair scenarios over raceCar, miniAssault and megaMech: complete, one missing, many missing, all missing, dead and count zero, three repeated restore calls each; additional complete-then-remove checks cover lazy adjacency cache differences.
- Six work-budget negative controls use the real old module: all three prefab sizes expose two full-list sorts per AI-life read and a graph traversal on complete repair. The current implementation performs neither operation in those cases.
- Recursive equality assertions count individual fields, not separate gameplay scenarios. The evidence reports the scenario counts separately.

## CPU profile boundary

`os.clock` measures the isolated Lua reads. It has coarse resolution here; a reported 0 or 1 ms across 30 calls is not zero work. Results vary with CPU scheduling and the evidence JSON is authoritative for the last execution.

Representative execution:

| Actual prefab | Parts | AI life, 1000 calls before/after | Complete repair, 30 calls before/after |
| --- | ---: | ---: | ---: |
| miniAssault | 312 | 124 / 11 ms | 13 / 0 ms |
| raceCar | 209 | 78 / 7 ms | 7 / 1 ms |
| megaMech | 1611 | 848 / 64 ms | 55 / 1 ms |

The 1611-part actual prefab is not the earlier 2227-part runtime assembly. Neither size proves all vehicle sizes or battle loads. These savings do not explain the whole observed 15.30 ms per Tick inclusive BeforeStep cost. Existing fixed-step frequency, catch-up, AI think times, targeting, effects, suspension, weapons, damage rules and controls are untouched. A newly built Web run must measure the remaining cost; desktop CPU ratios cannot be converted into Web/mobile FPS claims.

## Related checks and remaining evidence

- Actually rerun: `check-endless-spawn-cache.py` PASS, 51 prefabs, 1291 checks; `check-intro-actor-checkpoints.py` PASS, 9 actual actors, 41 cancellation cases, 4 negative mutations. Both associated reports now contain the actual frozen CarUnit SHA above.
- Actually rerun: `check-neighbor-removal.py` PASS, 2 negative controls, actual vanguard/scorpion removal and full damage-rebuild equivalence. Evidence `evidence/neighbor-removal-2026-10-16T07-50-34-681487Z.json`.
- The current part-hit-flash verifier uses `git show HEAD` for its historical negative control. Since HEAD now includes that earlier fix, its old-code expectation is stale and fails independently of these new read changes. A pinned genuine pre-fix revision must replace that control before it can pass again; do not accept a rewritten expected hash as verification.
- No browser/GPU/native/mobile acceptance, no commit, and no push were performed by this task.
