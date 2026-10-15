# Shell material identity and lifetime candidate

Status: production scripts frozen for the next candidate build. Offline checks PASS;
413 native functional assertions and actual model captures reviewed on October 15.
Whole native validator performance FAIL remains explicit; Web acceptance is open. This change is
not present in the running manifest `706d` candidate tested by the parent.

## Audited write paths

- `PartRig.Attach` starts `armorWhite` slots with `Materials.Get(slot, vis.instanced)`
  and records every shell slot. Weapon and dynamic emission slots are independent.
- `Materials.Get('armorWhite')` returns the exact cached coat base: default color
  `0xcbd1d7`, roughness `0.52`, metallic `0.28`, coat `0.06`, coat roughness `0.52`.
  The unrelated `FIXED.armorWhite` table is not this runtime path.
- Previously `VehicleView.Repaint` cloned this material per colored part and wrote
  only `base_color`. `VehicleView.RemovePart` disposed the private clone.
- No other script reads/writes `vis.shellMaterial`. Weapon animation uses its own
  material collection; restore flash uses separate overlays. These are unchanged.
- `BuildXray.SetBase` updates the preserved original while xray is active. Normal
  bindings use `StaticModel:SetMaterial`. The new helper keeps this exact route.
- Static debris transfer moves the same visual; its material ownership follows
  that visual without acquiring or releasing another reference. Reconstruction,
  cancellation, Clear and Dispose reach the normal RemovePart release path.

## Candidate behavior

`render.ShellMaterials` shares immutable clones by exact base object identity and
exact numeric color, without rounded shader-parameter cache keys. Cloning the
actual base preserves its complete shader, texture, render and parameter state.
Only the clone's initial `base_color` differs. Repaint acquires a different lease,
rebinds all slots and releases the previous lease. Clearing shellColor restores
the exact base. The last owner disposes its clone and removes the pool entry.

Clone parameter or slot binding errors clean up the new allocation. A partial
slot binding failure attempts to restore all previous bindings and keeps the
old lease. Existing private visual materials from script reload are released
through the same replacement/removal path.

The change preserves per-part instance color, variation, authored geometry,
animation, physics, destruction, effect counts, weapon state and gameplay RNG.

## Verification

- `tools/migration/check-shell-materials.py`: 29 checks PASS using production
  ShellMaterials, BuildXray and VehicleView with native object adapters. Tests
  cover cross-vehicle sharing, exact properties, color/base separation, repeated
  repaint, nil/cjson reset, active xray repaint/restore, static debris transfer,
  final-owner release, legacy objects, clone/parameter/bind failure rollback,
  cancelled rebuild, normal teardown, resource/node balance and unchanged RNG.
- Evidence: `evidence/shell-materials-2026-10-15T14-03-14-946820Z/report.json`.
- Existing `check-debris-visual-transfer.py`: 28 checks PASS.
- Evidence: `evidence/debris-visual-transfer-2026-10-15T14-03-14-946820Z/report.json`.
- Scoped `git diff --check`: PASS.

Production SHA256 at freeze:

| File | SHA256 |
| --- | --- |
| scripts/render/ShellMaterials.lua | 00A2BAAD7631537E60E3497D407776197A28D53A8ADA83BAE9D850072EB9484C |
| scripts/render/VehicleView.lua | CAD959AF7AE69A319CFEF87FF66F5AB797E3A158743AE4378DBFA3CA31CA99CF |
| tools/migration/check-shell-materials.lua | AF2C9D8512BC9C9C4FE0156C23E0AF7C8D8867852A68AE570063551CC5269FC5 |
| tools/migration/check-shell-materials.py | 1AC212A342031633F2DAFA5C167F54EB7DF0B2B645F97B9F58501C8DD37C22C6 |

## Runtime acceptance still needed

