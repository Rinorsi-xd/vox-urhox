# Opening request timing

Baseline remains `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
Both runs use immutable `.tmp/outgame-cached-1792108710605`, manifest
`d01102e0`, script fingerprint
`87ecf48a00cf2c524965e5912e6add987151322bb61df29e63f1d132c0b42ce9`.
No production download or prepare parameter was changed.

## Completed observations

| Run | Boot to ready | Matched project request window | No matched request in flight |
| --- | ---: | ---: | ---: |
| `boot-network-default`, QA4397 | 90.367 s | 42.269 s | 22.153 s |
| `boot-network-c8`, QA4398 | 89.616 s | 41.597 s | 21.463 s |

Both scoped boot checks PASS/CLOSED, game/HTTP errors zero. These are not
full playback or continuity results. Evidence prefixes:
`evidence/intro-natural-web-1600x900-manifest-d01102e0-boot-network-default`
and `evidence/intro-natural-web-1600x900-manifest-d01102e0-boot-network-c8`.

The profile binding actually logged `before:8, after:8`. Therefore the second
run did not change concurrency. The binding documentation's default of five
does not describe this runtime. The 0.751 s wall difference is not an
optimization result. No concurrency change is selected for production.

The request observer records start/body-finished timings and ResourceTiming,
without reading response bodies or changing cache/scheduling. The summarizer
uses browser timing fields, not delayed Playwright event delivery. Example:
`Crater/texture-2.png`, 21,561,575 bytes, default-run body span 5,004.887 ms,
observer delivery another 3,668.565 ms later. This event gap does not establish
which caller, worker or native queue blocked it.

The occupancy calculation includes only matched project requests that started
after the first sampled boot state, between the first such request and last
body completion. It excludes other origins, earlier requests and all native
cache/queue/worker work. No observed project request does not mean the process
was idle. The two runs contain different early/late request subsets; summed
manifest bytes are not a controlled bandwidth comparison. This is localhost
raw-fixture evidence, not Maker CDN or mobile performance.

Reproduce the calculation:

```powershell
node tools/migration/summarize-intro-downloads.cjs docs/migration/evidence/intro-natural-web-1600x900-manifest-d01102e0-boot-network-default.json
```

## Selected construction work

Both runs retain about 10.4 s sliced preparation but still expose a 328-331 ms
`intro-montage-view` slice and a 237-242 ms `intro-actors` slice. Actual
`CarUnit.New` already supports checkpoint and retained-owner callbacks, but
these two opening construction callers omit them. The current parallel batch
is connecting the existing callbacks and checking cancellation ownership.
This is a candidate until measured in a new package. It does not promise to
remove the 42 s raw gate or 29 s shader warmup.

The arm-vector physics cache was rejected after native numerical equivalence
passed but nine paired timing observations showed no stable benefit. The
existing strict-zero optimization is retained. Subsequent suspension/raycast
allocation candidates have separate evidence and must not borrow this run.
