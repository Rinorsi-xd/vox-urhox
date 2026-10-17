# Combat weapon presentation: one update per frame

## Confirmed consumer mismatch

The current measured Web `view.Update` owner includes actual spikes around 35 ms, but existing stripped WASM release stacks do not identify their source method. This change addresses a concrete duplicate consumer found while choosing finer attribution points; it does not label those spikes as weapon allocation or Lua GC.

Before this change `CombatView.Update` called `WeaponView.Update`, which performs `WeaponPresentation.Update` and applies the weapon presentation, then called `VehicleView.UpdateIdle`, which again advances and applies every `vis.weaponMotion`. `WeaponMotion.Update` has no same-time deduplication: it integrates springs/energy flow and replaces pending effects on each call. This repeats animation work and advances its private RNG twice where the frozen source advances once.

Frozen Three.js baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. Actual `CarVisual.update` first sets turret rig state, calls its main `VehicleView.update(time)` once, then applies interpolated turrets. The main `VehicleView.update` calls each `rig.update(t, dt)` once. Rotor child views own separate rig objects. Exact source hashes and checked call statements are stored in the offline evidence below. This is call-structure evidence, not numerical equivalence of the two engines.

## Narrow production change

Only `scripts/render/VehicleView.lua` and `scripts/render/CombatView.lua` changed for this candidate. `UpdateIdle` accepts an optional `skipWeapons` flag. Combat passes it when a weapon system exists, because `WeaponView.Update` owns those weapon updates. Joined blocks, rotor surfaces, livery, pose, equipment effects and hit flash still update. Vehicles without a weapon system retain idle weapon presentation. Existing hall/intro `UpdateIdle` call signatures retain their previous behavior.

## Executed offline regression

`tools/migration/check-combat-weapon-once.py` runs the actual `CombatView.Update`, `VehicleView.UpdateIdle`, `WeaponView.Update`, `WeaponPresentation.Update` and `WeaponMotion` Lua modules using Lua 5.4. It loads all 15 authored weapon rigs and actual motion profiles. Native drawing/turret calls are counted doubles; physics, rendering and GPU work do not execute.

Result: **225 cases, 5,258,148 recursive checks, PASS**. Each case executes 96 frames. Coverage is all 15 weapon types at five time steps (`0`, `1/120`, `1/60`, `1/30`, `0.1`) through armed combat, unarmed combat and hall consumers, with varying shot, charge, spin, lock, reload, tube and offline state. Every frame matches an explicit one-pass actual `WeaponMotion` reference, including numeric bits and private RNG sequence/count. Weapon application occurs once; other combat/idle consumers remain present. Fifteen negative controls reconstructing the previous combat consumer produce two applications and a different flow phase, and are rejected.

Evidence: `docs/migration/evidence/combat-weapon-once-offline-1017-a.json`. This is actual Lua consumer behavior with native boundary doubles. It does not prove rendered effect parity, audio, gameplay damage behavior or mobile performance.

## Prepared CPU microbenchmark and current limits

Root exclusively owns performance and browser runs. An optional `--benchmark` mode is ready; this subtask did not run it. It uses normal Lua GC and ABBA order, each run with eight sets of the same 15 authored weapon types, 60 warmup frames and 360 measured frames. The scheduled weapon input is identical; the old double integration intentionally produces different visual state and private RNG consumption, so this cannot be described as an exact-state whole-game A/B. Native drawing remains a counted double.

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-combat-weapon-once.py --benchmark --output docs/migration/evidence/combat-weapon-once-lupa-abba-1017-a.json
```

Root executed the normal-GC CPU microbenchmark. ABBA measured seconds were A1=1.051, B1=0.566, B2=0.563, A2=0.921 for 360 frames and 120 weapons. The pair averages are 0.986 versus 0.5645 seconds (42.75% less time in this microbenchmark). Applications counted across warmup plus measurement are 100800 versus 50400; turret calls remain 50400. The corrected private visual RNG runs once instead of twice, as required by the single-pass reference. Evidence: `evidence/combat-weapon-once-lupa-abba-1017-a.json`.

This measures Lua consumers with drawing doubles, not engine pose/material upload, full-battle frame rate or target-device performance. No Web FPS improvement or sustained TapTap Snapdragon 845 result is claimed here. G4's prepared Boss fixture remains frozen and unrun.

## Executed Web consumer regression

Root ran `evidence/ads-source-4a3a-1017-b/` against frozen manifest `4a3a78e7`: PASS/CLOSED/exit0, with no Runtime or HTTP errors. Actual MG, laser, sniper and missile fire/ADS/release checks passed. An observer around actual HandleUpdate recorded 883 eligible callbacks and 13249 WeaponMotion calls, with maximum one call per weapon per eligible callback, zero duplicate calls and zero update errors. There were 19 cumulative weapon identities, at most 19 weapon calls in one frame, and 40 calls outside eligible Update boundaries; those boundary calls remain reported. Loading and absent-trial callbacks were excluded explicitly.

The preceding `ads-source-4a3a-1017-a` ADS checks passed but its counter wrapped PostUpdate and observed no weapon updates, so it supplies no duplicate-update evidence. Both original runs are preserved. The b report SHA256 is `fc2dcc28b8ef50dadb24c0bc3ac78744e177d83fba5d1950efdf969bf17580af`; runtime log SHA256 is `f54c55ba70711ad9037a182c00175860596de475db6583ad739b3e78d91b7a9a`.

This verifies the consumer fix executes in the actual Web game; it is a diagnostic regression run, not a full-battle FPS A/B. Root inspected scoped screenshots: ordinary projectile glows remain, so complete ADS visual clearance is not signed. Separately, exact-WASM structural analysis now identifies GC as the main sampled cost in three previously captured spikes; it does not establish that this weapon change removes those spikes. See `PERF_WASM_LUA_GC_IDENTIFICATION_2026_10_17.md`.
