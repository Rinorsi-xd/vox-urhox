# Opening report refresh before the next package

`audit-report-freshness.cjs` reads the report registry from the unified auditor and checks registered hashes against current workspace files without altering the retained package audit. The initial result `evidence/intro-next-report-freshness-initial.json` found 16 stale associations across 13 reports after the frozen 3ba run.

Before actual reruns, the original 13 JSON reports, initial freshness result and old `unified-snapshot-manifest-3ba43bd8-audit.json` were copied to `evidence/history-next-opening-runtime-pre-refresh/`. The existing natural-run functionality/continuity reports and logs were not modified.

All 13 checks were actually rerun with the bundled Python runtime:

| Check | Assertions/result |
|---|---:|
| combat-result-production | 13005 PASS |
| story-input-progress | 296 PASS |
| match-actions | 103 PASS |
| part-hit-flash | 850 PASS |
| endless-spawn-lifetime | 22 PASS, plus 497 setup checks |
| trial-event-boundary | 24 PASS |
| ui-sounds | 200 PASS |
| build-sounds | 124 PASS |
| comms-portraits | 384 PASS, plus 36 source-fit cases |
| intro-portrait-handoff | 167 PASS |
| intro-sortie-feedback | 28 PASS |
| intro-timing | 3953 PASS |
| game-audio-context | 851 PASS |

`check-intro-runtime.py` was also actually rerun: 421 PASS. The GC caller change then added two actual App assertions and was rerun by its owner: 423 PASS. This executes the actual owned opening-retirement queue, completed and interrupted opening paths, FIFO work while a replacement match owns the app, idempotent disposal, synchronous Stop draining, incremental opening cache retirement that skips a synchronous Flush, ordinary retirement that retains Flush, and the existing source-backed sortie contracts. It does not claim coverage of an OpeningCinematic or BeginFrame module or physics-frequency redesign; those are not implemented by this increment.

The unified auditor now registers `intro-contract-cost` and `render-target-retirement` as current batch reports. The former retains its actual 84-case draw/geometry/cache comparison; the latter's owner actually ran 829 Lua finalizer assertions, including the old full-collection control, background stepping, retained explicit Flush and conservative generational-mode waiting.

After the final HangarApp caller freeze (`b0c484e3281a886dbaf5d569eae06d18924ff1a9a81f187321836f88314e5863`), five associations became stale again. Their intermediate JSON files and the five-drift freshness report were saved under `evidence/history-next-opening-runtime-pre-gc-caller/`. Combat-result-production 13005, match-actions 103, ui-sounds 200, build-sounds 124 and game-audio-context 851 were then actually rerun again and passed. Final `evidence/intro-next-report-freshness.json` is FRESH with zero drift across all registered reports.

The next package still requires an actual emitted-payload audit. A fresh hash association does not rerun behavior, establish natural Web continuity, or prove GPU/native safety. No GPU run was made for this report refresh.

## Frozen 5f39 package audit

The subsequent independent emitted-payload audit is PASS: `evidence/unified-snapshot-manifest-5f39f096-audit.json`. Snapshot `.tmp/outgame-cached-1792099539845`, manifest `manifest-5f39f096.json`, script fingerprint `48c659df9cc9568bc56e5c9db0bc6b225d038dde98a27357fd18dd43c4563643`.

- All 502 Lua files match workspace, frozen snapshot, identity and actual emitted payload; no missing, unexpected or wrong-size Lua entries. The manifest has 7500 entries.
- All 45 audited resources, 11 font/license/provenance files, 12 mission voices, seven UI sounds and seven radio sounds match their emitted payloads.
- All 65 registered reports pass their retained status and hash associations: 344 associations comprise 342 packaged production inputs and two explicitly identified workspace evidence-tool inputs. Drift is zero; current 13-report batch and historical regressions both pass.

This auditor run did not modify production, launch a browser/GPU or rerun behavioral tests. The actual CPU regression reruns are recorded above; root owns the separate natural Web run of this same frozen package.

## Next contract/gate/exit batch

The subsequent UI and 700 ms exit work is a different production state from 5f. Its source schedules and drawing limits are recorded in `INTRO_GATE_OVERLAYS_2026_10_16.md`. The unified registry now includes `intro-gate`, `intro-finish`, `intro-promo-motion` and `intro-audio-tail` as current reports. Gate drawing has 920 checks, including 88 Page cases and 56 Promo cases; finish and Promo/audio owners maintain their separate actual lifecycle/motion reports. The final root alpha uses wall elapsed rather than clamped simulation dt.

Before refreshing associated UI reports, the then-current JSON files were copied to `evidence/history-next-opening-pre-gate/`. The final audio-tail handoff changed Session/HangarApp/IntroAudio/Host associations; intermediate reports and the stale freshness result were copied to `evidence/history-next-opening-pre-audio-tail/`. Neither directory re-attests a historical package against newer workspace code.

