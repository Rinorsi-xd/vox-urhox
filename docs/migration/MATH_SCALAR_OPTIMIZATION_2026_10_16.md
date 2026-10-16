# Quaternion scalar optimization

This continues the existing combat-performance work. It does not close G6 or reset any migration stage.

## Production Change

`scripts/core/Math3.lua` changes only `QMul` and `RotateUnit`. The scalar forms preserve the original arithmetic grouping, quaternion conventions, nonunit-input behavior, fresh result tables, and input immutability. They remove intermediate Lua vector tables and helper calls: 11 temporary tables per `QMul`, and 6 per `RotateUnit`. Each function still returns one new result table.

The existing `Rotate` sandwich formula remains separate from `RotateUnit`; these forms are not interchangeable for nonunit quaternions or floating-point rounding. Physics frequency, ray order/count, impulses, RNG, enemies, visuals and rules are unchanged.

## Evidence

Run:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/migration/verify-math-scalar.py
```

The default reference is the frozen e1fc package's Math3, SHA256 `3f03e043874780814bcc5cb399f7f01928a18e82a6794829df8c322712573d12`. The runner checks that reference hash before executing. Local Lua 5.4 dependencies are in `.tmp/nav-python-deps`.

`evidence/math-scalar-offline.json` records:

- 2,020,286 math assertions PASS. Finite results use packed-double bit comparisons; NaN uses classification. Cases include deterministic random, unit/nonunit, signed zero, extreme magnitudes, infinity, NaN, aliased inputs, fresh result tables and metatable fields.
- Userdata field/index inputs PASS using Python objects exposed by Lupa as actual Lua userdata. This verifies field access semantics, not native engine userdata.
- 8,512,041 actual production LegControl/LegGait assertions PASS: 14 recorded H5 scenarios plus a 420-step mixed scenario, including air, walls, jump, restore, reset and damage. Old/new controller snapshots, ray calls, forces, IK targets and telemetry match exactly; source replay uses its existing numerical tolerance.
- Three alternating-order isolated benchmark passes, 500,000 calls each, with identical checksums. Latest QMul reference 0.511-0.538 s, candidate 0.099-0.100 s. Latest RotateUnit reference 0.304-0.353 s, candidate 0.077-0.082 s.

These timings measure only this machine's isolated Lua functions. They are not Web, native Bullet, GPU, mobile, M1 or complete-game speedups. The latest real combat CPU profile is predominantly stripped WASM without symbols; it does not prove either math function is the largest current combat cost. Combat frame-time acceptance remains OPEN/FAIL until the unified package is measured.
