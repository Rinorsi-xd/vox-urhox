# Combat FX Source Parity Progress

Baseline: H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Reference snapshot: `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
This increment continues the existing migration gates; it does not restart G0.

## 2026-10-17: Current Baseline And Reactor Hit Feedback

- The former 10/14 reference has been rechecked against the frozen 10/15 baseline. `weaponFx.js`, `effects.js`, `combatFeedback.js`, `matchView.js` and `matchSession.js` are byte-identical between these two snapshots. This statement applies only to those five files, not all gameplay or the whole repository.
- `combat-source-golden.cjs` now reads `outgame-baseline.json` and verifies the two executed source-file SHA-256 values. All 18 original direct-method H5/Lua scenarios pass on 10/15; the historical 10/14 path is no longer used by this runner.
- Confirmed omission: H5 `ConquestMode.hitSpecial/explodeSpecial` call `Reactor.hit()` only when charge theft returns a positive amount. Source `Reactor.update()` decays flash by `dt*4`, mixes the team/exposed warning color toward white, and jitters the entire reactor horizontally by `(random-.5)*flash*.3`. Lua previously stole charge without any reactor hit flash or movement.
- `BattleObjectives:Hit/Explode` now notify only that reactor after successful theft. `ObjectiveView` retains existing geometry optimizations, normal 10 Hz refresh and conservative culling; only an active hit reactor refreshes each frame until its 250 ms flash expires. The last flash frame restores its undisplaced position. Hidden reactors advance flash without building geometry and refresh on re-entry.
- Jitter uses a private visual PRNG to preserve gameplay RNG. Amplitude, axis, decay and activation follow source; its random sequence is intentionally not the source browser's per-frame sequence. Exposed warning retains the existing 10 Hz refresh when no hit is active.
- `check-reactor-feedback.py`: **249 actual-module/source checks, four visual fixtures, 32 activation fixtures and four rejected mutations PASS**. Includes both teams, shield/exposed colors, repeated hit reset, zero charge/damage, blast range, source 60% explosion theft, score depletion, offscreen expiry/re-entry, immediate refresh of only the hit batch and no gameplay RNG consumption. [Bound hashes and results](evidence/reactor-feedback-1015-offline.json).
- Existing conservative objective-culling regression: **45 checks and four rejected mutations PASS**. No shader depth state or unrelated weapon/kill formulas were changed. This is a functional feedback restoration; no frame-time, rendered-pixel or phone performance improvement is claimed.

### Rendered Acceptance Still Open

Natural route: public 4V4 station conquest, capture A/B/C to drop the red shield, then shoot the crystal ring above the red base with charge remaining. Expect theft plus a brief white flash and small X shake; shooting a shielded/empty reactor must not flash. This route needs natural objective progress and is not a short deterministic proof.

For a bounded rendered check, root can use a dedicated fixture based on `tools/migration/objective-web-native-probe.lua`: one real `Scene`/`Octree`/`Camera`, actual `render.ObjectiveView.New`, `id='conquest'`, no capture points, blue/red base aims `{−6,0,0}`/`{6,0,0}`, both scores 50, camera at `{0,5,−20}` looking at `{0,0,0}`. Render an idle second, call `view:HitReactor('red')` once, retain real Update dt for 0.3 seconds, and capture at 0/0.05/0.15/0.3 seconds. Repeat with red shield down and with the camera turned away/back. This is explicitly a rendering fixture, not natural combat or a performance benchmark. The production hit/explosion gates are covered offline above; actual public combat, audible kill feedback and sustained Snapdragon 845/TapTap remain unaccepted.

## Implemented And Checked Offline

| Item | Previous mismatch | Current implementation / acceptance evidence |
| --- | --- | --- |
| Gatling projectile | Old short light bolt and orbiting dots | H5 speed-dependent long tracer; gold halo + white hot core + two head glows; T3/T5 and muzzle-distance clamp match actual source methods |
| Streak silhouette | Fixed taper .9 for all uses | Per-streak .97/.95/.9 from source, transported by documented CustomGeometry tangent attribute; actual batch geometry/layout check passes |
| Muzzle flare spread | Used `tan(spread)` | Source `spread * sqrt(random)`; actual flare geometry golden passes with the same deterministic random stream |
| MG T4/T5 heat vents | Missing | Side vent sparks, source offset/velocity/drag/gravity; shot golden passes |
| Forward muzzle sparks | Generic spherical burst substituted | MG, laser and missile use source per-axis forward velocities and drag |
| Hit feedback | Laser target color and random smoke missing; rail splash extent missing | Target blue spark tint, source smoke probability, `max(tier extent, splash*.8)` rail arcs; hit golden includes complete arc endpoints/lifetimes |
| Dry sniper | Used laser spark color | Source rail spark color |
| Shield/repair/heal | Events not consumed visually | Source plateBreak flash/light/burst; repair flash + rising burst + inward sparks; heal upward motes |
| Flash size/profile | Started at 1.0 size multiplier, reused projectile glow gradient | Source `.6+t*.6`; legacy radial .25 gradient for flash/spark vs .18/.45 projectile glow gradient |
| Flash colors | Approximate RGB values | Exact source hex to linear color conversion |
| Missile smoke | Generic upward puff | Source direction-opposed trail smoke position/velocity/growth/drag/lifetime |
| Missile explosion | Initial burst used default vertical bias | Source up=.6; single/three-hit combo event golden includes flashes/rings/flares/bursts/arcs/boom timing |
| Translucent ordering | All effect batches at renderOrder142 | Smoke139, light strips/rings142, glow143; smoke precedes additive light as in H5 |
| Restore shell idle | Root transform/visibility native calls while empty | Clock advances, native root calls stop while no shell is active |
| Duplicate restored IDs | Rebuilt shells repeatedly within a batch | Last occurrence ordering retained, final geometry/pose/time unchanged |
| Active shell models | Copied identical model wrappers per shell | Reference counted copies shared only among live shells with equal source/selection/bounds; last owner disposes; no idle cache |
| Debris pose | Repeated full-size scale writes and two position writes | One position assignment, scale changes only during fade; eight golden ages retain source pose/rotation/scale and RNG sequence |

## Reproducible Checks

Run at the project root with the bundled Python runtime and existing `.tmp/nav-python-deps/lupa` dependency:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-combat-source-fx.py
```

