# Combat First-Use Warmup Audit

Updated: 2026-10-15 19:31 CST. Read-only production audit; no runtime browser was started. Source baseline remains `2b169a9964645f5f346a7158bcb14447f040814a`. This audit does not restart G0 or prove a frame-time improvement.

## Confirmed Coverage Difference

Ordinary `LoadingFlow:Finish` (`scripts/app/LoadingFlow.lua:78`) snapshots the current scene through `SceneWarmup.New`. That scanner considers already-existing, nonzero-mask drawables, skips those outside the current camera frustum, then submits batches of eight. It does not create missing effect geometry, allocate lazy pools, sample another camera pose or activate the disabled combat flash light.

`TrialSession:init` creates the real `CombatEffects` at line51, but its five batches start disabled and empty (`CombatEffects.lua:25`, `EffectBatch.lua:6`). Its initial `PostUpdate` does not call `effects:Update`. `Update` returns while `loadingFlow.active`, so these empty batches remain outside useful ordinary render warmup. Reading a shader resource in the dependency gate does not submit its vertex layout/pass variants.

Opening `IntroWarmup` explicitly renders seven poses, including synthetic shot/beam/impact/break/blast/explode, four missiles, four equipment proxies, weapon batches, a long-range combat flash point light, then single-instance variants. This warms actual shader programs but creates a separate temporary `CombatEffects` and disposes it. It does not retain slots/buffers for `session.effects`. The public opening test log in `evidence/intro-dialog-web-2026-10-15T11-22-36-417Z/runtime.log` records430 presented frames/409 warm batches, so reusing the entire opening warmer for ordinary matches would add substantial work.

| Feature | Ordinary First Use | Opening Coverage | Required Layout/State |
| --- | --- | --- | --- |
| Bolt, beam, blast, smoke, rings | Existing five materials, but no committed geometry until a live event/update | Synthetic events submit all five base batches | CustomGeometry POSITION/NORMAL/COLOR/UV; exact Combat shader path, transparent pass |
| Rail/laser helix and hit arcs | `CombatEffects:Path` lazily creates Arc batch at line176 | T5 sniper beam reaches Hit during first `.04`update, creates Arc | WeaponFx/Ribbon differs from Combat/Ribbon; cannot count one as the other |
| Missile body/glow | `MissileEffects.view=nil`; first missile creates two materials and bounded pool, then nodes | Four missiles, followed by one | Original Model layouts, body lit and glow unlit; one and instanced geometry |
| Small visual chips | Slots empty; first metal impact/break allocates StaticModel nodes | Break creates12 slots, later single instance | Box model, Chip.shader using INSTANCE_COLOR; lit/shadow/depth, one/instanced |
| Flash point light | Disabled at startup; first shot enables lit-object point-light pass | Enabled with range2000 in boot only | Same real model/material/vertex-layout masks with point light; ordinary map's sun and shadows must remain identical |
| Persistent weapon FX | Per-view lazy batch creation in `WeaponEffects:Batch` | Four explicit WeaponFx batches | Glow/Band/Swirl/Ribbon exact shaders; shared with real rig or isolated shader proxy |
| Thruster/hover/contact | Batches bind to equipped types but volume proxies appear only on power/contact | Thruster/Hover and Mote/Spot/Flare; Contact absent from explicit warmer | Exact Equipment shader/layout; one/instanced volume, flow texture |
| Base shield hit/down/raise | Hit uploads a uniform array; down/raise set uniforms | Existing shield scene geometry, camera-dependent | No new shader permutation per hit/down/raise; existing same-layout shield draw covers compilation |
| Restoration shell | Material exists, geometry absent until restored part | Dependency exists; no actual RestoreFlash geometry in explicit warmer | Joined geometry without COLOR/UV and StaticModel geometry need their distinct vertex layouts |
| Physical detached groups | First detached group builds new physics and a new VehicleView | Visual chips are not physical detached groups | Existing lit part/Joined shaders may be cached, but CPU shape/rig/joined rebuilding remains |

Uniform color, tier, radius, hit time and shield health are not separate shader programs. Do not brute-force every tier/state when geometry layout and render mode are identical. Preserve actual material identity, view/light/shadow masks and presence/absence of instancing when selecting representative draws.

## Event Costs That Warmup Cannot Remove

1. `CombatView:Consume` line29 creates a new `VehicleView` for every physical debris spawn, calls `AddPart` for all members, then `JoinedMesh:Update`. It disposes the view on removal. This is recurring node/rig/material work, not only cold shader compile.
2. `JoinedMesh:Update` line22 rebuilds the complete remaining exterior surface after a joined-block removal, then commits every resulting material mesh. Damage burst frames can combine multiple actor rebuilds. Profile `JoinedSurface.Build` and `CustomGeometry.Commit` separately before designing dirty-region updates.
3. `RestoreFlash:Add` line31 creates a node on each repaired part, a new Model wrapper for each retained source model, or a new CustomGeometry and cloned material for joined parts. After`.34s` they are disposed. A cache keyed by immutable original model plus selected material indices could reuse the model wrapper, but requires bounded ownership across scene release.
4. `MissileView:Add` line19 grows its node pool on first simultaneous demand. `ChipEffects:Emit` line12 grows its slot pool up to96mobile/360desktop. Opening temporary pools do not eliminate growth in the real combat owner.
5. `CombatEffects:Update` still builds transient Lua tables and calls CPU CustomGeometry definitions each live frame. Shader warming cannot fix sustained particle/arc rebuild cost.

Player display duplication was checked: practice, battle, story, endless and salvage mark the player `externalView=true`, so the additional player DriveView is intentional and not evidence of duplicate live player drawing.

