# G4 opening brand and film layers, 2026-10-16

## Scope and baseline

Continue the existing G0-G6 migration. No G0 restart, commit, upload, or GPU/browser test in this child task.

Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`. Source files: `three/src/intro/introLogo.js`, `three/src/intro/intro.js`, `three/src/intro/introSortie.js`, `shared/css/intro.css`.

User's approved subtitle block remains byte-for-byte unchanged. Existing three prosperity/order/leave comic panels keep their independent event clocks and foreground/background movement.

## Implemented candidate

- `scripts/ui/IntroBrand.lua` replaces the static approximation of the initial company sting. Source graphite background and 8vh grid; cyan line expands in 0.5s and fades from 1.1s; company mark reveals with a circular mask from 0.35s for 0.6s; word group fades from 0.5s; four Chinese glyphs enter individually from 0.6s at 0.06s intervals with clipped 105% upward motion. English starts at 0.85s, narrows tracking from 1.2em to 0.42em over 0.9s. Four corner labels fade at 1s, including the previously omitted `EST. 2187`.
- Source title is 10vh, logo is 20vh, horizontal gaps/padding are 4.5vh, metadata gutters 4vw. Source mono text uses the existing `vox-code` source face instead of the Chinese title face. Layout remeasures the English width as tracking contracts, matching the source centered flex row behavior.
- `scripts/ui/IntroFilm.lua` restores film underlay: source 0.4s opacity entry, 700ms first live-shot black fade, public-service emblem/title, advertisement badge, two legal lines, 1px scanlines at 3px intervals, and elliptical vignette. Scanlines use one path and one fill, not hundreds of independent filled rectangles.
- Film underlay runs before the promo panel branches. Therefore opaque comic/schematic layers cover it, as in the source DOM. Cinema bars run after the existing subtitle block, following source `idyll -> prosper -> sortie -> familiar -> galaxy -> montage` changes. The initial logo remains above the first live shot for its source 260ms vertical closing clip.
- `scripts/ui/IntroFamiliar.lua` restores the next confirmed gap: three panels enter individually at 0/.34/.68 seconds from left/top/right, using the source 300ms cubic curve and rotation. First captured shot zooms 1.14 to 1 over 3 seconds; the second zooms 1 to 1.12 and moves 2% to -2%. The third panel keeps the original workshop/character layering and 0.008-amplitude breathing. `轰——！`, `滋滋——`, and `……？` each have their source relative 120ms delay and 220ms spring entry. Existing actual captured textures are passed through the host's existing DrawCapture interface, without a new screenshot readback or host modification.
- Production call sites are confined to `scripts/ui/IntroPromo.lua`; no dialogue rendering, source captions, driving, audio timing, host scene ownership, or prewarm file was changed.

## Offline verification

Run bundled Python with `tools/migration/verify-intro-brand.py`.

`docs/migration/evidence/intro-brand-offline.json` records final source/production SHA-256 values and the actual rerun count. It parses the exact frozen selectors and CSS timings, compares the actual Lua plan against independently inverted cubic Bezier curves at 1,801 time samples, and exercises production Draw using stateful NanoVG/image doubles at 16:9, 20:9, and 16:10. Film checks cover real source enable/disable transitions, initial closing clip, batching, metadata, state restoration, and source subtitles unchanged. Lua 5.4 syntax is checked for all three production files.

This is algorithm and draw-call evidence only. It does not prove rendered text width, glyph atlas behavior, image uploads, CSS blur equality, natural complete opening, audio smoothness, or phone performance. Actual same-package Web screenshots and continuous opening playback remain OPEN with the parent agent.

Final narrow-window rerun: brand/film **20,482** checks; Familiar **21,015** checks with 1,201 time samples and 51 capture draws at three aspect ratios. Familiar evidence is `docs/migration/evidence/intro-familiar-offline.json`. Production is frozen for the parent's next unified package:

| Production | SHA-256 |
|---|---|
| `scripts/ui/IntroBrand.lua` | `a4f5612209dac864becfe1fa51e2807a3b3f03db89e54fb2e7d01e552a5ff90f` |
| `scripts/ui/IntroFilm.lua` | `c2b1612b46364e6d2759f9644cdbd97393be7fec6be2c12598794ee59e9de2b0` |
| `scripts/ui/IntroFamiliar.lua` | `4b0be98da3179c87c989b99bd21e48b0fe9561d565eea7f46d44579d61d9fca8` |
| `scripts/ui/IntroPromo.lua` | `c19fa2d2cb02d566344712e831d5da74595e38dac97128c66634783b6c31330a` |

## Confirmed remaining commercial-film differences

These are verified against frozen source code, not a claim that everything else matches.

| Segment | Source | Current remaining gap | Acceptance |
|---|---|---|---|
| Idyllic live shot | Actual garage, dove, three hover vehicles, rising camera | Those systems already exist; same-package composition and shader fidelity still need rendered comparison | Capture the natural first scene, compare camera/actors/visibility, no freeze during narration |
| Prosper/order/leave | Separate panel clocks and foreground parallax | Already implemented; paid-leave background still uses static workshop fallback instead of source captured outdoor planet view | Three separate entry times, captured planet behind family, no simultaneous-panel animation |
| NO impact | Red baked dove, actual clipped fragments, shake and page tint | Target has a plain dove sprite fragmented with simplified trajectories and fixed reference rectangle; red-hit appearance and exact transformed target tracking are not complete | Aim dot must hit the animated dove; red hit, shatter and NO overlap match source timing |
| Familiar | Three panels enter at 0/.34/.68s from left/top/right; distinct image moves; `轰`, `滋滋`, `……？`, breathing | Candidate now implements those layers; exact patterned backdrop, labels/font stroke, source filter compositing and actual captures need Web comparison | Sequential panel captures with original per-panel motion and all captions |
| Galaxy / payslip transitions | 760ms diagonal wipe, midpoint scene replacement | No full source diagonal wipe in current sequence | Continuous recording shows the wipe covering the actual scene handoff |
| Payslip | 520ms rotate/slide entrance, detailed typesetting/barcode, lock-on convergence, laser, cloned clipped paper fragments | Current sheet is simplified, lacks lock/laser; breakup is flat colored squares | Source sheet layout, lock convergence and patterned moving fragments, correct wrecked/nonwrecked figures |
| Decide / decided | Expanding spotlight, beam cone, breathing/jitter, hero swap and 420ms pop, speed lines | Current image opacity and ring are only a partial approximation | Hold/release and unattended completion show source spotlight and layered hero effect |
| Montage / recruitment | Actual gameplay, source cards, detailed character panel, final company card | Existing host shots and title cards are present, but complete natural recording and missing stage effects still need scoped comparison | One uninterrupted opening to contract, all source cuts and narration preserved |
| Film fidelity | CSS text shadow, emblem drop-shadow, radial vignette and exact raster edges | NanoVG vignette/line glow are bounded approximations; shadow/filter exactness requires Web comparison | Side-by-side screenshots at matched times and aspect ratios |

Do not mark the entire opening or G4 complete based on this candidate. The large missing layers above remain visible work items, not hidden acceptance exceptions.
