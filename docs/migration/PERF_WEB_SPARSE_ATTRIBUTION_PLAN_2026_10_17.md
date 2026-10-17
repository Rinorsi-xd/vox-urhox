# Exact Web symbols and next attribution experiment

Status: executable isolated prepare/observer/runner implemented and offline-tested; gameplay run still OPEN. No production changes or new performance claim. Root owns hardware. These tools do not replace the retained failed monitor A/C/C/A comparison.

## Evidence and symbol availability

The existing `PERF_COMBAT_ALLOCATION_STACKS_2026_10_17.md` establishes realloc 1257/export Ck from the exact JS/WASM; 5638 and 9978 still have no confirmed source names. The exact WASM SHA-256 is `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`, with 611 imported and 45,982 defined functions. The retained profile SHA-256 is `aa8c6ff4e7cf1fbbd5477002cf8245075f43b2793fc88ab79f4d33cf45001514`.

This follow-up checked the existing `.tmp/web-engine` files and the actual `D:/UrhoXEditor` installation, including beta40 `tools`, `EditorDebug`, `UserData` and `Updates`, for wasm/map/symbol/debug sidecars. None was found in those locations. This is a scoped local inventory, not a claim that engine-side build artifacts do not exist. The old `.tmp/g0-runtime.wat` contains the same hot function numbers and export names, but lacks provenance tying its generation to the exact current WASM. It contains no recovered function names and must not be used as a symbol map merely because the indices match.

The useful engine-side request is the function-name/index map, linker map or matching DWARF for this exact hash, retaining the full archived CPU profile. Required indices/body byte offsets include 5638/1095996, 9978/2316955, 3264/627701, 909/196519, 7185/1568417, 5650/1097273 and 1680/326460. An unrelated Native PDB, another beta build or a fresh debug build cannot silently symbolize this profile.

## One bounded diagnostic if symbols are unavailable

Goal: assign current Web wall cost to actual broad semantic owners with substantially less observer work than the former full pipeline. This does not name the C++ numbered functions or demonstrate a production speedup.

Use one frozen production package, actual eight-car conquest entry and ordinary 60 Hz simulation. Keep both the production monitor and the former 102-scope/frame-pipeline observers disabled from startup. In a dedicated QA suffix, install only these broad wrappers before entry callbacks are subscribed: `BattleController.BeforeStep`, `TrackWorld.Step`, `BattleController.AfterStep`, `CombatView.Update`, `CombatEffects.Update`, actual `DriveHud.Update`, and built-in `UI.Render`. Keep the broad `HandleUpdate` envelope so measured-child wall and remaining envelope wall can be reported separately. Source hashes must come from the frozen package, not current parallel worktree files.

The single variable is the sparse-recording switch. Both reference and recording windows retain the same dormant wrappers. In recording windows, select exactly one complete engine frame in every 17 frames; all steps in that frame are included. Gate before looking up a timer or allocating any row. The denominator is selected frames/steps/calls, never the whole capture length. Preserve a complete inexpensive engine-frame/step-count stream for selection coverage and detect missing selected frames. Do not choose frames based on their measured duration, damage or apparent slowness.

Prepare a bounded flat numeric ring and guard objects before timed gameplay. Each selected scope needs two existing integer `Time:GetSystemTime` readings and preallocated stack accounting. Do not call `table.pack`, `pcall`, JSON, `print`, file/network output, `collectgarbage('count')` or per-object/per-ray wrappers in the timed scopes. A preallocated Lua 5.4 close guard may unwind the stack on exceptions; failure aborts capture and preserves the error. Keep the original return values and errors. Do not copy the current `qa-frame-pipeline.lua` wrapper unchanged: it allocates per-call tables and packs protected-call results, defeating this experiment's purpose.

Run one 45-second real gameplay process: dormant reference A1 (15 s), sparse B (15 s), dormant A2 (15 s). Use the existing held fire input and no QA vehicle-count/AI/effect changes. Export after the capture is disabled and no measured guard is active. No detailed Chrome trace, screenshots or endpoint polling during those windows. Root requested retaining the actual 1 ms CDP CPU profile and synchronously associating numbered WASM samples with semantic boundaries; the executable variant therefore adds bounded console markers only for selected frames. Marker clocks are checked against Lua integer elapsed clocks, synchronous WASM origin, strict nesting, complete transport count, and pre/post Chrome monotonic clock brackets. Reject buffered clocks, unmatched markers or ambiguity instead of assigning them to an owner. Marker overhead is present in encompassing scopes; this is attribution, not an observer-free performance baseline. Take only pre/post screenshots outside the windows. If B visibly raises frame/step timing beyond A1-to-A2 drift, reject its cost attribution as observer-disturbed and reduce the observation rate; never subtract a synthetic per-call calibration from gameplay timings.

