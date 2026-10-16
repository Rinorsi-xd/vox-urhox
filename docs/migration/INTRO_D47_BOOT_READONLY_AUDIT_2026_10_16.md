# d47 opening boot audit

Read-only investigation, 2026-10-16. This note preserves the existing d47
loading evidence; it does not select or implement an optimization. No production,
asset, test, build, browser, GPU, service or upload change belongs to this audit.

## Evidence identity and boundary

- Frozen H5: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Package: `.tmp/outgame-cached-1792107779538/dist/1.0.0/manifest-d47ba6e2.json`;
  script fingerprint `b483380e943d26d69a4a0ebfc5105cf7a92ea2f1a3d7736157a8376066e57318`.
- [Natural-run report](evidence/intro-natural-web-1600x900-manifest-d47ba6e2-functional-audio.json):
  functionality PASS, continuity FAIL, shutdown CLOSED. These are historical
  results, not acceptance of a later package.
- [Raw log](evidence/intro-natural-web-1600x900-manifest-d47ba6e2-functional-audio.log),
  SHA256 `8e6c78a3a6db2b6a89151a41c8fd0a94be068c396490e46db3f50efa082d9918`.
  Log timestamps below use local UTC+8; report `samples[].at` uses UTC epoch ms.
- Windows Web/GLES, 1600x900 physical viewport, mobile quality. Public F8 method
  timing, RAF/audio sampling and screenshots were enabled. This is not an
  uninstrumented performance baseline, real mobile measurement or Maker CDN test.
  The fixture uses cached source packages and raw local preview files.

## Observed critical path

Report sample 0 is `23:45:59.809Z`, `openingLoad.wallMs=1106597377`.
Sample 135 is the first observed completed warmup, `23:47:32.405Z`,
`wallMs=1106689971`: **92.594 s**, while the clamped narrative `age` is only
39.078 s. Sample 136 has already advanced to CRT. This interval starts after
browser/bootstrap/hangar work and is not navigation-to-ready time.

| Segment | Existing measurement | Interpretation |
| --- | --- | --- |
| Raw map/actor gate | 528 missing resources, 180,518,811 bytes; native completion at log line 1221, `07:46:44.488` | 44.679 s after sample 0; native completion-chain wall time, not proven pure network time |
| First sampled raw-ready state | Sample 57, `23:46:45.927Z`, 46.118 s after sample 0 | Already in array preparation (`resources=1.427 s`); do not add 46.118 to all following stages |
| Media gate | 70 resources, 63,149,747 bytes; completion line 1156, `07:46:12.263` | Already parallel with raw map/actor bytes; all media/images/audio ready by sample 57 |
| Texture arrays | Final loader `phaseTimes.resources=1.483 s` | Native array preparation, distinct from raw download |
| Native scene | `phaseTimes.scene=6.088 s` | XML/resources already downloaded; includes native scene work |
| Sliced world/actor prepare | `phaseTimes.prepare=10.491 s`, 459 resumes, 4,257 ms inclusive measured prepare work | Remaining wall time includes frame scheduling; not all 10.491 s is removable CPU |
| Worst prepare slice | 329 ms, `intro-montage-view` | 3 ms checkpoint target does not bound indivisible calls; `intro-actors` reaches 246 ms |
| Activation | `phaseTimes.activate=0.013 s`; loader download bookkeeping 0.011 s | Small adjacent stages |
| Render warmup | Lines 1412-2173, `07:47:02.575` to `07:47:32.308`: **29.733 s**, 431 frames / 404 batches | Shader/driver/submission work after construction; not Lua prepare CPU |

Loader phase times and sampled gate states use different boundaries. They are
not mutually exclusive stopwatch spans; do not force their sum to 92.594 s.
Nonzero progressing gate byte fields identify the modern completion callback
branch of [ResourceGate](../../scripts/app/ResourceGate.lua), not its legacy
eight-path polling loop. The log has no individual response-body completion
timestamps, so transfer, cache writes, worker scheduling and callback delay
cannot be separated from this record alone.

## Shader finding

The `brief` warmup marker at log line 1484 (`07:47:06.516`) to `drive` at line
1932 (`07:47:22.975`) spans **16.459 s**. Between those markers are **181**
successful compiler records, **181 unique exact shader-path + defines keys**,
and **zero repeated exact keys**. First success: line 1487, `07:47:06.556`;
last success: line 1930, `07:47:21.747`, a **15.191 s** completion span.

This supports first-use shader variants as a substantial contributor. It does
not measure individual compile CPU/GPU duration or prove every draw necessary.
It does not justify deleting brief coverage or grouping warmup by material alone.
Keep the seven authored phases, additional idyll-start sample, batch 8, copies
4/1, model/layout/material/light/shadow identity keys and array `warmWait=3`.
The existing [e41 audit](INTRO_E41_BOOT_CRITICAL_PATH_2026_10_16.md) independently
found 181 brief identities; that older run is corroboration, not d47 timing.

## Resource scope

Frozen package [OpeningHost.Dependencies](../../scripts/app/OpeningHost.lua)
uses the crater resource list plus the actual player and authored actor parts,
weapon icons, audio and explicit effects. [parts.Dependencies](../../scripts/parts/Dependencies.lua)
selects paths for those parts, including a selected rotor's three alternatives;
it does not walk every catalog part's geometry.

