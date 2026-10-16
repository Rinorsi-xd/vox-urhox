# Native monitor overhead verification, 2026-10-16

Runtime: Windows Native 0.9.0-beta.40_20261015.121839.6dc5c357cced.
Six actual production T3 assault/heavy/sniper vehicles, actual Bullet flat
floor, seed 25149307, 180 warm-up steps and 1200 timed fixed 1/60 s steps.

| Run order | Monitor | Wall ms | Wall ms/step |
| --- | --- | ---: | ---: |
| 1 | Disabled | 1875 | 1.562500 |
| 2 | Enabled | 1639 | 1.365833 |
| 3 | Disabled | 1179 | 0.982500 |
| 4 | Enabled | 1429 | 1.190833 |

The disabled baseline changes by 696 ms; the first pair reverses the expected
ranking. The second pair's 250 ms difference (0.208333 ms/step) is an observed
pairwise difference, not an isolated causal overhead estimate. These runs do
not establish zero overhead or a stable percentage overhead. The existing user
Native session and independent browser playtest remained running, so scheduling,
clock changes and warm-up can affect these short loops.

All four final vehicle states, telemetry, vehicle metadata and next 32 RNG values
are exactly equal after canonical key ordering. Their combined SHA-256 is
`10d9e42d47f522fd9f847abb3be8286630e5a4f1f46c7d9442e054ce6939e384`.
The frozen and then-current production PerformanceMonitor.lua SHA-256 was
`e23c28bb62aa9e01edb3caf17ee1640e5bcfec005c465a6055746ee8266a5619`.

Enabled runs use actual PerformanceBindings.Attach/Context and monitor
BeginFrame/EndFrame each step. Their in-memory cjson sink serialized 511850 and
511423 bytes respectively (four records each including disposal). This includes
serialization work, but excludes console/file/network log transport. There is
no map, AI, active firing, rendering, HUD or audio. The timers are wall duration;
os.clock has not been verified as thread CPU time. This is not a combat FPS,
Web, mobile or GPU measurement.

All four owned processes exited normally. No production scripts were changed
by this probe. The archived run.ps1 is the original measurement script and uses
the original `.tmp/monitor-overhead-25149307` work path; its snapshot-exists guard
intentionally prevents overwriting prior evidence. The full frozen snapshot and
resource logs were not copied into this compact archive.
