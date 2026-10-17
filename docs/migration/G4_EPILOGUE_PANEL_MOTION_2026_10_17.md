# G4 epilogue panel motion

Baseline: frozen H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
Source `three/src/battle/storyEpilogue.js` SHA-256:
`fd082457e061957f83df9e2c251b819d4e6b3aec9114481aacf445bab79b165b`.

## Narrow Change

- Panel entrance now follows the original 320 ms `cubic-bezier(.2,.9,.3,1.05)` for translation, rotation and opacity. Rotation uses the panel center, matching the DOM transform origin.
- Impact text follows the original delayed 220 ms `cubic-bezier(.2,.9,.3,1.3)` for scale, rotating from the final angle minus 12 degrees, and opacity. Original 160 / 1650 ms delays remain.
- Character float follows the original 1600 ms `cubic-bezier(.2,.8,.2,1)` over 2% of its character container height, including zoom portraits.

Production ownership is limited to `scripts/ui/Epilogue.lua` and `EpilogueMotion.lua`. No loading, performance, opening decision, audio policy or gameplay changes.

## Executed Checks

`check-epilogue-panel-motion.py` executes the complete hash-verified frozen `playEpilogue` under DOM/WAAPI recording adapters, independently evaluates the authored curves, and executes actual Lua motion and Render. It checks transformed draw matrices, opacity and portrait image placement at 48 sampled times: **1570 checks PASS**, seven mutations rejected. The actual frozen `17ca8a04` renderer also fails the centered-transform assertion, establishing a historical behavioral negative control.

`verify-epilogue-stamp-motion.py`: **51 checks PASS**, retaining approval stamp, final stamp/outro and early-skip behavior.

Two existing regression tools were attempted and their limitations retained:

- `check-epilogue-pages.py` executes its 264 positive checks and four mutation controls, then fails its stale assumption that the current Git HEAD lacks the already committed page-lifecycle repair. This is not recorded as a full tool PASS.
- `verify-story-choice-epilogue.py` fails fixture initialization because a newer top-level SpawnViewCache dependency reaches Config / ResourceData without a fixture cache adapter. It does not reach a behavioral assertion for this change.

Evidence: `evidence/epilogue-panel-motion-offline.json` and freshly rerun `evidence/epilogue-stamp-motion-offline.json`.

## Rendered Checks Executed

Root ran the isolated fixture derived from unified production `e119fabb`, `.tmp/outgame-cached-1792197751695/identity.json`. Its derived fixture is `.tmp/epilogue-panel-motion-1017-e119`, manifest `26081867`. This lane reread both reports and verified their reported HTTP module hashes against the current production bytes and the unified frozen identity; both modules match the candidate hashes below.

| Evidence directory | Viewport | Result | Stages | Runtime / HTTP errors | Shutdown | Minimum non-dark pixels |
| --- | --- | --- | --- | --- | --- | --- |
| `evidence/epilogue-panel-motion-e119-1600` | 1600 x 900 | PASS | 8 | 0 / 0 | CLOSED | 329,514 |
| `evidence/epilogue-panel-motion-e119-2000` | 2000 x 900 | PASS | 8 | 0 / 0 | CLOSED | 410,261 |

Each report contains the eight screenshot hashes, decoded artwork handles and dimensions, canvas visibility checks, and differing image hashes for each middle/end pair. Root owns visual inspection of these actual screenshots; this lane does not claim an additional inspection. These are **fixed-time presentation checks**, not natural fifth-mission completion, an audio playback test, continuous ending timing or mobile performance acceptance. The actual Web renderer ran, while normal App/gameplay/audio and saves were deliberately outside the fixture.

## Reproduction

The fixture extends the existing `ResourceGate -> UI.Init -> staged production render -> F8 acknowledgement -> cleanup` pattern. It displays eight actual authored panel stages: entrance middle/end, impact overshoot/end, zoom portrait float/end, and contract impact middle/end. Runtime/source HTTP hashes, decoded artwork handles, nonblank canvas, distinct animation images and release are required. Synthetic clocks deliberately isolate these presentations; this is not natural ending, audio or performance acceptance.

After the root creates a new unified frozen build containing both tested module hashes:

```powershell
node tools/migration/epilogue-panel-motion-prepare.cjs --frozen <new-identity> --out .tmp/epilogue-panel-motion-1017
node tools/migration/g1-web-cpu-serve.cjs .tmp/epilogue-panel-motion-1017/identity.json <port>
node tools/migration/epilogue-panel-motion-run.cjs http://127.0.0.1:<port> docs/migration/evidence/epilogue-panel-motion-pc 1600 900
node tools/migration/epilogue-panel-motion-run.cjs http://127.0.0.1:<port> docs/migration/evidence/epilogue-panel-motion-wide 2000 900
```

The prepare gate refuses a frozen build missing the offline-tested fixes. No hardware/server launch, commit or upload was performed by this lane; root executed the two runs above and owns screenshot inspection.

Frozen candidate production hashes:

```text
ui/Epilogue.lua ecc9a3a41a73fcd15b69c079f9f24a7fc645d25e953964b6f7bf066bd868f898
ui/EpilogueMotion.lua eff15586196694211b55d1de67a9d30a4240f26894fa1b52cf30b024ddf7e11d
```
