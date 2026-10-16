# Opening runtime recovery after manifest 8581d52a

This batch is a new workspace change after the frozen `8581d52a` package. It must not be described as part of that package's natural Web playback evidence. No GPU, server, native runtime or publication was used for this batch.

Frozen source remains branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Production

- `scripts/app/OpeningHost.lua`: SHA-256 `f421ba08c158f967177d2e60c9787597478fd763869405e6f8034fe57c9db59d`.
- `scripts/intro/IntroBattle.lua`: SHA-256 `bcd41a4b4363ed9f3af8da4cd4108189a9e0569bd213c4845046cf0822994aea`.
- New `scripts/intro/IntroSortieCar.lua`: SHA-256 `5bc9b00e5931d823a013409d459203b261189e3c55f1612620f46cf77254df73`.
- `IntroSession.lua` is unchanged at SHA-256 `cef992d723e4f3b9b5ad8ea1550993c4422b431f6fa4fd7abc3bfaeb4721bfd2`. `IntroMontagePool.lua` also remains unchanged.

Enemy drivers now run during the establishing shot, briefing and countdown against the cart. A dead target parks the enemy rather than entering its driver. At player handoff, only the easy enemy receives multiplier 8 and moves to `[66, ground(66,-130)+1.2, -130]`, yaw PI. The exact source `placeUnit` uses 1.2 metres for this enemy; the player's source spawn uses 1.5 metres.

EndSortie resets the actor damage multipliers to 1, respawns destroyed non-cart enemies, restores cart targeting through stage 0, and activates the already prepared original hero pool at `[150, ground(150,-214)+1.5, -214]`, yaw 0. It clears pointer/held controls through the existing Pause and resets camera/action state. The existing m-drive relocation remains the next montage's authored placement. This moves activation earlier without allocating a second hero or changing shared session ownership.

The host records that sortie began at `sortie-brief`. Normal completion consumes this flag; an advertisement skip reaches `tvcut`, whose host callback performs the same cleanup. The flag makes repeated cleanup a no-op. Cancellation disposes the session and held pool directly; it does not activate a hero that is about to be destroyed. No extra Session timing callback was needed.

SortieCar reproduces the literal source predicate: valid spec, at least one weapon, no wings, and wheels OR legacy legs OR hovers. A mech-only car remains a fallback under this source rule, even though the general engine can drive it. The predicate intentionally does not introduce a new top-speed or working-mount requirement that the source lacks.

## Tests

`check-intro-runtime.py`: 399 PASS. The Node fixture executes actual frozen `sortieCar`, `endPlay`, `placeUnit`, handoff statement and cinematic `beforeStep`; the Lua fixture executes actual selector, battle construction/stages/driver/cleanup, host Shot/Update/End/Dispose, pooled hero activation/disposal, and actual Session.Run/Ad/Update branches. Native, spec, DOM and scene APIs are controlled adapters. Coverage includes 128 eligibility combinations, easy and ordinary enemies at stages 0-3, live/dead targets, natural completion, brief/countdown/play skips, cancel before/after handoff, repeated cleanup/disposal, and late callbacks after disposal.

Historical negative controls load the exact prior `8581d52a` IntroBattle and OpeningHost bytes independently and require failures at briefing AI and multiplier initialization. This proves the new fixture detects old behavior. Evidence: `docs/migration/evidence/intro-runtime-offline.json`.

Regressions after production edits:

- Opening construction: 328 PASS. Its VehicleSpec adapter now includes the actual wheels/wings/legs/hovers contract required by the selector.
- Sortie feedback: 28 PASS.
- Portrait handoff: 167 PASS.
- Comms portraits: 384 PASS, including 36 original source fit cases.

Before these edits, historical contract 53 / portrait 384 / portrait-handoff 167 checks were rerun for the prior package. Original reports were preserved byte-for-byte in `docs/migration/evidence/history-manifest-8581d52a-pre-refresh/`. The later host-dependent reports above describe this new workspace state; the prior package audit remains the prior package's own artifact.

These tests do not establish Bullet simulation equivalence, collision outcomes, natural full playback, rendered camera/framing, audio continuity, or mobile acceptance. The new package needs its own native/Web run.
