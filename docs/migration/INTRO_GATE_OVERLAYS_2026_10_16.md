# Contract, gate and root fade drawing

Source: frozen `.tmp/outgame-source-2026-10-15T12-35-57-243Z`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. This is next-package production work after frozen `manifest-5f39f096.json`; it does not change or revalidate that package.

## Production changes

`IntroPage.lua` retains the signed contract and name through the stamp shot. On `contractExitAt`, the contract leaves over 300 ms, stamp over 500 ms, portrait over 300 ms and background effects over 400 ms, while the gate closes in front. Stamp keeps the original 36vh size, -14 degree rotation, 260 ms three-keyframe entrance and original easing. Existing approved landscape contract geometry and bottom subtitle block are preserved.

`IntroGateMotion.lua` follows the actual frozen `actGate` wait/animation schedule. Seconds below are relative to the gate mark, excluding render-frame scheduling:

| Cue | Source Time |
| --- | ---: |
| Close finishes; full lock enters | 0.46 |
| Identity unfolds | 0.81 |
| Identity accepted | 1.89 |
| First bolt retracts | 2.44 |
| Six 80 ms bolt waits finish; disc starts 420 ms rotation | 2.92 |
| Unlock, illuminated seam, first pressure burst | 3.28 |
| Full lock becomes two clipped leaf locks; second pressure burst | 3.58 |
| Crack-open finishes; identity starts 300 ms exit | 3.94 |
| Full opening starts; seam starts 1200 ms fade | 4.24 |
| Gate/steam removed | 5.94 |

Each bolt retains its source 130 ms CSS transition. The last bolt's transition can therefore overlap the start of disc rotation by 50 ms, just as the source does; the 480 ms phase offset refers to six trigger/wait steps, not six completed CSS animations.

`IntroGateFx.lua` draws the seam, lock, two clipped halves and both pressure bursts (12 + 16 particles). Steam uses the original normalized origin/velocity/lifetime ranges, per-rendered-frame 0.97 velocity damping and CSS-pixel radii. The identity screen now uses source 50vh width / 8vh top and source row labels, sizes and spacing.

`IntroOpacity.lua` composes explicitly owned opacity groups per NanoVG context without changing the global API or engine library. IntroPage pushes the root fade from `finishing`, `fadeOutDuration` and wall-clock `fadeOutElapsed`, with `time - fadeOutAt` retained only as a compatibility fallback. A clamped simulation time step therefore cannot prolong the 700 ms fade after a long frame. The name TextField also receives its own UI opacity. Ten other Intro modules receive only a local alias for their existing alpha setter; IntroPromo uses the same API under its separate owner.

This applies alpha to every rendered element. CSS root opacity first composites the group offscreen and then fades its pixels. Those operations can differ where translucent primitives overlap; this implementation is not a claim of pixel-identical group compositing. No new render target was introduced.

## Verification

`check-intro-gate-offline.py`: PASS 920 checks, 88 actual Page.Render cases across four viewports plus 56 actual Promo cases. The fixture executes frozen `actGate` and the contract stamp tail in JavaScript with virtual waits, then executes production Page/Contract/Comms/Gate and actual Promo children in Lua 5.4. It checks source cue times/easing, contract exit layering, two moving lock halves, both steam burst counts and radius/lifetime ranges, finite native calls, balanced save/restore, nested opacity replacement semantics, and every emitted fill/stroke/text/portrait alpha at full, half and zero opacity (Promo at 0.37). Additional cases verify that wall elapsed overrides clamped simulation time, directly and through actual contract/stamp/gate drawing.

Re-executed existing fixtures: contract 53, comms portraits 384 plus 36 source-fit cases, portrait handoff 167, brand 20509, familiar 21017, noncaption text 2009, contract cost 84, sortie feedback 28, timing 3953, audio meter 27. All PASS. The contract cost fixture still compares emitted geometry and allocation to the historical 3ba package; it is not a Web timing result.

The native NanoVG and portrait surfaces are adapters. Steam is stochastic and the seam glow is an approximation of CSS shadow rasterization. These tests do not establish GPU appearance, source pixel identity, Web continuity, audible output, mobile performance or user visual acceptance. The 5f stamp Page.Render peak near 303 ms remains an unresolved runtime finding. This work used no GPU, browser, package, upload or commit.

Current production hashes are recorded by `evidence/intro-gate-offline.json`. Prior associated reports were copied to `evidence/history-next-opening-pre-gate/` before refreshing; that directory preserves the reports present at refresh time, not a new attestation of old package bytes. Frozen 5f package audit evidence remains separate.
