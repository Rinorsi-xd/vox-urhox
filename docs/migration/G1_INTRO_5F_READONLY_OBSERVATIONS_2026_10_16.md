# 5f opening read-only observations

Inspected existing natural-Web log `evidence/intro-natural-web-1600x900-manifest-5f39f096.log`; no new run, GPU operation, packaging or production edit. Times below are the log's local UTC+8 timestamps on 2026-10-16. Full functional/continuity acceptance belongs to the parent run.

## Target shadow permutations still compile during visible play

| Shader UUID | First actual shadow-pass load/compile | Shot and frame | Log lines |
| --- | --- | --- | --- |
| `Db92MdNcR8CY03WHsG6jS_0k` | BeginLoad 05:29:09.606; VS 09.647; FS 09.687 | sortie-countdown, frame 3235 | 2276-2281 |
| `BNNNcWhirBQkMho_un1Bywvh` | BeginLoad 05:29:44.350; VS 44.392; FS 44.432 | sortie-play, frame 3736 | 2367-2372 |

Both use `_shadow` with `RENDER_QUALITY=2;VERTEXCOLOR;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEVS` (or COMPILEPS) `;BGFX_CONFIG_MAX_BONES=1`, without INSTANCED. Boot contains their `_depth` and forward material variants, including forward `SHADOW` defines (05:28:39-40); those are different shader passes and do not prove shadow-caster warmup. The 5f static single-copy change has therefore not achieved the intended shadow-pass coverage.

## Boot wall interval and preparation

First IntroSession module load is 05:27:19.615 (line 1109); first observed boot is 05:27:19.936 (line 1138). First ready boot sample is 05:28:50.523 (line 2168), followed by crt at 05:28:50.688. Observed boot-to-ready is **90.587 s**; module-load-to-ready is **90.908 s**, an enclosing startup bound rather than an exact Start timestamp. Ready sample's cinematic time is 38.2578 s, which is not elapsed wall time. `openingLoad.wallMs` is the raw `Time:GetSystemTime()` counter (`tools/migration/probe-outgame-web.lua:149`), not an elapsed duration.

| First observed milestone | Timestamp | Detail |
| --- | --- | --- |
| Opening media ready | 05:27:31.544 | 70 resources, 63,149,747 bytes |
| Audio ready | 05:27:39.152 | 55 sounds; total instrumented PrepareNext 827 ms, max 195 ms |
| Scene prefetch ready/resources phase | 05:28:03.604 | 525 resources, 178,758,722 bytes |
| Scene phase | 05:28:04.510 | Sampling boundary, not exact phase start |
| Prepare phase | 05:28:10.392 | Sampling boundary, not exact phase start |
| First warmup pose | 05:28:20.782 | Actual IntroWarmup log |
| Warmup restored | 05:28:50.324 | 413 presented frames, 392 batches |
| Ready | 05:28:50.523 | All media, audio, scene and images ready |

Final loader counters at ready: download 0.012 s, resource decode 1.440 s, scene 6.005 s, prepare 10.358 s, activate 0.017 s. Prepare spans 449 updates; measured preparation work totals 4210 ms, max slice 398 ms (`intro-montage-view`). Other max preparation slices include intro-actors 249 ms, environment 167 ms, boulders 153 ms and data 115 ms. SceneLoader wrapper max is 680 ms; imagePrepare/openingPage max is 230 ms. These nested measurements must not be added as independent wall durations. Media/prefetch and audio overlap; milestone gaps are not pure download attribution.

## Easy target sample

At log line 2337, 05:29:31.358, frame 3549, sortie-play age 20.5933: `sortie.mine=true`, `sortieCombat.enemyHealth=0`, kills 1 and hits 396. Later samples also show zero before the later reset. This directly supports the source's easy-hit branch; a post-sortie snapshot with health 1 cannot disprove that earlier hit/kill.

## Short-batch/cache hypothesis

`scripts/render/SceneWarmup.lua:38-44` advances immediately on each Rendered call; `scripts/intro/IntroWarmup.lua:97-101` calls it once per Presented frame. Thus each small batch only has one presented frame. This establishes batch cadence, not whether its shadow casters were submitted.

The complete `engine-docs/recipes/lights-and-shadows.md` section 3.3 says temporal shadows are opt-in and default off. `assets/Scenes/Crater.xml:34-45` configures a directional sun with shadows but no temporal opt-in; `scripts/scene/Crater.lua:29-30` only sets direction, CSM splits and bias. No script enables temporal shadows. Consequently, source/config evidence does not currently support attributing the missing pass to active directional temporal scheduling.