The 12 authored hero/cart/invader/hover blueprints contain **30 distinct part
types**, versus **331 catalog entries**. The current player blueprint may add
types, and catalog metadata loading is distinct from loading every model. Thus
this is not evidence of the complete parts geometry library being prefetched.

Frozen `Crater/Resources.json` has 540 entries: 539 local files totaling
**170,971,943 bytes = 170.972 MB = 163.052 MiB**, plus shared `Models/Box.mdl`.
Local roots are only `Crater` (167,875,289 bytes), `Scenes` (3,036,751 bytes,
the crater XML) and `Shaders` (59,903 bytes). No second map's resource list was
found in this dependency route. A large raw group alone does not establish a
mixed-map or full-parts-library bug. The 528 gate count is missing downloaded
resources after deduplication/cache filtering, not the total dependency count.

## Two deferred A/B candidates

Both are proposals only. No parameter was changed or speedup measured.

| Candidate | One-variable change | Required evidence and limitation |
| --- | --- | --- |
| A, first choice | OpeningHost's loader only: `prepareBudgetMs` 3 to 5 ms; retain default 3 elsewhere | 459 resumes / 10.491 s with 4.257 s measured work suggests scheduling overhead worth testing. Compare wall time and worst frame/slice; the 329 ms indivisible montage call remains and may dominate responsiveness. |
| B, lower confidence | Add an opening-only option for `pending.asyncLoadingMs` 3 to 5 ms; retain default 3 elsewhere | Scene phase is 6.088 s, but no isolated native CPU attribution exists. Fewer cross-frame parser slices may help or may worsen long stalls/resource decoding. |

The settings live in [SceneLoader](../../scripts/app/SceneLoader.lua), with
OpeningHost owning the opt-in. Use separate packages, identical assets/backend/
cache state, exclusive GPU runs, repeated paired observations, and compare stage
wall times, loading-page responsiveness, maximum frame gap, memory peak and the
same natural opening continuity/visual checks. A shorter load alone is not
acceptance. Do not simultaneously alter warmup samples, batch size, quality,
collision content, actor content or the texture-array staging policy.

Media/raw parallel start is already implemented by IntroSession and
OpeningHost.Prefetch; it is not a new candidate. Download concurrency, Web
shader cache/precache support and HTTP compression need separate backend and
request-level evidence before selecting changes. Local results cannot establish
real-device performance.

## d011 current-run difference, 08:08:45 local

[d011 final-route report](evidence/intro-natural-web-1600x900-manifest-d01102e0-final-route.json)
is complete: 66 functional checks, functionality PASS, continuity FAIL, zero
runtime/HTTP errors, CLOSED/pageClosed. It reaches contract, stamp, gate,
700 ms fade and hall restoration. This is separate from the passing tutorial
drive route. Audio delivery has 10 gap candidates (1 countdown, 8 sortie-play,
1 hall-return), maximum 590.100 ms; hall-return RAF gap is 550.425 ms. Maximum
measured mixer call is only 1.235 ms; this does not identify the blocking caller.

The [d011 log](evidence/intro-natural-web-1600x900-manifest-d01102e0-final-route.log)
has SHA256 `cb0ebcf39ee2516d5c0ed3e14f2f803d7b43f2dd5d09088ad32753f298b21a3e`.
Its package is `.tmp/outgame-cached-1792108710605`, fingerprint
`87ecf48a00cf2c524965e5912e6add987151322bb61df29e63f1d132c0b42ce9`.
OpeningHost, SceneLoader and IntroWarmup are byte-identical to d47 and current
workspace files, so the two deferred candidates remain applicable.

| d011 measurement | Value |
| --- | ---: |
| First boot to first completed warmup sample, wall counters 1107682949 to 1107773002 | 90.053 s |
| Raw 528-resource native completion, line 1223 `08:04:47.838`, after first boot `08:04:05.382` | 42.456 s |
| Arrays / scene / prepare | 1.515 / 6.056 / 10.457 s |
| Prepare measured work / resumes / maximum slice | 4.243 s / 457 / 327 ms |
| Warmup, lines 1412-2175 | 29.135 s / 424 frames / 397 batches |
| Brief, lines 1485-1934 | 16.134 s / 181 compile successes / 181 unique keys / 0 duplicate keys |

Next smallest executable experiment: after creating OpeningHost's private
loader, set only `state.loader.prepareBudgetMs=5`; keep its shared default and
all other parameters unchanged. It can shorten the 90-second total only by
reducing checkpoint yield/frame waits inside the 10.457-second prepare phase.
The measured wall-minus-work remainder is 6.214 s, an optimistic accounting
space rather than a predicted saving; some waits may remain and larger slices
may hurt responsiveness. There is no demonstrated positive saving yet, and
this one-line candidate cannot remove the roughly 90-second load.

No verified fix currently covers the 42.456-second raw gate or 29.135-second
warmup. Raw request/body/cache/backend attribution is missing; brief still
compiles 181 distinct identities, and usable Web shader-cache/async compilation
support is unproven. The 6.056-second native scene phase lacks isolated parse
CPU attribution. Increasing its budget remains lower-confidence candidate B.
The 327 ms montage and 244 ms actor slices require finer caller attribution
before a content-preserving split can be selected. Playback/hall-return gaps
are separate from boot and will not be repaired by a boot-only budget change.
