# c787bbd6 independent package audit

## Scoped result: PASS

This is frozen-content, emitted-payload and report-freshness acceptance only. It does not close G0-G6 or supersede earlier runtime failures. Production remained frozen throughout the audit.

| Identity | Value |
|---|---|
| H5 | `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455` |
| Target HEAD | `9541dc59ef2f281cafa5126762a57550189e04dc` plus frozen working-tree increments |
| Snapshot | `.tmp/outgame-cached-1792089992674` |
| Manifest | `manifest-c787bbd6.json` |
| Script fingerprint | `ca51f664b2b5e9d4a67748fa800f9fb98ca739a7d8d1e0c12b2d37b41ce36d57` |
| Comparison | `.tmp/outgame-cached-1792089242755 / manifest-e31a194a.json` |

## Performed checks

- **486/486 Lua** agree between current source, frozen tree, identity and the actual emitted UUID/hash asset bytes. No unexpected manifest Lua; every Lua is blocking. Manifest total: 7,484 entries.
- **43 PASS/PASSED reports, 216 production/resource SHA256 references, zero drift**. Reports are checked against current and frozen files. This audit does not claim to rerun their behavior suites.
- **27 resources**, **11 font/license/provenance rows**, **12 result OGG**, **7 UI WAV** and **7 radio WAV** match their actual emitted payloads. OGG derived/source hashes and UI/radio original H5 WAV hashes match their registries. Headers are OggS or RIFF/WAVE as appropriate. These groups overlap where resources are also referenced in report hashes; their counts must not be summed as unique assets.
- Actual `audio/StoryComms.lua` payload is the final asynchronous-decoding version, SHA `566c1ae47d87d60060b38f323fa6167ae047e19eb3766ac640f66b097a410525`, not the earlier intermediate `57d05...` version.
- New project button base is the guarded version, SHA `c1562738a9cd8ba70a2e36f26e5a81fee4c5bfdaa7282e8214a991c864509dc0`. The action-button report covers all 22 changed production modules plus this base.
- MatchTarget module presence and actual controller/objective/driver wiring remain intact.

Machine evidence: `evidence/unified-snapshot-manifest-c787bbd6-audit.json`.

## Full delta from e31

All files under both frozen `scripts/` and `assets/` trees were read and SHA256-compared, including metadata and additions/removals: 14,993 before, 15,007 after.

| Category | Count |
|---|---:|
| Non-meta content changes | 43 |
| Lua content changes | 37 |
| Asset content changes | 6 |
| New content files | 7 |
| Removed content files | 0 |
| Script meta changes | 33 |
| Asset meta changes | 1,427 |
| Total meta changes | 1,460 |
| Normalized manifest row changes | 43 |

The 37 Lua changes comprise 22 project button-base substitutions, new ActionButton and StoryCommsCues modules, StoryComms/UiSound, BuildSession/HangarApp/BuildEditor/BuildStretch/LiverySession/BlueprintLibrary/InventoryPanel/LiveryPage sound integration, Tutorial cue preload, and AimLines/CombatWarmup actual geometry prewarm. The six asset changes are the expanded UI sound registry and five original WAV additions: open, paint, place, remove and stamp. The two original press/confirm WAV files did not change. No shader or font authored content changed in this comparison.

Manifest comparison excludes UUID/hash and resolves references to resource paths. Its 43 changed rows match the complete content delta. Metadata changes are recorded separately; the whole package is not byte-identical to e31.

Full hashes and metadata lists: `evidence/snapshot-manifest-c787bbd6-delta.json`.

## Boundaries and remaining work

- The e31 right-click navigation failure remains historical FAIL. Only a new public Web regression against c787 can verify its runtime resolution; offline 1,299 button checks and package identity are separate evidence.
- Original WAV bytes and tested event calls do not establish audible gain, decoder compatibility or voice continuity during page transitions.
- Background decode adapters and prewarm geometry lifecycle checks do not establish native/Web shader timing, absence of freezing or mobile performance. Existing loading/combat performance FAIL remains open.
- Full natural opening/tutorial/five-level/Boss/ending, endless death/revival, extraction, real-account/editor and 20:9 device acceptance remain outside this audit. Root owns new runtime results.
- No production edit, build, GPU/browser/native run, commit, upload or publication occurred in this independent audit.

## One Concrete Next Function

**Focused button Enter/Space activation and shortcut priority are still missing.** This is a read-only finding, not part of c787 production changes.

Frozen H5 `shared/ui/home.js:227` explicitly preserves native Enter/NumpadEnter/Space behavior when the hangar event target is a button or summary, and stops propagation so Shell's Enter-to-edit shortcut cannot intercept it. The `[data-cta]` actions use native `click` at line 249.

Target `ui/ActionButton.lua` and native Button do not define `OnKeyDown`/`OnKeyUp`. `ui/GarageHud.lua:207` only classifies `OnTextInput` focus as typing; line 217 routes non-typing Enter to `EnterBuild` outside the battle tab. Space has no focused-button activation path. Thus a focused ordinary action button has no native-equivalent Enter/Space handler, and Enter can take the global edit route. This is statically confirmed; no new GPU reproduction was run.

Suggested next implementation ownership: project ActionButton handles native-style Enter/Space activation and disabled/repeat/release rules; GarageHud gives that focused activation priority while preserving no-focus E/F/T/Enter shortcuts. Verify against frozen H5 focused deploy/settings/new-car actions, disabled controls, release outside, text fields and modal ownership before public Web acceptance.