Actual reruns after those changes passed: combat-result-production 13005, match-actions 103, ui-sounds 200, build-sounds 124, opening-construction 328, opening-prefetch 153, game-audio-context 851, contract 53, comms portraits 384 plus 36 source-fit cases, portrait handoff 167, brand 20509, familiar 21017, noncaption text 2009, contract-cost 84, sortie feedback 28, timing 3953, gate 920 and audio-meter 27. After the wall-clock alpha update, both Promo checks were actually rerun as well: 874 and 5942 checks / 316 motion draw cases. Node syntax checks passed for the new frozen-source gate fixture and unified auditor.

After the audio owner's final wall-time fix, `check-intro-finish.py` was actually rerun again: 53 PASS against final Session, IntroAudio and IntroAudioTail. The audio owner separately refreshed the actual tail fixture (402 PASS) and envelope fixture (1529 PASS).

The final candidate QA-tool revision is independently recorded by `intro-qa-tools-offline.json`: 30 PASS, comprising actual AudioMeter 27 assertions, Node syntax for the current natural Web test and unified auditor, and Lua 5.4 compile-only syntax for the current probe. Its five inputs are classified as workspace evidence tools by the unified auditor. The old 5f natural-run tool hashes remain historical; this fixture does not claim a new browser run.

Final `intro-next-report-freshness.json` is FRESH with zero drift across 70 reports and 385 associations; the current opening registry has 18 reports. This is still a workspace evidence check. A new snapshot needs its own emitted-payload audit and natural Web acceptance; no old package audit was overwritten or rerun against the new code. The 5f stamp Page.Render peak near 303 ms remains unresolved by these offline results.

## Frozen e9f2 candidate audit

The next independent emitted-payload audit is PASS: `evidence/unified-snapshot-manifest-e9f25319-audit.json`, SHA256 `64dd716ee3ee95142af8f4bfab805887b974e64328ef8fdc106d7d523c4483ca`. Snapshot `.tmp/outgame-cached-1792100831658`, manifest `manifest-e9f25319.json`, script fingerprint `7708b46bc4fa2b0c80ad13f79d472e06ebd71bb124bdfdd9ad65eb5abfdd3eb6`.

- All 507 Lua files match workspace, immutable snapshot, identity and actual emitted payload; all have blocking manifest entries. Manifest count is 7505.
- All 45 audited resources, 11 font/license/provenance files, 12 mission voices, seven UI sounds and seven radio sounds match their actual emitted payloads.
- All 70 reports pass, including 18 current opening reports. Their 385 associations comprise 376 packaged production inputs and nine workspace evidence-tool inputs. Drift is zero; both current and historical scopes pass.

This audit did not modify production or start a browser/GPU. It does not establish playback, render appearance, natural Web continuity or mobile acceptance. Root owns the separate natural run of this exact candidate; historical 5f package evidence was retained unchanged.

## Next audio mix transition batch

This is a new production state after e9f25319, not a re-attestation of that package. The audio owner confirmed the final freeze: IntroAudio `e7482426babe20b6e09612b49b5f6deb282df2096e9eb805ab1ffdf7a3f2e9d0`, IntroAudioTail `f86b7ddd5325372fde607f11a52ae98397559d4a3bebcd6e2aca77f7c264d9b7`, IntroSession `9869f1c2b8f2de682f1d2648ba0ec7e5f81a38931b0f12104f2553d708996149`, IntroPage `4135bef813f2d3f9f57ac4307ed7854dd389c328b947842d7a52a05913a2b2f0`. See `INTRO_MIX_TRANSITIONS_2026_10_16.md` for behavior and source boundaries.

The registry adds `intro-mix-transitions` as the nineteenth current opening report. Its actual 358-check report is `evidence/intro-mix-transitions-offline.json`, SHA256 `c0c7c0ada848b40b17cf322f1bbd0d07ce2f4cf7c8e0b5c3615def8f5fc0d4d9`. The audio owner actually reran envelope 1529, tail 402, finish 53, runtime 423, contract 53 and timing 3953 against the final production bytes.

The first new freshness run found seven stale associations in six reports. Before refreshing those reports, their exact JSON bytes and the STALE result were retained under `evidence/history-next-opening-pre-mix-refresh/`. The following tools were then actually executed, rather than updating only hashes:

| Tool | Actual result |
|---|---|
| `check-opening-prefetch.py` | 153 PASS |
| `check-comms-portraits.py` | 384 PASS plus 36 source-fit cases |
| `check-intro-portrait-handoff.py` | 167 PASS |
| `profile-intro-contract-offline.py` | 84 PASS |
| `check-intro-gate-offline.py` | 920 PASS, 88 Page cases |
| `check-intro-qa-tools.py` (audio owner) | 30 PASS |

All Python commands used the bundled runtime with `-B`. The QA fixture was rerun after the registry edit and binds auditor SHA256 `d2bebd6d3f1651aa5848ba5082235adf0fae3cce7589276c84907752dc847aeb`; QA report SHA256 is `fcb1b85badf051ee4cb21e6afe4fd6d363a52861ed3a5bfac1d0b0cb35bb38b8`.

