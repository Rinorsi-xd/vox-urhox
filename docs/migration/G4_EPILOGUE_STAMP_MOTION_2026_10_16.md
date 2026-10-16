# Epilogue Approval and Final Stamp

This candidate restores two specific missing effects after the S5 result screen, against frozen H5 commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. It has not been reached through a natural S5 completion or rendered on the GPU. The root's ongoing bb6e natural run does not validate this later candidate.

## Confirmed Differences

1. `storyEpilogue.js` shows the contract's approval stamp at panel age 1.6 seconds, then transitions scale 2.4 to 1 over 220ms using `cubic-bezier(.2,1.6,.4,1)` and opacity 0 to .9 over 150ms using CSS `ease`. The previous Lua renderer instantly drew its final size and opacity. `EpilogueMotion.Approval` now supplies these original curves to the actual stamp drawing, with scaling about its center. The base drawing alpha is fully opaque so the authored .9 opacity is applied once.
2. H5's `finish()` removes the overlay's `on` class but leaves the already-visible rejection stamp inside it during the 800ms whole-overlay fade. Previous Lua only drew that stamp during the `stamp` schedule step, so it disappeared immediately on `finish`. Lua now records when the stamp actually appears, retains it through the original CSS-eased fade, and still omits it when the player skips before the stamp. The existing 800ms disposal and callback remain unchanged.

Production ownership is limited to `scripts/ui/Epilogue.lua` and `scripts/ui/EpilogueMotion.lua`. The latter reuses the existing `IntroComicMotion.Ease` evaluator. Subtitle text, voice schedule, playback-version storage, original image/capture selection, result buttons, mission rules, maps, physics and automatic routes are unchanged. S4 has no authored post-result epilogue; S5 version 6 deliberately omits the older hangar and 404 sequence, which have not been added back.

## Verification

- `source-epilogue-stamp-motion.mjs` verifies the frozen source hash and executes its complete `playEpilogue` with deterministic DOM/timer adapters. It observes the approval class at 1600ms, the retained rejection stamp when the overlay starts fading, and removal 800ms later. It also verifies the actual source CSS declarations; a CSS compositor is not simulated.
- `verify-epilogue-stamp-motion.py`: 51 checks pass against actual Lua attach/update/render/finish/dispose. Independent numeric CSS curves check actual text-draw scale and opacity at boundary/intermediate samples. The check covers early skip and exactly one retirement callback. Actual bb6e payload files are identity-verified and fail 18 samples. Four required negative controls fail: absent approval motion, absent final-stamp retention, linear outro fade and a stamp incorrectly shown on early skip.
- Existing `check-epilogue-pages.py`: 264 checks pass, retaining its original page ownership, shake, drawing-state and cleanup negative controls.
- Existing `verify-story-choice-epilogue.py`: 171 checks pass, covering authored choices and versioned first-play/interrupt/reentry behavior.

The generated report is `docs/migration/evidence/epilogue-stamp-motion-offline.json`. Its production and test-input hashes identify this candidate. New-package construction and unified audit belong to root. No GPU/browser/native launch, natural S4/S5 completion, natural ending, listening, visual 1:1 or performance acceptance is claimed. Other known presentation differences, including captured-shot filters and broader panel styling, are outside this change.
