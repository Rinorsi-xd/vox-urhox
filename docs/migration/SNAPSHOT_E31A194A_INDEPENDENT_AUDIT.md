# e31a194a independent package audit

## Scoped result: PASS

This audit verifies frozen content, actual emitted resource payloads and report freshness. It does not close G0-G6 or establish visual, gameplay, audible or performance acceptance. Existing stage progress is retained.

| Identity | Frozen value |
|---|---|
| H5 source | `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455` |
| Target HEAD | `9541dc59ef2f281cafa5126762a57550189e04dc` plus frozen working-tree increments |
| Snapshot | `.tmp/outgame-cached-1792089242755` |
| Manifest | `manifest-e31a194a.json` |
| Script fingerprint | `72a18e389300951f4bc6019146d512d49a94bb3ccb21846bd4593ea82f5a06d6` |
| Comparison | `.tmp/outgame-cached-1792088233891 / manifest-046debe2.json` |

## Checks actually performed

- All 484 current Lua files match the frozen tree, identity hashes and actual emitted UUID/hash payloads. The manifest contains exactly 484 Lua entries, all in blocking preload, with no unexpected script. Total manifest entries: 7,477.
- All 40 behavior reports have PASS/PASSED status and all 161 production/resource SHA256 references match current and frozen files. Freshness checking does not rerun their behavior suites.
- Actual emitted payloads match all 14 audited configurations/shaders/resources, all 9 project TTF/OTF files plus repair-symbol license/provenance (11 font-related rows), all 12 result OGG files and both original UI WAV files.
- The 12 result OGG payloads match their derived hashes; original MP3 hashes match the frozen H5 and registry. The UI WAV payloads match the original H5 files byte for byte: `press_a.wav` 5,804 bytes and `confirm_b.wav` 52,466 bytes. OggS/RIFF-WAVE headers are checked. This does not establish decoder compatibility, playback, volume or continuity.
- MatchTarget module presence, BattleController delegation and objective/driver consumption remain present in the frozen Lua.
- New reports included since 046: `aim-lines-render`, `story-choice-epilogue`, `leg-target-scalar`, `ui-sounds`. Referenced resource payloads are collected dynamically so new shader/audio/configuration files receive actual emitted-byte checks.

Evidence: `evidence/unified-snapshot-manifest-e31a194a-audit.json`.

## Full delta from 046

Every file under both frozen `scripts/` and `assets/` trees was read and SHA256-compared, including metadata and additions/removals: 14,985 before and 14,993 after. There are 13 non-meta content changes, consisting of 9 script changes and 4 asset changes. Four content files are new; none were removed.

| Content | Scope |
|---|---|
| `scripts/drive/LegControl.lua` | Scalar target calculation; preserve operation grouping and return ownership while removing intermediate tables |
| `scripts/render/AimLines.lua`, `AimLinesRules.lua` | Source aim-line geometry/color/render contracts |
| `assets/Shaders/BLGL/Combat/Glow.shader` | Aim-line depth/render contract; actual shader payload audited |
| `scripts/story/Mission.lua`, `MissionRules.lua` | Source choice/epilogue progress and watched-state handling |
| `scripts/audio/UiSound.lua` (new) | Original UI press/confirm sound behavior |
| `scripts/app/HangarApp.lua`, `story/Tutorial.lua`, `ui/TutorialPage.lua` | Actual UI/tutorial sound call sites |
| `assets/UI/Sounds.json` (new) | Frozen source provenance, cue volume/gap and resource registry |
| `assets/Sounds/UI/press_a.wav`, `confirm_b.wav` (new) | Original H5 WAV bytes |

Metadata changes are separate: 32 script and 1,425 asset meta files, total 1,457. Manifest comparison drops UUID/hash fields and normalizes references to resource paths; exactly 13 rows change, matching all content changes, including the four additions. There are no other authored-content changes in this comparison.

Full before/after hashes, metadata and normalized manifest rows: `evidence/snapshot-manifest-e31a194a-delta.json`.

## Acceptance still open

- Aim-line shader presence and source render contracts do not prove rendered depth/occlusion, visual appearance or native/Web shader compilation.
- Choice/epilogue reports do not establish a natural end-to-end mission or the full opening/tutorial/five-level/Boss/ending flow.
- UI sound reports and original bytes do not establish audible playback or the user's reported voice continuity during UI transitions.
- Scalar target tests and isolated controller timings do not establish native Bullet feel, whole-game FPS, mobile heat or sustained frame pacing. Rejected caches were not installed in production.
- This package audit cannot supersede the existing loading/combat performance FAIL. New runtime performance evidence is owned by the root agent and must identify this snapshot explicitly.
- No browser/GPU/native playtest, real account, editor operation, 20:9 device or sustained mobile performance acceptance was performed here.
- This independent subtask made no production edit, build, commit, push, upload or publication. It changed only audit tooling, evidence and this document.