Command `node tools/migration/audit-report-freshness.cjs docs/migration/evidence/intro-next-mix-report-freshness.json` now returns FRESH: 71 reports, 390 associations, zero drift, all retained statuses PASS/PASSED. Result SHA256 is `fb4081d4d205946fadb22bcede9d67e77c3a8445efe9401fca2e720477945032`.

Historical boundary: the audio owner's seven current JSON reports were already regenerated before this refresh and were not separately archived by that owner. The e9 immutable snapshot contains scripts/assets/config but no report JSON directory. This refresh therefore does not claim to recover those original e9 report bytes; the unchanged e9 audit retains its original report hashes and package evidence. Its own SHA256 remains `64dd716ee3ee95142af8f4bfab805887b974e64328ef8fdc106d7d523c4483ca`.

No production, GPU/browser/native run, old package audit or old natural evidence was changed by this refresh. A new immutable snapshot still needs its own actual emitted-payload audit and natural-run acceptance. Freshness and offline envelope checks do not establish audible continuity.

### Optional exit-profiler QA revision

Root subsequently changed only `check-intro-natural-web.cjs` to support optional `VOX_INTRO_EXIT_PROFILE=1`: a short CDP CPU profile around contract-to-exit, with a saved profile, performance-clock interval and diagnostic overhead. After that edit, `check-intro-qa-tools.py` was actually rerun: 30 PASS. The preceding QA and freshness JSON bytes are retained under `evidence/history-next-opening-pre-exit-profile-tools/`.

The updated tool SHA256 is `799d4de3e450d5d4dcfd4b52eb68926fea5abe5b3d1a34742623d7053d55e1dd`; QA report SHA256 is `7e1d138072de659874127cf2fb9ec65fdb0baabde272b906d4f504be552e5f58`. The final freshness command was actually rerun and remains FRESH, 71 reports / 390 associations / zero drift, now SHA256 `05c0298cfa765a13b971d46c6dd1bdee8c395fd96c0e0eb9604e9b6103359f83`. These replace the immediately preceding workspace evidence hashes for the next candidate, without rewriting the retained historical files. Production is unchanged; syntax/fixture checks do not execute CDP profiling or establish its runtime overhead.

## Frozen 9b1a candidate audit

Snapshot `.tmp/outgame-cached-1792101454346`, manifest `manifest-9b1ad62f.json`, script fingerprint `975ff5f1fca165835a678a651b15630394e6aa5af20f8e32c14d36288c492d22`.

The independent actual emitted-payload audit first passed before the probe timing amendment. That exact PASS audit (SHA256 `e325eb2a70db0be3b9862539910cb716e63d959352001581836f7c8798b72820`), then-current QA report and freshness result were retained under `evidence/history-manifest-9b1ad62f-pre-refresh/`. The final production snapshot was not modified.

The probe owner then froze `probe-outgame-web.lua` at SHA256 `7511c2ae60446c6734a638e3b2bdc671d987b1d63dc04a535d9a212d74924681`: loaded-module-only timing wrappers observe App.Update, ResourceGate.UpdatePending, MusicPlayer.Next/PreparePending and OpeningRetirement.Step, accumulating wall intervals and logging calls of at least 100ms. The owner reported actual helper checks for idempotence, thresholds, accumulated/max/wall values, nil returns and collection of self. These instrumented timings include probe overhead and are not an uninstrumented baseline.

After that final probe handoff, `check-intro-qa-tools.py` was actually rerun: 30 PASS; QA report SHA256 `401223dc1dfcecdcff1edcd4dc2ebeca477c63b170f3375c9c0fdf8bed6accba`. Freshness was actually rerun: FRESH, 71 reports, 390 associations, zero drift; result SHA256 `24ffd911ee7b7f5617784f696a2dfe1fa9876a6ab53749cadf7f0c6a2b711b0d`.

The unified audit was then actually rerun on this same immutable candidate and passed: `evidence/unified-snapshot-manifest-9b1ad62f-audit.json`, SHA256 `6364aa2bb095eb37bac72e1e94b6ae621195caa5c0c7246102d6fe0254a6ec1c`.

- All 507 Lua files match workspace, snapshot, identity and actual emitted payload; every Lua entry is blocking. Manifest count is 7505.
- All 45 audited resources, 11 font/license/provenance entries, 12 mission voices, seven UI sounds and seven radio sounds match their actual emitted bytes.
- All 71 reports pass, including 19 current opening reports. Their 390 associations comprise 381 packaged production inputs and nine workspace evidence-tool inputs, with zero drift. Both current and historical scopes pass. The final QA report's five tools all pass as evidence-tool associations, not package payloads.

This audit does not run a GPU/browser/native session, execute the profiler, or establish visual, audible, continuity or mobile acceptance. Root owns the natural run of this exact immutable candidate. Historical 5f/e9 audits and natural evidence remain unchanged.
