# Scalar candidate rejected, 2026-10-17

The isolated `TurretRange.Prepare` scalar-allocation candidate is
**REJECTED_NO_GAIN / STRICT_EQ_FAILURE**. It was not merged into production.

The four Native runs completed with exit zero, no runtime ERROR lines, normal
automatic GC and 192 actual damage/rebuild/rebind updates each. Their runtime
tolerance checks passed. The unchanged independent analyzer rejected a native
state roundtrip in the original baseline: raw float32 body coordinates differed
slightly after rebuilding. Therefore these runs do not pass their declared
bit-exact behavior acceptance. The analyzer was not relaxed or overwritten.

Exploratory overlapping inclusive totals, in milliseconds:

| Run | Flush | TurretRange.For |
|---|---:|---:|
| A1 baseline | 1441 | 947 |
| B1 candidate | 1724 | 1234 |
| B2 candidate | 1466 | 994 |
| A2 baseline | 1433 | 931 |

There is no repeatable improvement; candidate runs are slower here. These
timings are diagnostic evidence, not accepted performance measurements or a
Web/mobile FPS result. Passing the separate pure-Lua exact correctness tests
did not imply that this candidate would be faster.

Original run JSON, launches, process records, logs, validation, source identity,
probe, baseline/candidate sources, unchanged analyzer and correctness checks are
archived byte-for-byte under
`evidence/native-damage-scalar-rejected-2026-10-17/`. `rejection.json` contains the
first raw native mismatch and strict-analyzer output. `archive-sha256.json`
records source/archive SHA-256 equality for each original.

The next experiment separately targets the actual cached-spawn first-damage
cache state. Its native float32 error boundary is declared before execution,
and its pure Lua signatures exclude native transforms. It cannot retroactively
change this scalar experiment's failed strict acceptance.