Documented controls exist: `.emmylua/Light.d.lua:196-243` exposes Get/SetTemporalShadows and InvalidateTemporalShadows; `.emmylua/Renderer.d.lua:102-106` says disabling clustered-local shadow cache forces depth redraws without disabling shadow sampling. The latter is for local lights, not the sun, and local shadows default off on mobile. Current run reports mobile/GLES. Static declarations are not proof those newer APIs exist in Runtime 20260923. A later controlled experiment should first probe the live method availability and actual sun setting, then capture/temporarily change/restore only a supported relevant setting. No such experiment was executed here; no production remedy is claimed.

The parent's later first-versus-nearest hypothesis was checked against authored map data only. Parsing all `StaticModel` components in `assets/Scenes/Crater.xml` gives 289 components and 289 distinct `(Model, Material, Cast Shadows)` groups: zero repeated groups. Source export `tools/migration/crater-source/rocks.json` also shows merged rocks as separate unique mesh-279/280/281 models. Consequently the authored static map alone offers no same-identity duplicate to replace with a nearer sample; dynamically added components were not inventoried live. The broad camera frustum (ChaseCamera default far clip 2600) versus 75m sun cascades/90m static shadow distance makes distance rejection plausible, but does not prove the actual selected candidates or explain which caster was submitted. No nearest-candidate production change was made or endorsed as a confirmed fix.

## Source simulation continues behind the comic

Read-only source comparison uses `.tmp/outgame-source-2026-10-15T12-35-57-243Z`, branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. Source paths below are relative to its `three/src/` directory.

The source does **not** stop battle simulation when the playable sortie ends. `intro/introSortie.js:303-318` sets `I.playing=false`, removes play controls, releases pointer lock, clears firing/scope, restores the cinematic script/target/camera and respawns dead non-cart actors, then swaps back to the demonstration car. It never sets `drive.active=false` or calls pause/exit. `swapPlayer` at 282-287 and `drive/testDrive.js:895-906` `_spawn` only replace/synchronize/place the player. The active-state writes in testDrive are construction (183), entry (338), pause (639), resume (686) and exit (695).

`intro/intro.js:197-198` updates drive whenever mode is crater and drive is active; `covered` only guards the garage branch. `actFamiliar` (906-934) shows captured images and sets `covered=true`, and `actGalaxy` (938-958) replaces the panels, but neither exits drive nor changes crater mode. `actPayslip` (963-973) clears covered and follows the live cart. Montage temporarily switches to garage for build, then back to crater for driving. Recruitment/motto keeps the live cinematic orbit (1211-1250). The later `prepareStoryScene` (1256-1262) explicitly exits drive and switches to garage.

This is a real simulation path, not only a view update: cinematic `paused=false` at `intro/intro.js:1293-1294`; `beforeStep` (1303-1316) steps external units and their AI/fire; `drive/testDrive.js:1028` only returns for a paused mode controller, and its fixed-step loop (1082-1099) executes the controller, player and simulation. Current `scripts/app/OpeningHost.lua:217` ticking the crater behind comic/payslip/motto therefore cannot be classified as a missing source stop switch. This finding does not prove equal cost or exact per-actor behavior; any selective background pause is a separate performance proposal requiring continuity checks.

## Exit audio parity gap found in the 5f snapshot

The 700ms exit lifecycle package does not implement the source audio tail. Source `_finish` calls `audio.fadeOutAll(1.2)` immediately at fade start (`intro/intro.js:150-154`). `intro/introAudio.js:183-189` cancels scheduled master-gain changes, starts from its current gain, linearly ramps to zero over 1.2 seconds and closes the context after 1.4 seconds.

Current `scripts/intro/IntroSession.lua:335-347` keeps audio updates during the 700ms overlay fade, then completes and disposes. `scripts/audio/IntroAudio.lua:115-120` immediately stops voice, every SFX and every music source and disposes its scene. There is no equivalent 1.2-second master fade or independently retained 1.4-second audio lifetime. Earlier gate `StopMusic(2)` can already make the remaining tail quiet; source inspection alone does not establish an audible click or abrupt cut in a natural run. Register this as an unresolved audio parity item outside the authorized 700ms visual/lifecycle package; no production audio edit was made.

Follow-up status: the parent subsequently authorized this exact audio gap. The new Session hash `32790d671ab260f2c334fed8c9377ac99c12e87cee818b249da4a7cfd9c2428e` starts g5's master tail at Finish and hands off only audio at 700ms of wall time. `intro-finish-offline.json` now has 53 passing checks using actual Session/Host/IntroAudio/IntroAudioTail, including wall/dt divergence, 1.2-second zero gain, absolute 1.4-second disposal and independent ownership. The paragraph above describes the inspected 5f snapshot, not the updated implementation. Native audible output remains unverified.
