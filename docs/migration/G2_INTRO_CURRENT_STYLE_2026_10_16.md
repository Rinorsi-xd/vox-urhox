# Opening late-section source audit and production style corrections

Frozen source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, directory `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

Independent immutable package: `.tmp/outgame-cached-1792102529909`, manifest `82a41dd6`, script fingerprint `ef3e9d7be054d3734a7e0401515e7fa440af1f67dd3811a1e59c06f7da7719fa`. The changes below are current production changes after that package. They do not change its scripts, HTTP content, GPU evidence or acceptance status.

## Audit Against 82a41dd6

Wages retain the source rows, values, conditional repair row and text. Comic source captions and layers are present; captured leave-background behavior still has the documented workshop fallback difference. Familiarization uses real OpeningHost captures. The montage has all four source stages. Gate original strings and the late transition implementation are present. No additional omitted wording was found in these surfaces.

The older residual document predates several implemented features. Do not relist final 700ms fade, gate seam/steam/split lock, contract/stamp 300/500ms exits, motto 400/900ms reveal and second-line 48% clock, or salvage 200ms artwork exit as absent from 82a.

Source detail anchors: `three/src/intro/intro.js` wages 962-1012, montage 1110-1206, recruit/motto 1210-1251; `introStory.js` unfolding 69-98, choices 349-371, contract 375-481 and gate 489-594; `shared/css/intro.css` contract 279-343 and motto 555-559.

## Current Production Corrections

- Motto follows the frozen centered flex composition: 16vh emblem, 2.4vh gaps, 4.4vh type at 1.5 line height and .2em tracking, 2vh vertical padding, two 1 CSS px rules, centered 1.3vh fineprint with .08em tracking. Existing reveal clocks and approved bottom subtitles are retained.
- Selected choices exit +2vw; other choices exit -10vw. Source ease-in durations remain 240/280/320ms, independently of the Session's 260ms narrative handoff. Exiting options register no new click targets.
- Contract terminal unfolds over 240ms. Signature pad starts after 250ms and unfolds over 200ms. Clip insets and opacity flicker follow frozen keyframes; clip is removed when complete. Scan lines are a NanoVG rendering approximation of the source gradient/glow and need visual acceptance.
- Name TextField is nested in a real overflow-hidden UI Panel. It shares the animated pad clip and opacity; field positioning is relative to that clip. Focus occurs once at source 700ms. Signature, terms, attachment and submit hit targets respect the visible clip.
- Employee benefit annotation uses source 1.25vh and ice .55 alpha, while normal value text remains 1.65vh. Contract fine addenda use 1.12vh, 1.7 line height, ice .55 alpha, and their source separator spacing/rule. Imported words are retained.
- Left top/bottom terminal corner text is hidden through contract, stamp and retained gate-exit layers. The right secure-link text remains.
- Continue arrow consumes Session `waitingAdvance`, which represents actual typing and voice completion. Session ownership and n17 subtitle correction belong to g5.

Read-only QA Snapshot fields added: `waitingAdvance`, `choiceExit={index,at,elapsed}`, `contractMotion={terminal,pad}`, `contractFieldVisible`, `contractFocused`. These introduce no per-frame logs. `choiceExit` can remain as a historical record after 320ms; visibility is determined by elapsed time.

## Verification

`tools/migration/verify-intro-contract-style.py`: 717 PASS, 64 actual draw cases. It executes the frozen JS `_unfold`, `_out` and `choose` methods; it exercises actual Lua Page.New, Contract, Comms, pointer and Backdrop paths with UI/NanoVG adapters and real SourceParagraph/SourceRichText. It also loads the actual TextField.Render and Theme.FontSize modules for placeholder and filled Unicode input, checking exact source CSS pixel size. Source timing/keyframes/easing, input hierarchy, clip/focus, rich words/style, actual choice exit/arrow calls and the immutable82 negative control are covered. Report: `evidence/intro-contract-current-style-offline.json`.

`tools/migration/verify-intro-promo-motion.py`: 6644 PASS, 316 actual Promo.Draw cases. Source-executed motto/salvage clocks, three aspect ratios, root opacity, disclaimer continuity and source motto layout are covered. New report: `evidence/intro-promo-motion-current-style-offline.json`; original pre-style evidence is preserved.

`tools/migration/check-intro-contract.py`: 53 PASS, actual pointer stroke and layout regression. Its generic `evidence/intro-contract-offline.json` was refreshed to the current Page hash.

After production freeze, six related checks were actually rerun against these hashes: comms portraits 384 PASS (36 frozen-source fit cases), portrait handoff 167 PASS, brand 20509 PASS, familiarization 21017 PASS, noncaption text 2009 PASS, sortie Promo.Draw 874 PASS / 153 cases. Their existing reports were refreshed; pre-refresh copies are also retained in `.tmp/g2-pre-style-evidence`. Portrait-handoff's download-failure log is an intentional failure fixture.

### e41 Screenshot Follow-Up

Read-only inspection of `intro-natural-web-1600x900-manifest-e41f909a-unified-{motto-text,disclaimer-text,choice-options,choice-exit,contract-settled,contract-tablet-4-3,contract-tablet-16-10,contract-phone-20-9}.png` found one concrete typography issue: name TextField inherited UI's points-to-pixels conversion, yielding source CSS size multiplied by 96/72 (at 1600x900, 31.2px instead of 23.4px). Only that control now converts through actual Theme.FontSize(1), without changing global font mode. Source SIGN scrim/border, two label square markers and the signature 1 CSS px dashed border were also added. These changes are post-e41; that package's images do not verify the corrected rendering.

The screenshots show the restored motto rules/centered fineprint and contract content fitting desktop, tablet 4:3/16:10 and phone 20:9 without pad-over-terms overlap. The e41 choice-exit image already has all options removed, so it is not evidence of the intermediate 240/280/320ms fade/translation. Source-to-source checks cover those clocks; future natural capture must record the intermediate state to prove its rendering.

Remaining small contract CSS differences include header/subtitle and submit tracking/font details and hover glow/translation. These are outside the approved narrow follow-up. No new wording omissions or motto overlap were observed in the inspected images.

After the post-e41 narrow fix, affected reports were actually rerun: signature 53, comms portraits 384, portrait handoff 167, gate 920 / 88 cases, mix transitions 358, current contract style 717 / 64 cases, all PASS. Production Page SHA below is the post-e41 version.

No GPU, build or packaging was run for this batch. CPU adapters do not prove font raster appearance, visual clipping in the shipped renderer, natural interaction, sound continuity or target-device acceptance. Next unified package needs natural acceptance.

The old `profile-intro-contract-offline.py` asserts identical drawing against a pre-style implementation; that premise intentionally no longer applies. Keep its historical report; do not present it as current style equivalence or rerun it as an acceptance requirement.

## Remaining Open

Source audio-amplitude mouth switching and amplitude-driven communication bars are still absent; current bars remain a synthetic animation. Full damped multilevel parallax/rotation remains partial. Coordinated root shakes/pulses around stamp, gate and wages are not fully represented. Comic leave background capture remains partial as above. These were not expanded in this batch.

Rendered equivalence of wages, comic, familiarization, montage, contract, motto and gate remains distinct from the source/code checks. This document does not upgrade 82a or current production to visual acceptance.

## Frozen Production SHA256

| File | SHA256 |
| --- | --- |
| scripts/ui/IntroPage.lua | 054af2a5bd0d02e637c3185a33febf3d17cd2a0b6d406c11817f9569504c6132 |
| scripts/ui/IntroPromo.lua | cf3a288a80f273557d7a23de85329ff6209de847e6aa40afb3cb34697cb7de33 |
| scripts/ui/IntroTerminalFx.lua | 9bc2c60d421c3ec7c6812588d9e0dec02354c336db2dd87ee1fab960899bc4d5 |
| scripts/ui/IntroContractMotion.lua | f4068d612cb5d0611db4c31195aae119f5025b7467f1a8d0de8947920fe856b6 |
| scripts/ui/IntroContractText.lua | 566dc8b818d9457ef9b18ef577b49ade052ad4c6714fa422cc3fae083fc3e70e |
| scripts/ui/IntroMotto.lua | df2ab887ecbce59472e5f856bd6e477c230588e009001fac56d836b337ffc851 |
