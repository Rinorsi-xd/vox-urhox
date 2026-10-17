# G4 Opening Sortie R Reset

Date: 2026-10-17. Frozen source: `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`.

Status: **ISOLATED_CANDIDATE_OFFLINE_PASS; NOT_MERGED; ACTUAL_INPUT_AND_RENDER_PENDING**. Production input and UI are unchanged while the coordinating agent tests its frozen build.

## Confirmed Omission

The source opening's `_key()` delegates playing input to the ordinary TestDrive keyboard handler. It stops Escape, T and Backspace, but allows R to reach `_beginReset()`. The source cinematic mode controller has no keyboard override. The source therefore retains its existing safe reset during the first live driving segment.

The target `HangarApp:Update()` returns after updating the opening. `OpeningHost.Update()` handles Escape and weapon number selection, but does not pass R to the existing `TrialSession:Flip()` / SafeReset channel. `TrialSession:Tick()` already updates that channel, so the missing part is its input entry and the opening's custom HUD presentation.

Escape was checked separately and is not treated as a discrepancy: both source and target release pointer capture during this introductory drive. The candidate does not add the ordinary pause settings menu there.

## Isolated Candidate

Candidate files are in `.tmp/intro-sortie-r-candidate/scripts/`:

- `app/OpeningHost.lua`: while the intro is playing, an R edge calls the existing `s:Flip()` safe reset entry. Montage input does not trigger it.
- `ui/IntroSortieUi.lua`: attaches the existing `ui.ResetProgress` component, renders it using the same viewport layout as the reticle and disposes it with the opening HUD. The existing component supplies the source-derived thin reset bar and text.

No reset algorithm, physics, damage, timing, C/follow-camera behavior, T/Backspace routing, audio or production source was changed.

Candidate SHA-256:

| File | SHA-256 |
| --- | --- |
| OpeningHost.lua | `18baf92668d85e6611f53bbc1dbe49878ca4f615f52ee610f7e616a312a5a261` |
| IntroSortieUi.lua | `7b63347516c6289c7f4f14f1edb3a1954aac23eaf28ba5bf450030cad523830e` |

## Verification

`node tools/migration/source-intro-sortie-reset.mjs` verifies frozen hashes, executes the actual source Intro and TestDrive keyboard methods and confirms R reaches reset while Escape, T and Backspace do not reach the drive handler. It also confirms the actual source cinematic controller has no key override.

`verify-intro-sortie-reset.py` executes the actual isolated OpeningHost module with controlled engine adapters. Four checks pass: playing R reaches reset, nonplaying R does not, Escape remains release-only and no R edge does not reset. The current production OpeningHost is a negative control and fails specifically at the missing R route. The actual isolated IntroSortieUi constructor, draw path and disposal also run with adapter widgets; its reset layer draws and releases once and shares the full reticle viewport.

These are CPU adapter checks. They do not accept actual pointer-lock behavior, reset completion against native collisions or rendered text placement. After the coordinating agent's current freeze is released, merge only the reviewed small differences and run natural opening input/render acceptance. Do not replace later production files wholesale with these isolated copies.