This sequential run is an attribution pilot, not a matched optimization A/B: combat damage, deaths and respawns may change its workload. Report each window's actual alive/part counts, shots/hits/damage, deaths/respawns and fixed-step counts. If these diverge materially, do not convert window FPS differences to observer overhead percentages. For sampled frames, report inclusive and exclusive wall per owner, per-frame and per-fixed-step as appropriate, selected call counts and all selection gaps. Integer sub-millisecond sections are unresolved, not free.

## Decision gates

If one owner repeatedly explains most sampled wall or >80 ms selected frames, the next experiment splits only that owner. For example, a repeated BeforeStep self spike accompanied by 152 AddPart calls is a respawn-construction candidate; it is not evidence that every 9978 sample belongs to construction. If BeforeStep, presentation and UI all remain small while frame wall is large, report the uncovered envelope and request exact engine symbols instead of optimizing random gameplay tables.

This pilot must not claim to attribute an unsampled instantaneous freeze, identify Lua GC, replace ordinary uninstrumented full combat regression, or establish Snapdragon 845/TapTap sustained 30 FPS. It only reduces observer density and locates the next real broad owner to investigate. No production algorithm should change until that measurement yields an actionable, repeatable owner.

## Executable tools and offline checks

`tools/migration/sparse-combat-prepare.cjs` accepts an explicit frozen package identity and creates a dedicated `.tmp/` derivative. It appends an isolated suffix to unchanged production main, preserves all other frozen script bytes, and disables the real Monitor before original `Start`. `sparse-combat-core.lua` uses preallocated flat arrays and close guards; dormant wrappers return directly before clock/marker work. `sparse-combat-run.cjs` derives the exact existing public monitor-combat runner with unique checked anchors: actual public hall/match entry, all eight real production vehicles and seven drivers, dimension/terrain/visibility-safe placement, positive player damage and actual structural loss, and public return to hall remain required. It does not run the synthetic CPU lane entry.

`sparse-combat-cpu.cjs` enables CPU sampling only, never `Tracing.start`. A browser init script captures bounded semantic markers synchronously before forwarding console output. The first marker must show the actual WASM stack. All marker pairs must nest and their JS/Lua elapsed values must agree within 5 ms. Chrome offset brackets must overlap and each be at most 10 ms wide; only samples whose entire interval lies inside one span beyond the uncertainty bounds are assigned to the deepest semantic owner. Missing 9978 samples or no unambiguous assignments fail capture. The index is deliberately not named as Lua GC or a source function.

Commands, from project root, with a newly confirmed frozen identity and unused output names:

```powershell
node tools/migration/sparse-combat-prepare.cjs --frozen <confirmed-frozen-identity.json> --out .tmp/sparse-combat-confirmed --duration 45000
node tools/migration/g1-web-cpu-serve.cjs .tmp/sparse-combat-confirmed/identity.json <unused-port>
node tools/migration/sparse-combat-run.cjs http://127.0.0.1:<unused-port> docs/migration/evidence/sparse-combat-confirmed 45000
```

The server is separately owned; the runner closes its own browser/CDP session with bounded cancellation/deadline cleanup, not somebody else's preview. Root serializes all hardware work. Do not use `monitor-combat-serve.cjs`, which intentionally requires the production Monitor to remain enabled.

Offline checks passed on 2026-10-17:

```powershell
node tools/migration/check-sparse-combat.cjs
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-sparse-combat-offline.py
```

They cover actual Lua core phase/17-frame selection, dormant timer gating, nil-containing return arity, nested original errors and guard reuse, strict frame capacity, generated suffix Lua 5.4 syntax; checked runner transforms; marker nesting/clock/overflow/error/missing-symbol negative controls; and synthetic CPU sample attribution. A derived package was generated offline from `.tmp/outgame-cached-1792209050608/identity.json` under `.tmp/sparse-combat-offline-20261017-a` to verify preparation only, before final tooling edits. It was never served or executed and is not the latest production baseline. Root must regenerate from its confirmed latest input.