## Smallest Implementable Plan

1. A new scene-owned `render.CombatWarmup` should run behind the existing opaque loading page, after TrialSession initialization and before `LoadingFlow` reveals. It must render a small number of representatives with the exact final camera lighting/post chain. Do not reuse the full seven-pose opening warmer.
2. Warm the **actual** `session.effects` owner for the five base batches, Arc, first missile body/glow and a small retained chip pool. Render one and four repeated copies for instanced variants. Clear event lists and hide warm geometry after real FramePresented; keep allocated pools alive for that session. Restore every mask, camera pose and flash-light field on completion, cancellation and error.
3. Avoid `CombatEffects:Consume` synthetic events in a no-gameplay-change implementation: it calls global `math.random`, advancing the same RNG used by gameplay. Standard Lua cannot restore that RNG's internal state. Add narrow deterministic reserve/warm APIs on ChipEffects/MissileView/CombatEffects or fill existing EffectBatch geometry directly with fixed coordinates. Never reseed the shared RNG as a workaround.
4. Submit exact non-empty geometry for each shader/layout, then a separate lit-scene representative phase with the actual combat point light. Reuse `SceneWarmup` batch submission and mask restoration. Do not mark warmup done before a frame is presented. Camera-excluded map geometry still remains cold; this plan addresses combat first use, not every possible future camera view.
5. A second phase can pre-reserve bounded slot capacity in small chunks when the measured profiler identifies allocation spikes. Warm minimal geometry first; a one-quad warm does not prove the later maximum-size dynamic buffer allocation was covered.
6. Acceptance must include cold ordinary match without first playing opening: loading stays responsive; first fire, first metal hit, first missile and first destruction recorded; corresponding generated shaders loaded before reveal; no synthetic damage/audio/FX remains; retained pool grows only at declared budget; cancellation releases every temporary owner. Compare frame distribution to the same immutable package and device/browser settings. No visual downgrade or raised threshold.

## Ownership Before Implementation

| File/Area | Owner/Status |
| --- | --- |
| SceneWarmup, CombatEffects, TrialSession, LoadingFlow/HangarApp wiring | Root reserved; do not edit concurrently |
| New CombatWarmup small module | Unassigned; root can delegate after agreeing integration interface |
| Narrow reserve API in ChipEffects/MissileView | Requires root assignment; would retain actual pool without changing simulation |
| JoinedMesh/physical debris/RestoreFlash caching | Separate measured work, not folded into shader warmup |
| Intro/IntroPage and evidence | G4 agent completed current text increment; no browser remains |

No performance percentage is claimed from this source audit. Root's exclusive runtime profile determines which of shader compilation, pool growth, mesh rebuild, raycasts and Lua allocation dominates the reported stutter.

## Implemented Increment

2026-10-15 19:52 CST: `scripts/render/CombatWarmup.lua` and narrow `Reserve` APIs in CombatEffects, MissileView and ChipEffects are implemented. Root integrated the warmer into LoadingFlow after existing SceneWarmup, before reveal. Boot/hangar without a trial do not construct it. Failure clears pending work and restores active warmers; Close disposes it before session teardown.

- Contract: `warm=CombatWarmup.New(trial,{batchSize=8,chips=32,missiles=4})`; call `warm:Presented()` once after each actual rendered frame; true means complete. Cancel/error teardown uses idempotent `warm:Dispose()` before scene disposal.
- Actual session pool retained: five existing effect batches plus Arc,32 inactive chip slots,4 inactive missile slots. Reserve is bounded and has no RNG calls. No synthetic Consume, simulation tick, damage, sound, physics or global random reseeding.
- Phases: four/one effect copies with ordinary lighting, four/one with the actual combat flash light, then visible real-scene model/material/mask/layout groups with flash light, instanced and single passes. Same-group four copies remain in one batch; each real-scene batch is at most8drawables. The temporary flash range covers the view and brightness140 makes it representative of an actual explosion, then its original fields are restored.
- Restores masks, batch visibility/count/camera/clock, chip node transforms/visibility/instance color and instance-color flag, missile transforms/visibility/count, flash node/brightness/range/enabled. Warm geometry stays disabled until a real effect overwrites it. Initialized pools stay scene-owned.
- API names checked against actual declarations: Drawable masks/maxLights/zone, StaticModel useInstanceColor/useInstanceCustomData, Component enabledEffective, Material Get/RemoveShaderParameter, and Variant copy constructor are declared in `.emmylua`.

Offline Lua5.4 validation through existing `.tmp/nav-python-deps` Lupa:

1. `tools/migration/check-combat-warmup.lua`: **12 scenarios PASS**. Cancellation after0..6frames, normal completion, active-session rejection, reserve failure, initial geometry upload failure, later presented-frame failure; masks/lighting/geometry visibility restored; pools retained/bounded; global random sequence unchanged.
2. `tools/migration/check-loading-combat-warmup.lua`: **7 scenarios PASS** against current real LoadingFlow. Scene warmup precedes combat warmup, repeated Rendered initializes only once, warmFrames cannot reveal early, boot exclusion, pending/active cancellation, New/Presented failure, restoring SceneWarmup on failure.

These checks mock engine objects. Actual Web must still demonstrate generated shader permutations before reveal, no lingering fake geometry, first fire/hit/missile/destruction behavior and frame times. Camera-excluded assets, later maximum dynamic-buffer growth and recurring physical-debris/JoinedMesh/RestoreFlash rebuild costs remain outside this increment. No browser or runtime instance was opened by the implementing agent during root's exclusive profile.
