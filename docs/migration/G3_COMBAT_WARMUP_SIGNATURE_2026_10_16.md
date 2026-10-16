# Combat shader-layout candidate

2026-10-16. **CPU-verified candidate; Web shader-set and loading-time acceptance remain open.** Frozen H5 stays `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. Parent owns the next immutable build and actual S3 entry comparison. No gameplay, scene authoring, camera, lighting content, first full restored-world frame or effect stage is changed here.

## Evidence and candidate boundary

The recorded S3 `5b8cf21c` log at `evidence/story-presentation-manifest-5b8cf21c-2026-10-16T01-14-34-240Z/pc.log` has 331 unique compiled shader paths during the public S3 loading entry. CombatWarmup accounts for 157: 135 vertex / 22 pixel, 68 carrying `INSTANCED` / 89 without it. Removing only each final variant hash leaves 58 distinct shader basenames. Some of those are depth, shadow and directional-light variants, so a count of 429 model groups does not mean there are only a handful of point-light shaders.

`engine-docs/recipes/surface-shader.md:635` explicitly distinguishes automatic GPU instancing and single-instance uniform paths. Both must reach the renderer. `.emmylua/Model.d.lua`, `Geometry.d.lua`, `VertexBuffer.d.lua`, `GraphicsDefs.d.lua`, `Material.d.lua` and `Skeleton.d.lua` expose the model geometry, LOD count, vertex stream, complete element description, material and bone information used below. They do not expose the final native shader-selection key. Consequently CPU fixture equality does not replace the actual logged compile-set comparison.

## Conservative implementation

`scripts/render/WarmupSignature.lua` can merge only StaticModel groups satisfying all of these conditions:

- Actual same material object in every slot. This retains its complete SurfaceShader or Technique/pass/define/texture choices. Ordinary materials require exactly one Technique; SurfaceShader materials use the documented separate path, without ordinary Technique LOD.
- Exactly one geometry LOD per slot, zero morphs, zero skeleton bones, outline explicitly disabled and known zone.
- Same ordered geometry-slot count, primitive type, stream count, vertex stride and full ordered element type/semantic/index/perInstance/offset description for every stream. User instance streams, missing APIs/fields and non-array/sparse element results are rejected.
- Same original view/light/shadow/zone masks, castShadows, maxLights, instance-color/custom-data flags, draw/shadow distance, LOD bias, occluder/occludee and occlusion LOD state.

Unsupported kinds, unknown values and native API exceptions retain the original atom untouched. The compacted representative is the original same-model atom with the most retained source instances (maximum four); different models are never combined to impersonate an instanced draw. Both single-source and single-volume scheduling guard shared actual Geometry/material identities against being re-instanced in a combined batch. Known and unknown single groups are separated; unknown groups otherwise preserve their old batching.

The existing one-time full mask hide and incremental exposure ledger remain. Every original source drawable is still retained for complete mask restoration. Volume proxies still use a real representative model and its materials. The first full restored-world shadow frame, four shared effects frames, optional two flash frames, four world point-light/volume stages and cancel/failure Dispose remain.

The begin log prints one summary: `groups`, `originalGroups`, `signatureEligible`, `signatureRejected`, `signatureErrors`, `firstReject`, `firstError`. This must be inspected on the first Web run: a missing binding may correctly cause all groups to fall back, yielding no benefit. There is no per-object logging. The existing constructor option `groupEquivalent=false` preserves old grouping for controlled comparison.

Production SHA256:

| File | SHA256 |
| --- | --- |
| `scripts/render/CombatWarmup.lua` | `251c8a87386aa8ea2f82b744568f873b7c86d2bb7eade367e9815a793fe9b70f` |
| `scripts/render/WarmupSignature.lua` | `ad87945a905d6bad5053cc10c5c1011cbd6bbf7e38fd2a41e2d1f39636485508` |

## Executed CPU checks

`verify-combat-warmup-signature.py` runs the actual production collector and presentation scheduler with strict native-layout adapters. Its supported fixture uses 60 distinct models in four shader/layout classes plus two unsupported original groups. It preserves the fixture's abstract shader obligations for both single/instanced point-world and point-volume paths while reducing 62 groups / 73 presented frames to six groups / 14 frames. These counts are synthetic, not actual S3 results.

3836 assertions pass, including 25 layout/rejection examples, all 15 candidate cancellation boundaries, source-mask/light/effect cleanup, preservation of the largest actual same-model atom, and actual Geometry/material single-batch collision guards. Four mutation controls must fail: omit complete layout, discard the actual instanced atom, accept ordinary material Technique LOD, and permit native re-instancing in the single stage.

Directly dependent AimLines (1272 assertions / 59 lifecycle scenarios), PostUpdate ownership (684 / ten stages), and flash/loading ownership (59 + seven scenarios) reran and pass. The original mask-work equivalence fixture uses intentionally unknown model-layout APIs, so fallback preserves its exact old 156-frame schedule and 475629-to-8798 synthetic setter reduction. Supported-layout compaction is tested separately rather than relabeling old frame-equivalence evidence. Every affected report now binds the new helper's source hash.

Evidence: `evidence/combat-warmup-signature-offline.json`, registered in the unified snapshot auditor. Independent review and actual Web acceptance are recorded by the parent when available. No GPU/build/browser run was performed by this agent.

## Required actual acceptance

1. Freeze the exact two production hashes above into the same immutable package as the other accepted changes. Record candidate identity and one serial public S3 loading entry/return.
2. Check original/compacted/eligible/rejected/error counts. Unknown APIs must fall back; do not invent a compatible return shape. A zero-reduction result is not an optimization delivery.
3. Compare full shader path plus defines against the prior same-route actual set. The prior 331 paths are a reference. Preserve every existing shader obligation, including actual single/instanced depth/shadow/directional/point variants and the restored-world frame's 18 variants. Explain any additions from separately accepted effect fixes; a missing existing variant rejects this candidate.
4. Confirm no new first-use shader stall appears after reveal, first attack or destruction. Confirm original masks and effects restore on normal finish, cancellation, failure and return.
5. Compare actual SceneWarmup / CombatWarmup / reveal timings and wall-frame gaps. Remove the candidate if savings are absent or it moves freezes into gameplay. Audible continuity, full mission parity and mobile sustained performance remain separate acceptance items.
