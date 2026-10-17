# Scene warmup batch experiment

Decision: do not merge. Production SceneWarmup retains its default batch size 8.

The derived fixture changes only that default to 32. It uses the unchanged
production public eight-car match and return path plus the existing isolated
NPC respawn check. All runtime and HTTP checks passed; the test browser closed
and the dedicated server stopped. No desktop or mobile FPS claim is made.

| Observation | Prior size 8 | Candidate size 32 |
| --- | ---: | ---: |
| Crater admitted drawables | 1346 | 1359 |
| Scene batches | 169 | 43 |
| Scene warmup wall time | 18613 ms | 17256 ms |
| Largest reported scene slow frame | 1474 ms | 3702 ms |
| Successful compile log records in scene stage | 191 | 196 |

The two public runs have random rosters and differing admitted drawable counts.
They are exploratory observations, not a controlled causal speed comparison.
The candidate does not establish improved responsiveness: the observed longest
loading stall is substantially worse, and total warmup time remains high.
Fewer presented batches alone is not evidence that shader/driver costs disappear.
No repeated full-map performance run is justified before a more specific cause
or a better candidate is available.

Inputs: `evidence/respawn-cache-web-17ca-1017-b/runtime.log` and
`evidence/scene-batch32-17ca-c/runtime.log`; both original reports are retained.
The log-only slow-frame analysis had zero JSON parse failures in these stages.
The native compile records identify compiler output and ordering, not exclusive
CPU or GPU compilation duration. Tool: `tools/migration/prepare-scene-batch-candidate.cjs`.
