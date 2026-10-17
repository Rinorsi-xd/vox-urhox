# Empty-hover candidate rejected (2026-10-17)

Decision: **REJECTED / NO PERFORMANCE GAIN CLAIM / PRODUCTION UNCHANGED**.

The narrower candidate preserves fresh state/output tables and the original support calculation for zero-hover vehicles, while skipping unused Lua Body pose wrapper calls and closures. The nonempty function body is retained. This follows measured Web `HoverControl.Step` cost, not a claim that the whole measured subtree belongs to the empty path.

Offline actual Lua 5.4 checks pass 648 cases and 52,606 assertions: exact numeric bits or NaN classification, states/results, force/ray order, fresh table identity and nonempty getter counts. With actual `Body.Wrap` in a prewarmed read scope, baseline makes two extra Lua pose wrapper calls and candidate zero; both make zero additional native pose reads. This is not a claim of reduced native IO.

Root ran the existing actual eight-source normal-GC fired CPU fixture serially: 120 warmup + 240 measured 1/60 steps, seven AI plus held player fire, real crater/Bullet, no added method wrappers in primary timing. No renderer, audio, UI or full objective consumers are measured.

| Order | Total step wall ms | Mean ms/step | P95 ms | Native exit/errors |
|---|---:|---:|---:|---|
| A1 | 861 | 3.587500 | 9 | 0 / 0 |
| B1 | 832 | 3.466667 | 8 | 0 / 0 |
| B2 | 853 | 3.554167 | 8 | 0 / 0 |
| A2 | 1126 | 4.691667 | 11 | 0 / 0 |

The four processes complete, but the exact state/workload gate fails before any benefit calculation. Both B runs already differ from A1 at the initial snapshot after warmup:

- Second car steer: A1 `-0.3843839820488639`; B1/B2 `0.13674892254641005`.
- First measured 60-step snapshot firing requests: 652 versus 711.
- First per-step counter difference occurs at measured step 4: damage 824 versus 831.
- First final RNG value: `0.5078765951878959` versus `0.8222155215073488`.

Metadata matches. A2 exactly matches A1 in initial state, every saved snapshot, final RNG and every per-step workload counter, although its wall time drifts. B1 exactly matches B2 in those same fields. This identifies a repeatable A/B workload mismatch, but does not by itself identify its cause or prove an arithmetic defect in HoverControl. No arbitrary rerun, workload relaxation, state tolerance or selected timing discard was used.

`analyze-hover-empty-normal.cjs` now writes a concise **FAIL_EXACT_WORKLOAD** artifact and exits 1, instead of dumping thousands of assertion lines. It omits a reduction percentage when workload differs. Failure evidence with SHA-256 for all four result JSON files: `evidence/hover-empty-normal-1017-failure.json`. Original raw results/launch/process/validation files remain in `.tmp/hover-empty-normal-1017-A` and `-B`.

Production `scripts/drive/HoverControl.lua` still hashes to `37e039a5de205df95ba8fd0007492cade7407b3272a837a686069ee7b27c6732`, matching A. No candidate production patch, commit or upload was made. These results establish neither a Web FPS improvement nor sustained TapTap Snapdragon 845 performance.