`combat-source-golden.cjs` directly executes the frozen H5 class methods using recording render sinks. It does not copy their event formulas into the expected results. `check-combat-source-fx.lua` invokes the actual migrated Lua methods using the same deterministic random stream. Result: **18 scenarios PASS**.

Other actual-module checks: `check-effect-batch-source-layout.lua` (taper/rounded-head geometry/profile/HDR-alpha/order/empty), `check-restore-flash.lua` (**10 scenarios PASS**), `check-combat-debris-pose.lua` (**8 golden ages + RNG/release PASS**), existing `check-combat-warmup.lua` (**12 scenarios PASS**).

## Depth And Remaining Acceptance

- Source world-space weapon particles/ribbons/streaks/glows use `depthTest:true` (Three default), `depthWrite:false`. Combat shader render modes do not disable depth test, and `depth_draw_never` preserves the source write behavior. There is no static evidence here proving a source-to-target depth-test mismatch. Actual generated alpha pass and wall/car occlusion must be checked in root's same-build Web run.
- `Material.depthTestMode` is not a documented Material API. Depth state belongs to `material:GetPass(0,'alpha')` and Pass getters/setters. Do not claim an unbound Material field assignment fixes occlusion.
- `drillSpeedFx.js` explicitly uses `depthTest:false` for the screen speed overlay. Its intentional overlay must not be treated as a world-occlusion regression.
- The Streak shader now has a tangent vertex stream and Glow shader now carries a profile varying. Real Web compilation and rendered inspection are still required; offline geometry checks do not prove GPU output.
- Current bounded mobile/desktop effect budgets remain. Saturation, very large salvoes, sustained phone frame pacing, rail helix segment caps, exact point-sprite subpixel footprint, and all full-scene source captures are not closed by these checks.
- The tested source snapshot must remain present for the direct-method golden runner. No generated art, browser instance, native game, upload, publication or commit was performed by this child increment.