Use one immutable build containing these hashes. Compare same-color shell parts
before/after on Scorpion/Fox/Trooper and a mech, then repaint one part, toggle
xray, remove/restore parts and return to hangar. Check native material identity,
exact visible colors, no released-material access and no resource growth after
repeat enter/leave. Retest real first-fire/destruction with the existing 100 ms
criterion; offline material deduplication is not evidence that that criterion
passes. The default RaceCar has no explicit shellColor, so this optimization
alone does not explain or fix its historical 1716 batch count.

## Native evidence added at 14:19 UTC

Immutable run: `evidence/shell-materials-native-2026-10-15T14-19-45-009Z`.
The before/after manifest contains all 15 production/fixture hashes; no drift.
Fixture SHA `7666C91302D261204EF0DB2C05699F3EAF7B5B82483C2F3186C26C72213B018E`;
wrapper SHA `1F6833C5348AE6E64C5830E38CC0D9B8C8527CA4776EA6AFF2ABECDD19B8F329`.

- Native test assertions: 413/413 PASS; zero Lua/resource errors.
- Four actual native authored presets: Scorpion 29 eligible colored-shell parts /
  2 materials, Fox 32/1, Trooper 33/2, Manta 10/1. Counts exclude explicit color
  fields whose actual rig has no armorWhite slots; they are not raw catalog counts.
- 22 distinct shell leases reached zero refs through the actual production native
  disposal path. The observer wraps Lua Apply/Release, not native Material methods;
  this is lifecycle-path evidence, not an external GPU allocation profiler.
- Complete native Material SaveJSON comparisons on all four presets differ only
  in `/shaderParameters/base_color`; shader parameters, textures and render state
  retain their exact serialized values. Actual texture-handle assertions pass.
- Eighteen actual 1740x921 rendered PNGs show all four models, individual repaint,
  xray, part restoration and explicit fixture damage before/after. Loading overlay
  is closed and fixture viewport/root ownership is asserted before each capture.
  Contact sheet and pixel-difference crops were independently opened and inspected.
- Actual changed pixels (per-channel delta > 2/255), repaint / xray:
  Scorpion 721/1063; Fox 624/1200; Trooper 5134/10757; Manta 8261/9057.
  Restored material bindings pass exact identity checks; restored pose pixels are
  recorded as informational, not treated as an image-equality acceptance claim.
- Real isolated Scorpion Damage/Flush removed sniper5 part 1557: amount 380,
  wall time 65 ms, vehicle survives. This action creates no debris in this fixture;
  actual shell-material transfer to a debris object is therefore not claimed by
  this native run. Existing offline transfer ownership coverage remains separate.
- Independent review: `independent-review.json`; raw evidence hashes unchanged.
  Derived inspection images: `shell-contact-sheet.png`, `shell-difference-crops.png`.

The overall native validator is still **FAIL**: 338/338 engine errors are precisely
`Frame time spike: ...ms (threshold: 100ms)`, with maximum 1694.15 ms. The earliest
is frame 2 at 100.045 ms, before this fixture first runs at frame 20. There are no
other validator engine error types and no material/GPU shader error in the logs.
Numerous ~100 ms frames are consistent with the hidden/inactive runtime cadence;
the synchronous creation/screenshot fixture and cold boot also remain included.
No attribution to shell GPU cost is established, no old-VehicleView native A/B
was run, and the 100 ms threshold was not raised or filtered. Root chose actual
Web lifecycle measurement as the next performance acceptance surface.

Two startup stderr errors remain recorded separately at frame 0:
`Could not find resource Cube/Day/DaySpecularHDR.dds` and
`Can not load themis_x64.dll.` They are not the 338 validator frame-spike errors.

Two earlier attempts remain retained, explicitly unaccepted: 14:14 UTC failed from
an unsupported native-method observer; 14:17 UTC passed material assertions but
was overlaid by the loading page and its fixture drifted during validator tail
frames. Neither earlier capture is used as rendered-model proof.
