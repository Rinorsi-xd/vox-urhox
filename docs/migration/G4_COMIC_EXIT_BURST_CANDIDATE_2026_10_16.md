# Frozen comic exit and burst candidate

Source: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`, frozen `.tmp/outgame-source-2026-10-15T12-35-57-243Z`. This continues the current G4 work; it does not reopen G0. Production is frozen for root's unified package. No build/browser/GPU/commit/upload was run by this agent.

## Implemented

- Retain all three accumulated comic title cards for the first 150 ms of `no`, applying source `ease-in` opacity 1 to 0 and scale 1 to 1.08 around each card center. Nested glyph opacity composes with the exit and parent fade. Original captions and lettering remain unchanged.
- Compute the laser target and fragment origin from the frozen animated dove layer's rotated bounding rectangle. Original image containment and the source's reset-to-axis-aligned clone geometry remain separate.
- Swap to a precomputed red image at `no + 0.4 s`, hide the original at `+0.5 s`, and draw 36 clipped pieces with source random force, pixel displacement, rotation, duration and easing. A fixed local random stream preserves the same distribution and makes captures reproducible. Fragments can leave the panel polygon, then release with the owning comic page. The cache uses the logged `no` timestamp, avoiding per-frame regeneration from floating-point clock subtraction.
- Add `Intro.json.images.dove_red`. Actual Session dependency enumeration includes it; actual ImageWarmup loads it before playback and releases its owned image once. No Session, Host, audio, physics or shared library edit.
- Derive the red bitmap from the frozen original using the exact authored filter order: `sepia(1) saturate(7) hue-rotate(-28deg) brightness(1.15)`. `bake-intro-red-dove.py` records source SHA and verifies original PNG equality, 1024x1024 dimensions and unchanged alpha bytes. Result is 1,537,251 B; RGB uses deterministic 8-bit color-matrix stages. Browser Canvas rounding equality has not been measured and remains pending.

## Production Freeze

| File | SHA256 |
| --- | --- |
| `scripts/ui/IntroTitleCard.lua` | `8f77551d6df7dc95cf066cf746779f4cc79bec8edae99365582461f47a64332d` |
| `scripts/ui/IntroComic.lua` | `4d2e03607768816cf5f4c57fe79536fb4bbf511bb093389d60b4a6df696d2182` |
| `scripts/ui/IntroComicMotion.lua` | `259d2836989b654b31f1888a153b8dbc480f63c6b5e81b0611356be9877bc77b` |
| `scripts/ui/IntroComicBurst.lua` | `f1bd6414a544ec7f24069c776e8ce120f1d0068d9ceda79cf05b7c423f06a8cf` |
| `scripts/ui/IntroPromo.lua` | `f17e9934b4422ddd0ec755ef832458209ffde6ffa562b2f1b30f6030abc4f2f9` |
| `assets/Intro/Intro.json` | `74c772de477efabfb9880d58067abf329b575243d0bbd2a379c81c6e3cfb5964` |
| `assets/Intro/Images/dove_red.png` | `5766b73ee7c1d98fff9d1ac0a412c5028ce50a84ffaec0ee61b753d0e8dcdc25` |

## Validation

Actual `check-intro-comic-motion.py`: 1945 checks PASS. Executes frozen JS actVirtues/shakeDom/_burst/titleCard exit and actual Lua Comic/Promo/Burst/TitleCard drawing, Session dependency enumeration and ImageWarmup ownership release. Three viewport ratios, source 36-particle parameters with identical random inputs, live-fragment removal, red-image cue, 150 ms title removal, nested fades and balanced drawing state. New module, JSON, red image and evidence tools are associated by SHA in the existing `intro-comic-motion-offline.json`; no new snapshot registry entry is needed.

Actually refreshed affected reports: brand 20509, familiar 21017, non-caption text 2137, promo 874, contract style 717, gate 920, promo motion 6960, promo effects 1709, payslip layers 293. All PASS. `audit-report-freshness.cjs` returns FRESH / drift 0 after these runs. GPU raster, whole natural sequence and mobile performance remain root's acceptance, not certified by these tests.

## Remaining Boundaries

- Payslip corner blur/glow was not changed; it remains OPEN. No further opening decoration is being added in this batch.
- Laser growth/impact lettering, full-screen coordinated motion, exact DSP and browser pixel equality are not certified by this narrow candidate.
- Comic text/font source audit remains `G1_INTRO_TEXT_FONT_DIFF_2026_10_16.md`: all source captions/dialogue and nine title strings match; source intentionally uses GameFont for comic titles/SFX/stamps. This batch changes no strings or font faces. It does not convert the earlier source audit into rendered font approval.
- Old `Intro.json` provenance still labels the original 10/14 export. Text equality with 10/15 was separately verified; no blind metadata relabel was made.
- Root should inspect final leave, `no + 75 ms`, `no + 0.4 s` and `no + 0.6 s` in the new package. Previous d011 natural PASS cannot certify this candidate.