## Confirmed Kill Feedback Increment

- Source `combatFeedback.kill` called confirmed-kill audio, a delayed `.7` vehicle destruction sound, a combo objective sound, and score ticks as its 22 cubes arrived. The migrated animation had no arrival audio callback. `CombatFeedbackAudio:Kill(streak)` and `ScoreTick()` now expose those exact cues; G5 owns their `DriveOverlay` / `CombatFeedbackMotion` hookup.
- Two existing approved H5 WAVs (`score_tick_a`, `objective_gain_b`) are copied by `import-kill-feedback.mjs` from the frozen snapshot, with SHA-256 provenance in `FeedbackSounds.json`. Existing cue records keep their original provenance. No new audio was generated.
- Delayed destruction sounds retain the source 120 ms delay, 400 ms / `.71` confirmation duck and FIFO timer registration order. Cue gaps still prevent coincident duplicate playback. Pause/dispose clear queued sounds.
- `combat.KillImpact` ports the actual source confirmation conditions: confirmed vehicle kill starts 80 ms at 6% game speed, FOV punch at least 4, trauma at least `.35`; only a nonempty list of nonneutral enemies with none alive starts the `.7` second finishing slowdown. Vehicle parts and debris quantities are unchanged.
- `TrialSession` now applies that game delta to its normal Update/Tick and PostUpdate camera/effect path. The feedback audio queue keeps the real frame delta, matching source `setTimeout`. Introduction, MVP and endless editor gates do not consume the impact clock.
- `check-kill-impact.py` executes the frozen H5 update and confirmation clauses directly, compares six enemy-list fixtures and eleven frame steps each against real Lua `KillImpact`, and exercises the actual `TrialSession.Update` gate path. Additional actual audio-module checks cover waveform choice, delayed playback, duck, score tick gap, strength clamp, combo sound, FIFO, dedup, pause and disposal. **PASS**.
- Actual same-build Web enemy kills, readable score aggregation, audible cues, explosion/debris framing and sustained phone behavior remain root's rendered acceptance. These offline checks do not close those items.

## Destruction Rendering Cost Increment

- `JoinedMesh.Update` now computes each distinct linear vertex color once per rebuild and reuses the same winding order array. It still runs the actual `JoinedSurface.Build`, emits all the same exterior triangles/normals/colors, uploads the same geometries, and uses the same shared materials. A mixed 240-part / six-shape fixture emits 6960 vertices: `HexLinear` calls fall from 6960 to 3, with exact output equality across later removals, x-ray and cleanup.
- `EffectBatch.Begin` now records the camera/time and defers native `BeginGeometry` plus shader clock assignment to the first accepted quad. Empty frames hide the mesh without resetting a native stream. First nonempty frames reset before writing; full frames retain the cap and their vertex order. Five batch kinds across empty/nonempty/overflow fixtures retain exact vertex, normal, UV, tangent, HDR color, visible state and drawn clock; native Begin/clock writes fall from 40 to 15, with the same commits and resource allocations.
- `check-render-destruction-cost.py` compares the real modified modules with the exact pre-change frozen build, verifying reference hashes first. **PASS**. Existing source layout, 12 warmup lifecycle scenarios and eight debris pose/fade golden samples also pass. These count reductions are offline call evidence, not Web frame-time measurements.
- Read-only lifecycle audit found normal removal paths dispose killed unit views, expired debris views, private weapon materials and corresponding scene nodes. Physical fragments remain bounded at the source limit of 60 and five seconds. This was not a live heap retention test.
- Remaining destruction cost includes reconstructing each physical fragment's part rig and private weapon materials, rebuilding the actual joined exterior, and rebinding survivors after physical rebuild. Reparenting old visuals or skipping spawn/remove pairs can alter authored fragment poses or global wing RNG; neither was done. CarUnit/Blueprint/VehicleSpec/TurretRange and HUD ownership stayed with their assigned agents.
